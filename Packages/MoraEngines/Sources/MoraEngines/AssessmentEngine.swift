import Foundation
import MoraCore

public enum AssessmentLeniency: Sendable {
    case newWord
    case mastered
}

/// Result of evaluating a learner's full read-aloud against a `DecodeSentence`.
/// Compared to the per-word `TrialAssessment`, this carries token-coverage
/// counts so callers (orchestrator, future telemetry) can reason about how
/// much of the sentence was actually read — the sentence is accepted as
/// "correct" when coverage clears the leniency-specific threshold and the
/// ASR confidence is above the floor.
public struct SentenceAssessment: Sendable, Equatable {
    public let correct: Bool
    public let coverage: Double
    public let matchedTokenCount: Int
    public let expectedTokenCount: Int

    public init(
        correct: Bool,
        coverage: Double,
        matchedTokenCount: Int,
        expectedTokenCount: Int
    ) {
        self.correct = correct
        self.coverage = coverage
        self.matchedTokenCount = matchedTokenCount
        self.expectedTokenCount = expectedTokenCount
    }
}

public struct AssessmentEngine: Sendable {
    public let l1Profile: any L1Profile
    public let evaluator: any PronunciationEvaluator
    /// 0.0 = strictest, 1.0 = most lenient. Pre-dates the `AssessmentLeniency`
    /// enum; left in place for the current test suite and the future
    /// AdaptivePlanEngine refactor that will consolidate leniency semantics.
    public let leniency: Double

    public init(
        l1Profile: any L1Profile,
        evaluator: any PronunciationEvaluator = NullPronunciationEvaluator(),
        leniency: Double = 0.5
    ) {
        self.l1Profile = l1Profile
        self.evaluator = evaluator
        self.leniency = leniency
    }

    /// Backwards-compatible entry point: same as `.mastered`.
    public func assess(expected: Word, asr: ASRResult) -> TrialAssessment {
        assess(expected: expected, asr: asr, leniency: .mastered)
    }

    /// Three-argument form used by `SessionOrchestrator` in v1 (always `.newWord`
    /// until mastery tracking lands). `.newWord` accepts one extra edit-distance
    /// unit and lowers the confidence floor; `.mastered` uses the strict path.
    public func assess(
        expected: Word,
        asr: ASRResult,
        leniency: AssessmentLeniency
    ) -> TrialAssessment {
        let normalized = normalize(asr.transcript)
        let target = expected.surface.lowercased()

        if normalized.isEmpty {
            return TrialAssessment(
                expected: expected, heard: asr.transcript,
                correct: false, errorKind: .omission,
                l1InterferenceTag: nil
            )
        }
        if normalized == target {
            return TrialAssessment(
                expected: expected, heard: asr.transcript,
                correct: true, errorKind: .none,
                l1InterferenceTag: nil
            )
        }

        // Leniency-aware path: for .newWord, accept the transcript as
        // correct when it is within one edit of the target AND the ASR
        // confidence is at least 0.25 (i.e. not a stab in the dark).
        if leniency == .newWord {
            if editDistance(normalized, target) <= 1 && asr.confidence >= 0.25 {
                return TrialAssessment(
                    expected: expected, heard: asr.transcript,
                    correct: true, errorKind: .none,
                    l1InterferenceTag: nil
                )
            }
        }

        let (errorKind, l1Tag) = classify(
            expected: expected, heardNormalized: normalized
        )
        return TrialAssessment(
            expected: expected, heard: asr.transcript,
            correct: false, errorKind: errorKind,
            l1InterferenceTag: l1Tag
        )
    }

    /// Recording-aware entry point used by the pronunciation-feedback pipeline.
    /// Builds the transcript-only baseline via the synchronous overload, then
    /// consults `evaluator` when the word carries a `targetPhoneme` the
    /// evaluator can score. The returned `TrialAssessment` only gains a
    /// `phoneme` payload when both conditions are true — otherwise this is a
    /// pure pass-through of the baseline and preserves existing behavior.
    public func assess(
        expected: Word,
        recording: TrialRecording,
        leniency: AssessmentLeniency
    ) async -> TrialAssessment {
        let baseline = assess(expected: expected, asr: recording.asr, leniency: leniency)
        guard let target = expected.targetPhoneme else { return baseline }
        guard evaluator.supports(target: target, in: expected) else { return baseline }
        let phoneme = await evaluator.evaluate(
            audio: recording.audio,
            expected: expected,
            targetPhoneme: target,
            asr: recording.asr
        )
        return TrialAssessment(
            expected: baseline.expected,
            heard: baseline.heard,
            correct: baseline.correct,
            errorKind: baseline.errorKind,
            l1InterferenceTag: baseline.l1InterferenceTag,
            phoneme: phoneme
        )
    }

    /// Sentence-level read-aloud assessment. Tokenizes both the expected
    /// `DecodeSentence` (using its `words` field) and the heard ASR
    /// transcript, then greedily pairs each expected token to a heard
    /// token within edit distance 1. The sentence is accepted when
    /// `matched / expected >= threshold` and ASR confidence clears the
    /// floor for the chosen leniency.
    ///
    /// Thresholds (April 2026 calibration against on-device th-voiceless
    /// session: Apple ASR's per-token confidence collapses to 0.0–0.1
    /// whenever the silence-driven cancel path produces the final
    /// transcript, so a strict floor would reject reads that cleared
    /// coverage. Coverage 0.6 lets a 4-of-7 word read pass — the
    /// pedagogical bar is "did the learner read most of the sentence",
    /// not "did Apple ASR transcribe it perfectly"):
    ///   - `.newWord`: coverage ≥ 0.6, confidence ≥ 0.10
    ///   - `.mastered`: coverage ≥ 0.85, confidence ≥ 0.50
    public func assessSentence(
        expected: DecodeSentence,
        asr: ASRResult,
        leniency: AssessmentLeniency
    ) -> SentenceAssessment {
        let expectedTokens = expected.words.map { $0.surface.lowercased() }
        let heardTokens = tokenizeTranscript(asr.transcript)

        guard !expectedTokens.isEmpty else {
            return SentenceAssessment(
                correct: false, coverage: 0,
                matchedTokenCount: 0, expectedTokenCount: 0
            )
        }

        // Greedy left-to-right pairing: each heard token can satisfy at
        // most one expected token. Cheap and deterministic — for typical
        // 4-7 word A-day sentences the input is small enough that the
        // O(n*m) walk does not warrant a Hungarian-style optimal match.
        var remainingHeard = heardTokens
        var matched = 0
        for token in expectedTokens {
            if let idx = remainingHeard.firstIndex(where: { editDistance($0, token) <= 1 }) {
                remainingHeard.remove(at: idx)
                matched += 1
            }
        }
        let coverage = Double(matched) / Double(expectedTokens.count)

        let coverageThreshold: Double
        let confidenceFloor: Double
        switch leniency {
        case .newWord:
            coverageThreshold = 0.6
            confidenceFloor = 0.10
        case .mastered:
            coverageThreshold = 0.85
            confidenceFloor = 0.50
        }

        let correct =
            matched > 0
            && coverage >= coverageThreshold
            && asr.confidence >= confidenceFloor
        return SentenceAssessment(
            correct: correct,
            coverage: coverage,
            matchedTokenCount: matched,
            expectedTokenCount: expectedTokens.count
        )
    }

    /// Lowercases, splits on whitespace, strips outer punctuation per
    /// token, drops empty entries. Mirrors the per-token shape of
    /// `Word.surface` so comparisons line up with `expected.words`.
    private func tokenizeTranscript(_ s: String) -> [String] {
        let punctuation = CharacterSet(charactersIn: ".,!?;:\"'()[]")
        return s.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: punctuation) }
            .filter { !$0.isEmpty }
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
    }

    private func classify(expected: Word, heardNormalized: String) -> (TrialErrorKind, String?) {
        // v1 heuristic: compare expected grapheme count to heard character count.
        // Each char of free-text ASR output is treated as one grapheme-sized unit,
        // and Word.graphemes already encodes digraphs like "sh" as a single entry,
        // so "ship" (3 graphemes) misread as "sip" (3 chars) registers as a
        // substitution rather than the spurious omission a raw letter-count diff
        // would produce.
        let expectedUnits = expected.graphemes.count
        let heardUnits = heardNormalized.count
        let diff = heardUnits - expectedUnits
        let kind: TrialErrorKind
        if diff > 0 {
            kind = .insertion
        } else if diff < 0 {
            kind = .omission
        } else {
            kind = .substitution
        }

        let tag = l1InterferenceTag(
            expected: expected,
            heardNormalized: heardNormalized
        )
        return (kind, tag)
    }

    private func l1InterferenceTag(expected: Word, heardNormalized: String) -> String? {
        guard let expectedOnset = expected.phonemes.first else { return nil }
        guard let heardOnset = inferHeardOnset(heardNormalized) else { return nil }
        return l1Profile.matchInterference(expected: expectedOnset, heard: heardOnset)?.tag
    }

    // For v1, infer the onset phoneme from the first character of the heard word
    // using a small Latin-to-IPA map that covers the phonemes relevant to the
    // Japanese L1 profile (r, l, f, h, v, b, s, t). v1.5 will replace this with
    // a richer phoneme-level alignment using the full segmentation in
    // Word.phonemes; this narrow coverage is intentional, not a bug.
    private func inferHeardOnset(_ heard: String) -> Phoneme? {
        guard let first = heard.first else { return nil }
        switch first {
        case "r": return Phoneme(ipa: "r")
        case "l": return Phoneme(ipa: "l")
        case "f": return Phoneme(ipa: "f")
        case "h": return Phoneme(ipa: "h")
        case "v": return Phoneme(ipa: "v")
        case "b": return Phoneme(ipa: "b")
        case "s": return Phoneme(ipa: "s")
        case "t": return Phoneme(ipa: "t")
        default: return nil
        }
    }

    /// Iterative Levenshtein distance over Swift's Character collection.
    /// Inlined here rather than in a shared utility — it is only used by
    /// the leniency branch and small enough that a helper obscures flow.
    private func editDistance(_ a: String, _ b: String) -> Int {
        let ac = Array(a)
        let bc = Array(b)
        if ac.isEmpty { return bc.count }
        if bc.isEmpty { return ac.count }
        var prev = Array(0...bc.count)
        var curr = Array(repeating: 0, count: bc.count + 1)
        for i in 1...ac.count {
            curr[0] = i
            for j in 1...bc.count {
                let cost = ac[i - 1] == bc[j - 1] ? 0 : 1
                curr[j] = min(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[bc.count]
    }
}

/// Default evaluator used when no pronunciation pipeline is wired. Returns
/// `supports = false` for every target, so `AssessmentEngine` falls back to
/// transcript-only assessment — preserving pre-v1.5 behavior for call sites
/// that have not yet been updated to inject a real evaluator.
public struct NullPronunciationEvaluator: PronunciationEvaluator {
    public init() {}

    public func supports(target: Phoneme, in word: Word) -> Bool { false }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: [:],
            isReliable: false
        )
    }
}
