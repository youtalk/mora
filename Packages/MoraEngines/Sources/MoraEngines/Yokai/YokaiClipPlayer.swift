import Foundation

/// Plays a yokai voice clip located at `url`. Returns `true` if playback was
/// initiated successfully (the audio file existed and the player accepted it),
/// `false` otherwise — callers fall back to a different audio path on `false`.
@MainActor
public protocol YokaiClipPlayer: AnyObject {
    func play(url: URL) -> Bool
    func stop()

    /// Plays `url` and suspends until playback ends. Real audio backends
    /// (e.g. `AVFoundationYokaiClipPlayer`) override to await the delegate
    /// callback and return `true` only when the clip reaches natural
    /// completion (`false` for preempt / stop / decode error / failure to
    /// start). The default implementation forwards to `play(url:)` and
    /// returns immediately with whatever the synchronous start returned —
    /// sufficient for fakes/tests where there is no real audio to wait
    /// for, but it cannot distinguish "started" from "completed".
    func playAndAwait(url: URL) async -> Bool
}

extension YokaiClipPlayer {
    public func playAndAwait(url: URL) async -> Bool {
        play(url: url)
    }
}
