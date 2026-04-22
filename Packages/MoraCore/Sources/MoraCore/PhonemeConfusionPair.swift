import Foundation

public enum CharacterSystem: String, Hashable, Codable, Sendable, CaseIterable {
    case alphabetic
    case logographic
    case mixed
}

public struct PhonemeConfusionPair: Hashable, Codable, Sendable {
    public let tag: String
    public let from: Phoneme
    public let to: Phoneme
    public let examples: [String]
    public let bidirectional: Bool

    public init(
        tag: String, from: Phoneme, to: Phoneme,
        examples: [String] = [], bidirectional: Bool = false
    ) {
        self.tag = tag
        self.from = from
        self.to = to
        self.examples = examples
        self.bidirectional = bidirectional
    }
}
