import AVFoundation
import Foundation

@MainActor
public final class AVFoundationYokaiClipPlayer: YokaiClipPlayer {
    private var player: AVAudioPlayer?

    public init() {}

    public func play(url: URL) -> Bool {
        player?.stop()
        guard let next = try? AVAudioPlayer(contentsOf: url) else {
            player = nil
            return false
        }
        player = next
        return next.play()
    }

    public func stop() {
        player?.stop()
        player = nil
    }
}
