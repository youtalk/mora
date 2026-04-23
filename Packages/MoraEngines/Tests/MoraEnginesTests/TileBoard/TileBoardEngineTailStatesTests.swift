import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class TileBoardEngineTailStatesTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    private func completedEngine() -> TileBoardEngine {
        let word = Word(surface: "ship", graphemes: [g("sh"), g("i"), g("p")], phonemes: [])
        let trial = TileBoardTrial.build(
            target: BuildTarget(word: word),
            pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))]
        )
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        engine.apply(.tileDropped(slotIndex: 1, tileID: "i"))
        engine.apply(.tileDropped(slotIndex: 2, tileID: "p"))
        return engine
    }

    func testCompletionAnimationAdvancesToSpeaking() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        XCTAssertEqual(engine.state, .speaking)
    }

    func testUtteranceRecordedAdvancesToFeedback() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        engine.apply(.utteranceRecorded)
        XCTAssertEqual(engine.state, .feedback)
    }

    func testFeedbackDismissedAdvancesToTransitioning() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        engine.apply(.utteranceRecorded)
        engine.apply(.feedbackDismissed)
        XCTAssertEqual(engine.state, .transitioning)
    }

    func testResultAfterCleanRunHasZeroScaffold() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        engine.apply(.utteranceRecorded)
        engine.apply(.feedbackDismissed)
        let result = engine.result
        XCTAssertEqual(result.scaffoldLevel, 0)
        XCTAssertEqual(result.buildAttempts.count, 3)
        XCTAssertEqual(result.word.surface, "ship")
    }
}
