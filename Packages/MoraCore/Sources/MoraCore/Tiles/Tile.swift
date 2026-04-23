import Foundation

/// A single draggable tile on the decoding board. Identity is the grapheme —
/// two tiles with the same grapheme are the same tile for engine purposes.
public struct Tile: Hashable, Codable, Sendable, Identifiable {
    public let grapheme: Grapheme

    public var id: String { grapheme.letters }
    public var kind: TileKind { TileKind(grapheme: grapheme) }
    public var display: String { grapheme.letters }

    public init(grapheme: Grapheme) {
        self.grapheme = grapheme
    }
}
