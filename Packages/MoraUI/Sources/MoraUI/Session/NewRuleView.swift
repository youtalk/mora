import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("New rule")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            Text("\(letters) → /\(ipa)/")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text("Two letters, one sound.")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.secondary)

            HStack(spacing: MoraTheme.Space.lg) {
                workedExample("ship")
                workedExample("shop")
                workedExample("fish")
            }
            .padding(.top, MoraTheme.Space.lg)

            Spacer()

            HeroCTA(title: "Got it") {
                Task { await orchestrator.handle(.advance) }
            }
            .padding(.bottom, MoraTheme.Space.xl)
        }
    }

    private func workedExample(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(MoraTheme.Ink.primary)
            .padding(.horizontal, MoraTheme.Space.lg)
            .padding(.vertical, MoraTheme.Space.md)
            .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.tile))
            .shadow(color: MoraTheme.Ink.secondary.opacity(0.15), radius: 3, y: 2)
    }

    private var letters: String {
        orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? "?"
    }
    private var ipa: String {
        orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? "?"
    }
}
