import MoraCore
import MoraEngines
import SwiftUI

struct WarmupView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: 32) {
            Text("Which one says /\(targetIPA)/?")
                .font(.largeTitle.weight(.semibold))
            Text("Listen and tap.")
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 32) {
                ForEach(orchestrator.warmupOptions, id: \.letters) { g in
                    Button(action: {
                        Task { await orchestrator.handle(.warmupTap(g)) }
                    }) {
                        Text(g.letters)
                            .font(.system(size: 84, weight: .bold, design: .rounded))
                            .frame(minWidth: 140, minHeight: 140)
                            .background(Color.white, in: .rect(cornerRadius: 24))
                            .shadow(radius: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            if orchestrator.warmupMissCount > 0 {
                Text("Let's try again — listen.")
                    .foregroundStyle(.orange)
            }
        }
        .padding()
    }

    private var targetIPA: String {
        orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? "?"
    }
}
