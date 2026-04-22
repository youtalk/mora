import XCTest
@testable import MoraEngines

final class MoraEnginesSmokeTests: XCTestCase {
    func test_version_isNonEmpty() {
        XCTAssertFalse(MoraEngines.version.isEmpty)
    }
}
