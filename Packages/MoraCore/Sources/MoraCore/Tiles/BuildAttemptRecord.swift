import Foundation

/// One tile drop on a slot during a Build or Change trial.
public struct BuildAttemptRecord: Hashable, Codable, Sendable {
    public let slotIndex: Int
    public let tileDropped: Grapheme
    public let wasCorrect: Bool
    public let timestampOffset: TimeInterval

    public init(
        slotIndex: Int,
        tileDropped: Grapheme,
        wasCorrect: Bool,
        timestampOffset: TimeInterval
    ) {
        self.slotIndex = slotIndex
        self.tileDropped = tileDropped
        self.wasCorrect = wasCorrect
        self.timestampOffset = timestampOffset
    }
}
