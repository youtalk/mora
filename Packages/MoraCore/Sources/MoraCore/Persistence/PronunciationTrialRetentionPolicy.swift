import Foundation
import SwiftData

/// FIFO retention for `PronunciationTrialLog`. Called at app launch by
/// `MoraApp`; the logger itself does not enforce the cap so per-trial
/// writes stay cheap. At most one cleanup pass per process lifetime.
public enum PronunciationTrialRetentionPolicy {
    public static let maxRows = 1_000

    @MainActor
    public static func cleanup(_ ctx: ModelContext) throws {
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
