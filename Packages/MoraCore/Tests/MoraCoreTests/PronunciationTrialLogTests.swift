import XCTest
import SwiftData
@testable import MoraCore

@MainActor
final class PronunciationTrialLogTests: XCTestCase {
    func testInsertAndFetchRoundTrip() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = PronunciationTrialLog(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            wordSurface: "ship",
            targetPhonemeIPA: "ʃ",
            engineALabel: "{\"label\":\"matched\"}",
            engineAScore: 88,
            engineAFeaturesJSON: "{\"spectralCentroid\":3100}",
            engineBState: "completed",
            engineBLabel: "{\"label\":\"matched\"}",
            engineBScore: 91,
            engineBLatencyMs: 240
        )
        ctx.insert(row)
        try ctx.save()

        var descriptor = FetchDescriptor<PronunciationTrialLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.fetchLimit = 10
        let rows = try ctx.fetch(descriptor)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].wordSurface, "ship")
        XCTAssertEqual(rows[0].engineAScore, 88)
        XCTAssertEqual(rows[0].engineBState, "completed")
        XCTAssertEqual(rows[0].engineBLatencyMs, 240)
    }

    func testOptionalFieldsRoundTripAsNil() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = PronunciationTrialLog(
            timestamp: Date(),
            wordSurface: "sheep",
            targetPhonemeIPA: "ʃ",
            engineALabel: "{\"label\":\"unclear\"}",
            engineAScore: nil,
            engineAFeaturesJSON: "{}",
            engineBState: "timedOut",
            engineBLabel: nil,
            engineBScore: nil,
            engineBLatencyMs: 1000
        )
        ctx.insert(row)
        try ctx.save()
        let rows = try ctx.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertNil(rows[0].engineAScore)
        XCTAssertNil(rows[0].engineBLabel)
        XCTAssertEqual(rows[0].engineBLatencyMs, 1000)
    }

    func testSchemaIncludesEntity() {
        let types = MoraModelContainer.schema.entities.map { $0.name }
        XCTAssertTrue(types.contains("PronunciationTrialLog"))
    }
}
