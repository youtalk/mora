import Foundation
import MoraCore

public enum ADayPhase: String, Hashable, Codable, Sendable, CaseIterable {
    case notStarted
    case warmup
    case newRule
    case decoding
    case shortSentences
    case completion
}

public enum OrchestratorEvent: Sendable {
    case warmupTap(Grapheme)
    case advance
    case answerHeard(TrialRecording)
    case answerManual(correct: Bool)
}
