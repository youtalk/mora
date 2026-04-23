import XCTest
import MoraCore
@testable import MoraEngines

final class OrchestratorEventTileBoardShapeTests: XCTestCase {
    func testTileBoardEventsAreDistinct() {
        let recording = TrialRecording(asr: ASRResult(transcript: "ship", confidence: 0.9), audio: .empty)
        let events: Set<OrchestratorEvent> = [
            .tileBoardTrialCompleted(recording),
            .chainFinished(.warmup),
            .phaseFinished(TileBoardMetrics(chainCount: 3)),
        ]
        XCTAssertEqual(events.count, 3)
    }
}
