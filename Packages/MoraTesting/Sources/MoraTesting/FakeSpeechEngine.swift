import Foundation
import MoraCore
import MoraEngines

public enum FakeSpeechEngineError: Error, Equatable {
    case scriptExhausted
}

public final class FakeSpeechEngine: SpeechEngine, @unchecked Sendable {
    /// Scripted sequence of events emitted by `listen()`. Each call to
    /// `listen()` consumes one script. A script that does not end with a
    /// `.final` event is a test bug — the orchestrator waits for a
    /// terminating event to advance.
    private var scripts: [[SpeechEvent]]
    private let lock = NSLock()

    public init(scripts: [[SpeechEvent]] = []) {
        self.scripts = scripts
    }

    /// Convenience: wrap a sequence of final ASRResults into single-event
    /// scripts that carry an empty `AudioClip`. Existing tests that do not
    /// exercise the pronunciation pipeline continue to work unchanged — the
    /// empty clip flows through and the evaluator is expected to skip it.
    public static func yielding(finals: [ASRResult]) -> FakeSpeechEngine {
        FakeSpeechEngine(
            scripts: finals.map { asr in
                [SpeechEvent.final(TrialRecording(asr: asr, audio: .empty))]
            })
    }

    /// Convenience overload for tests that want to control the audio payload.
    public static func yielding(recordings: [TrialRecording]) -> FakeSpeechEngine {
        FakeSpeechEngine(scripts: recordings.map { [SpeechEvent.final($0)] })
    }

    /// Convenience: wrap a sequence of events into a single script.
    public static func yielding(_ events: [SpeechEvent]) -> FakeSpeechEngine {
        FakeSpeechEngine(scripts: [events])
    }

    public func listen() -> AsyncThrowingStream<SpeechEvent, Error> {
        let script: [SpeechEvent]? = {
            lock.lock()
            defer { lock.unlock() }
            guard !scripts.isEmpty else { return nil }
            return scripts.removeFirst()
        }()
        return AsyncThrowingStream { continuation in
            guard let script else {
                continuation.finish(throwing: FakeSpeechEngineError.scriptExhausted)
                return
            }
            Task {
                for event in script {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    public func cancel() {}
}
