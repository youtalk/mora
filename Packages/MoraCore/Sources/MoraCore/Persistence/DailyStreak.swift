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
}
