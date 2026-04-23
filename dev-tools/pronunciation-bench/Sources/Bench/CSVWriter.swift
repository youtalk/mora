import Foundation

public struct CSVWriter {

    public static let header: [String] = [
        "fixture", "captured_at", "target_phoneme", "expected_label",
        "substitute_phoneme", "word", "speaker_tag", "engine_a_label",
        "engine_a_score", "engine_a_is_reliable", "engine_a_features_json",
        "speechace_score", "speechace_raw_json",
    ]

    private let output: FileHandle
    private let lineSeparator = "\n"

    public init(output: FileHandle) {
        self.output = output
    }

    public static func create(at url: URL) throws -> CSVWriter {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        let writer = CSVWriter(output: handle)
        try writer.writeLine(Self.row(cells: Self.header))
        return writer
    }

    public func write(row cells: [String]) throws {
        precondition(cells.count == Self.header.count)
        try writeLine(Self.row(cells: cells))
    }

    private func writeLine(_ line: String) throws {
        try output.write(contentsOf: Data((line + lineSeparator).utf8))
    }

    public func close() { try? output.close() }

    public static func row(cells: [String]) -> String {
        cells.map(escape).joined(separator: ",")
    }

    public static func escape(_ s: String) -> String {
        let needsQuotes = s.contains(",") || s.contains("\"") || s.contains("\n")
        guard needsQuotes else { return s }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
