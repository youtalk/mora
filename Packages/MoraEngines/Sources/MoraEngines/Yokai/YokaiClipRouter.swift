import Foundation
import MoraCore
import OSLog

private let clipLog = Logger(subsystem: "tech.reenable.Mora", category: "YokaiClip")

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
        clipLog.info(
            """
            Clip request: \(clip.rawValue, privacy: .public) \
            yokai=\(self.yokaiID, privacy: .public)
            """
        )
        guard let url = store.voiceClipURL(for: yokaiID, clip: clip) else {
            clipLog.info(
                """
                Clip URL missing: \(clip.rawValue, privacy: .public) \
                yokai=\(self.yokaiID, privacy: .public)
                """
            )
            return false
        }
        clipLog.info("Clip silencer: awaiting TTS stop")
        await silencer()
        if Task.isCancelled {
            clipLog.info(
                "Clip cancelled post-silencer: \(clip.rawValue, privacy: .public)"
            )
            return false
        }
        clipLog.info("Clip silencer: returned")
        let started = player.play(url: url)
        clipLog.info(
            """
            Clip dispatch: \(clip.rawValue, privacy: .public) \
            started=\(started, privacy: .public)
            """
        )
        return started
    }

    /// Same as `play(_:)` but suspends until playback ends. Returns `true`
    /// only when the clip ran to natural completion. Use this when the next
    /// audio step (another clip, a TTS prompt, a CTA enable) must wait for
    /// the clip to finish — e.g., a multi-clip rule intro.
    @discardableResult
    public func playAndAwait(_ clip: YokaiClipKey) async -> Bool {
        clipLog.info(
            """
            Clip request (await): \(clip.rawValue, privacy: .public) \
            yokai=\(self.yokaiID, privacy: .public)
            """
        )
        guard let url = store.voiceClipURL(for: yokaiID, clip: clip) else {
            clipLog.info(
                """
                Clip URL missing: \(clip.rawValue, privacy: .public) \
                yokai=\(self.yokaiID, privacy: .public)
                """
            )
            return false
        }
        clipLog.info("Clip silencer: awaiting TTS stop")
        await silencer()
        if Task.isCancelled {
            clipLog.info(
                "Clip cancelled post-silencer: \(clip.rawValue, privacy: .public)"
            )
            return false
        }
        clipLog.info("Clip silencer: returned")
        let finished = await player.playAndAwait(url: url)
        clipLog.info(
            """
            Clip dispatch (await): \(clip.rawValue, privacy: .public) \
            finished=\(finished, privacy: .public)
            """
        )
        return finished
    }

    public func stop() {
        player.stop()
    }

    private var consecutiveCorrect: Int = 0
    private var trialIndex: Int = 0
    private var lastGentleRetryTrialIndex: Int = -100

    /// Record a correct trial in `shortSentences`. Fires `.encourage` and
    /// resets the streak on every 3rd consecutive correct. Returns `true`
    /// if a clip was actually started, so callers can suppress an
    /// overlapping TTS path (e.g., the mic-mode "Listen: …" prompt).
    @discardableResult
    public func recordCorrect() async -> Bool {
        trialIndex += 1
        consecutiveCorrect += 1
        if consecutiveCorrect >= 3 {
            consecutiveCorrect = 0
            return await play(.encourage)
        }
        return false
    }

    /// Record an incorrect trial in `shortSentences`. Resets the streak and
    /// fires `.gentle_retry` if at least 5 trials have passed since the last
    /// retry clip — protects the learner from a retry-clip storm during a
    /// rough run. Returns `true` if a clip was actually started, so callers
    /// can suppress an overlapping corrective TTS path.
    @discardableResult
    public func recordIncorrect() async -> Bool {
        trialIndex += 1
        consecutiveCorrect = 0
        if trialIndex - lastGentleRetryTrialIndex >= 5 {
            lastGentleRetryTrialIndex = trialIndex
            return await play(.gentleRetry)
        }
        return false
    }
}
