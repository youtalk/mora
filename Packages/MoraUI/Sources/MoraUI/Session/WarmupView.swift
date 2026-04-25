import MoraCore
import MoraEngines
import SwiftUI

struct WarmupView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?
    let clipRouter: YokaiClipRouter?

    private static let promptPrefix = "Which one says"

    var body: some View {
        ScrollView {
            VStack(spacing: MoraTheme.Space.lg) {
                Text("\(Self.promptPrefix) /\(targetIPA)/?")
                    .font(MoraType.heading())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                Text("Listen and tap.")
                    .font(MoraType.subtitle())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .minimumScaleFactor(0.5)

                HStack(spacing: MoraTheme.Space.lg) {
                    ForEach(orchestrator.warmupOptions, id: \.letters) { g in
                        Button(action: {
                            Task { await orchestrator.handle(.warmupTap(g)) }
                        }) {
                            Text(g.letters)
                                .font(MoraType.heroWord(120))
                                .foregroundStyle(MoraTheme.Ink.primary)
                                .frame(width: 180, height: 180)
                                .background(
                                    Color.white,
                                    in: .rect(cornerRadius: MoraTheme.Radius.card)
                                )
                                .minimumScaleFactor(0.5)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if orchestrator.warmupMissCount > 0 {
                    Text("Let's try again — listen.")
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Accent.orange)
                        .minimumScaleFactor(0.5)
                }

                Button(action: { Task { await playTargetPhoneme() } }) {
                    Text(strings.warmupListenAgain)
                        .font(MoraType.cta())
                        .foregroundStyle(MoraTheme.Accent.teal)
                        .padding(.vertical, MoraTheme.Space.md)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .background(MoraTheme.Background.mint, in: .capsule)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.plain)
                .disabled(speech == nil)
            }
            .padding(.vertical, MoraTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .task {
            await playTargetPhoneme()
        }
    }

    /// Speaks the warmup prompt and the target phoneme. Sequence:
    /// 1. Apple TTS narrator: "Which one says".
    /// 2. Yokai's `phoneme` clip if the active week has one bundled.
    /// 3. If no yokai clip is available, fall back to Apple TTS `.phoneme`.
    private func playTargetPhoneme() async {
        guard let speech else { return }
        await speech.playAndAwait([.text(Self.promptPrefix, .normal)])
        let played = (await clipRouter?.play(.phoneme)) ?? false
        if !played, let phoneme = orchestrator.target.phoneme {
            await speech.playAndAwait([.phoneme(phoneme, .slow)])
        }
    }

    private var targetIPA: String {
        orchestrator.target.ipa ?? "?"
    }
}
