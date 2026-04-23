import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class TileBoardEngineBuildingTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    private func ship() -> Word {
        Word(surface: "ship", graphemes: [g("sh"), g("i"), g("p")], phonemes: [])
    }

    private func primedEngine(pool: [Tile]) -> TileBoardEngine {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: pool)
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        return engine
    }

    func testCorrectDropLocksSlotAndRecordsAttempt() {
        let engine = primedEngine(pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        XCTAssertEqual(engine.filled[0], g("sh"))
        XCTAssertEqual(engine.buildAttempts.last?.wasCorrect, true)
    }

    func testWrongDropLeavesSlotEmptyAndRecordsMiss() {
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
        ])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "ch"))
        XCTAssertNil(engine.filled[0])
        XCTAssertEqual(engine.buildAttempts.last?.wasCorrect, false)
        XCTAssertEqual(engine.slotMissCount(for: 0), 1)
        XCTAssertEqual(engine.lastIntervention, .bounceBack)
    }

    func testSecondMissOnSameSlotRaisesTTSHint() {
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("t")), Tile(grapheme: g("i")),
            Tile(grapheme: g("p")),
        ])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "ch"))
        engine.apply(.tileDropped(slotIndex: 0, tileID: "t"))
        XCTAssertEqual(engine.lastIntervention, .ttsHint)
        XCTAssertTrue(engine.ttsHintIssued)
    }

    func testFourthMissAutoFillsSlotAndRaisesScaffoldLevel() {
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("t")),
            Tile(grapheme: g("k")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
        ])
        for bad in ["ch", "t", "k", "ch"] {
            engine.apply(.tileDropped(slotIndex: 0, tileID: bad))
        }
        XCTAssertEqual(engine.filled[0], g("sh"))
        XCTAssertTrue(engine.autoFilled)
        XCTAssertEqual(engine.scaffoldLevel, 4)
        XCTAssertEqual(engine.autoFilledSlots, [0])
    }

    func testAutoFillRecordsOnlyTheRescuedSlotIndex() {
        // Slot 0 is rescued by auto-fill; slots 1 and 2 are placed correctly
        // by the learner. The view layer should only show the dashed
        // auto-fill chrome on slot 0.
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("t")),
            Tile(grapheme: g("k")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
        ])
        for bad in ["ch", "t", "k", "ch"] {
            engine.apply(.tileDropped(slotIndex: 0, tileID: bad))
        }
        engine.apply(.tileDropped(slotIndex: 1, tileID: "i"))
        engine.apply(.tileDropped(slotIndex: 2, tileID: "p"))
        XCTAssertEqual(engine.autoFilledSlots, [0])
        XCTAssertEqual(engine.state, .completed)
    }

    func testAutoFillCompletionMatchesNormalDropCompletion() {
        // Auto-fill of the last empty slot must transition to .completed
        // exactly the same way a correct drop on the last slot does.
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
            Tile(grapheme: g("ch")), Tile(grapheme: g("t")), Tile(grapheme: g("k")),
        ])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        engine.apply(.tileDropped(slotIndex: 1, tileID: "i"))
        for bad in ["ch", "t", "k", "ch"] {
            engine.apply(.tileDropped(slotIndex: 2, tileID: bad))
        }
        XCTAssertEqual(engine.filled[2], g("p"))
        XCTAssertEqual(engine.state, .completed)
        XCTAssertEqual(engine.autoFilledSlots, [2])
    }

    func testCompletingAllSlotsAdvancesToCompleted() {
        let engine = primedEngine(pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        engine.apply(.tileDropped(slotIndex: 1, tileID: "i"))
        engine.apply(.tileDropped(slotIndex: 2, tileID: "p"))
        XCTAssertEqual(engine.state, .completed)
    }

    func testCorrectDropAfterMissClearsLastIntervention() {
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
        ])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "ch"))
        XCTAssertEqual(engine.lastIntervention, .bounceBack)
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        XCTAssertNil(engine.lastIntervention)
    }
}
