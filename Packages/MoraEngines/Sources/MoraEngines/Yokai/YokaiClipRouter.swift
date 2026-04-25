import Foundation
import MoraCore

/// Coordinates yokai voice-clip playback during an A-day session.
///
/// The router resolves a `YokaiClipKey` to a bundled URL via the injected
/// `YokaiStore`, drains any in-flight Apple TTS through the `silencer`
/// closure (so playback never overlaps), and dispatches to a `YokaiClipPlayer`.
/// Streak (`recordCorrect` → `.encourage` on 3rd consecutive correct) and
/// throttle (`recordIncorrect` → `.gentle_retry` ≤1 per 5 trials) live here so
/// view code stays purely declarative.
///
/// Construction lives in `SessionContainerView.bootstrap`; the router is
/// scoped to a single session and discarded with the view.
@MainActor
public final class YokaiClipRouter {
    private let yokaiID: String
    private let store: YokaiStore
    private let player: YokaiClipPlayer
    private let silencer: () async -> Void

    public init(
        yokaiID: String,
        store: YokaiStore,
        player: YokaiClipPlayer,
        silencer: @escaping () async -> Void
    ) {
        self.yokaiID = yokaiID
        self.store = store
        self.player = player
        self.silencer = silencer
    }

    /// Play a clip directly. Returns `true` if the clip URL resolved and the
    /// player started playback, `false` otherwise — callers fall back to a
    /// different audio path on `false`.
    @discardableResult
    public func play(_ clip: YokaiClipKey) async -> Bool {
        guard let url = store.voiceClipURL(for: yokaiID, clip: clip) else {
            return false
        }
        await silencer()
        return player.play(url: url)
    }

    public func stop() {
        player.stop()
    }
}
