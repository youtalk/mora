import Foundation

/// The head of a word chain: all slots empty, pool contains the word's
/// graphemes plus distractors.
public struct BuildTarget: Hashable, Codable, Sendable {
    public let word: Word

    public init(word: Word) {
        self.word = word
    }

    public var slots: [Grapheme] { word.graphemes }
}
