import XCTest
@testable import MoraCore

final class WordDecodabilityTests: XCTestCase {
    private let shipWord = Word(
        surface: "ship",
        graphemes: [
            Grapheme(letters: "sh"),
            Grapheme(letters: "i"),
            Grapheme(letters: "p"),
        ],
        phonemes: [
            Phoneme(ipa: "ʃ"),
            Phoneme(ipa: "ɪ"),
            Phoneme(ipa: "p"),
        ]
    )

    private let catWord = Word(
        surface: "cat",
        graphemes: [
            Grapheme(letters: "c"),
            Grapheme(letters: "a"),
            Grapheme(letters: "t"),
        ],
        phonemes: [
            Phoneme(ipa: "k"),
            Phoneme(ipa: "æ"),
            Phoneme(ipa: "t"),
        ]
    )

    func test_word_surfaceAndSegmentation() {
        XCTAssertEqual(shipWord.surface, "ship")
        XCTAssertEqual(shipWord.graphemes.count, 3)
    }

    func test_decodable_whenAllGraphemesTaught() {
        let taught: Set<Grapheme> = [
            .init(letters: "c"), .init(letters: "a"), .init(letters: "t"),
        ]
        XCTAssertTrue(catWord.isDecodable(taughtGraphemes: taught, target: nil))
    }

    func test_notDecodable_whenGraphemeMissing() {
        let taught: Set<Grapheme> = [
            .init(letters: "i"), .init(letters: "p"),
        ]
        XCTAssertFalse(shipWord.isDecodable(taughtGraphemes: taught, target: nil))
    }

    func test_decodable_whenTargetGraphemeCoversMissing() {
        let taught: Set<Grapheme> = [
            .init(letters: "i"), .init(letters: "p"),
        ]
        XCTAssertTrue(
            shipWord.isDecodable(
                taughtGraphemes: taught,
                target: Grapheme(letters: "sh")
            ))
    }
}
