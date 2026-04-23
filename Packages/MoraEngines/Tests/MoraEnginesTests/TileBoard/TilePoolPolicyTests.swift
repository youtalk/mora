import XCTest
import MoraCore
@testable import MoraEngines

final class TilePoolPolicyTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testBuildFromWordReturnsWordTilesPlusDistractors() {
        let word = Word(
            surface: "ship",
            graphemes: [g("sh"), g("i"), g("p")],
            phonemes: []
        )
        let distractors: Set<Grapheme> = [g("t"), g("a"), g("ch")]
        let policy = TilePoolPolicy.buildFromWord(word: word, extraDistractors: 2)
        let tiles = policy.resolve(distractorsPool: distractors)
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("sh"))))
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("i"))))
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("p"))))
        XCTAssertEqual(tiles.count, 5)
    }

    func testChangeModeAllowsReplacementsOfCorrectKind() {
        let vowelDistractors: Set<Grapheme> = [g("a"), g("e"), g("o"), g("u")]
        let policy = TilePoolPolicy.changeSlot(
            correct: g("o"),
            kind: .vowel,
            extraDistractors: 3
        )
        let tiles = policy.resolve(distractorsPool: vowelDistractors)
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("o"))))
        XCTAssertTrue(tiles.allSatisfy { $0.kind == .vowel })
    }

    func testReducedToTwoReturnsExactlyTwoTiles() {
        let policy = TilePoolPolicy.reducedToTwo(correct: g("o"), distractor: g("a"))
        let tiles = policy.resolve(distractorsPool: [])
        XCTAssertEqual(Set(tiles), [Tile(grapheme: g("o")), Tile(grapheme: g("a"))])
    }
}
