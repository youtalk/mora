import XCTest
import SwiftData

@testable import MoraCore

final class SchemaMigrationTests: XCTestCase {
    @MainActor
    func testInMemoryContainerAcceptsLegacyInsert() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = PerformanceEntity(
            sessionId: UUID(),
            skillCode: "L2.sh",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date()
        )
        ctx.insert(row)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PerformanceEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.scaffoldLevel, 0)
    }

    @MainActor
    func testSessionSummaryLegacyInsert() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = SessionSummaryEntity(
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "L2.sh",
            durationSec: 1000,
            trialsTotal: 12,
            trialsCorrect: 10,
            escalated: false
        )
        ctx.insert(row)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<SessionSummaryEntity>())
        XCTAssertNil(fetched.first?.tileBoardMetricsJSON)
    }
}
