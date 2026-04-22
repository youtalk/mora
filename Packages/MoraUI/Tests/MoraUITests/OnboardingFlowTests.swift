import MoraCore
import SwiftData
import XCTest

@testable import MoraUI

@MainActor
final class OnboardingFlowTests: XCTestCase {
    func test_stateProgression_advancesThroughSteps() {
        let state = OnboardingState()
        XCTAssertEqual(state.step, .welcome)
        state.advance()
        XCTAssertEqual(state.step, .name)
        state.advance()
        XCTAssertEqual(state.step, .interests)
        state.advance()
        XCTAssertEqual(state.step, .permission)
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func test_skipNameLeavesNameEmpty() {
        let state = OnboardingState()
        state.advance()  // to .name
        state.skipName()
        XCTAssertEqual(state.step, .interests)
        XCTAssertEqual(state.name, "")
    }

    func test_finalize_insertsProfileAndStreak_andSetsFlag() throws {
        let container = try MoraModelContainer.inMemory()
        let state = OnboardingState()
        state.name = "Hiro"
        state.selectedInterests = ["dinosaurs", "space", "robots"]
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.removeObject(forKey: OnboardingState.onboardedKey)

        state.finalize(in: container.mainContext, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: OnboardingState.onboardedKey))
        let profiles = try container.mainContext.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.displayName, "Hiro")
        XCTAssertEqual(
            Set(profiles.first?.interests ?? []), ["dinosaurs", "space", "robots"]
        )
        let streaks = try container.mainContext.fetch(FetchDescriptor<DailyStreak>())
        XCTAssertEqual(streaks.count, 1)
        XCTAssertEqual(streaks.first?.currentCount, 0)
    }
}
