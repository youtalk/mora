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

    // Placeholders filled by Task 24:
    private func handleDecodingAnswer(correct: Bool, asr: ASRResult?) {}
    private func handleSentenceAnswer(correct: Bool, asr: ASRResult?) {}
}
