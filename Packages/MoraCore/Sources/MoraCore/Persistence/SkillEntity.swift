import Foundation
import SwiftData

@Model
public final class SkillEntity {
    public var code: String
    public var level: Int
    public var state: String
    public var accuracy: Double
    public var trialCount: Int
    public var lastReviewedAt: Date?
    public var nextReviewDue: Date?

    public init(
        code: String,
        level: Int,
        state: String = "new",
        accuracy: Double = 0.0,
        trialCount: Int = 0,
        lastReviewedAt: Date? = nil,
        nextReviewDue: Date? = nil
    ) {
        self.code = code
        self.level = level
        self.state = state
        self.accuracy = accuracy
        self.trialCount = trialCount
        self.lastReviewedAt = lastReviewedAt
        self.nextReviewDue = nextReviewDue
    }
}
