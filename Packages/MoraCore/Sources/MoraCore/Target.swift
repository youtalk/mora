import Foundation

public struct Target: Hashable, Codable, Sendable {
    public let weekStart: Date
    public let skill: Skill

    public init(weekStart: Date, skill: Skill) {
        self.weekStart = weekStart
        self.skill = skill
    }
}
