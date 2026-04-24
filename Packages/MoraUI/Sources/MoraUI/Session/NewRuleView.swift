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

                Button(action: replayIntro) {
                    Text(strings.newRuleListenAgain)
                        .font(MoraType.cta())
                        .foregroundStyle(MoraTheme.Accent.teal)
                        .padding(.vertical, MoraTheme.Space.md)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .background(MoraTheme.Background.mint, in: .capsule)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.plain)
                .disabled(speech == nil)

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
        await speech.playAndAwait(introPrompts(includePhoneme: true))
        // Only flip the gate when the intro actually finished. A cancelled
        // run (view disappeared, close button, user-initiated interrupt)
        // leaves the gate closed so that a re-entering view replays the
        // full sequence instead of skipping straight to the CTA.
        if !Task.isCancelled {
            finishedIntro = true
        }
    }

    /// Re-plays the phrase + exemplars without the lead-in phoneme. The
    /// learner already heard the bare /ʃ/ on first entry; replaying it
    /// on every tap of the listen-again button feels repetitive. The CTA
    /// stays active so the learner can advance whenever they're ready.
    ///
    /// `introPrompts()` reads `orchestrator.target` and the resulting
    /// playback routes through `SpeechController`, both of which are
    /// `@MainActor`-isolated. Building the prompt list *inside* the
    /// `Task { @MainActor in ... }` keeps every orchestrator / speech
    /// access on the same actor under Swift's strict concurrency
    /// checking.
    private func replayIntro() {
        guard let speech else { return }
        Task { @MainActor in
            let prompts = introPrompts(includePhoneme: false)
            await speech.playAndAwait(prompts)
        }
    }

    /// Build an optional lead-in phoneme + "Two letters, one sound." +
    /// three exemplar words. Avoids speaking the digraph letters in
    /// isolation (TTS spells "sh" out as letters in plain text); the IPA
    /// hint is the documented way to coax a clean /ʃ/ from Premium voices.
    private func introPrompts(includePhoneme: Bool) -> [SpeechPrompt] {
        var prompts: [SpeechPrompt] = []
        if includePhoneme, let phoneme = orchestrator.target.phoneme {
            prompts.append(.phoneme(phoneme, .slow))
        }
        prompts.append(.text("Two letters, one sound.", .slow))
        for word in ["ship", "shop", "fish"] {
            prompts.append(.text(word, .slow))
        }
        return prompts
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
