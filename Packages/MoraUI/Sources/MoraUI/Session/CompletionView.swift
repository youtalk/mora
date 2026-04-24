import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

struct CompletionView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?
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

            Button("Done") { dismissSession() }
                .font(MoraType.cta())
                .foregroundStyle(MoraTheme.Accent.teal)
                .padding(.top, MoraTheme.Space.md)
                .padding(.bottom, MoraTheme.Space.xl)
                .accessibilityHint("Returns to the home screen.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismissSession() }
        .accessibilityAction(named: "Return home") { dismissSession() }
        .onAppear { persistOnce() }
        .task {
            // Spoken in English (the whole app teaches English phonics to
            // an L1-Japanese learner) — keeping this literal rather than a
            // MoraStrings entry since every L1 profile would emit the same
            // celebratory line in English anyway.
            speech?.play(
                [.text("Quest complete! You got \(correct) out of \(total).", .normal)]
            )
        }
    }

    @MainActor
    private func dismissSession() {
        // Silence the celebration utterance and wait for it to stop before
        // dismissing. A detached stop followed by an immediate dismiss
        // races against the synthesizer draining and lets audio leak onto
        // the Home screen.
        guard let speech else {
            dismiss()
            return
        }
        Task { @MainActor in
            await speech.stop()
            dismiss()
        }
    }

    @MainActor
    private func persistOnce() {
        guard !didPersist else { return }
        didPersist = true
        persistSummary(orchestrator.sessionSummary(endedAt: Date()))

        // For normal (non-Friday) sessions, advance the yokai's
        // sessionCompletionCount + apply the +5% session bonus. Friday
        // sessions auto-finalize through finalizeFridayIfNeeded when the
        // last trial lands, so calling recordSessionCompletion here would
        // double-count. Friday completion flips the state off `.active`
        // (to `.befriended` or `.carryover`), so gating on `.active`
        // filters them out.
        if orchestrator.yokai?.currentEncounter?.state == .active {
            orchestrator.yokai?.recordSessionCompletion()
        }

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
