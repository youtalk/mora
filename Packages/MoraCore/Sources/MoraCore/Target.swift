import Foundation

public struct Target: Hashable, Codable, Sendable {
    public let weekStart: Date
    public let skill: Skill

    public init(weekStart: Date, skill: Skill) {
        self.weekStart = weekStart
        self.skill = skill
    }

    public var grapheme: Grapheme? { skill.graphemePhoneme?.grapheme }
    public var phoneme: Phoneme? { skill.graphemePhoneme?.phoneme }
    public var letters: String? { skill.graphemePhoneme?.grapheme.letters }
    public var ipa: String? { skill.graphemePhoneme?.phoneme.ipa }
}
