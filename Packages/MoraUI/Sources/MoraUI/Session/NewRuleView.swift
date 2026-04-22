import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    let orchestrator: SessionOrchestrator
    let ttsEngine: TTSEngine?

    @State private var finishedIntro = false

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
            .disabled(!finishedIntro)
            .opacity(finishedIntro ? 1.0 : 0.4)
            .padding(.bottom, MoraTheme.Space.xl)
        }
        .task {
            await playIntro()
        }
    }

    @MainActor
    private func playIntro() async {
        guard !finishedIntro else { return }
        guard let tts = ttsEngine else {
            finishedIntro = true
            return
        }
        await tts.speak("\(letters) says \(ipa). Two letters, one sound.")
        for word in ["ship", "shop", "fish"] {
            await tts.speak(word)
        }
        finishedIntro = true
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

    private var letters: String { orchestrator.target.letters ?? "?" }
    private var ipa: String { orchestrator.target.ipa ?? "?" }
}
