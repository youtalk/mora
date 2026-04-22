import Foundation
import MoraCore
import Observation

@Observable
@MainActor
public final class SessionOrchestrator {
    public private(set) var phase: ADayPhase = .notStarted
    public private(set) var warmupMissCount: Int = 0
    public private(set) var trials: [TrialAssessment] = []
    public private(set) var wordIndex: Int = 0
    public private(set) var sentenceIndex: Int = 0
    public private(set) var sessionStartedAt: Date?

    public let target: Target
    public let taughtGraphemes: Set<Grapheme>
    public let warmupOptions: [Grapheme]
    public let words: [DecodeWord]
    public let sentences: [DecodeSentence]

    private let assessment: AssessmentEngine
    private let clock: @Sendable () -> Date

    public init(
        target: Target,
        taughtGraphemes: Set<Grapheme>,
        warmupOptions: [Grapheme],
        words: [DecodeWord],
        sentences: [DecodeSentence],
        assessment: AssessmentEngine,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.target = target
        self.taughtGraphemes = taughtGraphemes
        self.warmupOptions = warmupOptions
        self.words = words
        self.sentences = sentences
        self.assessment = assessment
        self.clock = clock
    }

    public func start() async {
        guard phase == .notStarted else { return }
        sessionStartedAt = clock()
        transitionTo(.warmup)
    }

    public func handle(_ event: OrchestratorEvent) async {
        switch (phase, event) {
        case (.warmup, .warmupTap(let g)):
            if let targetG = target.skill.graphemePhoneme?.grapheme, g == targetG {
                transitionTo(.newRule)
            } else {
                warmupMissCount += 1
            }

        case (.newRule, .advance):
            transitionTo(.decoding)

        case (.decoding, .answerResult(let correct, let asr)):
            handleDecodingAnswer(correct: correct, asr: asr)

        case (.shortSentences, .answerResult(let correct, let asr)):
            handleSentenceAnswer(correct: correct, asr: asr)

        default:
            // Other (phase, event) pairs — including .advance outside .newRule
            // — are intentionally ignored so the gated state machine can't be
            // skipped (e.g., bypassing warmup with a stray .advance event).
            break
        }
    }

    /// Sets `phase` and immediately skips through any subsequent phase whose
    /// queue is empty, so the orchestrator can never get stuck waiting for an
    /// answer that has no question to ask.
    private func transitionTo(_ newPhase: ADayPhase) {
        phase = newPhase
        switch phase {
        case .decoding where words.isEmpty:
            transitionTo(.shortSentences)
        case .shortSentences where sentences.isEmpty:
            transitionTo(.completion)
        default:
            break
        }
    }

    private func handleDecodingAnswer(correct: Bool, asr: ASRResult?) {
        guard wordIndex < words.count else {
            transitionTo(.shortSentences)
            return
        }
        let expected = words[wordIndex].word
        trials.append(makeTrial(expected: expected, correct: correct, asr: asr))
        wordIndex += 1
        if wordIndex >= words.count { transitionTo(.shortSentences) }
    }

    private func handleSentenceAnswer(correct: Bool, asr: ASRResult?) {
        guard sentenceIndex < sentences.count else {
            transitionTo(.completion)
            return
        }
        let sentence = sentences[sentenceIndex]
        // Pick the first word that contains the target grapheme; fall back to
        // the sentence's first word. If the sentence has no words at all
        // (malformed content), skip it without recording a trial rather than
        // force-unwrapping into a crash.
        let targetGrapheme = target.skill.graphemePhoneme?.grapheme
        let expected =
            sentence.words.first { w in
                guard let g = targetGrapheme else { return true }
                return w.graphemes.contains(g)
            } ?? sentence.words.first
        if let expected {
            trials.append(makeTrial(expected: expected, correct: correct, asr: asr))
        }
        sentenceIndex += 1
        if sentenceIndex >= sentences.count { transitionTo(.completion) }
    }

    /// The dev-mode "Correct"/"Wrong" buttons treat the `correct` flag as the
    /// source of truth — when correct, we record a clean pass with `heard`
    /// pinned to `expected.surface` (the supplied ASR transcript may be
    /// stale or empty in dev mode and would otherwise produce inconsistent
    /// rows like correct=true / heard="x"). On a miss we hand off to
    /// AssessmentEngine so error kind and L1 interference tagging stay
    /// accurate against the actual transcript.
    private func makeTrial(expected: Word, correct: Bool, asr: ASRResult?) -> TrialAssessment {
        if correct {
            return TrialAssessment(
                expected: expected,
                heard: expected.surface,
                correct: true,
                errorKind: .none,
                l1InterferenceTag: nil
            )
        }
        let effectiveAsr = asr ?? ASRResult(transcript: "", confidence: 0)
        return assessment.assess(expected: expected, asr: effectiveAsr)
    }
}

public struct SessionSummary: Hashable, Sendable {
    public let sessionType: SessionType
    public let targetSkillCode: SkillCode
    public let durationSec: Int
    public let trialsTotal: Int
    public let trialsCorrect: Int
    public let struggledSkillCodes: [SkillCode]
    public let escalated: Bool
}

extension SessionOrchestrator {
    public func sessionSummary(endedAt: Date) -> SessionSummary {
        let duration = Int(max(0, endedAt.timeIntervalSince(sessionStartedAt ?? endedAt)))
        let correct = trials.filter(\.correct).count
        let struggled: [SkillCode] =
            trials.contains { !$0.correct }
            ? [target.skill.code]
            : []
        return SessionSummary(
            sessionType: .coreDecoder,
            targetSkillCode: target.skill.code,
            durationSec: duration,
            trialsTotal: trials.count,
            trialsCorrect: correct,
            struggledSkillCodes: struggled,
            escalated: false
        )
    }
}
