import SwiftUI

public struct StreakChip: View {
    public let count: Int
    public init(count: Int) { self.count = count }

    @State private var pulse: Bool = false

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
        .scaleEffect(pulse ? 1.2 : 1.0)
        .onChange(of: count) { _, _ in
            withAnimation(.easeInOut(duration: 0.35)) { pulse = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                withAnimation(.easeInOut(duration: 0.35)) { pulse = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak")
        .accessibilityValue("\(count) \(count == 1 ? "day" : "days")")
    }
}
