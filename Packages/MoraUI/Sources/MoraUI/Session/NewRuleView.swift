import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?
    let clipRouter: YokaiClipRouter?

    @State private var finishedIntro = false
    /// Tracks the most recent intro task spawned by the listen-again button
    /// so a rapid second tap cancels the in-flight intro before kicking off
    /// a new one. Without this, two `runIntro` instances race on the shared
    /// `clipRouter` / `speech` and produce overlapping playback. The initial
    /// `.task { await playIntro() }` is owned by SwiftUI and gets cancelled
    /// on view disappear; we only need to track the detached replays here.
    @State private var replayTask: Task<Void, Never>?

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
                    ForEach(exemplars, id: \.self) { workedExample($0) }
                }

                HStack(spacing: MoraTheme.Space.md) {
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
                }
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
        await runIntro(speech: speech)
        // Only flip the gate when the intro actually finished. A cancelled
        // run (view disappeared, close button, user-initiated interrupt)
        // leaves the gate closed so that a re-entering view replays the
        // full sequence instead of skipping straight to the CTA.
        if !Task.isCancelled {
            finishedIntro = true
        }
    }

    private func replayIntro() {
        guard let speech else { return }
        replayTask?.cancel()
        replayTask = Task { @MainActor in
            await runIntro(speech: speech)
        }
    }

    /// Plays the intro: TTS narrates "Two letters, one sound." and then the
    /// three exemplar words play in the yokai's voice via bundled
    /// `example_1` / `example_2` / `example_3` clips. Each exemplar falls
    /// back to TTS when the corresponding clip URL is missing or the router
    /// is absent (e.g. a session without an encountered yokai).
    ///
    /// Deliberately omits a TTS /ʃ/ lead-in — the learner already heard the
    /// yokai's `phoneme.m4a` in warmup, the rule card displays the IPA on
    /// screen, and synthesized single-fricative phonemes from compact voices
    /// land as a clipped "shh" that distracts from the rule narration.
    @MainActor
    private func runIntro(speech: SpeechController) async {
        await speech.playAndAwait([.text("Two letters, one sound.", .slow)])
        if Task.isCancelled { return }

        let clipKeys: [YokaiClipKey] = [.example1, .example2, .example3]
        for (index, word) in exemplars.enumerated() {
            if Task.isCancelled { return }
            let key = index < clipKeys.count ? clipKeys[index] : nil
            if let key, let clipRouter,
                await clipRouter.playAndAwait(key)
            {
                continue
            }
            await speech.playAndAwait([.text(word, .slow)])
        }
    }

    private var exemplars: [String] {
        guard let phoneme = orchestrator.target.phoneme else { return [] }
        return JapaneseL1Profile().exemplars(for: phoneme)
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
