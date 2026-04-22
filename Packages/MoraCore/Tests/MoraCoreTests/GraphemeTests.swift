import XCTest
@testable import MoraCore

final class GraphemeTests: XCTestCase {
    func test_singleLetter_isSingleKind() {
        let g = Grapheme(letters: "a")
        XCTAssertEqual(g.kind, .single)
        XCTAssertEqual(g.letters, "a")
    }

    func test_twoLetters_isDigraph() {
        XCTAssertEqual(Grapheme(letters: "sh").kind, .digraph)
        XCTAssertEqual(Grapheme(letters: "ch").kind, .digraph)
    }

    func test_threeLetters_isTrigraph() {
        XCTAssertEqual(Grapheme(letters: "tch").kind, .trigraph)
    }

    func test_graphemes_areCaseFolded() {
        XCTAssertEqual(Grapheme(letters: "SH"), Grapheme(letters: "sh"))
    }

    func test_graphemes_areCodable() throws {
        let g = Grapheme(letters: "sh")
        let data = try JSONEncoder().encode(g)
        let decoded = try JSONDecoder().decode(Grapheme.self, from: data)
        XCTAssertEqual(decoded, g)
    }
}
