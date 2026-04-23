import Foundation
import SwiftData

@Model
public final class SessionSummaryEntity {
    public var id: UUID
    public var date: Date
    public var sessionType: String
    public var targetSkillCode: String
    public var durationSec: Int
    public var trialsTotal: Int
    public var trialsCorrect: Int
    public var escalated: Bool
    public var tileBoardMetricsJSON: Data?

    public init(
        id: UUID = UUID(),
        date: Date,
        sessionType: String,
        targetSkillCode: String,
        durationSec: Int,
        trialsTotal: Int,
        trialsCorrect: Int,
        escalated: Bool,
        tileBoardMetricsJSON: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.sessionType = sessionType
        self.targetSkillCode = targetSkillCode
        self.durationSec = durationSec
        self.trialsTotal = trialsTotal
        self.trialsCorrect = trialsCorrect
        self.escalated = escalated
        self.tileBoardMetricsJSON = tileBoardMetricsJSON
    }
}
