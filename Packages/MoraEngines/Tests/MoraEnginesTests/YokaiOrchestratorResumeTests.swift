// Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorResumeTests.swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class YokaiOrchestratorResumeTests: XCTestCase {
    private func makeStore() throws -> BundledYokaiStore {
        try BundledYokaiStore()
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try MoraModelContainer.inMemory())
    }

    func test_resume_restoresStateFromExistingEncounter() throws {
        let ctx = try makeContext()
        let store = try makeStore()
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            state: .active,
            friendshipPercent: 0.42,
            sessionCompletionCount: 2
        )
        ctx.insert(encounter)
        try ctx.save()

        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        orch.resume(encounter: encounter)

        XCTAssertEqual(orch.currentEncounter?.yokaiID, "sh")
        XCTAssertEqual(orch.currentYokai?.id, "sh")
        XCTAssertNil(orch.activeCutscene, "resume must not fire Monday intro again")
    }

    func test_resume_onSessionCount4_doesNotAutoPlayClimax() throws {
        let ctx = try makeContext()
        let store = try makeStore()
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: Date(),
            state: .active,
            friendshipPercent: 0.9,
            sessionCompletionCount: 4
        )
        ctx.insert(encounter)
        try ctx.save()

        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        orch.resume(encounter: encounter)

        XCTAssertNil(orch.activeCutscene)
        XCTAssertEqual(orch.currentEncounter?.sessionCompletionCount, 4)
    }
}
