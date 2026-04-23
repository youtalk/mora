import MoraCore
import SwiftUI

public enum TileVisualState: Hashable, Sendable {
    case idle
    case lifted
    case settling
    case ghost  // used in auto-fill animations
}

public struct TileView: View {
    public let tile: Tile
    public let visual: TileVisualState
    public let size: CGFloat
    public var reduceMotion: Bool = false

    public init(tile: Tile, visual: TileVisualState = .idle, size: CGFloat = 64, reduceMotion: Bool = false) {
        self.tile = tile
        self.visual = visual
        self.size = size
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        let kind = tile.kind
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(TilePalette.fill(for: kind))
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(TilePalette.border(for: kind), lineWidth: 2)
            Text(tile.display)
                .font(.openDyslexic(size: size * 0.5))
                .foregroundColor(TilePalette.text(for: kind))
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        .animation(animation, value: visual)
        .accessibilityLabel(Text(tile.display))
    }

    private var scale: CGFloat {
        switch visual {
        case .idle, .ghost: return 1.0
        case .lifted: return 1.12
        case .settling: return 1.04
        }
    }

    private var rotation: CGFloat {
        guard !reduceMotion else { return 0 }
        switch visual {
        case .idle, .ghost, .settling: return 0
        case .lifted: return 3
        }
    }

    private var shadowColor: Color {
        Color.black.opacity(visual == .lifted ? 0.18 : 0.08)
    }

    private var shadowRadius: CGFloat {
        visual == .lifted ? 12 : 3
    }

    private var shadowY: CGFloat {
        visual == .lifted ? 6 : 2
    }

    private var animation: Animation? {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.7)
    }
}

#Preview {
    HStack {
        TileView(tile: Tile(grapheme: Grapheme(letters: "sh")))
        TileView(tile: Tile(grapheme: Grapheme(letters: "i")), visual: .lifted)
        TileView(tile: Tile(grapheme: Grapheme(letters: "p")))
    }
    .padding()
}
