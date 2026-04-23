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

public enum OrchestratorEvent: Hashable, Sendable {
    case warmupTap(Grapheme)
    case advance
    case answerHeard(TrialRecording)
    case answerManual(correct: Bool)
    case tileBoardTrialCompleted(TrialRecording)
    case chainFinished(ChainRole)
    case phaseFinished(TileBoardMetrics)
}
