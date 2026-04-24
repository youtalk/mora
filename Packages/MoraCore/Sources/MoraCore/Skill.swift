import Foundation

public struct SkillCode: Hashable, Codable, Sendable, RawRepresentable,
    ExpressibleByStringLiteral
{
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

public enum OGLevel: Int, Hashable, Codable, Sendable, CaseIterable {
    case l1 = 1
    case l2 = 2
    case l3 = 3
    case l4 = 4
}

public enum SkillState: String, Hashable, Codable, Sendable, CaseIterable {
    case new
    case learning
    case mastered
    case shaky
}

public struct Skill: Hashable, Codable, Sendable, Identifiable {
    public var id: SkillCode { code }
    public let code: SkillCode
    public let level: OGLevel
    public let displayName: String
    public let graphemePhoneme: GraphemePhoneme?
    public let warmupCandidates: [Grapheme]
    public let yokaiID: String?

    public init(
        code: SkillCode,
        level: OGLevel,
        displayName: String,
        graphemePhoneme: GraphemePhoneme? = nil,
        warmupCandidates: [Grapheme] = [],
        yokaiID: String? = nil
    ) {
        self.code = code
        self.level = level
        self.displayName = displayName
        self.graphemePhoneme = graphemePhoneme
        self.warmupCandidates = warmupCandidates
        self.yokaiID = yokaiID
    }
}
