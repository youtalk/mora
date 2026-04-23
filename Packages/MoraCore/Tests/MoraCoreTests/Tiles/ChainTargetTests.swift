import XCTest

@testable import MoraCore

final class ChainTargetTests: XCTestCase {
    private func w(_ surface: String, _ graphemes: [String]) -> Word {
        Word(
            surface: surface,
            graphemes: graphemes.map { Grapheme(letters: $0) },
            phonemes: []
        )
    }

    func testBuildTargetExposesSlotGraphemes() {
        let t = BuildTarget(word: w("ship", ["sh", "i", "p"]))
        XCTAssertEqual(t.slots.map(\.letters), ["sh", "i", "p"])
    }

    func testChangeTargetIdentifiesChangedIndex() {
        let pred = w("ship", ["sh", "i", "p"])
        let succ = w("shop", ["sh", "o", "p"])
        let t = ChangeTarget(predecessor: pred, successor: succ)
        XCTAssertEqual(t?.changedIndex, 1)
        XCTAssertEqual(t?.oldGrapheme.letters, "i")
        XCTAssertEqual(t?.newGrapheme.letters, "o")
    }

    func testChangeTargetReturnsNilWhenLengthsDiffer() {
        // "ship" has 3 grapheme slots; "stomp" has 5 — slot counts differ.
        let pred = w("ship", ["sh", "i", "p"])
        let succ = w("stomp", ["s", "t", "o", "m", "p"])
        XCTAssertNil(ChangeTarget(predecessor: pred, successor: succ))
    }

    func testChangeTargetReturnsNilWhenMultiplePositionsDiffer() {
        let pred = w("cat", ["c", "a", "t"])
        let succ = w("dog", ["d", "o", "g"])
        XCTAssertNil(ChangeTarget(predecessor: pred, successor: succ))
    }
}
