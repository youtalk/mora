import SwiftUI

public enum ChainPipState: Hashable, Sendable {
    case pending
    case active
    case done
}

public struct ChainProgressRibbon: View {
    public let states: [ChainPipState]  // expected count: 12

    public init(states: [ChainPipState]) {
        self.states = states
    }

    public var body: some View {
        HStack(spacing: 6) {
            group(Array(states.prefix(4)))
            separator
            group(Array(states.dropFirst(4).prefix(4)))
            separator
            group(Array(states.dropFirst(8).prefix(4)))
        }
    }

    private func group(_ slice: [ChainPipState]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(slice.enumerated()), id: \.offset) { _, state in
                pip(state)
            }
        }
    }

    private func pip(_ state: ChainPipState) -> some View {
        Circle()
            .fill(fill(state))
            .frame(width: 14, height: 14)
            .overlay(
                Circle().strokeBorder(halo(state), lineWidth: 2)
            )
            .animation(.easeOut(duration: 0.3), value: state)
    }

    private func fill(_ s: ChainPipState) -> Color {
        switch s {
        case .pending: return Color.gray.opacity(0.3)
        case .active: return Color.blue
        case .done: return Color.yellow
        }
    }

    private func halo(_ s: ChainPipState) -> Color {
        switch s {
        case .pending: return .clear
        case .active: return Color.blue.opacity(0.3)
        case .done: return Color.yellow.opacity(0.5)
        }
    }

    private var separator: some View {
        Rectangle().fill(Color.gray.opacity(0.4)).frame(width: 1, height: 16)
    }
}
