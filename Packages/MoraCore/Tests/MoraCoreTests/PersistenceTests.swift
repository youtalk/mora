import SwiftData
import XCTest

@testable import MoraCore

final class PersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            LearnerEntity.self, SkillEntity.self,
            SessionSummaryEntity.self, PerformanceEntity.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func test_learnerEntity_roundtripsThroughContext() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let learner = LearnerEntity(
            displayName: "Soma",
            birthYear: 2017,
            l1Identifier: "ja"
        )
        ctx.insert(learner)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<LearnerEntity>())
        XCTAssertEqual(fetched.first?.displayName, "Soma")
    }

    @MainActor
    func test_skillEntity_storesStateAsString() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let entity = SkillEntity(code: "sh_onset", level: 3)
        ctx.insert(entity)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<SkillEntity>())
        XCTAssertEqual(fetched.first?.state, "new")
    }

    @MainActor
    func test_sessionSummary_storesTrialCounts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let summary = SessionSummaryEntity(
            id: UUID(),
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "sh_onset",
            durationSec: 900,
            trialsTotal: 15,
            trialsCorrect: 12,
            escalated: false
        )
        ctx.insert(summary)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<SessionSummaryEntity>())
        XCTAssertEqual(fetched.first?.trialsTotal, 15)
    }

    @MainActor
    func test_performance_storesL1Tag() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let perf = PerformanceEntity(
            id: UUID(),
            sessionId: UUID(),
            skillCode: "sh_onset",
            expected: "ship",
            heard: "sip",
            correct: false,
            l1InterferenceTag: "f_h_sub",
            timestamp: Date()
        )
        ctx.insert(perf)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PerformanceEntity>())
        XCTAssertEqual(fetched.first?.expected, "ship")
        XCTAssertEqual(fetched.first?.heard, "sip")
        XCTAssertEqual(fetched.first?.l1InterferenceTag, "f_h_sub")
    }

    @MainActor
    func test_performance_storesNilL1Tag() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let perf = PerformanceEntity(
            id: UUID(),
            sessionId: UUID(),
            skillCode: "sh_onset",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date()
        )
        ctx.insert(perf)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PerformanceEntity>())
        XCTAssertNil(fetched.first?.l1InterferenceTag)
    }
}
