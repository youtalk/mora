import AVFoundation

/// `AVAudioPlayer`-backed production implementation of `YokaiClipPlayer`.
///
/// Constructed once per session in `SessionContainerView.bootstrap` and
/// injected into `YokaiClipRouter`. Not unit-tested — `AVAudioPlayer` requires
/// an active audio session and is verified by on-device manual runs.
@MainActor
public final class AVFoundationYokaiClipPlayer: YokaiClipPlayer {
    private var player: AVAudioPlayer?

    public init() {}

    public func play(url: URL) -> Bool {
        player?.stop()
        guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else {
            player = nil
            return false
        }
        player = newPlayer
        newPlayer.prepareToPlay()
        return newPlayer.play()
    }

    public func stop() {
        player?.stop()
        player = nil
    }
}
