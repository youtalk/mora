import XCTest
@testable import MoraEngines

final class TileBoardStateTests: XCTestCase {
    func testStatesAreExhaustive() {
        let all: [TileBoardState] = [
            .preparing, .listening, .building, .completed, .speaking, .feedback, .transitioning,
        ]
        XCTAssertEqual(Set(all.map(\.debugTag)).count, all.count)
    }

    func testEventsAreExhaustiveAndHashable() {
        let set: Set<TileBoardEvent> = [
            .preparationFinished,
            .promptFinished,
            .tileLifted(tileID: "sh"),
            .tileDropped(slotIndex: 0, tileID: "sh"),
            .completionAnimationFinished,
            .utteranceRecorded,
            .feedbackDismissed,
            .transitionFinished,
        ]
        XCTAssertEqual(set.count, 8)
    }
}
