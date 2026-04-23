import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class TileBoardEnginePreparingListeningTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    private func ship() -> Word {
        Word(surface: "ship", graphemes: [g("sh"), g("i"), g("p")], phonemes: [])
    }

    func testEngineStartsInPreparingForBuildTrial() {
        let trial = TileBoardTrial.build(
            target: BuildTarget(word: ship()),
            pool: [
                Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
            ])
        let engine = TileBoardEngine(trial: trial)
        XCTAssertEqual(engine.state, .preparing)
    }

    func testPreparationFinishedAdvancesToListening() {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: [])
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        XCTAssertEqual(engine.state, .listening)
    }

    func testPromptFinishedAdvancesToBuilding() {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: [])
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        XCTAssertEqual(engine.state, .building)
    }
}
