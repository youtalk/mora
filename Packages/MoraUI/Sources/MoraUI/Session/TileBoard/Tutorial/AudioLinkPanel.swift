import MoraCore
import SwiftUI

struct AudioLinkPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.tileTutorialAudioTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            audioColumn
                .frame(height: 220)

            Text(strings.tileTutorialAudioBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.tileTutorialTry, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await runPulseLoop()
        }
    }

    private var audioColumn: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text("🔊")
                .font(.system(size: 64))
                .scaleEffect(pulseScale)
                .accessibilityHidden(true)
            Image(systemName: "arrow.down")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MoraTheme.Ink.muted)
            HStack(spacing: MoraTheme.Space.md) {
                emptySlot
                emptySlot
                emptySlot
            }
        }
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
            .stroke(
                MoraTheme.Ink.muted.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )
            .frame(width: 50, height: 50)
    }

    @MainActor
    private func runPulseLoop() async {
        if reduceMotion {
            return
        }
        // `try? await sleep` would swallow CancellationError and busy-loop
        // after view teardown; thread cancellation through with explicit
        // try/catch returns. (See Yokai/SparkleOverlay for the same pattern.)
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.5)) {
                pulseScale = 1.15
            }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                pulseScale = 1.0
            }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
        }
    }
}

#if DEBUG
#Preview {
    AudioLinkPanel(onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
