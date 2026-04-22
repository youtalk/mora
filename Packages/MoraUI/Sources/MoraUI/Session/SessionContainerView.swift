import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

private let persistLog = Logger(subsystem: "tech.reenable.Mora", category: "Persistence")

/// UI mode is currently fixed to `.tap` until PR 5 introduces `.mic`. Keep the
/// enum so downstream views can switch on it without a later rewrite.
public enum SessionUIMode: Equatable, Sendable {
    case tap
    case mic
}

public struct SessionContainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?
    @State private var feedback: FeedbackState = .none
    @State private var uiMode: SessionUIMode = .tap

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
            }

            FeedbackOverlay(state: feedback)
        }
        #if os(iOS)
            .navigationBarHidden(true)
        #endif
    }

    private var topChrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.6), in: .circle)
            }
            .buttonStyle(.plain)

            Spacer()

            if let orchestrator {
                PhasePips(phase: orchestrator.phase)
            } else {
                PhasePips(currentIndex: -1)
            }

            Spacer()

            // Streak is wired in PR 3 when DailyStreak lands; until then, stub 0.
            StreakChip(count: 0)
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
                WarmupView(orchestrator: orchestrator)
            case .newRule:
                NewRuleView(orchestrator: orchestrator)
            case .decoding:
                DecodeActivityView(
                    orchestrator: orchestrator, uiMode: uiMode, feedback: $feedback)
            case .shortSentences:
                ShortSentencesView(
                    orchestrator: orchestrator, uiMode: uiMode, feedback: $feedback)
            case .completion:
                CompletionView(
                    orchestrator: orchestrator,
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
        do {
            let curriculum = CurriculumEngine.defaultV1Ladder()
            let target = curriculum.currentTarget(forWeekIndex: 0)
            let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
            guard let targetGrapheme = target.skill.graphemePhoneme?.grapheme else {
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
