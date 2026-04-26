import AVFoundation
import OSLog

private let clipLog = Logger(subsystem: "tech.reenable.Mora", category: "YokaiClip")

/// `AVAudioPlayer`-backed production implementation of `YokaiClipPlayer`.
///
/// One instance lives per session as a `@State` default on
/// `SessionContainerView` and is shared between `YokaiClipRouter` (for
/// in-session clips) and `WeeklyIntroView` (for the Monday intro greet
/// clip), so stopping playback on one path silences the other. Not
/// unit-tested — `AVAudioPlayer` requires an active audio session and
/// is verified by on-device manual runs.
///
/// Emits OSLog signals on category `YokaiClip` so a Console.app filter can
/// interleave them with the `AudioSession` (TTS) and `Speech` (ASR) streams
/// to diagnose playback overlaps and timing.
@MainActor
public final class AVFoundationYokaiClipPlayer: NSObject, YokaiClipPlayer, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var pendingContinuation: CheckedContinuation<Bool, Never>?

    public override init() { super.init() }

    public func play(url: URL) -> Bool {
        let name = url.lastPathComponent
        if let prev = player, prev.isPlaying {
            let prevName = prev.url?.lastPathComponent ?? "?"
            clipLog.info(
                "Clip preempt: \(prevName, privacy: .public) by \(name, privacy: .public)"
            )
            prev.stop()
        }
        // Anything still awaiting the previous clip is now preempted; resume
        // it as `false` so callers can move on instead of hanging on a
        // never-firing delegate callback.
        resumePending(false)
        let newPlayer: AVAudioPlayer
        do {
            newPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            clipLog.error(
                """
                Clip init failed: \(name, privacy: .public) \
                err=\(String(describing: error), privacy: .public)
                """
            )
            player = nil
            return false
        }
        newPlayer.delegate = self
        player = newPlayer
        newPlayer.prepareToPlay()
        let started = newPlayer.play()
        if started {
            clipLog.info("Clip play: \(name, privacy: .public)")
        } else {
            clipLog.error("Clip play() returned false: \(name, privacy: .public)")
        }
        return started
    }

    public func stop() {
        if let p = player {
            if p.isPlaying {
                let name = p.url?.lastPathComponent ?? "?"
                clipLog.info("Clip stop: \(name, privacy: .public)")
            }
            p.stop()
        }
        player = nil
        resumePending(false)
    }

    public func playAndAwait(url: URL) async -> Bool {
        let started = play(url: url)
        guard started else { return false }
        return await withCheckedContinuation { cont in
            // `play(url:)` already cleared any prior pendingContinuation via
            // `resumePending`, and we're on the MainActor so the delegate
            // callback (which hops back through `Task { @MainActor in }`)
            // can't fire before this assignment.
            self.pendingContinuation = cont
        }
    }

    private func resumePending(_ value: Bool) {
        if let cont = pendingContinuation {
            pendingContinuation = nil
            cont.resume(returning: value)
        }
    }

    public nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        let name = player.url?.lastPathComponent ?? "?"
        Task { @MainActor in
            clipLog.info("Clip done: \(name, privacy: .public) ok=\(flag, privacy: .public)")
            // The delegate callback hops main-actor via `Task { @MainActor in }`,
            // so a preempted clip can deliver its "finished" message after a
            // newer clip has already installed a fresh continuation. Only
            // resume when the callback's player is still the installed one;
            // a stale callback gets dropped and the new continuation will be
            // resolved by its own player's callback (or by the next preempt).
            guard player === self.player else { return }
            self.resumePending(flag)
        }
    }

    public nonisolated func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        let name = player.url?.lastPathComponent ?? "?"
        Task { @MainActor in
            clipLog.error(
                """
                Clip decode error: \(name, privacy: .public) \
                err=\(String(describing: error), privacy: .public)
                """
            )
            guard player === self.player else { return }
            self.resumePending(false)
        }
    }
}
