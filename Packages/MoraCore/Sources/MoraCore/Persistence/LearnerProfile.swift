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
    public var interests: [String]
    public var preferredFontKey: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        l1Identifier: String,
        ageYears: Int? = nil,
        interests: [String],
        preferredFontKey: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.l1Identifier = l1Identifier
        self.ageYears = ageYears
        self.interests = interests
        self.preferredFontKey = preferredFontKey
        self.createdAt = createdAt
    }
}
