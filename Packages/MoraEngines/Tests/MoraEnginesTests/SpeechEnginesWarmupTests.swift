import MoraTesting
import XCTest

@testable import MoraEngines

@MainActor
final class SpeechEnginesWarmupTests: XCTestCase {
    func testInitialPhaseIsNotStarted() {
        let state = SpeechEnginesWarmup()
        XCTAssertEqual(state.phase, .notStarted)
        XCTAssertFalse(state.isResolved)
        XCTAssertNil(state.speechEngine)
        XCTAssertNil(state.ttsEngine)
        XCTAssertNil(state.speechFailureReason)
    }

    func testMarkLoadingMovesPhaseToLoading() {
        let state = SpeechEnginesWarmup()
        state.markLoading()
        XCTAssertEqual(state.phase, .loading)
        XCTAssertFalse(state.isResolved)
    }

    func testResolveWithBothEnginesPopulatesEngines() {
        let state = SpeechEnginesWarmup()
        let speech = FakeSpeechEngine()
        let tts = FakeTTSEngine()
        state.markLoading()
        state.resolve(speechEngine: speech, ttsEngine: tts)
        XCTAssertEqual(state.phase, .resolved)
        XCTAssertTrue(state.isResolved)
        XCTAssertNotNil(state.speechEngine)
        XCTAssertNotNil(state.ttsEngine)
        XCTAssertNil(state.speechFailureReason)
    }

    func testResolveWithSpeechNilRecordsFailureReason() {
        let state = SpeechEnginesWarmup()
        let tts = FakeTTSEngine()
        state.markLoading()
        state.resolve(speechEngine: nil, ttsEngine: tts, speechFailureReason: "test failure")
        XCTAssertEqual(state.phase, .resolved)
        XCTAssertTrue(state.isResolved)
        XCTAssertNil(state.speechEngine)
        XCTAssertNotNil(state.ttsEngine)
        XCTAssertEqual(state.speechFailureReason, "test failure")
    }
}
