import Foundation
import SwiftData

@Model
public final class DailyStreak {
    public var id: UUID
    public var currentCount: Int
    public var longestCount: Int
    public var lastCompletedOn: Date?

    public init(
        id: UUID = UUID(),
        currentCount: Int = 0,
        longestCount: Int = 0,
        lastCompletedOn: Date? = nil
    ) {
        self.id = id
        self.currentCount = currentCount
        self.longestCount = longestCount
        self.lastCompletedOn = lastCompletedOn
    }

    /// Record that a session completed on the given day. Increments
    /// `currentCount` when `date` is exactly one day after the previous
    /// completion, resets to 1 on a longer gap, no-ops on the same day.
    /// `longestCount` is bumped whenever `currentCount` changes; same-day
    /// calls skip the update since `currentCount` doesn't change and the
    /// previous call already recorded the max.
    public func recordCompletion(
        on date: Date,
        calendar: Calendar = .init(identifier: .gregorian)
    ) {
        let today = calendar.startOfDay(for: date)
        guard let previous = lastCompletedOn else {
            currentCount = 1
            longestCount = max(longestCount, currentCount)
            lastCompletedOn = today
            return
        }
        let prevDay = calendar.startOfDay(for: previous)
        if today == prevDay { return }
        let daysBetween = calendar.dateComponents([.day], from: prevDay, to: today).day ?? 0
        if daysBetween == 1 {
            currentCount += 1
        } else {
            currentCount = 1
        }
        longestCount = max(longestCount, currentCount)
        lastCompletedOn = today
    }
}
