import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?

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

            HeroCTA(title: strings.newRuleGotIt) {
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
        guard let speech else {
            finishedIntro = true
            return
        }
        var prompts: [SpeechPrompt] = [
            .text("\(letters) says \(ipa). Two letters, one sound.")
        ]
        for word in ["ship", "shop", "fish"] {
            prompts.append(.text(word))
        }
        await speech.playAndAwait(prompts)
        // Only flip the gate when the intro actually finished. A cancelled
        // run (view disappeared, close button, user-initiated interrupt)
        // leaves the gate closed so that a re-entering view replays the
        // full sequence instead of skipping straight to the CTA.
        if !Task.isCancelled {
            finishedIntro = true
        }
    }

    private func workedExample(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(MoraTheme.Ink.primary)
            .padding(.horizontal, MoraTheme.Space.lg)
            .padding(.vertical, MoraTheme.Space.md)
            .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.tile))
    }

    private var letters: String { orchestrator.target.letters ?? "?" }
    private var ipa: String { orchestrator.target.ipa ?? "?" }
}
