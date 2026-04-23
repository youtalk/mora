import MoraCore
import SwiftUI

public struct TilePoolView: View {
    public let tiles: [Tile]
    public let tileSize: CGFloat
    public let reduceMotion: Bool

    public init(
        tiles: [Tile],
        tileSize: CGFloat = 128,
        reduceMotion: Bool = false
    ) {
        self.tiles = tiles
        self.tileSize = tileSize
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        WrappingHStack(tiles) { tile in
            TileView(tile: tile, visual: .idle, size: tileSize, reduceMotion: reduceMotion)
                .draggable(tile.id)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.15))
                )
        )
    }
}

/// Minimal flow-layout used by TilePoolView. Wraps children to new rows
/// when they exceed the available width. Kept in this file to avoid a
/// cross-view layout helper until the project actually needs one elsewhere.
public struct WrappingHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    public let data: Data
    public let content: (Data.Element) -> Content
    public var spacing: CGFloat = 10

    public init(_ data: Data, spacing: CGFloat = 10, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo.size)
        }
        .frame(minHeight: 80)
    }

    private func generateContent(in size: CGSize) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            ForEach(data) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > size.width {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if item.id == data.last?.id { width = 0 } else { width -= d.width }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item.id == data.last?.id { height = 0 }
                        return result
                    }
            }
        }
    }
}
