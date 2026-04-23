import Foundation
import SwiftData

/// FIFO retention for `PronunciationTrialLog`. Called by `MoraApp` once at
/// launch from a background task; the logger itself does not enforce the
/// cap so per-trial writes stay cheap. Uses a fresh `ModelContext` so the
/// cleanup pass does not contend with the main-actor context used by the
/// UI.
public enum PronunciationTrialRetentionPolicy {
    public static let maxRows = 1_000

    public static func cleanup(_ container: ModelContainer) throws {
        let ctx = ModelContext(container)
        let total = try ctx.fetchCount(FetchDescriptor<PronunciationTrialLog>())
        guard total > maxRows else { return }
        let excess = total - maxRows
        var descriptor = FetchDescriptor<PronunciationTrialLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.fetchLimit = excess
        let victims = try ctx.fetch(descriptor)
        for row in victims {
            ctx.delete(row)
        }
        try ctx.save()
    }
}
