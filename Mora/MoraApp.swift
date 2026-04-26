import Foundation
import MoraCore
import MoraEngines
import MoraMLX
import MoraUI
import OSLog
import SwiftData
import SwiftUI

@main
struct MoraApp: App {
    let container: ModelContainer
    private let shadowFactory: ShadowEvaluatorFactory
    private let mlxWarmupState: MLXWarmupState
    private let speechEnginesWarmup: SpeechEnginesWarmup

    init() {
        self.container = Self.makeContainer()
        self.shadowFactory = Self.makeShadowFactory()
        self.mlxWarmupState = MLXWarmupState()
        self.speechEnginesWarmup = SpeechEnginesWarmup()
        Self.scheduleBackgroundCleanup(container: container)
        Self.scheduleMLXWarmup(state: mlxWarmupState)
        Self.scheduleSpeechEnginesWarmup(state: speechEnginesWarmup)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.shadowEvaluatorFactory, shadowFactory)
                .environment(\.mlxWarmupState, mlxWarmupState)
                .environment(\.speechEnginesWarmup, speechEnginesWarmup)
        }
        .modelContainer(container)
    }

    private static let log = Logger(subsystem: "tech.reenable.Mora", category: "Pronunciation")
    private static let speechLog = Logger(subsystem: "tech.reenable.Mora", category: "Speech")

    private static func makeContainer() -> ModelContainer {
        let log = Logger(subsystem: "tech.reenable.Mora", category: "ModelContainer")
        do {
            let c = try MoraModelContainer.onDisk()
            try MoraModelContainer.seedIfEmpty(c.mainContext)
            return c
        } catch {
            log.error("Falling back to in-memory store after on-disk init failed: \(error)")
            do {
                let c = try MoraModelContainer.inMemory()
                try MoraModelContainer.seedIfEmpty(c.mainContext)
                return c
            } catch {
                fatalError("ModelContainer in-memory fallback also failed: \(error)")
            }
        }
    }

    /// Schedules `PronunciationTrialRetentionPolicy.cleanup` on a detached
    /// background task so app launch is not blocked even if the log grew
    /// far past the cap (e.g., after a bug or a long-running dev build).
    /// The policy uses a fresh `ModelContext` internally, so it does not
    /// contend with the main-actor context used by the UI.
    private static func scheduleBackgroundCleanup(container: ModelContainer) {
        Task.detached(priority: .background) {
            do {
                try PronunciationTrialRetentionPolicy.cleanup(container)
            } catch {
                log.error("PronunciationTrialLog cleanup failed at launch: \(error)")
            }
        }
    }

    /// Pre-loads the bundled wav2vec2 CoreML model on a background task so
    /// the first session-start does not block the main actor for ~10 s on
    /// `MLModel(contentsOf:)`. `MoraMLXModelCatalog` caches the loaded
    /// model for the process lifetime, so this warm-up benefits the first
    /// session; subsequent sessions hit the cache instantly regardless.
    /// `state` is updated on the main actor so SwiftUI views (the Home
    /// start-session CTA) can gate tapping until the load resolves —
    /// `ShadowEvaluatorFactory` re-runs the load on first use if it fails.
    ///
    /// Runs at `.utility` — higher than `.background` so it actually starts
    /// promptly on a warm system, but below `.userInitiated` so it cannot
    /// steal scheduler time from the SwiftUI / Metal work that renders the
    /// first frame during app launch.
    private static func scheduleMLXWarmup(state: MLXWarmupState) {
        Task.detached(priority: .utility) {
            await MainActor.run { state.markLoading() }
            let start = ContinuousClock.now
            log.info("MLX warmup: started")
            do {
                _ = try MoraMLXModelCatalog.loadPhonemeEvaluator()
                let ms = Self.millis(since: start)
                log.info("MLX warmup: ready in \(ms) ms")
                await MainActor.run { state.markReady() }
            } catch {
                let ms = Self.millis(since: start)
                log.error("MLX warmup: failed after \(ms) ms: \(String(describing: error))")
                await MainActor.run { state.markFailed() }
            }
        }
    }

    private static func millis(since start: ContinuousClock.Instant) -> Int {
        let components = start.duration(to: .now).components
        return Int(components.seconds) * 1000
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }

    /// Pre-loads `AppleSpeechEngine` (~100–500 ms `SFSpeechRecognizer`
    /// locale-model lazy-load on cold launch) and `AppleTTSEngine`
    /// (~10 ms `AVSpeechSynthesizer` construction) on a detached
    /// background task at app launch. Mirrors `scheduleMLXWarmup` —
    /// runs at `.utility` priority so the load can't steal scheduler
    /// time from the SwiftUI / Metal first-frame work, but high enough
    /// to resolve well before the learner taps "▶ はじめる" on Home
    /// (the onboarding read-flow on first launch buys multiple seconds
    /// of headroom; on subsequent launches the home hero card buys at
    /// least a second).
    ///
    /// `AppleSpeechEngine` requires no microphone or speech-recognition
    /// permission to construct — only the per-session `listen()` call
    /// does — so the warmup runs unconditionally. If init fails (older
    /// device, simulator without on-device Speech support, missing
    /// locale model), the warmup resolves with `speechEngine == nil`
    /// and `SessionContainerView.bootstrap` falls back to tap mode at
    /// session start, same branch the permission check already takes
    /// for `.partial` / `.notDetermined`.
    ///
    /// `AppleTTSEngine` is constructed on every host (including Mac)
    /// because `AVSpeechSynthesizer` is available everywhere — the
    /// session-time priming utterance still goes through it.
    private static func scheduleSpeechEnginesWarmup(state: SpeechEnginesWarmup) {
        Task.detached(priority: .utility) {
            await MainActor.run { state.markLoading() }
            let start = ContinuousClock.now
            speechLog.info("Speech engines warmup: started")
            #if os(iOS)
            let speechResult: (engine: (any SpeechEngine)?, failureReason: String?)
            do {
                let engine = try AppleSpeechEngine()
                speechResult = (engine, nil)
            } catch {
                let reason = String(describing: error)
                speechLog.error(
                    "Speech engines warmup: AppleSpeechEngine failed: \(reason, privacy: .public)"
                )
                speechResult = (nil, reason)
            }
            #else
            let speechResult: (engine: (any SpeechEngine)?, failureReason: String?) = (nil, nil)
            #endif
            let tts: any TTSEngine = AppleTTSEngine(l1Profile: JapaneseL1Profile())
            let ms = Self.millis(since: start)
            let speechReady = speechResult.engine != nil ? "yes" : "no"
            speechLog.info(
                "Speech engines warmup: ready in \(ms) ms (speech=\(speechReady, privacy: .public))"
            )
            await MainActor.run {
                state.resolve(
                    speechEngine: speechResult.engine,
                    ttsEngine: tts,
                    speechFailureReason: speechResult.failureReason
                )
            }
        }
    }

    private static func makeShadowFactory() -> ShadowEvaluatorFactory {
        ShadowEvaluatorFactory { container in
            let engineA = FeatureBasedPronunciationEvaluator()
            let logger = SwiftDataPronunciationTrialLogger(container: container)
            let timeout = Self.evaluatorTimeout
            // The resolver closure is consulted per-trial: if the
            // background MLX warmup hasn't finished compiling the ANE
            // graph yet (first launch after install can take ~100 s on
            // A-series iPads), `cachedPhonemeEvaluator()` returns `nil`
            // and the shadow wrapper logs the trial with `B=notReady`.
            // Once the warmup resolves, subsequent trials in the SAME
            // session transparently pick up Engine B — no need to end
            // and restart the session.
            return ShadowLoggingPronunciationEvaluator(
                primary: engineA,
                shadowResolver: { MoraMLXModelCatalog.cachedPhonemeEvaluator(timeout: timeout) },
                logger: logger,
                timeout: timeout
            )
        }
    }

    /// Per-trial Engine B budget. iPad Air M2 lands in ~250–600 ms; the
    /// `Designed for iPad` and `Mac Catalyst` runtime on Apple Silicon
    /// Mac measured ~6.7 s on the first inference (the wav2vec2 CoreML
    /// graph appears to land on the CPU/GPU rather than the Neural
    /// Engine on macOS — the warmup `MLModel(contentsOf:)` already
    /// took ~38 s). Stretch the budget on Mac so Engine B actually
    /// produces a result instead of every trial logging `B=timedOut`,
    /// which makes the cross-engine debug loop unusable on the
    /// developer's Mac. The Mac path is dev-only — production
    /// distribution targets iPad. The same timeout is applied at both
    /// layers (shadow composite and the inner `PhonemeModelPronunciation
    /// Evaluator.timeout`) because the inner one bounds the
    /// `PhonemePosteriorProvider` call and will short-circuit to
    /// `.unclear` first if it expires.
    private static var evaluatorTimeout: Duration {
        let info = ProcessInfo.processInfo
        if info.isiOSAppOnMac || info.isMacCatalystApp {
            return .milliseconds(8000)
        }
        return .milliseconds(1000)
    }
}
