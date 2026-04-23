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

        case (.decoding, .answerHeard(let recording)):
            await handleDecodingHeard(recording: recording)
        case (.decoding, .answerManual(let correct)):
            handleDecodingManual(correct: correct)

        case (.shortSentences, .answerHeard(let recording)):
            await handleSentenceHeard(recording: recording)
        case (.shortSentences, .answerManual(let correct)):
            handleSentenceManual(correct: correct)

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

    private func handleDecodingHeard(recording: TrialRecording) async {
        guard wordIndex < words.count else {
            transitionTo(.shortSentences)
            return
        }
        let expected = words[wordIndex].word
        let trial = await assessment.assess(
            expected: expected,
            recording: recording,
            leniency: .newWord
        )
        trials.append(trial)
        wordIndex += 1
        if wordIndex >= words.count { transitionTo(.shortSentences) }
    }

    private func handleDecodingManual(correct: Bool) {
        guard wordIndex < words.count else {
            transitionTo(.shortSentences)
            return
        }
        let expected = words[wordIndex].word
        trials.append(manualTrial(expected: expected, correct: correct))
        wordIndex += 1
        if wordIndex >= words.count { transitionTo(.shortSentences) }
    }

    private func handleSentenceHeard(recording: TrialRecording) async {
        guard sentenceIndex < sentences.count else {
            transitionTo(.completion)
            return
        }
        let sentence = sentences[sentenceIndex]
        let targetGrapheme = target.skill.graphemePhoneme?.grapheme
        let expected =
            sentence.words.first { w in
                guard let g = targetGrapheme else { return true }
                return w.graphemes.contains(g)
            } ?? sentence.words.first
        if let expected {
            let trial = await assessment.assess(
                expected: expected,
                recording: recording,
                leniency: .newWord
            )
            trials.append(trial)
        }
        sentenceIndex += 1
        if sentenceIndex >= sentences.count { transitionTo(.completion) }
    }

    private func handleSentenceManual(correct: Bool) {
        guard sentenceIndex < sentences.count else {
            transitionTo(.completion)
            return
        }
        let sentence = sentences[sentenceIndex]
        let targetGrapheme = target.skill.graphemePhoneme?.grapheme
        let expected =
            sentence.words.first { w in
                guard let g = targetGrapheme else { return true }
                return w.graphemes.contains(g)
            } ?? sentence.words.first
        if let expected {
            trials.append(manualTrial(expected: expected, correct: correct))
        }
        sentenceIndex += 1
        if sentenceIndex >= sentences.count { transitionTo(.completion) }
    }

    /// Manual Correct/Wrong taps bypass ASR entirely and record a trial
    /// that mirrors `correct == true` → clean pass, `correct == false` →
    /// `.omission` with empty heard transcript. This keeps the summary
    /// consistent when dev-mode tap mode is used, independent of whatever
    /// (if any) ASR transcript was active on screen.
    private func manualTrial(expected: Word, correct: Bool) -> TrialAssessment {
        TrialAssessment(
            expected: expected,
            heard: correct ? expected.surface : "",
            correct: correct,
            errorKind: correct ? .none : .omission,
            l1InterferenceTag: nil
        )
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
