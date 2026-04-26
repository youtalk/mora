import XCTest
@testable import MoraCore

final class LearnerLevelTests: XCTestCase {
    func test_from_years_below7_returnsEntry() {
        XCTAssertEqual(LearnerLevel.from(years: 0), .entry)
        XCTAssertEqual(LearnerLevel.from(years: 5), .entry)
        XCTAssertEqual(LearnerLevel.from(years: 6), .entry)
    }

    func test_from_years_7_returnsCore() {
        XCTAssertEqual(LearnerLevel.from(years: 7), .core)
    }

    func test_from_years_8OrAbove_returnsAdvanced() {
        XCTAssertEqual(LearnerLevel.from(years: 8), .advanced)
        XCTAssertEqual(LearnerLevel.from(years: 11), .advanced)
        XCTAssertEqual(LearnerLevel.from(years: 99), .advanced)
    }

    func test_rawValues() {
        XCTAssertEqual(LearnerLevel.entry.rawValue, "entry")
        XCTAssertEqual(LearnerLevel.core.rawValue, "core")
        XCTAssertEqual(LearnerLevel.advanced.rawValue, "advanced")
    }

    func test_allCases_count_is3() {
        XCTAssertEqual(LearnerLevel.allCases.count, 3)
    }

    func test_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for level in LearnerLevel.allCases {
            let data = try encoder.encode(level)
            let decoded = try decoder.decode(LearnerLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }
}
