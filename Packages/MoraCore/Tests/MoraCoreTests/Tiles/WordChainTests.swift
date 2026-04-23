import XCTest

@testable import MoraCore

final class WordChainTests: XCTestCase {
    private func w(_ surface: String, _ gs: [String]) -> Word {
        Word(surface: surface, graphemes: gs.map { Grapheme(letters: $0) }, phonemes: [])
    }

    private let shInventory: Set<Grapheme> = Set(
        ["c", "s", "h", "i", "o", "p", "t", "sh"].map { Grapheme(letters: $0) }
    )

    func testValidChain() {
        let chain = WordChain(
            role: .targetIntro,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("shop", ["sh", "o", "p"]), w("shot", ["sh", "o", "t"])],
            inventory: shInventory
        )
        XCTAssertNotNil(chain)
        XCTAssertEqual(chain?.successors.count, 2)
        XCTAssertEqual(chain?.successors.first?.changedIndex, 1)
    }

    func testRejectsChainWithNondecodableWord() {
        let chain = WordChain(
            role: .warmup,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("shab", ["sh", "a", "b"])],  // 'a' and 'b' not in inventory
            inventory: shInventory
        )
        XCTAssertNil(chain)
    }

    func testRejectsChainWithTwoPositionDelta() {
        let chain = WordChain(
            role: .warmup,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("shot", ["sh", "o", "t"])],  // two positions differ
            inventory: shInventory
        )
        XCTAssertNil(chain)
    }

    func testRejectsChainHeadOutsideInventory() {
        let chain = WordChain(
            role: .warmup,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [],
            inventory: Set(["c", "a", "t"].map { Grapheme(letters: $0) })
        )
        XCTAssertNil(chain)
    }

    func testAllowsDigraphToDigraphReplacement() {
        let inv = Set(["sh", "ch", "i", "p"].map { Grapheme(letters: $0) })
        let chain = WordChain(
            role: .mixedApplication,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("chip", ["ch", "i", "p"])],
            inventory: inv
        )
        XCTAssertNotNil(chain)
    }

    func testRejectsDigraphToSingleLetterReplacement() {
        // Spec §8.3: digraphs swap with digraphs, single letters with single
        // letters. `sh` (digraph) → `s` (single) is not a valid delta even
        // though both graphemes are in the inventory.
        let inv = Set(["sh", "s", "i", "p"].map { Grapheme(letters: $0) })
        let chain = WordChain(
            role: .mixedApplication,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("sip", ["s", "i", "p"])],
            inventory: inv
        )
        XCTAssertNil(chain)
    }
}
