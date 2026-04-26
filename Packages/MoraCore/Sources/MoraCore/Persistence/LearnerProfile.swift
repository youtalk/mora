import Foundation
import SwiftData

@Model
public final class LearnerProfile {
    public var id: UUID
    public var displayName: String
    public var l1Identifier: String
    /// Learner's age in raw years. `nil` on profiles created before
    /// `LanguageAgeFlow` shipped — those rows re-run language+age
    /// onboarding on next launch and this field is filled in.
    public var ageYears: Int?
    /// Optional difficulty override. Stored as the raw value of
    /// `LearnerLevel` so SwiftData lightweight migration handles it as
    /// a plain optional `String` column. `nil` means "derive from age".
    /// See spec §5.3 / §7.5.
    public var levelOverride: String?
    public var interests: [String]
    public var preferredFontKey: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        l1Identifier: String,
        ageYears: Int? = nil,
        levelOverride: String? = nil,
        interests: [String],
        preferredFontKey: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.l1Identifier = l1Identifier
        self.ageYears = ageYears
        self.levelOverride = levelOverride
        self.interests = interests
        self.preferredFontKey = preferredFontKey
        self.createdAt = createdAt
    }

    /// Resolved difficulty level for this learner. When `levelOverride` is
    /// set to a valid `LearnerLevel.rawValue`, that wins. Otherwise the
    /// level is derived from `ageYears` (defaulting to 8 → `.advanced` if
    /// age is also nil — defensive, never reached in onboarded paths).
    public var resolvedLevel: LearnerLevel {
        if let raw = levelOverride, let level = LearnerLevel(rawValue: raw) {
            return level
        }
        return LearnerLevel.from(years: ageYears ?? 8)
    }
}
