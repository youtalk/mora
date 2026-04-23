import XCTest

@testable import MoraCore

final class TileKindTests: XCTestCase {
    func testSingleVowelLettersAreVowel() {
        for letter in ["a", "e", "i", "o", "u"] {
            XCTAssertEqual(TileKind(grapheme: Grapheme(letters: letter)), .vowel, "\(letter) should be vowel")
        }
    }

    func testSingleConsonantLettersAreConsonant() {
        for letter in ["b", "c", "d", "f", "s", "t", "z"] {
            XCTAssertEqual(TileKind(grapheme: Grapheme(letters: letter)), .consonant, "\(letter) should be consonant")
        }
    }

    func testDigraphsAndLongerAreMultigrapheme() {
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "sh")), .multigrapheme)
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "ch")), .multigrapheme)
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "str")), .multigrapheme)
    }

    func testUppercaseInputIsLowercasedByGrapheme() {
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "A")), .vowel)
    }
}
