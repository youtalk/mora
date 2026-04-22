import Foundation

public struct Phoneme: Hashable, Codable, Sendable {
    public let ipa: String

    public init(ipa: String) {
        self.ipa = ipa
    }
}

public struct GraphemePhoneme: Hashable, Codable, Sendable {
    public let grapheme: Grapheme
    public let phoneme: Phoneme

    public init(grapheme: Grapheme, phoneme: Phoneme) {
        self.grapheme = grapheme
        self.phoneme = phoneme
    }
}
