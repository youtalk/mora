import Foundation
import MoraCore
import MoraEngines

public final class FakeTTSEngine: TTSEngine, @unchecked Sendable {
    private var _uttered: [String] = []
    private let lock = NSLock()

    /// Simulated speak duration. Non-zero values sleep inside `speak`
    /// cooperatively — the sleep throws on cancellation, so callers that
    /// wrap `FakeTTSEngine` in a cancellable task see the speak return
    /// early. Used by tests that verify cancellation propagates from a
    /// parent task into the engine.
    public var speakDuration: Duration

    /// Reading `uttered` from outside `speak`/`reset` is safe — the getter
    /// takes the same lock the mutators use, so the snapshot is consistent.
    public var uttered: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _uttered
    }

    public init(speakDuration: Duration = .zero) {
        self.speakDuration = speakDuration
    }

    public func speak(_ text: String) async {
        // Honor cancellation before recording so a caller that checks
        // `Task.isCancelled` after cancelling sees no trace of an abandoned
        // speak in the history.
        if Task.isCancelled { return }
        lock.lock()
        _uttered.append(text)
        lock.unlock()
        await simulateSpeakDuration()
    }

    public func speak(phoneme: Phoneme) async {
        if Task.isCancelled { return }
        lock.lock()
        _uttered.append("<phoneme: \(phoneme.ipa)>")
        lock.unlock()
        await simulateSpeakDuration()
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _uttered.removeAll()
    }

    private func simulateSpeakDuration() async {
        guard speakDuration > .zero else { return }
        // `Task.sleep(for:)` throws on cancellation, so a parent task's
        // cancel interrupts the simulated playback and lets the engine
        // return promptly — the same semantics an on-device engine must
        // satisfy when the view driving it disappears.
        try? await Task.sleep(for: speakDuration)
    }
}
