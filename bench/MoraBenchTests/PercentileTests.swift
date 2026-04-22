import XCTest
@testable import MoraBench

final class PercentileTests: XCTestCase {
    func testMedianOfOdd() {
        XCTAssertEqual(percentile([1, 2, 3, 4, 5], p: 0.5), 3)
    }

    func testMedianOfEven() {
        XCTAssertEqual(percentile([1, 2, 3, 4], p: 0.5), 2.5)
    }

    func test95thOfUnsorted() throws {
        let result = try XCTUnwrap(percentile([5, 1, 3, 4, 2, 6, 7, 8, 9, 10], p: 0.95))
        XCTAssertEqual(result, 9.55, accuracy: 0.001)
    }

    func testEmpty() {
        XCTAssertNil(percentile([], p: 0.5))
    }

    func testSingleton() {
        XCTAssertEqual(percentile([42], p: 0.5), 42)
    }
}
