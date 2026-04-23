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
        XCTAssertEqual(CSVWriter.escape(""), "")
    }

    func testRowJoinsEscapedCellsWithCommas() {
        let row = CSVWriter.row(cells: ["a", "b,c", "d\"e", ""])
        XCTAssertEqual(row, "a,\"b,c\",\"d\"\"e\",")
    }
}
