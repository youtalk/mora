import MoraCore
import MoraEngines
import SwiftUI

struct CompletionView: View {
    let orchestrator: SessionOrchestrator
    let persistSummary: (SessionSummary) -> Void
    @State private var didPersist = false

    var body: some View {
        VStack(spacing: 28) {
            Text("Quest complete!")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
            VStack(spacing: 8) {
                Text("Correct: \(correct) / \(total)")
                    .font(.title2)
                Text("Today's target: \(letters)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Text("Come back tomorrow!")
                .font(.title3)
        }
        .padding()
        .onAppear {
            guard !didPersist else { return }
            didPersist = true
            let summary = orchestrator.sessionSummary(endedAt: Date())
            persistSummary(summary)
        }
    }

    private var correct: Int { orchestrator.trials.filter(\.correct).count }
    private var total: Int { orchestrator.trials.count }
    private var letters: String {
        orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? "?"
    }
}
