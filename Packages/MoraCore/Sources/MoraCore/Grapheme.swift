import Foundation

public enum GraphemeKind: String, Hashable, Codable, Sendable {
    case single
    case digraph
    case trigraph
    case longer
}

public struct Grapheme: Hashable, Codable, Sendable {
    public let letters: String

    public init(letters: String) {
        self.letters = letters.lowercased()
    }

    public var kind: GraphemeKind {
        switch letters.count {
        case 1: return .single
        case 2: return .digraph
        case 3: return .trigraph
        default: return .longer
        }
    }
}
