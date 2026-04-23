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
        Self.cleanupPronunciationTrialLog(container: container)
        self.shadowFactory = Self.makeShadowFactory()
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

    @MainActor
    private static func cleanupPronunciationTrialLog(container: ModelContainer) {
        do {
            try PronunciationTrialRetentionPolicy.cleanup(container.mainContext)
        } catch {
            log.error("PronunciationTrialLog cleanup failed at launch: \(error)")
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
            } catch {
                log.error(
                    "MLX phoneme evaluator load failed (\(String(describing: error))); running Engine A only"
                )
                return engineA
            }
        }
    }
}
