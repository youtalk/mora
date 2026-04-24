import Foundation
import SwiftData

@Model
public final class YokaiEncounterEntity {
    public var id: UUID
    public var yokaiID: String
    public var weekStart: Date
    public var stateRaw: String
    public var friendshipPercent: Double
    public var correctReadCount: Int
    public var sessionCompletionCount: Int
    public var befriendedAt: Date?
    public var storedRolloverFlag: Bool

    public var state: YokaiEncounterState {
        get { YokaiEncounterState(rawValue: stateRaw) ?? .upcoming }
        set { stateRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        yokaiID: String,
        weekStart: Date,
        state: YokaiEncounterState,
        friendshipPercent: Double = 0.0,
        correctReadCount: Int = 0,
        sessionCompletionCount: Int = 0,
        befriendedAt: Date? = nil,
        storedRolloverFlag: Bool = false
    ) {
        self.id = id
        self.yokaiID = yokaiID
        self.weekStart = weekStart
        self.stateRaw = state.rawValue
        self.friendshipPercent = friendshipPercent
        self.correctReadCount = correctReadCount
        self.sessionCompletionCount = sessionCompletionCount
        self.befriendedAt = befriendedAt
        self.storedRolloverFlag = storedRolloverFlag
    }
}
