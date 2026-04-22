import Foundation

final class ResultStore {
    static let shared = ResultStore()

    private let fileURL: URL

    convenience init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.init(fileURL: support.appending(path: "bench-results.json"))
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
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
        return (try? Self.decoder().decode([BenchResult].self, from: data)) ?? []
    }

    func exportURL() -> URL? {
        let all = loadAll()
        guard !all.isEmpty else { return nil }
        let export = FileManager.default.temporaryDirectory.appending(
            path: "bench-results-\(ISO8601DateFormatter().string(from: Date())).json"
        )
        let encoder = Self.encoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(ExportEnvelope(device: DeviceInfo.current(), results: all)),
              (try? data.write(to: export)) != nil else {
            return nil
        }
        return export
    }

    private func save(_ all: [BenchResult]) {
        if let data = try? Self.encoder().encode(all) {
            try? data.write(to: fileURL)
        }
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

private struct ExportEnvelope: Codable {
    let device: DeviceInfo
    let results: [BenchResult]
}
