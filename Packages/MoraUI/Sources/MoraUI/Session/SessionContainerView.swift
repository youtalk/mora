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
    @Query(sort: \DailyStreak.lastCompletedOn, order: .reverse)
    private var streaks: [DailyStreak]
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?
    @State private var feedback: FeedbackState = .none
    @State private var uiMode: SessionUIMode = .tap
    @State private var speechEngine: SpeechEngine?
    @State private var ttsEngine: TTSEngine?
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
        }
        .alert(strings.sessionCloseTitle, isPresented: $showCloseConfirm) {
            Button(strings.sessionCloseKeepGoing, role: .cancel) {}
            Button(strings.sessionCloseEnd, role: .destructive) {
                // Record a partial summary so progress is not silently dropped.
                if let orchestrator {
                    let partial = orchestrator.sessionSummary(endedAt: Date())
                    persist(summary: partial)
                }
                dismiss()
            }
        } message: {
            Text(strings.sessionCloseMessage)
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
                WarmupView(orchestrator: orchestrator, ttsEngine: ttsEngine)
            case .newRule:
                NewRuleView(orchestrator: orchestrator, ttsEngine: ttsEngine)
            case .decoding:
                DecodeActivityView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback,
                    speechEngine: uiMode == .mic ? speechEngine : nil,
                    ttsEngine: ttsEngine
                )
            case .shortSentences:
                ShortSentencesView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback,
                    speechEngine: uiMode == .mic ? speechEngine : nil,
                    ttsEngine: ttsEngine
                )
            case .completion:
                CompletionView(
                    orchestrator: orchestrator, ttsEngine: ttsEngine,
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
        ttsEngine = AppleTTSEngine(l1Profile: JapaneseL1Profile())
        #else
        uiMode = .tap
        #endif

        do {
            let curriculum = CurriculumEngine.sharedV1
            let target = curriculum.currentTarget(forWeekIndex: 0)
            let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
            guard let targetGrapheme = target.grapheme else {
                bootError =
                    "Target skill \(target.skill.code.rawValue) has no grapheme/phoneme mapping"
                return
            }
            let provider = try ScriptedContentProvider.bundledShWeek1()
            let words = try provider.decodeWords(
                ContentRequest(
                    target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 5
                ))
            let sentences = try provider.decodeSentences(
                ContentRequest(
                    target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2
                ))
            self.orchestrator = SessionOrchestrator(
                target: target, taughtGraphemes: taught,
                warmupOptions: [
                    Grapheme(letters: "s"),
                    Grapheme(letters: "sh"),
                    Grapheme(letters: "ch"),
                ],
                words: words, sentences: sentences,
                assessment: AssessmentEngine(l1Profile: JapaneseL1Profile())
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
