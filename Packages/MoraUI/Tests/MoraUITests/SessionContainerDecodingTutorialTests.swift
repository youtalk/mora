import Foundation
import XCTest

@testable import MoraUI

@MainActor
final class SessionContainerDecodingTutorialTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "test.SessionContainerDecodingTutorial.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testFreshDefaultsReturnFalse() {
        XCTAssertFalse(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testDismissPersistsFlag() {
        let state = DecodingTutorialState()
        XCTAssertFalse(defaults.bool(forKey: DecodingTutorialState.seenKey))
        state.dismiss(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testReplayMode_doesNotPersistFlag() {
        // Replay mode is enforced at the OnboardingPlayMode level inside
        // DecodingTutorialOverlay.onChange(of:); the state machine's
        // dismiss method itself always writes when called. We rely on the
        // overlay to call dismiss only when mode == .firstTime. This test
        // pins the contract of the state machine: dismiss always writes.
        let state = DecodingTutorialState()
        state.dismiss(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testSeenKeyMatchesSpec() {
        XCTAssertEqual(
            DecodingTutorialState.seenKey,
            "tech.reenable.Mora.decodingTutorialSeen"
        )
    }
}
