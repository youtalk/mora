import XCTest
@testable import MoraBench

final class MetricsCollectorTests: XCTestCase {
    func testTokensPerSecondComputation() {
        let result = BenchResult(
            id: UUID(),
            modelID: "m", promptID: "p",
            startedAt: Date(), finishedAt: Date(),
            coldLoadSeconds: nil, warmLoadSeconds: nil,
            inputTokenCount: 200,
            outputTokenCount: 41,
            ttftSeconds: 0.5,
            totalGenerationSeconds: 2.5,
            peakRSSBytes: 0, availableMemoryMinBytes: 0, availableMemoryStartBytes: 0,
            thermalSamples: [], outputPreview: ""
        )
        // prefill: 200 / 0.5 = 400
        XCTAssertEqual(result.prefillTokensPerSecond, 400, accuracy: 0.01)
        // decode: (41 - 1) / (2.5 - 0.5) = 20
        XCTAssertEqual(result.decodeTokensPerSecond, 20, accuracy: 0.01)
    }

    func testDecodeZeroWhenOutputSingleton() {
        let result = BenchResult(
            id: UUID(), modelID: "m", promptID: "p",
            startedAt: Date(), finishedAt: Date(),
            coldLoadSeconds: nil, warmLoadSeconds: nil,
            inputTokenCount: 10, outputTokenCount: 1,
            ttftSeconds: 0.2, totalGenerationSeconds: 0.2,
            peakRSSBytes: 0, availableMemoryMinBytes: 0, availableMemoryStartBytes: 0,
            thermalSamples: [], outputPreview: ""
        )
        XCTAssertEqual(result.decodeTokensPerSecond, 0)
    }
}
