import Foundation
import SwiftData

@Model
public final class LearnerEntity {
    public var id: UUID
    public var displayName: String
    public var birthYear: Int
    public var l1Identifier: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        birthYear: Int,
        l1Identifier: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.birthYear = birthYear
        self.l1Identifier = l1Identifier
        self.createdAt = createdAt
    }
}
