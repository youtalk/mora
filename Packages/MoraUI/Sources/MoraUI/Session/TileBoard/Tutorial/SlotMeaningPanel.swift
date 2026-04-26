import MoraCore
import SwiftUI

struct SlotMeaningPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    @State private var draggingTileOffset: CGSize = .zero
    @State private var draggingTileVisible: Bool = true
    @State private var slotFilled: Bool = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.tileTutorialSlotTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)

            slotDemo
                .frame(height: 220)
                .padding(.horizontal, MoraTheme.Space.xl)

            Text(strings.tileTutorialSlotBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.tileTutorialNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await runDragLoop()
        }
    }

    private var slotDemo: some View {
        ZStack {
            VStack(spacing: MoraTheme.Space.lg) {
                slotsRow
                Spacer().frame(height: 8)
                tilePool
            }
            if draggingTileVisible {
                ghostHand
                    .offset(draggingTileOffset)
            }
        }
    }

    private var slotsRow: some View {
        HStack(spacing: MoraTheme.Space.md) {
            tutorialSlot(filled: slotFilled, label: "sh")
            tutorialSlot(filled: false, label: nil)
            tutorialSlot(filled: false, label: nil)
        }
    }

    private var tilePool: some View {
        HStack(spacing: MoraTheme.Space.md) {
            tutorialTile(letters: "sh", kind: .multigrapheme, opacity: slotFilled ? 0.0 : 1.0)
            tutorialTile(letters: "i", kind: .vowel)
            tutorialTile(letters: "p", kind: .consonant)
        }
    }

    private func tutorialSlot(filled: Bool, label: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
                .stroke(
                    filled ? MoraTheme.Accent.orange : MoraTheme.Ink.muted.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: filled ? [] : [6, 4])
                )
                .frame(width: 60, height: 60)
            if filled, let label {
                Text(label)
                    .font(MoraType.heroWord(36))
                    .foregroundStyle(MoraTheme.Ink.primary)
            }
        }
    }

    private func tutorialTile(letters: String, kind: TileKind, opacity: CGFloat = 1.0) -> some View {
        Text(letters)
            .font(MoraType.heroWord(36))
            .foregroundStyle(TilePalette.text(for: kind))
            .frame(width: 60, height: 60)
            .background(TilePalette.fill(for: kind), in: .rect(cornerRadius: MoraTheme.Radius.tile))
            .overlay(
                RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
                    .strokeBorder(TilePalette.border(for: kind), lineWidth: 2)
            )
            .opacity(opacity)
    }

    private var ghostHand: some View {
        Text("👆")
            .font(.system(size: 38))
            .opacity(0.85)
    }

    @MainActor
    private func runDragLoop() async {
        if reduceMotion {
            slotFilled = true
            draggingTileVisible = false
            return
        }
        // Loop forever while panel is on-screen.
        while !Task.isCancelled {
            // Reset
            withAnimation(.easeOut(duration: 0.2)) {
                slotFilled = false
                draggingTileOffset = CGSize(width: -90, height: 70)
                draggingTileVisible = true
            }
            try? await Task.sleep(for: .milliseconds(500))
            // Drag
            withAnimation(.easeInOut(duration: 0.7)) {
                draggingTileOffset = CGSize(width: -90, height: -50)
            }
            try? await Task.sleep(for: .milliseconds(700))
            // Drop
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                slotFilled = true
                draggingTileVisible = false
            }
            try? await Task.sleep(for: .milliseconds(900))
        }
    }
}

#if DEBUG
#Preview {
    SlotMeaningPanel(onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
