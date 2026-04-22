import Foundation

struct BenchModel: Identifiable, Codable, Hashable {
    let id: String             // stable key, matches HF repo id
    let displayName: String
    let huggingFaceRepo: String
    let approxSizeBytes: Int64
    let contextLength: Int
    let isSmokeModel: Bool

    var approxSizeGB: Double { Double(approxSizeBytes) / 1_000_000_000 }
}
