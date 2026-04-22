import XCTest
@testable import MoraBench

final class RSSReaderTests: XCTestCase {
    func testCurrentRSSIsPositive() {
        let rss = RSSReader.current()
        XCTAssertNotNil(rss)
        XCTAssertGreaterThan(rss ?? 0, 1_000_000) // > 1 MB
    }

    func testAvailableMemoryIsPositive() throws {
        #if targetEnvironment(simulator)
        // os_proc_available_memory() returns 0 in non-app process contexts
        // (Apple os/proc.h). This test is meaningful only on a real device.
        try XCTSkipIf(true, "AvailableMemory is only meaningful on physical iPad")
        #else
        let avail = AvailableMemory.current()
        XCTAssertNotNil(avail)
        XCTAssertGreaterThan(avail ?? 0, 1_000_000)
        #endif
    }

    func testRSSReturnsMonotonicAfterAllocation() {
        let before = RSSReader.current() ?? 0
        // Allocate ~50 MB to guarantee a bump
        var blob = [UInt8](repeating: 0, count: 50 * 1024 * 1024)
        blob[0] = 1 // prevent dead-store optimization
        let after = RSSReader.current() ?? 0
        XCTAssertGreaterThanOrEqual(after, before)
        _ = blob[0]
    }
}
