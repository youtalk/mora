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

    init() {
        self.container = Self.makeContainer()
        self.shadowFactory = Self.makeShadowFactory()
        Self.scheduleBackgroundCleanup(container: container)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.shadowEvaluatorFactory, shadowFactory)
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
            } catch {
                log.error(
                    "MLX phoneme evaluator load failed (\(String(describing: error))); running Engine A only"
                )
                return engineA
            }
        }
    }
}
