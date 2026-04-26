import XCTest

@testable import MoraUI

final class MicButtonStateTests: XCTestCase {
    func test_iconName_perState() {
        XCTAssertEqual(MicButtonState.idle.iconName, "mic.fill")
        XCTAssertEqual(MicButtonState.listening.iconName, "waveform")
        XCTAssertEqual(MicButtonState.assessing.iconName, "ellipsis")
    }

    func test_micUIState_buttonState_mapping() {
        XCTAssertEqual(MicUIState.idle.buttonState, .idle)
        XCTAssertEqual(MicUIState.listening(partialText: "fi").buttonState, .listening)
        XCTAssertEqual(MicUIState.listening(partialText: "").buttonState, .listening)
        XCTAssertEqual(MicUIState.assessing.buttonState, .assessing)
    }
}
