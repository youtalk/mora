import XCTest
@testable import MoraCore

final class MoraCoreSmokeTests: XCTestCase {
    func test_version_isNonEmpty() {
        XCTAssertFalse(MoraCore.version.isEmpty)
    }
}
