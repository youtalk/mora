import Foundation
import MoraCore
import Observation

@Observable
@MainActor
public final class SessionOrchestrator {
    public private(set) var phase: ADayPhase = .notStarted
    public private(set) var warmupMissCount: Int = 0
    public private(set) var trials: [TrialAssessment] = []
    public private(set) var sentenceIndex: Int = 0
    public private(set) var sessionStartedAt: Date?
    public private(set) var pendingChains: [WordChain] = []
    public private(set) var completedTrialCount: Int = 0
    private var currentTrialInChain: Int = 0
    private var phaseMetrics: TileBoardMetrics = TileBoardMetrics()
    private var phaseTotalTrialCount: Int = 0
    private var cachedTileBoardEngine: TileBoardEngine?

    public var currentChainRole: ChainRole {
        pendingChains.first?.role ?? .mixedApplication
    }

    /// One pip per trial across the loaded phase. Length tracks the actual
    /// chain configuration, not a hardcoded 12 — chains may be shorter than
    /// four words when the library is sparse.
    public var chainPipStates: [ChainPipStateOrchestratorValue] {
        let total = phaseTotalTrialCount
        guard total > 0 else { return [] }
        let done = completedTrialCount
        return (0..<total).map { i in
            if i < done { return .done }
            if i == done { return .active }
            return .pending
        }
    }

    /// Returns the engine driving the current trial, or `nil` if no chain is
    /// active. The instance is cached and survives view re-renders so trial
    /// state (`@Observable` properties, drop attempts, scaffold misses) is
    /// preserved between SwiftUI body invocations. The cache is invalidated
    /// when the trial advances or a new phase begins.
    public var currentTileBoardEngine: TileBoardEngine? {
        if let cached = cachedTileBoardEngine { return cached }
        guard let chain = pendingChains.first else { return nil }
        let engine = makeEngine(for: currentTrialInChain, in: chain)
        cachedTileBoardEngine = engine
        return engine
    }

    private func makeEngine(for trialIndex: Int, in chain: WordChain) -> TileBoardEngine {
        if trialIndex == 0 {
            let pool = TilePoolPolicy.buildFromWord(word: chain.head.word, extraDistractors: 2)
                .resolve(distractorsPool: taughtGraphemes)
            return TileBoardEngine(trial: .build(target: chain.head, pool: pool))
        } else {
            let change = chain.successors[trialIndex - 1]
            let lockedSlots = change.predecessor.graphemes
            let pool =
                TilePoolPolicy
                .changeSlot(
                    correct: change.newGrapheme,
                    kind: TileKind(grapheme: change.newGrapheme),
                    extraDistractors: 3
                )
                .resolve(distractorsPool: taughtGraphemes)
            return TileBoardEngine(trial: .change(target: change, lockedSlots: lockedSlots, pool: pool))
        }
    }

    public let target: Target
    public let taughtGraphemes: Set<Grapheme>
    public let warmupOptions: [Grapheme]
    public let chainProvider: any WordChainProvider
    public let sentences: [DecodeSentence]
    public let yokai: YokaiOrchestrator?

    /// Callback for tile-board phase events. Wired up by the UI so that
    /// chain-finished and phase-finished transitions can trigger scene
    /// transitions without polling state.
    public var onTileBoardEvent: ((OrchestratorEvent) -> Void)?

    private let assessment: AssessmentEngine
    private let clock: @Sendable () -> Date

    public init(
        target: Target,
        taughtGraphemes: Set<Grapheme>,
        warmupOptions: [Grapheme],
        chainProvider: any WordChainProvider,
        sentences: [DecodeSentence],
        assessment: AssessmentEngine,
        clock: @escaping @Sendable () -> Date = Date.init,
        yokai: YokaiOrchestrator? = nil
    ) {
        self.target = target
        self.taughtGraphemes = taughtGraphemes
        self.warmupOptions = warmupOptions
        self.chainProvider = chainProvider
        self.sentences = sentences
        self.assessment = assessment
        self.clock = clock
        self.yokai = yokai
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
        case .decoding:
            do {
                pendingChains = try chainProvider.generatePhase(
                    target: target.grapheme ?? Grapheme(letters: ""),
                    masteredSet: taughtGraphemes
                )
                phaseMetrics = TileBoardMetrics(chainCount: pendingChains.count)
                phaseTotalTrialCount = pendingChains.reduce(0) { $0 + 1 + $1.successors.count }
                currentTrialInChain = 0
                completedTrialCount = 0
                cachedTileBoardEngine = nil
            } catch {
                // Content gap: surface a phase-finished event so subscribers
                // get a deterministic signal, then fall through to
                // shortSentences so the session does not stall.
                phaseMetrics.truncatedChainCount = phaseMetrics.chainCount
                onTileBoardEvent?(.phaseFinished(phaseMetrics))
                transitionTo(.shortSentences)
            }
        case .shortSentences where sentences.isEmpty:
            transitionTo(.completion)
        default:
            break
        }
    }

    public func consumeTileBoardTrial(_ result: TileBoardTrialResult) {
        guard let chain = pendingChains.first else { return }

        // Record a TrialAssessment using the actual TrialAssessment shape.
        let trial = TrialAssessment(
            expected: result.word,
            heard: result.word.surface,
            correct: true,
            errorKind: .none,
            l1InterferenceTag: nil
        )
        trials.append(trial)
        yokai?.recordTrialOutcome(correct: trial.correct)
        phaseMetrics.totalDropMisses += result.buildAttempts.filter { !$0.wasCorrect }.count
        if result.autoFilled { phaseMetrics.autoFillCount += 1 }

        let assessmentRecording = TrialRecording(
            asr: ASRResult(transcript: result.word.surface, confidence: 1.0),
            audio: .empty,
            buildAttempts: result.buildAttempts,
            scaffoldLevel: result.scaffoldLevel
        )
        onTileBoardEvent?(.tileBoardTrialCompleted(assessmentRecording))
        completedTrialCount += 1
        currentTrialInChain += 1
        cachedTileBoardEngine = nil

        if currentTrialInChain > chain.successors.count {
            // Chain finished.
            onTileBoardEvent?(.chainFinished(chain.role))
            pendingChains.removeFirst()
            currentTrialInChain = 0
            if pendingChains.isEmpty {
                onTileBoardEvent?(.phaseFinished(phaseMetrics))
                transitionTo(.shortSentences)
            }
        }
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
            yokai?.recordTrialOutcome(correct: trial.correct)
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
            yokai?.recordTrialOutcome(correct: correct)
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

    #if DEBUG
    /// Dev-only: abandons any remaining tile-board chains and jumps
    /// straight to the ShortSentences phase so Engine A/B paths can be
    /// reached in a handful of taps during on-device iteration. Emits a
    /// `phaseFinished` event with the chain count marked truncated so the
    /// summary stays internally consistent. Never exposed in Release
    /// builds — see the `#if DEBUG` guard at the declaration.
    public func debugSkipDecoding() {
        guard phase == .decoding else { return }
        phaseMetrics.truncatedChainCount = phaseMetrics.chainCount
        pendingChains.removeAll()
        onTileBoardEvent?(.phaseFinished(phaseMetrics))
        transitionTo(.shortSentences)
    }
    #endif
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
