import MoraCore
import SwiftUI

struct InterestPickView: View {
    @Binding var selectedKeys: Set<String>
    let categories: [InterestCategory]
    let onContinue: () -> Void

    /// Emoji icons are a UI-layer concern; keeping them here avoids polluting
    /// the pure-domain InterestCategory struct.
    private static let emoji: [String: String] = [
        "animals": "🐕",
        "dinosaurs": "🦖",
        "vehicles": "🚗",
        "space": "🚀",
        "sports": "⚽",
        "robots": "🤖",
    ]

    private let columns = [
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
    ]

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text("What do you like?")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            Text("Pick 3–5 — we'll use these for your stories.")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            LazyVGrid(columns: columns, spacing: MoraTheme.Space.md) {
                ForEach(categories) { cat in
                    tile(for: cat)
                }
            }
            .padding(.horizontal, MoraTheme.Space.lg)
            .frame(maxWidth: 720)

            Spacer()

            HeroCTA(title: "Next", action: onContinue)
                .disabled(!isSelectionValid)
                .opacity(isSelectionValid ? 1.0 : 0.4)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isSelectionValid: Bool {
        (3...5).contains(selectedKeys.count)
    }

    private func tile(for cat: InterestCategory) -> some View {
        let selected = selectedKeys.contains(cat.key)
        return Button(action: { toggle(cat.key) }) {
            VStack(spacing: MoraTheme.Space.sm) {
                Text(Self.emoji[cat.key] ?? "⭐")
                    .font(.system(size: 48))
                Text(cat.displayName)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MoraTheme.Space.lg)
            .background(
                selected ? MoraTheme.Background.mint : Color.white,
                in: .rect(cornerRadius: MoraTheme.Radius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoraTheme.Radius.card)
                    .strokeBorder(
                        selected ? MoraTheme.Accent.teal : MoraTheme.Ink.muted.opacity(0.3),
                        lineWidth: selected ? 3 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ key: String) {
        if selectedKeys.contains(key) {
            selectedKeys.remove(key)
        } else if selectedKeys.count < 5 {
            selectedKeys.insert(key)
        }
    }
}
