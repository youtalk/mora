import Foundation
import MoraCore
import MoraEngines

public enum FakeSpeechEngineError: Error, Equatable {
    case scriptExhausted
}

public final class FakeSpeechEngine: SpeechEngine, @unchecked Sendable {
    private var _scriptedResults: [ASRResult] = []
    private let lock = NSLock()

    /// Mutating `scriptedResults` from outside `listen()` is safe — both
    /// the getter and setter take the same lock that `listen()` uses.
    public var scriptedResults: [ASRResult] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _scriptedResults
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _scriptedResults = newValue
        }
    }

    public init(scriptedResults: [ASRResult] = []) {
        self._scriptedResults = scriptedResults
    }

    public func listen() async throws -> ASRResult {
        lock.lock()
        defer { lock.unlock() }
        guard !_scriptedResults.isEmpty else {
            throw FakeSpeechEngineError.scriptExhausted
        }
        return _scriptedResults.removeFirst()
    }

    public func cancel() {}
}
