import Foundation
import MoraCore
import MoraEngines

public final class FakeTTSEngine: TTSEngine, @unchecked Sendable {
    public private(set) var uttered: [String] = []
    private let lock = NSLock()

    public init() {}

    public func speak(_ text: String) async {
        lock.lock()
        defer { lock.unlock() }
        uttered.append(text)
    }

    public func speak(phoneme: Phoneme) async {
        lock.lock()
        defer { lock.unlock() }
        uttered.append("<phoneme: \(phoneme.ipa)>")
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        uttered.removeAll()
    }
}
