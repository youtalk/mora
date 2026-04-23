import Foundation

/// Inputs the engine consumes from the UI and the TTS/ASR adapters.
public enum TileBoardEvent: Hashable, Sendable {
    case preparationFinished
    case promptFinished
    case tileLifted(tileID: String)
    case tileDropped(slotIndex: Int, tileID: String)
    case completionAnimationFinished
    case utteranceRecorded
    case feedbackDismissed
    case transitionFinished
}
