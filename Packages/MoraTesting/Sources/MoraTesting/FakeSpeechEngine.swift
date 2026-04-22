import Foundation
import MoraCore
import MoraEngines

public enum FakeSpeechEngineError: Error, Equatable {
    case scriptExhausted
}

public final class FakeSpeechEngine: SpeechEngine, @unchecked Sendable {
    public var scriptedResults: [ASRResult] = []
    private let lock = NSLock()

    public init(scriptedResults: [ASRResult] = []) {
        self.scriptedResults = scriptedResults
    }

    public func listen() async throws -> ASRResult {
        lock.lock()
        defer { lock.unlock() }
        guard !scriptedResults.isEmpty else {
            throw FakeSpeechEngineError.scriptExhausted
        }
        return scriptedResults.removeFirst()
    }

    public func cancel() {}
}
