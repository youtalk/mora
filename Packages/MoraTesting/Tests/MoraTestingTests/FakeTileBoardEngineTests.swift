import XCTest
import MoraCore
import MoraEngines
@testable import MoraTesting

@MainActor
final class FakeTileBoardEngineTests: XCTestCase {
    func testRecordsEventsInOrder() {
        let engine = FakeTileBoardEngine()
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        XCTAssertEqual(engine.recordedEvents, [.preparationFinished, .promptFinished])
    }

    func testShFixtureChainsHaveThreeValidChains() {
        let phase = FixtureWordChains.shPhase()
        XCTAssertEqual(phase.count, 3)
        XCTAssertEqual(phase[0].role, .warmup)
        XCTAssertEqual(phase[1].role, .targetIntro)
        XCTAssertEqual(phase[2].role, .mixedApplication)
    }
}
