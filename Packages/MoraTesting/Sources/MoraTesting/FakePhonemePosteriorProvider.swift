// Packages/MoraTesting/Sources/MoraTesting/FakePhonemePosteriorProvider.swift
import Foundation
import MoraEngines

/// Scripted double for `PhonemePosteriorProvider`. Tests set `nextResult`
/// to either a `PhonemePosterior` or an error; the fake returns / throws
/// exactly that on the next call. Set `shouldBlock = true` to make the
/// call suspend until `release()` is called, which is how
/// `ShadowLoggingPronunciationEvaluatorTests` exercises the timeout path.
public final class FakePhonemePosteriorProvider: PhonemePosteriorProvider, @unchecked Sendable {
    public enum ScriptedError: Error, Sendable, Equatable {
        case boom
        case other(String)
    }

    private let lock = NSLock()
    private var _nextResult: Result<PhonemePosterior, Error> = .success(.empty)
    private var _shouldBlock: Bool = false
    private var continuation: CheckedContinuation<Void, Never>?

    public var nextResult: Result<PhonemePosterior, Error> {
        get { lock.lock(); defer { lock.unlock() }; return _nextResult }
        set { lock.lock(); defer { lock.unlock() }; _nextResult = newValue }
    }

    public var shouldBlock: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _shouldBlock }
        set { lock.lock(); defer { lock.unlock() }; _shouldBlock = newValue }
    }

    public init() {}

    public func release() {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume()
    }

    public func posterior(for audio: AudioClip) async throws -> PhonemePosterior {
        let block: Bool
        lock.lock()
        block = _shouldBlock
        lock.unlock()

        if block {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                lock.lock()
                continuation = c
                lock.unlock()
            }
        }

        switch nextResult {
        case .success(let p): return p
        case .failure(let e): throw e
        }
    }
}
