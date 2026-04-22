import SwiftUI
import MoraEngines

public struct PhasePips: View {
    public let currentIndex: Int
    public let totalCount: Int

    public init(currentIndex: Int, totalCount: Int = 5) {
        self.currentIndex = currentIndex
        self.totalCount = totalCount
    }

    /// Convenience initializer mapping ADayPhase → pip index:
    /// warmup=0, newRule=1, decoding=2, shortSentences=3, completion=4.
    /// .notStarted shows no active pip (index -1).
    public init(phase: ADayPhase) {
        let idx: Int
        switch phase {
        case .notStarted: idx = -1
        case .warmup: idx = 0
        case .newRule: idx = 1
        case .decoding: idx = 2
        case .shortSentences: idx = 3
        case .completion: idx = 4
        }
        self.init(currentIndex: idx, totalCount: 5)
    }

    public var body: some View {
        HStack(spacing: MoraTheme.Space.sm) {
            ForEach(0..<totalCount, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: 34, height: 6)
            }
        }
    }

    private func color(for i: Int) -> Color {
        if i < currentIndex { return MoraTheme.Accent.teal }
        if i == currentIndex { return MoraTheme.Accent.orange }
        return MoraTheme.Ink.muted.opacity(0.3)
    }
}
