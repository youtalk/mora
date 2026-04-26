import XCTest
@testable import MoraCore

final class AgeBandTests: XCTestCase {
    func test_from_yearsBucketsCorrectly() {
        XCTAssertEqual(AgeBand.from(years: 3), .early)
        XCTAssertEqual(AgeBand.from(years: 4), .early)
        XCTAssertEqual(AgeBand.from(years: 7), .early)
        XCTAssertEqual(AgeBand.from(years: 8), .mid)
        XCTAssertEqual(AgeBand.from(years: 10), .mid)
        XCTAssertEqual(AgeBand.from(years: 11), .late)
        XCTAssertEqual(AgeBand.from(years: 13), .late)
        XCTAssertEqual(AgeBand.from(years: 99), .late)
    }

    func test_rawValuesAreStable() {
        // Bundled JSON files key cells on these strings; renaming requires a
        // bundle migration and is breaking. Lock the names here so a careless
        // rename trips this test.
        XCTAssertEqual(AgeBand.early.rawValue, "early")
        XCTAssertEqual(AgeBand.mid.rawValue, "mid")
        XCTAssertEqual(AgeBand.late.rawValue, "late")
    }
}
