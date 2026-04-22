import MoraCore
import MoraEngines
import SwiftUI

struct WarmupView: View {
    let orchestrator: SessionOrchestrator

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
                            .shadow(color: MoraTheme.Ink.secondary.opacity(0.20), radius: 4, y: 2)
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

            Button(action: {
                // TTS replay wires in PR 6; no-op stub keeps the layout today.
            }) {
                Label("Listen again", systemImage: "speaker.wave.2.fill")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .padding(.vertical, MoraTheme.Space.md)
                    .padding(.horizontal, MoraTheme.Space.lg)
                    .background(MoraTheme.Background.mint, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.bottom, MoraTheme.Space.lg)
        }
    }

    private var targetIPA: String {
        orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? "?"
    }
}
