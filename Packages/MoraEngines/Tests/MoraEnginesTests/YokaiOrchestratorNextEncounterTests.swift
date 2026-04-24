// Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorNextEncounterTests.swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class YokaiOrchestratorNextEncounterTests: XCTestCase {
    private func makeOrch(
        progression: YokaiProgressionSource = ClosureYokaiProgressionSource { _ in "th" }
    ) throws -> (YokaiOrchestrator, ModelContext) {
        let ctx = ModelContext(try MoraModelContainer.inMemory())
        let orch = YokaiOrchestrator(
            store: try BundledYokaiStore(),
            modelContext: ctx,
            progressionSource: progression
        )
        return (orch, ctx)
    }

    func test_finalizeFriday_atHundredPercent_befriendsAndInsertsNextEncounter() throws {
        let (orch, ctx) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.98
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordTrialOutcome(correct: true)  // Friday dispatch

        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
        let encounters = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
        XCTAssertEqual(encounters.count, 2, "sh befriended + new th encounter")
        XCTAssertEqual(
            encounters.first(where: { $0.state == .active })?.yokaiID,
            "th"
        )
    }

    func test_finalizeFriday_withoutNextYokai_befriendsButInsertsNoNewEncounter() throws {
        let (orch, ctx) = try makeOrch(
            progression: ClosureYokaiProgressionSource { _ in nil }
        )
        try orch.startWeek(yokaiID: "short_a", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.99
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordTrialOutcome(correct: true)

        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
        let active = try ctx.fetch(
            FetchDescriptor<YokaiEncounterEntity>(
                predicate: #Predicate { $0.stateRaw == "active" }
            )
        )
        XCTAssertTrue(active.isEmpty, "no next yokai means no new active encounter")
    }

    func test_recordTrialOutcome_normalMode_usesPerDayCapMath() throws {
        let (orch, _) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.dismissCutscene()
        orch.beginDay()

        for _ in 0..<20 {
            orch.recordTrialOutcome(correct: true)
        }
        let pct = orch.currentEncounter?.friendshipPercent ?? 0
        XCTAssertEqual(pct, 0.35, accuracy: 1e-9, "start 0.10 + day cap 0.25")
    }

    func test_recordTrialOutcome_fridayMode_usesFloorBoost() throws {
        let (orch, _) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.50
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 10)
        orch.recordTrialOutcome(correct: true)

        XCTAssertEqual(orch.currentEncounter?.friendshipPercent ?? 0, 1.0, accuracy: 1e-9)
    }
}
