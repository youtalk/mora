import Foundation

public struct Word: Hashable, Codable, Sendable {
    public let surface: String
    public let graphemes: [Grapheme]
    public let phonemes: [Phoneme]

    public init(surface: String, graphemes: [Grapheme], phonemes: [Phoneme]) {
        self.surface = surface
        self.graphemes = graphemes
        self.phonemes = phonemes
    }

    public func isDecodable(
        taughtGraphemes: Set<Grapheme>,
        target: Grapheme?
    ) -> Bool {
        for g in graphemes {
            if taughtGraphemes.contains(g) { continue }
            if let target, g == target { continue }
            return false
        }
        return true
    }
}
