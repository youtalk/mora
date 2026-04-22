import Foundation
import MoraCore
import MoraEngines

public final class FakeTTSEngine: TTSEngine, @unchecked Sendable {
    private var _uttered: [String] = []
    private let lock = NSLock()

    /// Reading `uttered` from outside `speak`/`reset` is safe — the getter
    /// takes the same lock the mutators use, so the snapshot is consistent.
    public var uttered: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _uttered
    }

    public init() {}

    public func speak(_ text: String) async {
        lock.lock()
        defer { lock.unlock() }
        _uttered.append(text)
    }

    public func speak(phoneme: Phoneme) async {
        lock.lock()
        defer { lock.unlock() }
        _uttered.append("<phoneme: \(phoneme.ipa)>")
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _uttered.removeAll()
    }
}
