import Foundation
import SwiftData

@Model
public final class PerformanceEntity {
    public var id: UUID
    public var sessionId: UUID
    public var skillCode: String
    public var expected: String
    public var heard: String?
    public var correct: Bool
    public var l1InterferenceTag: String?
    public var timestamp: Date

    // Tile-board scaffold telemetry. All defaults represent "no tile-board
    // activity" so legacy rows migrate additively.
    public var buildAttemptsJSON: Data?
    public var scaffoldLevel: Int
    public var ttsHintIssued: Bool
    public var poolReducedToTwo: Bool
    public var autoFilled: Bool

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        skillCode: String,
        expected: String,
        heard: String?,
        correct: Bool,
        l1InterferenceTag: String?,
        timestamp: Date,
        buildAttemptsJSON: Data? = nil,
        scaffoldLevel: Int = 0,
        ttsHintIssued: Bool = false,
        poolReducedToTwo: Bool = false,
        autoFilled: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.skillCode = skillCode
        self.expected = expected
        self.heard = heard
        self.correct = correct
        self.l1InterferenceTag = l1InterferenceTag
        self.timestamp = timestamp
        self.buildAttemptsJSON = buildAttemptsJSON
        self.scaffoldLevel = scaffoldLevel
        self.ttsHintIssued = ttsHintIssued
        self.poolReducedToTwo = poolReducedToTwo
        self.autoFilled = autoFilled
    }
}
