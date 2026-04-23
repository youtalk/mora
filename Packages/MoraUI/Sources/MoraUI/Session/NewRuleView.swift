import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?

    @State private var finishedIntro = false

    var body: some View {
        ScrollView {
            VStack(spacing: MoraTheme.Space.lg) {
                Text("New rule")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)

                Text("\(letters) → /\(ipa)/")
                    .font(MoraType.heroWord(140))
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .minimumScaleFactor(0.5)

                Text("Two letters, one sound.")
                    .font(MoraType.heading())
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                HStack(spacing: MoraTheme.Space.lg) {
                    workedExample("ship")
                    workedExample("shop")
                    workedExample("fish")
                }

                HeroCTA(title: strings.newRuleGotIt) {
                    Task { await orchestrator.handle(.advance) }
                }
                .disabled(!finishedIntro)
                .opacity(finishedIntro ? 1.0 : 0.4)
                .padding(.top, MoraTheme.Space.md)
            }
            .padding(.vertical, MoraTheme.Space.xl)
            .frame(maxWidth: .infinity)
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
        // Play the bare phoneme via IPA hint, then ground it in three
        // exemplars. Avoids speaking the digraph letters in isolation
        // (TTS spells "sh" out as letters in plain text); the IPA hint is
        // the documented way to coax a clean /ʃ/ from Premium voices.
        var prompts: [SpeechPrompt] = []
        if let phoneme = orchestrator.target.phoneme {
            prompts.append(.phoneme(phoneme, .slow))
        }
        prompts.append(.text("Two letters, one sound.", .slow))
        for word in ["ship", "shop", "fish"] {
            prompts.append(.text(word, .slow))
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
            .font(MoraType.bodyReading(size: 56))
            .foregroundStyle(MoraTheme.Ink.primary)
            .padding(.horizontal, MoraTheme.Space.lg)
            .padding(.vertical, MoraTheme.Space.md)
            .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.tile))
            .minimumScaleFactor(0.5)
    }

    private var letters: String { orchestrator.target.letters ?? "?" }
    private var ipa: String { orchestrator.target.ipa ?? "?" }
}
