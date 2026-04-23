import XCTest

@testable import MoraCore

final class TelemetryTests: XCTestCase {
    func testBuildAttemptRecordRoundTrips() throws {
        let r = BuildAttemptRecord(
            slotIndex: 1,
            tileDropped: Grapheme(letters: "i"),
            wasCorrect: false,
            timestampOffset: 1.25
        )
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(BuildAttemptRecord.self, from: data)
        XCTAssertEqual(r, back)
    }

    func testTileBoardMetricsDefaults() {
        let m = TileBoardMetrics()
        XCTAssertEqual(m.chainCount, 0)
        XCTAssertEqual(m.truncatedChainCount, 0)
        XCTAssertEqual(m.totalDropMisses, 0)
        XCTAssertEqual(m.autoFillCount, 0)
    }
}
