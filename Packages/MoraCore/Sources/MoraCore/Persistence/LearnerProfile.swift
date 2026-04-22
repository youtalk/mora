import Foundation
import SwiftData

@Model
public final class LearnerProfile {
    public var id: UUID
    public var displayName: String
    public var l1Identifier: String
    public var interests: [String]
    public var preferredFontKey: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        l1Identifier: String,
        interests: [String],
        preferredFontKey: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.l1Identifier = l1Identifier
        self.interests = interests
        self.preferredFontKey = preferredFontKey
        self.createdAt = createdAt
    }
}
