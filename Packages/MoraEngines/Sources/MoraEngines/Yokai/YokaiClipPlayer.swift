import Foundation

/// Plays a yokai voice clip located at `url`. Returns `true` if playback was
/// initiated successfully (the audio file existed and the player accepted it),
/// `false` otherwise — callers fall back to a different audio path on `false`.
@MainActor
public protocol YokaiClipPlayer: AnyObject {
    func play(url: URL) -> Bool
    func stop()
}
