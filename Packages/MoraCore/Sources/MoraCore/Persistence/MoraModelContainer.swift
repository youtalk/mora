import Foundation
import SwiftData

public enum MoraModelContainer {
    public static let schema = Schema([
        LearnerEntity.self,
        SkillEntity.self,
        SessionSummaryEntity.self,
        PerformanceEntity.self,
    ])

    public static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func onDisk() throws -> ModelContainer {
        let config = ModelConfiguration()
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func seedIfEmpty(
        _ ctx: ModelContext,
        defaultName: String = "Learner",
        birthYear: Int = 2017,
        l1Identifier: String = "ja"
    ) throws {
        // fetchLimit=1 keeps the existence check O(1) regardless of how many
        // learners already exist; we only care whether the table is empty.
        var descriptor = FetchDescriptor<LearnerEntity>()
        descriptor.fetchLimit = 1
        let learners = try ctx.fetch(descriptor)
        if !learners.isEmpty { return }
        let learner = LearnerEntity(
            displayName: defaultName,
            birthYear: birthYear,
            l1Identifier: l1Identifier
        )
        ctx.insert(learner)
        try ctx.save()
    }
}
