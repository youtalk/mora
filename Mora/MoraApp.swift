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
            do {
                _ = try MoraMLXModelCatalog.loadPhonemeEvaluator()
                await MainActor.run { state.markReady() }
            } catch {
                log.error("MLX warmup failed: \(String(describing: error))")
                await MainActor.run { state.markFailed() }
            }
        }
    }

    private static func makeShadowFactory() -> ShadowEvaluatorFactory {
        ShadowEvaluatorFactory { container in
            let engineA = FeatureBasedPronunciationEvaluator()
            do {
                let engineB = try MoraMLXModelCatalog.loadPhonemeEvaluator()
                let logger = SwiftDataPronunciationTrialLogger(container: container)
                return ShadowLoggingPronunciationEvaluator(
                    primary: engineA,
                    shadow: engineB,
                    logger: logger,
                    timeout: .milliseconds(1000)
                )
            } catch MoraMLXError.modelNotBundled {
                // Expected in Part 1 of the Engine B rollout: the catalog is
                // still a stub. Log at `.info` to avoid spamming `.error`
                // on every session bootstrap.
                log.info("MLX phoneme evaluator not bundled yet; running Engine A only")
                return engineA
            } catch MoraMLXError.modelLoadFailed(let reason) {
                // Once the real model lands a `.modelLoadFailed` means the
                // compiled bundle is corrupted or truncated — a real error
                // we want to see in logs.
                log.error(
                    "MLX phoneme evaluator model load failed (\(reason)); running Engine A only"
                )
                return engineA
            } catch {
                log.error(
                    "MLX phoneme evaluator load failed (\(String(describing: error))); running Engine A only"
                )
                return engineA
            }
        }
    }
}
