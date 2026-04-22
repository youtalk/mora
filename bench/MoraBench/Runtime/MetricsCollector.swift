import Foundation

final class MetricsCollector {
    private let startClock = DispatchTime.now()
    private var firstTokenClock: DispatchTime?
    private var lastSampleClock: DispatchTime?
    private var outputTokens = 0
    private var peakRSS: UInt64 = 0
    private var minAvailable: UInt64 = .max
    private let availableStart: UInt64

    init() {
        self.availableStart = AvailableMemory.current() ?? 0
        sampleMemory()
    }

    func recordFirstToken() {
        if firstTokenClock == nil {
            firstTokenClock = DispatchTime.now()
        }
    }

    func recordChunk(tokenCount: Int) {
        outputTokens += tokenCount
        lastSampleClock = DispatchTime.now()
        sampleMemory()
    }

    func finalize(inputTokens: Int, promptID: String, modelID: String, output: String,
                  thermalSamples: [ThermalMonitor.Sample], coldLoad: Double?, warmLoad: Double?) -> BenchResult {
        sampleMemory()
        let end = DispatchTime.now()
        let ttft = firstTokenClock.map { elapsedSeconds(from: startClock, to: $0) } ?? 0
        let total = elapsedSeconds(from: startClock, to: end)
        let thermal = thermalSamples.enumerated().map { i, s in
            BenchResult.ThermalSample(
                offsetSeconds: thermalSamples.first.map { s.timestamp.timeIntervalSince($0.timestamp) } ?? Double(i),
                state: s.state.label
            )
        }
        return BenchResult(
            id: UUID(),
            modelID: modelID,
            promptID: promptID,
            startedAt: Date(timeIntervalSinceNow: -total),
            finishedAt: Date(),
            coldLoadSeconds: coldLoad,
            warmLoadSeconds: warmLoad,
            inputTokenCount: inputTokens,
            outputTokenCount: outputTokens,
            ttftSeconds: ttft,
            totalGenerationSeconds: total,
            peakRSSBytes: peakRSS,
            availableMemoryMinBytes: minAvailable,
            availableMemoryStartBytes: availableStart,
            thermalSamples: thermal,
            outputPreview: String(output.prefix(400))
        )
    }

    private func sampleMemory() {
        if let rss = RSSReader.current() { peakRSS = max(peakRSS, rss) }
        if let avail = AvailableMemory.current() { minAvailable = min(minAvailable, avail) }
    }

    private func elapsedSeconds(from a: DispatchTime, to b: DispatchTime) -> Double {
        Double(b.uptimeNanoseconds &- a.uptimeNanoseconds) / 1_000_000_000
    }
}
