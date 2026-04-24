import Foundation
import SwiftData

@Model
public final class BestiaryEntryEntity {
    public var id: UUID
    public var yokaiID: String
    public var befriendedAt: Date
    public var playbackCount: Int
    public var lastPlayedAt: Date?

    public init(
        id: UUID = UUID(),
        yokaiID: String,
        befriendedAt: Date,
        playbackCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.yokaiID = yokaiID
        self.befriendedAt = befriendedAt
        self.playbackCount = playbackCount
        self.lastPlayedAt = lastPlayedAt
    }
}
