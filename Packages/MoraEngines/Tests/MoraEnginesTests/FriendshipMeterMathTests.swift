import XCTest
@testable import MoraEngines

final class FriendshipMeterMathTests: XCTestCase {
    func test_correctTrialAddsTwoPercentagePoints() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.10, correct: true, dayGainSoFar: 0.0)
        XCTAssertEqual(after.percent, 0.12, accuracy: 1e-9)
        XCTAssertEqual(after.dayGain, 0.02, accuracy: 1e-9)
    }

    func test_missedTrialLeavesPercentUnchanged() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.10, correct: false, dayGainSoFar: 0.0)
        XCTAssertEqual(after.percent, 0.10, accuracy: 1e-9)
        XCTAssertEqual(after.dayGain, 0.0, accuracy: 1e-9)
    }

    func test_dayGainCapHaltsFurtherCredit() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.50, correct: true, dayGainSoFar: 0.25)
        XCTAssertEqual(after.percent, 0.50, accuracy: 1e-9)  // cap reached before
        XCTAssertEqual(after.dayGain, 0.25, accuracy: 1e-9)
    }

    func test_sessionCompletionAddsFivePp() {
        let after = FriendshipMeterMath.applySessionCompletion(percent: 0.30, dayGainSoFar: 0.15)
        XCTAssertEqual(after.percent, 0.35, accuracy: 1e-9)
        XCTAssertEqual(after.dayGain, 0.20, accuracy: 1e-9)
    }

    func test_sessionCompletionRespectsDayCap() {
        let after = FriendshipMeterMath.applySessionCompletion(percent: 0.40, dayGainSoFar: 0.22)
        // only 3pp of the 5pp bonus fits before the 25pp day cap
        XCTAssertEqual(after.percent, 0.43, accuracy: 1e-9)
        XCTAssertEqual(after.dayGain, 0.25, accuracy: 1e-9)
    }

    func test_percentClampedToOne() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.99, correct: true, dayGainSoFar: 0.0)
        XCTAssertEqual(after.percent, 1.0, accuracy: 1e-9)
    }

    func test_floorBoostLiftsTowardOneHundred() {
        // Under-performing week: Friday with 60% at 4 trials remaining should weight each to >= 10pp.
        let boost = FriendshipMeterMath.floorBoostWeight(currentPercent: 0.60, trialsRemaining: 4)
        XCTAssertGreaterThanOrEqual(boost, 0.10)
    }
}
