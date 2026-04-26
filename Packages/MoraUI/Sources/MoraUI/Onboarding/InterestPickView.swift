import MoraCore
import SwiftUI

struct InterestPickView: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.currentL1Profile) private var currentL1Profile
    @Binding var selectedKeys: Set<String>
    let categories: [InterestCategory]
    var ageYears: Int = 8
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

            Text(strings.interestPrompt)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            LazyVGrid(columns: columns, spacing: MoraTheme.Space.md) {
                ForEach(categories) { cat in
                    tile(for: cat)
                }
            }
            .padding(.horizontal, MoraTheme.Space.lg)
            .frame(maxWidth: 720)

            Spacer()

            HeroCTA(title: strings.interestCTA, action: onContinue)
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
                Text(
                    currentL1Profile.interestCategoryDisplayName(
                        key: cat.key, at: LearnerLevel.from(years: ageYears)
                    )
                )
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
