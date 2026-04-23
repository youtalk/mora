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
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        guard fm.createFile(atPath: url.path, contents: nil) else {
            throw NSError(
                domain: "CSVWriter", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "could not create \(url.path)"]
            )
        }
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
        // Check at the scalar level because Swift normalizes "\r\n" into a
        // single Character (grapheme cluster), so String.contains("\r") on
        // a CRLF-terminated line returns false — missing the RFC 4180
        // quoting obligation.
        let needsQuotes = s.unicodeScalars.contains { scalar in
            scalar == "," || scalar == "\"" || scalar == "\n" || scalar == "\r"
        }
        guard needsQuotes else { return s }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
