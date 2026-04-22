import MoraCore
import MoraEngines
import SwiftUI

struct CompletionView: View {
    let orchestrator: SessionOrchestrator
    let persistSummary: (SessionSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didPersist = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()

            Text("Quest complete!")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text("\(correct) / \(total)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Accent.teal)

            Text("Today's target: \(letters)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.secondary)

            Spacer()

            Text("Come back tomorrow!")
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            guard !didPersist else { return }
            didPersist = true
            persistSummary(orchestrator.sessionSummary(endedAt: Date()))
        }
    }

    private var correct: Int { orchestrator.trials.filter(\.correct).count }
    private var total: Int { orchestrator.trials.count }
    private var letters: String {
        orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? "?"
    }
}
