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
        self.init(currentIndex: Self.pipIndex(for: phase), totalCount: 5)
    }

    /// Exposed for testing so the phase → pip mapping is verifiable without
    /// rendering the view. Internal access is enough — tests reach it via
    /// `@testable import MoraUI`, so the module's published surface stays
    /// limited to the two initializers.
    static func pipIndex(for phase: ADayPhase) -> Int {
        switch phase {
        case .notStarted: return -1
        case .warmup: return 0
        case .newRule: return 1
        case .decoding: return 2
        case .shortSentences: return 3
        case .completion: return 4
        }
    }

    public var body: some View {
        HStack(spacing: MoraTheme.Space.sm) {
            ForEach(0..<totalCount, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: 34, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Accessible-equivalent of the pip row. Internal for the same reason as
    /// `pipIndex(for:)` — tests use `@testable import MoraUI`.
    var accessibilityLabel: String {
        guard currentIndex >= 0 else { return "Session not started" }
        return "Phase \(currentIndex + 1) of \(totalCount)"
    }

    private func color(for i: Int) -> Color {
        if i < currentIndex { return MoraTheme.Accent.teal }
        if i == currentIndex { return MoraTheme.Accent.orange }
        return MoraTheme.Ink.muted.opacity(0.3)
    }
}
