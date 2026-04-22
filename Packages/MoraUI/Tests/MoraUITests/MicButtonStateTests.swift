import XCTest

@testable import MoraUI

final class MicButtonStateTests: XCTestCase {
    func test_iconName_perState() {
        XCTAssertEqual(MicButtonState.idle.iconName, "mic.fill")
        XCTAssertEqual(MicButtonState.listening.iconName, "waveform")
        XCTAssertEqual(MicButtonState.assessing.iconName, "ellipsis")
    }

    func test_accessibilityLabel_perState() {
        XCTAssertEqual(MicButtonState.idle.accessibilityLabel, "Start speaking")
        XCTAssertEqual(MicButtonState.listening.accessibilityLabel, "Listening")
        XCTAssertEqual(MicButtonState.assessing.accessibilityLabel, "Checking your answer")
    }

    func test_accessibilityHint_perState() {
        XCTAssertEqual(MicButtonState.idle.accessibilityHint, "Tap to start recording")
        XCTAssertEqual(MicButtonState.listening.accessibilityHint, "Tap to stop recording")
        // .assessing is non-interactive; an empty hint keeps VoiceOver quiet.
        XCTAssertEqual(MicButtonState.assessing.accessibilityHint, "")
    }

    func test_micUIState_buttonState_mapping() {
        XCTAssertEqual(MicUIState.idle.buttonState, .idle)
        XCTAssertEqual(MicUIState.listening(partialText: "fi").buttonState, .listening)
        XCTAssertEqual(MicUIState.listening(partialText: "").buttonState, .listening)
        XCTAssertEqual(MicUIState.assessing.buttonState, .assessing)
    }
}
