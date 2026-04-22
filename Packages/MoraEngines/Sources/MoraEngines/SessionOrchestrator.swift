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
        phase = .warmup
    }

    public func handle(_ event: OrchestratorEvent) async {
        switch (phase, event) {
        case (.warmup, .warmupTap(let g)):
            if let targetG = target.skill.graphemePhoneme?.grapheme, g == targetG {
                phase = .newRule
            } else {
                warmupMissCount += 1
            }

        case (.newRule, .advance):
            phase = .decoding

        case (.decoding, .answerResult(let correct, let asr)):
            handleDecodingAnswer(correct: correct, asr: asr)

        case (.shortSentences, .answerResult(let correct, let asr)):
            handleSentenceAnswer(correct: correct, asr: asr)

        case (.completion, _):
            break

        case (_, .advance):
            // Fallback advance: move forward one phase.
            advanceCurrentPhase()

        default:
            break
        }
    }

    private func advanceCurrentPhase() {
        switch phase {
        case .notStarted: phase = .warmup
        case .warmup: phase = .newRule
        case .newRule: phase = .decoding
        case .decoding: phase = .shortSentences
        case .shortSentences: phase = .completion
        case .completion: break
        }
    }

    private func handleDecodingAnswer(correct: Bool, asr: ASRResult?) {
        guard wordIndex < words.count else { return }
        let expected = words[wordIndex].word
        trials.append(makeTrial(expected: expected, correct: correct, asr: asr))
        wordIndex += 1
        if wordIndex >= words.count { phase = .shortSentences }
    }

    private func handleSentenceAnswer(correct: Bool, asr: ASRResult?) {
        guard sentenceIndex < sentences.count else { return }
        let sentence = sentences[sentenceIndex]
        // First word in the sentence that contains the target grapheme is
        // the one the trial assesses against. Fallback: the sentence's first word.
        let targetGrapheme = target.skill.graphemePhoneme?.grapheme
        let expected =
            sentence.words.first { w in
                guard let g = targetGrapheme else { return true }
                return w.graphemes.contains(g)
            } ?? sentence.words.first!
        trials.append(makeTrial(expected: expected, correct: correct, asr: asr))
        sentenceIndex += 1
        if sentenceIndex >= sentences.count { phase = .completion }
    }

    /// The dev-mode "Correct"/"Wrong" buttons treat the `correct` flag as the
    /// source of truth — when correct, we record a clean pass even if the
    /// supplied ASRResult would have failed the engine's match. On a miss we
    /// hand off to AssessmentEngine so error kind and L1 interference tagging
    /// stay accurate.
    private func makeTrial(expected: Word, correct: Bool, asr: ASRResult?) -> TrialAssessment {
        if correct {
            return TrialAssessment(
                expected: expected,
                heard: asr?.transcript ?? expected.surface,
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
