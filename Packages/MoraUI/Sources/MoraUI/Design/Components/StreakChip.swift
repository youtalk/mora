import SwiftUI

public struct StreakChip: View {
    public let count: Int
    public init(count: Int) { self.count = count }

    public var body: some View {
        HStack(spacing: MoraTheme.Space.xs) {
            Text("🔥")
                .font(.system(size: 18))
                .accessibilityHidden(true)
            Text("\(count)")
                .font(MoraType.pill())
                .foregroundStyle(MoraTheme.Ink.primary)
        }
        .padding(.horizontal, MoraTheme.Space.md)
        .padding(.vertical, MoraTheme.Space.sm)
        .background(MoraTheme.Background.mint, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak")
        .accessibilityValue("\(count) \(count == 1 ? "day" : "days")")
    }
}
