import XCTest

@testable import MoraCore

final class SessionSummaryTileBoardTests: XCTestCase {
    func testDefaultTileBoardMetricsIsNil() {
        let s = SessionSummaryEntity(
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "L2.sh",
            durationSec: 1000,
            trialsTotal: 12,
            trialsCorrect: 10,
            escalated: false
        )
        XCTAssertNil(s.tileBoardMetricsJSON)
    }

    func testTileBoardMetricsRoundTrip() throws {
        let metrics = TileBoardMetrics(
            chainCount: 3, truncatedChainCount: 0, totalDropMisses: 2, autoFillCount: 0)
        let data = try JSONEncoder().encode(metrics)
        let s = SessionSummaryEntity(
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "L2.sh",
            durationSec: 1000,
            trialsTotal: 12,
            trialsCorrect: 11,
            escalated: false,
            tileBoardMetricsJSON: data
        )
        let back = try JSONDecoder().decode(
            TileBoardMetrics.self, from: XCTUnwrap(s.tileBoardMetricsJSON))
        XCTAssertEqual(back, metrics)
    }
}
