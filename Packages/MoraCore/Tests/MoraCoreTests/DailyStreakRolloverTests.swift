import XCTest

@testable import MoraCore

@MainActor
final class DailyStreakRolloverTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = cal
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)!
    }

    func test_firstSession_setsCountTo1() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        XCTAssertEqual(streak.currentCount, 1)
        XCTAssertEqual(streak.longestCount, 1)
    }

    func test_sameDay_noChange() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        XCTAssertEqual(streak.currentCount, 1)
    }

    func test_consecutiveDays_increments() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-23"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-24"), calendar: cal)
        XCTAssertEqual(streak.currentCount, 3)
        XCTAssertEqual(streak.longestCount, 3)
    }

    func test_gapResets_butKeepsLongest() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-23"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-26"), calendar: cal)  // 2-day gap
        XCTAssertEqual(streak.currentCount, 1)
        XCTAssertEqual(streak.longestCount, 2)
    }
}
