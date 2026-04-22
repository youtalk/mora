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

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        skillCode: String,
        expected: String,
        heard: String?,
        correct: Bool,
        l1InterferenceTag: String?,
        timestamp: Date
    ) {
        self.id = id
        self.sessionId = sessionId
        self.skillCode = skillCode
        self.expected = expected
        self.heard = heard
        self.correct = correct
        self.l1InterferenceTag = l1InterferenceTag
        self.timestamp = timestamp
    }
}
