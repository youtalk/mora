import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

struct CompletionView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let ttsEngine: TTSEngine?
    let persistSummary: (SessionSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    // Sort so that if duplicate rows ever land in the store (migration bug,
    // test seed leakage) the freshest one wins deterministically. HomeView
    // uses the same sort; both views agree on which row is "the" streak.
    @Query(sort: \DailyStreak.lastCompletedOn, order: .reverse)
    private var streaks: [DailyStreak]
    @State private var didPersist = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()

            Text(strings.completionTitle)
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text(strings.completionScore(correct, total))
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Accent.teal)

            Text("Today's target: \(letters)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.secondary)

            Spacer()

            Text(strings.completionComeBack)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.muted)

            Button("Done") { dismiss() }
                .font(MoraType.cta())
                .foregroundStyle(MoraTheme.Accent.teal)
                .padding(.top, MoraTheme.Space.md)
                .padding(.bottom, MoraTheme.Space.xl)
                .accessibilityHint("Returns to the home screen.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .accessibilityAction(named: "Return home") { dismiss() }
        .onAppear { persistOnce() }
        .task {
            guard let tts = ttsEngine else { return }
            await tts.speak("Quest complete! You got \(correct) out of \(total).")
        }
    }

    @MainActor
    private func persistOnce() {
        guard !didPersist else { return }
        didPersist = true
        persistSummary(orchestrator.sessionSummary(endedAt: Date()))

        let streak: DailyStreak
        if let existing = streaks.first {
            streak = existing
        } else {
            streak = DailyStreak()
            ctx.insert(streak)
        }
        streak.recordCompletion(on: Date())
        try? ctx.save()
    }

    private var correct: Int { orchestrator.trials.filter(\.correct).count }
    private var total: Int { orchestrator.trials.count }
    private var letters: String { orchestrator.target.letters ?? "?" }
}
