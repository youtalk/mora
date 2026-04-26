import Foundation
import XCTest

@testable import MoraUI

@MainActor
final class SessionContainerDecodingTutorialTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "test.SessionContainerDecodingTutorial.\(UUID().uuidString)"

    override func setUpWithError() throws {
        try super.setUpWithError()
        // UserDefaults(suiteName:) returns nil on invalid suite names
        // (e.g. matching the main bundle id or starting with "."); surface
        // that explicitly instead of crashing on a force-unwrap later.
        defaults = try XCTUnwrap(
            UserDefaults(suiteName: suite),
            "Failed to construct UserDefaults suite \(suite)"
        )
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suite)
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

    func testDismissAlwaysWritesRegardlessOfMode() {
        // The replay-mode contract — "do not flip the seen flag on a
        // help-button replay" — is enforced upstream, in
        // DecodingTutorialOverlay.onChange(of:): the overlay only invokes
        // dismiss when mode == .firstTime. The state machine's dismiss
        // itself is unconditional. This test pins that lower-level
        // contract: once dismiss runs, the flag is set, regardless of
        // which OnboardingPlayMode the caller was rendering.
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
