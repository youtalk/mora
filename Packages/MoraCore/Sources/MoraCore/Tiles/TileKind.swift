import Foundation

public enum TileKind: String, Hashable, Codable, Sendable {
    case consonant
    case vowel
    case multigrapheme

    public init(grapheme: Grapheme) {
        if grapheme.letters.count == 1, "aeiou".contains(grapheme.letters) {
            self = .vowel
        } else if grapheme.letters.count == 1 {
            self = .consonant
        } else {
            self = .multigrapheme
        }
    }
}
