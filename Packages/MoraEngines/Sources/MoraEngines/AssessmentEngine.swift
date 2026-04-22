import Foundation
import MoraCore

public struct AssessmentEngine: Sendable {
    public let l1Profile: any L1Profile
    /// 0.0 = strictest (exact match required), 1.0 = most lenient.
    /// Reserved for the v1.5 swap to real ASR, where it will gate
    /// confidence thresholds and edit-distance tolerance. The current
    /// fake-ASR scoring path treats every transcript as definitive
    /// and ignores this value.
    public let leniency: Double

    public init(l1Profile: any L1Profile, leniency: Double = 0.5) {
        self.l1Profile = l1Profile
        self.leniency = leniency
    }

    public func assess(expected: Word, asr: ASRResult) -> TrialAssessment {
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

        let (errorKind, l1Tag) = classify(
            expected: expected,
            heardNormalized: normalized
        )
        return TrialAssessment(
            expected: expected, heard: asr.transcript,
            correct: false, errorKind: errorKind,
            l1InterferenceTag: l1Tag
        )
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
}
