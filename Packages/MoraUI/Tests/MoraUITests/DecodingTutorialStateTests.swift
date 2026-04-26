import XCTest
@testable import MoraUI

@MainActor
final class DecodingTutorialStateTests: XCTestCase {
    func testStartsAtSlot() {
        let state = DecodingTutorialState()
        XCTAssertEqual(state.step, .slot)
    }

    func testAdvanceWalksAllSteps() {
        let state = DecodingTutorialState()
        state.advance()
        XCTAssertEqual(state.step, .audio)
        state.advance()
        XCTAssertEqual(state.step, .finished)
        // Idempotent at terminal state.
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func testDismissFlipsFlag() {
        let suite = "test.DecodingTutorialStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(defaults.bool(forKey: DecodingTutorialState.seenKey))
        DecodingTutorialState().dismiss(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testSeenKeyIsNamespaced() {
        XCTAssertEqual(
            DecodingTutorialState.seenKey,
            "tech.reenable.Mora.decodingTutorialSeen"
        )
    }
}
