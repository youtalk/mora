import Foundation
import MoraCore

public struct TileBoardTrialResult: Hashable, Sendable {
    public let word: Word
    public let buildAttempts: [BuildAttemptRecord]
    public let scaffoldLevel: Int
    public let ttsHintIssued: Bool
    public let poolReducedToTwo: Bool
    public let autoFilled: Bool
}
