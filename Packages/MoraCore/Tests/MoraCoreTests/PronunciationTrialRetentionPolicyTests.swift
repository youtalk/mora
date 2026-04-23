import XCTest
import SwiftData
@testable import MoraCore

@MainActor
final class PronunciationTrialRetentionPolicyTests: XCTestCase {
    func testCleanupBelowCapIsNoop() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        for i in 0..<100 {
            ctx.insert(row(at: i))
        }
        try ctx.save()
        try PronunciationTrialRetentionPolicy.cleanup(ctx)
        let count = try ctx.fetchCount(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(count, 100)
    }

    func testCleanupTrimsDownToCap() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        for i in 0..<1100 {
            ctx.insert(row(at: i))
        }
        try ctx.save()
        try PronunciationTrialRetentionPolicy.cleanup(ctx)
        let count = try ctx.fetchCount(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(count, PronunciationTrialRetentionPolicy.maxRows)
    }

    func testCleanupRemovesOldestFirst() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        for i in 0..<1005 {
            ctx.insert(row(at: i))
        }
        try ctx.save()
        try PronunciationTrialRetentionPolicy.cleanup(ctx)
        var desc = FetchDescriptor<PronunciationTrialLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        desc.fetchLimit = 1
        let oldest = try ctx.fetch(desc).first!
        XCTAssertGreaterThanOrEqual(oldest.timestamp.timeIntervalSince1970, 5)
    }

    private func row(at i: Int) -> PronunciationTrialLog {
        PronunciationTrialLog(
            timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
            wordSurface: "w\(i)",
            targetPhonemeIPA: "ʃ",
            engineALabel: "{\"label\":\"unclear\"}",
            engineAScore: nil,
            engineAFeaturesJSON: "{}",
            engineBState: "unsupported",
            engineBLabel: nil,
            engineBScore: nil,
            engineBLatencyMs: nil
        )
    }
}
