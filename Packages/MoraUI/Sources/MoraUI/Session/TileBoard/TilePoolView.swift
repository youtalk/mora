import MoraCore
import SwiftUI
import UniformTypeIdentifiers

public struct TilePoolView: View {
    public let tiles: [Tile]
    public let reduceMotion: Bool
    public var onLift: (String) -> Void = { _ in }

    public init(tiles: [Tile], reduceMotion: Bool = false, onLift: @escaping (String) -> Void = { _ in }) {
        self.tiles = tiles
        self.reduceMotion = reduceMotion
        self.onLift = onLift
    }

    public var body: some View {
        WrappingHStack(tiles) { tile in
            TileView(tile: tile, visual: .idle, reduceMotion: reduceMotion)
                .onDrag {
                    onLift(tile.id)
                    return NSItemProvider(object: tile.id as NSString)
                }
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
