import XCTest

@testable import MoraEngines

@MainActor
final class MLXWarmupStateTests: XCTestCase {
    func testInitialPhaseIsNotStarted() {
        let state = MLXWarmupState()
        XCTAssertEqual(state.phase, .notStarted)
        XCTAssertFalse(state.isResolved)
    }

    func testLoadingTransitionKeepsResolvedFalse() {
        let state = MLXWarmupState()
        state.markLoading()
        XCTAssertEqual(state.phase, .loading)
        XCTAssertFalse(state.isResolved)
    }

    func testReadyIsResolved() {
        let state = MLXWarmupState()
        state.markLoading()
        state.markReady()
        XCTAssertEqual(state.phase, .ready)
        XCTAssertTrue(state.isResolved)
    }

    func testFailedIsResolvedSoStartIsNotPermanentlyBlocked() {
        let state = MLXWarmupState()
        state.markLoading()
        state.markFailed()
        XCTAssertEqual(state.phase, .failed)
        XCTAssertTrue(state.isResolved)
    }
}
