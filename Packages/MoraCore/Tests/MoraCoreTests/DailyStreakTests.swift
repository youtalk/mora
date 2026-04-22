import SwiftData
import XCTest

@testable import MoraCore

@MainActor
final class DailyStreakTests: XCTestCase {
    func test_insertAndFetch_startsAtZero() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let streak = DailyStreak(currentCount: 0, longestCount: 0, lastCompletedOn: nil)
        ctx.insert(streak)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<DailyStreak>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.currentCount, 0)
        XCTAssertNil(fetched.first?.lastCompletedOn)
    }
}
