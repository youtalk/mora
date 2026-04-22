import Foundation
import MoraCore

public struct DecodeWord: Hashable, Codable, Sendable {
    public let word: Word
    public let note: String?

    public init(word: Word, note: String? = nil) {
        self.word = word
        self.note = note
    }
}

public struct DecodeSentence: Hashable, Codable, Sendable {
    public let text: String
    public let words: [Word]

    public init(text: String, words: [Word]) {
        self.text = text
        self.words = words
    }
}

public struct ContentRequest: Sendable {
    public let target: Grapheme
    public let taughtGraphemes: Set<Grapheme>
    public let interests: [InterestCategory]
    public let count: Int

    public init(target: Grapheme, taughtGraphemes: Set<Grapheme>,
                interests: [InterestCategory], count: Int) {
        self.target = target
        self.taughtGraphemes = taughtGraphemes
        self.interests = interests
        self.count = count
    }
}

public protocol ContentProvider: Sendable {
    func decodeWords(_ request: ContentRequest) throws -> [DecodeWord]
    func decodeSentences(_ request: ContentRequest) throws -> [DecodeSentence]
}
