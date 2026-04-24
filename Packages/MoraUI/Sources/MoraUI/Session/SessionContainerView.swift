import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

private let persistLog = Logger(subsystem: "tech.reenable.Mora", category: "Persistence")
private let speechLog = Logger(subsystem: "tech.reenable.Mora", category: "Speech")

public enum SessionUIMode: Equatable, Sendable {
    case tap
    case mic
}

public struct SessionContainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.moraStrings) private var strings
    @Environment(\.shadowEvaluatorFactory) private var shadowEvaluatorFactory
    @Query(sort: \DailyStreak.lastCompletedOn, order: .reverse)
    private var streaks: [DailyStreak]
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?
    @State private var feedback: FeedbackState = .none
    @State private var uiMode: SessionUIMode = .tap
    @State private var speechEngine: SpeechEngine?
    @State private var speech: SpeechController?
    @State private var showCloseConfirm = false

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                    .padding(.horizontal, MoraTheme.Space.md)
                    .padding(.top, MoraTheme.Space.md)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, MoraTheme.Space.xxl)
                    .animation(.easeInOut(duration: 0.25), value: orchestrator?.phase)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            FeedbackOverlay(state: feedback)

            if let yokai = orchestrator?.yokai {
                YokaiLayerView(orchestrator: yokai, speech: speech)
                    .ignoresSafeArea()
            }
        }
        .alert(strings.sessionCloseTitle, isPresented: $showCloseConfirm) {
            Button(strings.sessionCloseKeepGoing, role: .cancel) {}
            Button(strings.sessionCloseEnd, role: .destructive) {
                // Record a partial summary so progress is not silently dropped.
                if let orchestrator {
                    let partial = orchestrator.sessionSummary(endedAt: Date())
                    persist(summary: partial)
                }
                // Cancel in-flight speech, drain the engine, then dismiss.
                // Awaiting `speech.stop()` before `dismiss()` is what stops
                // the tail of the current utterance from riding out onto
                // whatever screen the learner lands on next — a detached
                // stop racing against dismiss leaves the audio audible.
                if let speech {
                    Task { @MainActor in
                        await speech.stop()
                        dismiss()
                    }
                } else {
                    dismiss()
                }
            }
        } message: {
            Text(strings.sessionCloseMessage)
        }
        // Every phase transition cancels whatever the prior phase was
        // speaking. The new phase view owns the next utterance via its
        // own `.task`. Without this, a long-press speak left over from
        // a prior phase-intro view would keep playing into the next
        // phase if that view has no `.task` of its own.
        //
        // Skip the entry from `.notStarted` — nothing is playing yet, and
        // racing a no-op `stop()` against the new phase view's first
        // `speech.play(...)` can cancel the very first utterance (the
        // warmup phoneme that introduces the target grapheme).
        .onChange(of: orchestrator?.phase) { oldValue, _ in
            guard oldValue != nil, oldValue != .notStarted else { return }
            guard let speech else { return }
            Task { await speech.stop() }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    private var topChrome: some View {
        HStack {
            Button(action: { showCloseConfirm = true }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.6), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(strings.a11yCloseSession)
            .accessibilityHint("Confirms before leaving so you don't lose progress.")

            Spacer()

            if let orchestrator {
                PhasePips(phase: orchestrator.phase)
            } else {
                PhasePips(currentIndex: -1)
            }

            Spacer()

            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let orchestrator {
            switch orchestrator.phase {
            case .notStarted:
                ProgressView("Preparing…")
                    .task { await orchestrator.start() }
            case .warmup:
                WarmupView(orchestrator: orchestrator, speech: speech)
            case .newRule:
                NewRuleView(orchestrator: orchestrator, speech: speech)
            case .decoding:
                if let engine = orchestrator.currentTileBoardEngine {
                    DecodeBoardView(
                        engine: engine,
                        chainPipStates: orchestrator.chainPipStates.map(ChainPipState.init),
                        incomingRole: orchestrator.currentChainRole,
                        speech: speech,
                        onTrialComplete: { result in
                            orchestrator.consumeTileBoardTrial(result)
                        }
                    )
                    .id(orchestrator.completedTrialCount)
                } else {
                    Color.clear
                }
            case .shortSentences:
                ShortSentencesView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback,
                    speechEngine: uiMode == .mic ? speechEngine : nil,
                    speech: speech
                )
            case .completion:
                CompletionView(
                    orchestrator: orchestrator, speech: speech,
                    persistSummary: { summary in persist(summary: summary) }
                )
            }
        } else if let bootError {
            Text("Could not start session: \(bootError)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
        } else {
            ProgressView("Loading session…")
                .task { await bootstrap() }
        }
    }

    @MainActor
    private func bootstrap() async {
        #if os(iOS)
        // Decide mic vs tap before building the engine — if the user
        // denied either permission, skip engine construction entirely.
        let coord = PermissionCoordinator()
        switch coord.current() {
        case .allGranted:
            do {
                speechEngine = try AppleSpeechEngine()
                uiMode = .mic
            } catch {
                speechLog.error(
                    "AppleSpeechEngine init failed, falling back to tap: \(String(describing: error))"
                )
                uiMode = .tap
            }
        case .partial, .notDetermined:
            uiMode = .tap
        }
        speech = SpeechController(tts: AppleTTSEngine(l1Profile: JapaneseL1Profile()))
        // Prime AVSpeechSynthesizer so the warmup phoneme isn't the
        // utterance that gets eaten by the cold-launch first-utterance
        // quirk: on a fresh audio session the very first short speak()
        // sometimes never fires `didFinish`, leaving the queue stalled
        // and the learner's first prompt silent. A space-only primer
        // routed through `SpeechController` takes that hit on a no-op
        // so the real prompt plays cleanly — and because it goes through
        // the controller's `inflight`, the warmup view's first
        // `speech.play(...)` cancels it via the same chokepoint as any
        // other in-flight sequence.
        speech?.play([.text(" ", .normal)])
        #else
        uiMode = .tap
        #endif

        do {
            let ladder = CurriculumEngine.sharedV1
            guard
                let resolution = try WeekRotation.resolve(
                    context: context,
                    ladder: ladder
                )
            else {
                // All five yokai befriended. PR 2 replaces this with a proper
                // curriculum-complete navigation; for PR 1 we surface a plain
                // message so the session does not crash.
                bootError = "Curriculum complete — all five yokai befriended."
                return
            }
            let skill = resolution.skill
            let target = Target(weekStart: resolution.encounter.weekStart, skill: skill)
            let weekIdx = ladder.indexOf(code: skill.code) ?? 0
            let taught = ladder.taughtGraphemes(beforeWeekIndex: weekIdx)
            guard let targetGrapheme = target.grapheme else {
                bootError =
                    "Target skill \(skill.code.rawValue) has no grapheme/phoneme mapping"
                return
            }
            let provider = try ScriptedContentProvider.bundled(for: skill.code)
            let sentences = try provider.decodeSentences(
                ContentRequest(
                    target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2
                ))
            self.orchestrator = SessionOrchestrator(
                target: target,
                taughtGraphemes: taught,
                warmupOptions: skill.warmupCandidates,
                chainProvider: LibraryFirstWordChainProvider(),
                sentences: sentences,
                assessment: AssessmentEngine(
                    l1Profile: JapaneseL1Profile(),
                    evaluator: shadowEvaluatorFactory.make(context.container)
                )
            )
        } catch {
            bootError = String(describing: error)
        }
    }

    @MainActor
    private func persist(summary: SessionSummary) {
        let entity = SessionSummaryEntity(
            date: Date(),
            sessionType: summary.sessionType.rawValue,
            targetSkillCode: summary.targetSkillCode.rawValue,
            durationSec: summary.durationSec,
            trialsTotal: summary.trialsTotal,
            trialsCorrect: summary.trialsCorrect,
            escalated: summary.escalated
        )
        context.insert(entity)
        do {
            try context.save()
        } catch {
            // Best-effort: a save failure here means the session log is lost
            // for this run, but the in-memory orchestrator state still
            // reflects what the learner just did. Surface to Console so the
            // failure is debuggable; do not crash the celebration screen.
            persistLog.error("SessionSummary save failed: \(error)")
        }
    }
}
