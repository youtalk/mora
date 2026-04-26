import XCTest
@testable import MoraUI

@MainActor
final class YokaiIntroStateTests: XCTestCase {
    func testStartsAtConcept() {
        let state = YokaiIntroState()
        XCTAssertEqual(state.step, .concept)
    }

    func testAdvanceWalksAllSteps() {
        let state = YokaiIntroState()
        state.advance()
        XCTAssertEqual(state.step, .todayYokai)
        state.advance()
        XCTAssertEqual(state.step, .sessionShape)
        state.advance()
        XCTAssertEqual(state.step, .progress)
        state.advance()
        XCTAssertEqual(state.step, .finished)
        // Idempotent at terminal state.
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func testFinalizeFlipsFlag() {
        let suite = "test.YokaiIntroStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(defaults.bool(forKey: YokaiIntroState.onboardedKey))
        YokaiIntroState().finalize(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: YokaiIntroState.onboardedKey))
    }

    func testOnboardedKeyIsNamespaced() {
        XCTAssertEqual(
            YokaiIntroState.onboardedKey,
            "tech.reenable.Mora.yokaiIntroSeen"
        )
    }
}
