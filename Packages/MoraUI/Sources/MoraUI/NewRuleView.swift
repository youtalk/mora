import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: 28) {
            Text("New rule")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(letters) says /\(ipa)/")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
            Text("Two letters, one sound.")
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 24) {
                worked("ship")
                worked("shop")
                worked("fish")
            }
            Button("Got it") {
                Task { await orchestrator.handle(.advance) }
            }
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 32).padding(.vertical, 16)
            .background(.tint, in: .capsule)
            .foregroundStyle(.white)
        }
        .padding()
    }

    private func worked(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 44, weight: .bold, design: .rounded))
            .padding(.horizontal, 24).padding(.vertical, 12)
            .background(Color.white, in: .rect(cornerRadius: 16))
            .shadow(radius: 2)
    }

    private var letters: String {
        orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? "?"
    }
    private var ipa: String {
        orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? "?"
    }
}
