import Foundation

final class ResultStore {
    static let shared = ResultStore()

    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = support.appending(path: "bench-results.json")
    }

    func append(_ result: BenchResult) {
        var all = loadAll()
        all.append(result)
        save(all)
    }

    func appendBatch(_ results: [BenchResult]) {
        var all = loadAll()
        all.append(contentsOf: results)
        save(all)
    }

    func loadAll() -> [BenchResult] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([BenchResult].self, from: data)) ?? []
    }

    func exportURL() -> URL? {
        let all = loadAll()
        guard !all.isEmpty else { return nil }
        let export = FileManager.default.temporaryDirectory.appending(
            path: "bench-results-\(ISO8601DateFormatter().string(from: Date())).json"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(ExportEnvelope(device: DeviceInfo.current(), results: all)),
              (try? data.write(to: export)) != nil else {
            return nil
        }
        return export
    }

    private func save(_ all: [BenchResult]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(all) {
            try? data.write(to: fileURL)
        }
    }
}

private struct ExportEnvelope: Codable {
    let device: DeviceInfo
    let results: [BenchResult]
}
