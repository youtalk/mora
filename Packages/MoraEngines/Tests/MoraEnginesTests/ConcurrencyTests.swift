import XCTest
@testable import MoraEngines

final class ConcurrencyTests: XCTestCase {
    func testFastOperationReturnsValue() async {
        let v = await withTimeout(.milliseconds(500)) { 42 }
        XCTAssertEqual(v, 42)
    }

    func testSlowOperationReturnsNil() async {
        let v = await withTimeout(.milliseconds(50)) { () async -> Int in
            try? await Task.sleep(for: .milliseconds(500))
            return 42
        }
        XCTAssertNil(v)
    }

    func testThrowingOperationReturnsNil() async {
        struct Boom: Error {}
        let v = await withTimeout(.milliseconds(200)) { () async throws -> Int in
            throw Boom()
        }
        XCTAssertNil(v)
    }

    func testCompletesBeforeTimeoutCapturesResult() async {
        let v = await withTimeout(.milliseconds(500)) { () async -> String in
            try? await Task.sleep(for: .milliseconds(10))
            return "ok"
        }
        XCTAssertEqual(v, "ok")
    }
}
