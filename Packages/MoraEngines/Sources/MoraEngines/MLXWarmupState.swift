import Foundation
import Observation

/// Tracks progress of the background load that pulls the bundled wav2vec2
/// CoreML model into memory via `MoraMLXModelCatalog`. The app target drives
/// the transitions; views observe `phase` to gate CTAs (e.g. Home's
/// "はじめる" button) until the model is ready, so the first session does
/// not stall on a synchronous `MLModel(contentsOf:)` when the child taps.
///
/// `.failed` is treated as "proceed without Engine B" at the callsite —
/// Engine A works standalone — so a load failure must not permanently
/// gate the session start.
@Observable
@MainActor
public final class MLXWarmupState {
    public enum Phase: Sendable {
        case notStarted
        case loading
        case ready
        case failed
    }

    public private(set) var phase: Phase = .notStarted

    public init() {}

    public func markLoading() { phase = .loading }
    public func markReady() { phase = .ready }
    public func markFailed() { phase = .failed }

    /// `true` once the warmup has resolved either way — ready or failed.
    /// Callers that only need to know "is it safe to stop blocking the UI"
    /// should use this rather than comparing `phase` directly.
    public var isResolved: Bool {
        switch phase {
        case .ready, .failed: return true
        case .notStarted, .loading: return false
        }
    }
}
