import XCTest
@testable import MoraBench

final class ResultStoreTests: XCTestCase {
    var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default.temporaryDirectory
            .appending(path: "bench-results-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempURL)
    }

    /// Regression for the encode/decode date-strategy mismatch that made
    /// the Results sheet silently empty: the file was written with
    /// `.iso8601` dates but `loadAll()` decoded with the default strategy
    /// (seconds since reference date), so decode failed silently via `try?`.
    func testAppendedResultSurvivesReload() {
        let store = ResultStore(fileURL: tempURL)
        let original = sampleResult()

        store.append(original)

        let reloaded = ResultStore(fileURL: tempURL).loadAll()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.first?.id, original.id)
        XCTAssertEqual(reloaded.first?.modelID, original.modelID)
        XCTAssertEqual(
            reloaded.first?.startedAt.timeIntervalSince1970 ?? 0,
            original.startedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testLoadAllReturnsEmptyWhenFileMissing() {
        let store = ResultStore(fileURL: tempURL)
        XCTAssertTrue(store.loadAll().isEmpty)
    }

    private func sampleResult() -> BenchResult {
        BenchResult(
            id: UUID(),
            modelID: "smollm-135m-4bit",
            promptID: "slot-fill-short",
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            finishedAt: Date(timeIntervalSince1970: 1_700_000_006),
            coldLoadSeconds: nil,
            warmLoadSeconds: nil,
            inputTokenCount: 234,
            outputTokenCount: 256,
            ttftSeconds: 2.4,
            totalGenerationSeconds: 6.3,
            peakRSSBytes: 275_611_648,
            availableMemoryMinBytes: 0,
            availableMemoryStartBytes: 0,
            thermalSamples: [
                .init(offsetSeconds: 0, state: "nominal"),
                .init(offsetSeconds: 6.3, state: "nominal"),
            ],
            outputPreview: "hello"
        )
    }
}
