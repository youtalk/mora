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
        let nextActive = encounters.first(where: { $0.state == .active })
        XCTAssertEqual(nextActive?.yokaiID, "th")
        // Bootstrap uses these two fields to detect an unstarted handoff
        // encounter and route it through startWeek (Monday intro + 10% seed)
        // instead of resume; pin the invariant so the detection can rely
        // on it.
        XCTAssertEqual(nextActive?.sessionCompletionCount, 0)
        XCTAssertEqual(nextActive?.friendshipPercent, 0)
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

    func test_recordTrialOutcome_fridayMode_distributesFloorBoostAcrossTrials() throws {
        let (orch, _) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.50
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 10)
        orch.recordTrialOutcome(correct: true)

        // One of ten planned correct trials — floor-boost math spreads the
        // 0.50 deficit evenly, so a single correct trial contributes 0.05
        // rather than concentrating the whole deficit into this one shot.
        XCTAssertEqual(
            orch.currentEncounter?.friendshipPercent ?? 0, 0.55, accuracy: 1e-9
        )
        XCTAssertEqual(orch.currentEncounter?.state, .active)
    }

    func test_recordTrialOutcome_fridayMode_reachesHundredAcrossAllTrials() throws {
        let (orch, _) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.50
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 10)
        for _ in 0..<10 {
            orch.recordTrialOutcome(correct: true)
        }

        // Ten correct trials consume the entire budget; floor boost lands on
        // 100% and the final trial finalizes the encounter as befriended.
        XCTAssertEqual(
            orch.currentEncounter?.friendshipPercent ?? 0, 1.0, accuracy: 1e-9
        )
        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
    }
}
