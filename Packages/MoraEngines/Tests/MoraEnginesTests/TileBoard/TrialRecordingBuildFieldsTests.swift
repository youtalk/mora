import XCTest
import MoraCore
@testable import MoraEngines

final class TrialRecordingBuildFieldsTests: XCTestCase {
    func testLegacyInitializerStillWorks() {
        let r = TrialRecording(asr: ASRResult(transcript: "ship", confidence: 0.9), audio: .empty)
        XCTAssertEqual(r.buildAttempts, [])
        XCTAssertEqual(r.scaffoldLevel, 0)
    }

    func testNewInitializerCarriesBuildTelemetry() {
        let attempt = BuildAttemptRecord(
            slotIndex: 0,
            tileDropped: Grapheme(letters: "s"),
            wasCorrect: false,
            timestampOffset: 0.4
        )
        let r = TrialRecording(
            asr: ASRResult(transcript: "ship", confidence: 0.9),
            audio: .empty,
            buildAttempts: [attempt],
            scaffoldLevel: 2
        )
        XCTAssertEqual(r.buildAttempts.count, 1)
        XCTAssertEqual(r.scaffoldLevel, 2)
    }
}
