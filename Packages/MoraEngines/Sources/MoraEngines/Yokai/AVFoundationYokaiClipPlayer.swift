import AVFoundation
import OSLog

private let clipLog = Logger(subsystem: "tech.reenable.Mora", category: "YokaiClip")

/// `AVAudioPlayer`-backed production implementation of `YokaiClipPlayer`.
///
/// Constructed once per session in `SessionContainerView.bootstrap` and
/// injected into `YokaiClipRouter`. Not unit-tested — `AVAudioPlayer` requires
/// an active audio session and is verified by on-device manual runs.
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
            #if DEBUG
            clipLog.info(
                "Clip preempt: \(prevName, privacy: .public) by \(name, privacy: .public)"
            )
            #endif
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
            #if DEBUG
            clipLog.info("Clip play: \(name, privacy: .public)")
            #endif
        } else {
            clipLog.error("Clip play() returned false: \(name, privacy: .public)")
        }
        return started
    }

    public func stop() {
        if let p = player {
            #if DEBUG
            if p.isPlaying {
                let name = p.url?.lastPathComponent ?? "?"
                clipLog.info("Clip stop: \(name, privacy: .public)")
            }
            #endif
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
            #if DEBUG
            clipLog.info("Clip done: \(name, privacy: .public) ok=\(flag, privacy: .public)")
            #endif
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
            self.resumePending(false)
        }
    }
}
