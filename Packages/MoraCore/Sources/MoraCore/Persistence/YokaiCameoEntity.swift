import Foundation
import SwiftData

/// Local-only cameo log. Not synced via CloudKit (matches `PerformanceEntity` policy
/// in the canonical spec §13).
@Model
public final class YokaiCameoEntity {
    public var id: UUID
    public var yokaiID: String
    public var sessionID: UUID
    public var triggeredAt: Date
    public var pronunciationSuccess: Bool

    public init(
        id: UUID = UUID(),
        yokaiID: String,
        sessionID: UUID,
        triggeredAt: Date,
        pronunciationSuccess: Bool
    ) {
        self.id = id
        self.yokaiID = yokaiID
        self.sessionID = sessionID
        self.triggeredAt = triggeredAt
        self.pronunciationSuccess = pronunciationSuccess
    }
}
