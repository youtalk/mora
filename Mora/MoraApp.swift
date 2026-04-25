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

    init() {
        self.container = Self.makeContainer()
        self.shadowFactory = Self.makeShadowFactory()
        self.mlxWarmupState = MLXWarmupState()
        Self.scheduleBackgroundCleanup(container: container)
        Self.scheduleMLXWarmup(state: mlxWarmupState)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.shadowEvaluatorFactory, shadowFactory)
                .environment(\.mlxWarmupState, mlxWarmupState)
        }
        .modelContainer(container)
    }

    private static let log = Logger(subsystem: "tech.reenable.Mora", category: "Pronunciation")

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
            log.info("MLX warmup: started (Engine B / wav2vec2-phoneme CoreML)")
            do {
                _ = try MoraMLXModelCatalog.loadPhonemeEvaluator()
                let ms = Self.millis(since: start)
                log.info(
                    """
                    MLX warmup: ready in \(ms) ms — Engine B online \
                    (will run in shadow on each shortSentences trial)
                    """
                )
                await MainActor.run { state.markReady() }
            } catch {
                let ms = Self.millis(since: start)
                log.error(
                    """
                    MLX warmup: failed after \(ms) ms — Engine A only mode: \
                    \(String(describing: error))
                    """
                )
                await MainActor.run { state.markFailed() }
            }
        }
    }

    private static func millis(since start: ContinuousClock.Instant) -> Int {
        let components = start.duration(to: .now).components
        return Int(components.seconds) * 1000
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }

    private static func makeShadowFactory() -> ShadowEvaluatorFactory {
        ShadowEvaluatorFactory { container in
            let engineA = FeatureBasedPronunciationEvaluator()
            let logger = SwiftDataPronunciationTrialLogger(container: container)
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
                shadowResolver: { MoraMLXModelCatalog.cachedPhonemeEvaluator() },
                logger: logger,
                timeout: .milliseconds(1000)
            )
        }
    }
}
