import MoraCore
import SwiftUI

public enum SlotState: Hashable, Sendable {
    case emptyInactive
    case emptyActive
    case filled(Tile)
    case locked(Tile)
    case autoFilled(Tile)
}

public struct SlotView: View {
    public let state: SlotState
    public let size: CGFloat
    public var reduceMotion: Bool

    public init(state: SlotState, size: CGFloat = 84, reduceMotion: Bool = false) {
        self.state = state
        self.size = size
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        ZStack {
            backgroundShape
            if let tile = tile {
                Text(tile.display)
                    .font(.openDyslexic(size: size * 0.38))
                    .foregroundColor(TilePalette.text(for: tile.kind))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var backgroundShape: some View {
        switch state {
        case .emptyInactive:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .foregroundColor(.gray.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.05))
                )
        case .emptyActive:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(reduceMotion ? 0.3 : 0.4), lineWidth: 2)
                        .scaleEffect(reduceMotion ? 1 : 1.06)
                        .opacity(reduceMotion ? 0.6 : 0)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: reduceMotion
                        )
                )
        case let .filled(tile):
            RoundedRectangle(cornerRadius: 16)
                .fill(TilePalette.fill(for: tile.kind))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TilePalette.border(for: tile.kind), lineWidth: 2)
                )
        case let .locked(tile):
            RoundedRectangle(cornerRadius: 16)
                .fill(TilePalette.fill(for: tile.kind).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TilePalette.border(for: tile.kind).opacity(0.6), lineWidth: 2)
                )
        case let .autoFilled(tile):
            RoundedRectangle(cornerRadius: 16)
                .fill(TilePalette.fill(for: tile.kind).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TilePalette.border(for: tile.kind), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                )
        }
    }

    private var tile: Tile? {
        switch state {
        case .emptyInactive, .emptyActive: return nil
        case let .filled(t), let .locked(t), let .autoFilled(t): return t
        }
    }

    private var accessibilityLabel: Text {
        switch state {
        case .emptyInactive: return Text("empty slot")
        case .emptyActive: return Text("active slot, empty")
        case let .filled(t): return Text("slot contains \(t.display)")
        case let .locked(t): return Text("locked slot, \(t.display)")
        case let .autoFilled(t): return Text("auto-filled slot, \(t.display)")
        }
    }
}
