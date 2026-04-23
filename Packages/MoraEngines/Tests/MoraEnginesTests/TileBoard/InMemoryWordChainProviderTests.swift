import XCTest
import MoraCore
@testable import MoraEngines

final class InMemoryWordChainProviderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testProviderReturnsInjectedPhase() throws {
        let inventory: Set<Grapheme> = Set(["c", "a", "t", "u", "h", "sh", "i", "p", "o", "f", "d", "w", "m", "s"].map { Grapheme(letters: $0) })
        let warmupHead = Word(surface: "cat", graphemes: [g("c"), g("a"), g("t")], phonemes: [])
        let warmup = try XCTUnwrap(WordChain(
            role: .warmup,
            head: BuildTarget(word: warmupHead),
            successorWords: [
                Word(surface: "cut", graphemes: [g("c"), g("u"), g("t")], phonemes: []),
                Word(surface: "hut", graphemes: [g("h"), g("u"), g("t")], phonemes: []),
                Word(surface: "hat", graphemes: [g("h"), g("a"), g("t")], phonemes: []),
            ],
            inventory: inventory
        ))
        let provider = InMemoryWordChainProvider(phase: [warmup, warmup, warmup])  // stubbed intro/mixed
        let phase = try provider.generatePhase(
            target: Grapheme(letters: "sh"),
            masteredSet: inventory
        )
        XCTAssertEqual(phase.count, 3)
    }

    func testProviderThrowsWhenUnderThreeChains() {
        let provider = InMemoryWordChainProvider(phase: [])
        XCTAssertThrowsError(try provider.generatePhase(
            target: Grapheme(letters: "sh"),
            masteredSet: []
        ))
    }
}
