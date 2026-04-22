import Foundation

struct BenchResult: Identifiable, Codable, Hashable {
    let id: UUID
    let modelID: String
    let promptID: String
    let startedAt: Date
    let finishedAt: Date

    // Load
    let coldLoadSeconds: Double?
    let warmLoadSeconds: Double?

    // Inference
    let inputTokenCount: Int
    let outputTokenCount: Int
    let ttftSeconds: Double
    let totalGenerationSeconds: Double
    var prefillTokensPerSecond: Double {
        guard ttftSeconds > 0 else { return 0 }
        return Double(inputTokenCount) / ttftSeconds
    }
    var decodeTokensPerSecond: Double {
        let decodeTime = totalGenerationSeconds - ttftSeconds
        guard decodeTime > 0, outputTokenCount > 1 else { return 0 }
        return Double(outputTokenCount - 1) / decodeTime
    }

    // Memory
    let peakRSSBytes: UInt64
    let availableMemoryMinBytes: UInt64
    let availableMemoryStartBytes: UInt64

    // Thermal
    let thermalSamples: [ThermalSample]

    // Output (for debugging prompt correctness, not part of timing)
    let outputPreview: String

    struct ThermalSample: Codable, Hashable {
        let offsetSeconds: Double
        let state: String
    }
}
