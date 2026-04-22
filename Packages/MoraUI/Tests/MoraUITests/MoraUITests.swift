import XCTest
@testable import MoraUI

final class MoraUISmokeTests: XCTestCase {
    func test_version_isNonEmpty() {
        XCTAssertFalse(MoraUI.version.isEmpty)
    }
}
