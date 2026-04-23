import XCTest
import MoraCore
@testable import MoraEngines

final class LibraryFirstWordChainProviderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testGenerateShPhaseFromBundledLibrary() throws {
        let inv = Set(["c", "a", "t", "u", "h", "sh", "i", "o", "p", "f", "d", "w", "m", "s"].map { Grapheme(letters: $0) })
        let provider = LibraryFirstWordChainProvider()
        let phase = try provider.generatePhase(target: g("sh"), masteredSet: inv)
        XCTAssertEqual(phase.count, 3)
        XCTAssertEqual(phase[0].role, .warmup)
        XCTAssertEqual(phase[1].role, .targetIntro)
        XCTAssertEqual(phase[2].role, .mixedApplication)
        XCTAssertEqual(phase[0].allWords.first?.surface, "cat")
        XCTAssertEqual(phase[1].allWords.first?.surface, "ship")
        XCTAssertEqual(phase[2].allWords.first?.surface, "fish")
    }

    func testMissingLibraryThrows() {
        let provider = LibraryFirstWordChainProvider()
        XCTAssertThrowsError(try provider.generatePhase(
            target: g("zz"),
            masteredSet: [g("zz")]
        ))
    }
}
