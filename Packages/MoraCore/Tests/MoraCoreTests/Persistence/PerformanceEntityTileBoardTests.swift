import XCTest
import SwiftData

@testable import MoraCore

final class PerformanceEntityTileBoardTests: XCTestCase {
    func testDefaultsAreTileBoardNeutral() {
        let e = PerformanceEntity(
            sessionId: UUID(),
            skillCode: "L2.sh",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date()
        )
        XCTAssertNil(e.buildAttemptsJSON)
        XCTAssertEqual(e.scaffoldLevel, 0)
        XCTAssertFalse(e.ttsHintIssued)
        XCTAssertFalse(e.poolReducedToTwo)
        XCTAssertFalse(e.autoFilled)
    }

    func testTileBoardFieldsRoundTripViaDecodedJSON() throws {
        let attempts: [BuildAttemptRecord] = [
            BuildAttemptRecord(
                slotIndex: 0, tileDropped: Grapheme(letters: "s"), wasCorrect: false,
                timestampOffset: 0.5),
            BuildAttemptRecord(
                slotIndex: 0, tileDropped: Grapheme(letters: "sh"), wasCorrect: true,
                timestampOffset: 1.1),
        ]
        let data = try JSONEncoder().encode(attempts)
        let e = PerformanceEntity(
            sessionId: UUID(),
            skillCode: "L2.sh",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date(),
            buildAttemptsJSON: data,
            scaffoldLevel: 1,
            ttsHintIssued: true
        )
        XCTAssertEqual(e.scaffoldLevel, 1)
        XCTAssertTrue(e.ttsHintIssued)
        let decoded = try JSONDecoder().decode(
            [BuildAttemptRecord].self, from: XCTUnwrap(e.buildAttemptsJSON))
        XCTAssertEqual(decoded.count, 2)
    }
}
