import XCTest
import MoraCore
@testable import MoraEngines

final class OrchestratorEventShapeTests: XCTestCase {
    func testAnswerHeardCarriesTrialRecording() {
        let recording = TrialRecording(
            asr: ASRResult(transcript: "ship", confidence: 0.9),
            audio: .empty
        )
        let event = OrchestratorEvent.answerHeard(recording)
        guard case .answerHeard(let carried) = event else {
            return XCTFail("expected .answerHeard case")
        }
        XCTAssertEqual(carried.asr.transcript, "ship")
    }
}
