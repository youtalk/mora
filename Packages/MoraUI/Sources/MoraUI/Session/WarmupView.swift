import MoraCore
import MoraEngines
import SwiftUI

struct WarmupView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?

    var body: some View {
        VStack(spacing: MoraTheme.Space.xl) {
            Spacer()
            Text("Which one says /\(targetIPA)/?")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
            Text("Listen and tap.")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            HStack(spacing: MoraTheme.Space.xl) {
                ForEach(orchestrator.warmupOptions, id: \.letters) { g in
                    Button(action: {
                        Task { await orchestrator.handle(.warmupTap(g)) }
                    }) {
                        Text(g.letters)
                            .font(.system(size: 84, weight: .heavy, design: .rounded))
                            .foregroundStyle(MoraTheme.Ink.primary)
                            .frame(width: 140, height: 140)
                            .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.card))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, MoraTheme.Space.lg)

            if orchestrator.warmupMissCount > 0 {
                Text("Let's try again — listen.")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.orange)
            }

            Spacer()

            Button(action: playTargetPhoneme) {
                Text(strings.warmupListenAgain)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .padding(.vertical, MoraTheme.Space.md)
                    .padding(.horizontal, MoraTheme.Space.lg)
                    .background(MoraTheme.Background.mint, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(speech == nil)
            .padding(.bottom, MoraTheme.Space.lg)
        }
        .task {
            playTargetPhoneme()
        }
    }

    private func playTargetPhoneme() {
        guard let speech, let phoneme = orchestrator.target.phoneme else { return }
        speech.play([.phoneme(phoneme)])
    }

    private var targetIPA: String {
        orchestrator.target.ipa ?? "?"
    }
}
