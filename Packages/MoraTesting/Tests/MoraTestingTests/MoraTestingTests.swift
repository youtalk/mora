import XCTest
@testable import MoraTesting

final class MoraTestingSmokeTests: XCTestCase {
    func test_version_isNonEmpty() {
        XCTAssertFalse(MoraTesting.version.isEmpty)
    }
}
