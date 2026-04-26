import Foundation

/// Plays a yokai voice clip located at `url`. Returns `true` if playback was
/// initiated successfully (the audio file existed and the player accepted it),
/// `false` otherwise — callers fall back to a different audio path on `false`.
@MainActor
public protocol YokaiClipPlayer: AnyObject {
    func play(url: URL) -> Bool
    func stop()

    /// Plays `url` and suspends until playback ends. Returns `true` if the
    /// clip ran to natural completion, `false` if it was preempted, stopped,
    /// failed to start, or hit a decode error. The default implementation
    /// dispatches to `play(url:)` and returns immediately — sufficient for
    /// fakes/tests where there is no real audio to wait for. Real audio
    /// backends override to wait on their delegate callback.
    func playAndAwait(url: URL) async -> Bool
}

extension YokaiClipPlayer {
    public func playAndAwait(url: URL) async -> Bool {
        play(url: url)
    }
}
