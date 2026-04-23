import Foundation
import MoraCore

public struct TileBoardTrialResult: Hashable, Sendable {
    public let word: Word
    public let buildAttempts: [BuildAttemptRecord]
    public let scaffoldLevel: Int
    public let ttsHintIssued: Bool
    public let poolReducedToTwo: Bool
    public let autoFilled: Bool

    public init(
        word: Word,
        buildAttempts: [BuildAttemptRecord],
        scaffoldLevel: Int,
        ttsHintIssued: Bool,
        poolReducedToTwo: Bool,
        autoFilled: Bool
    ) {
        self.word = word
        self.buildAttempts = buildAttempts
        self.scaffoldLevel = scaffoldLevel
        self.ttsHintIssued = ttsHintIssued
        self.poolReducedToTwo = poolReducedToTwo
        self.autoFilled = autoFilled
    }
}
