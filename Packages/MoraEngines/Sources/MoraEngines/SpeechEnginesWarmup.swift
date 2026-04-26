import Foundation
import Observation

/// Holds the `AppleSpeechEngine` (`SpeechEngine`) and `AppleTTSEngine`
/// (`TTSEngine`) instances pre-warmed by the app target at launch so
/// that the first session's `SessionContainerView.bootstrap` does not
/// pay the `SFSpeechRecognizer(locale:)` lazy-load cost (~100–500 ms
/// on cold launch) on the @MainActor mid-navigation.
///
/// Mirrors the `MLXWarmupState` pattern: app target drives the load
/// lifecycle on a detached `.utility`-priority `Task`; views observe
/// `phase` to decide whether to consume the pre-warmed instances or
/// fall back to constructing fresh ones (previews / tests / a session
/// that started before warmup resolved).
///
/// Permissions are not consulted here — `SFSpeechRecognizer(locale:)`
/// succeeds regardless of mic / speech-recognition authorization. The
/// session-time permission check still decides mic vs tap; if mic is
/// denied at session start, the pre-warmed `speechEngine` is simply
/// unused for that session.
///
/// `speechEngine` is `nil` after `.resolved` when init failed (older
/// device, simulator without on-device Speech support, missing locale
/// model, or a non-iOS host). Callers treat that as "no mic this
/// session" and fall back to tap mode — same branch the bootstrap
/// permission check already takes for `.partial` / `.notDetermined`.
@Observable
@MainActor
public final class SpeechEnginesWarmup {
    public enum Phase: Sendable {
        case notStarted
        case loading
        case resolved
    }

    public private(set) var phase: Phase = .notStarted
    public private(set) var speechEngine: (any SpeechEngine)?
    public private(set) var ttsEngine: (any TTSEngine)?
    public private(set) var speechFailureReason: String?

    public init() {}

    public func markLoading() { phase = .loading }

    public func resolve(
        speechEngine: (any SpeechEngine)?,
        ttsEngine: any TTSEngine,
        speechFailureReason: String? = nil
    ) {
        self.speechEngine = speechEngine
        self.ttsEngine = ttsEngine
        self.speechFailureReason = speechFailureReason
        self.phase = .resolved
    }

    /// `true` once the warmup target has finished running (engines
    /// available or speech init failed and recorded). Callers that
    /// only need to know "is it safe to consume the engines" should
    /// branch on this rather than comparing `phase` directly.
    public var isResolved: Bool { phase == .resolved }
}
