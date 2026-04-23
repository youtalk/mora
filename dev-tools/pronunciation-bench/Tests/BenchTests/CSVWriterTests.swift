import XCTest

@testable import Bench

final class CSVWriterTests: XCTestCase {

    func testHeaderHasThirteenColumnsInFixedOrder() {
        XCTAssertEqual(CSVWriter.header, [
            "fixture", "captured_at", "target_phoneme", "expected_label",
            "substitute_phoneme", "word", "speaker_tag", "engine_a_label",
            "engine_a_score", "engine_a_is_reliable", "engine_a_features_json",
            "speechace_score", "speechace_raw_json",
        ])
    }

    func testEscapesCommasAndQuotesAndNewlines() {
        XCTAssertEqual(CSVWriter.escape("plain"), "plain")
        XCTAssertEqual(CSVWriter.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVWriter.escape("a\"b"), "\"a\"\"b\"")
        XCTAssertEqual(CSVWriter.escape("a\nb"), "\"a\nb\"")
        XCTAssertEqual(CSVWriter.escape("a\rb"), "\"a\rb\"")
        XCTAssertEqual(CSVWriter.escape("a\r\nb"), "\"a\r\nb\"")
        XCTAssertEqual(CSVWriter.escape(""), "")
    }

    func testRowJoinsEscapedCellsWithCommas() {
        let row = CSVWriter.row(cells: ["a", "b,c", "d\"e", ""])
        XCTAssertEqual(row, "a,\"b,c\",\"d\"\"e\",")
    }

    func testCreateTruncatesPreexistingFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let url = tempDir.appendingPathComponent("out.csv")

        let old = String(repeating: "stale,leftover,junk\n", count: 200)
        try old.write(to: url, atomically: true, encoding: .utf8)

        let writer = try CSVWriter.create(at: url)
        try writer.write(row: Array(repeating: "v", count: CSVWriter.header.count))
        writer.close()

        let written = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(written.contains("stale"))
        XCTAssertTrue(written.hasPrefix("fixture,captured_at,"))
    }
}
