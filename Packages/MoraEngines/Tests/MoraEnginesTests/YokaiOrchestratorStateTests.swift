import Foundation
import SwiftData
import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiOrchestratorStateTests: XCTestCase {
    func test_fridayFinalTrial_pushesOverOne_befriends() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.98  // pre-seeded
        orch.recordFridayFinalTrial(correct: true)
        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
        XCTAssertEqual(orch.activeCutscene, .fridayClimax(yokaiID: "sh"))
        let entries = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.yokaiID, "sh")
    }

    func test_fridayUnderPerforming_floorBoost_befriends() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.60  // low entering Friday
        orch.beginFridaySession(trialsPlanned: 4)
        for _ in 0..<3 { orch.recordTrialOutcome(correct: true) }
        orch.recordFridayFinalTrial(correct: true)
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 1.0, accuracy: 1e-9)
        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
    }

    func test_fridayMissedFinal_carryover() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.30
        orch.beginFridaySession(trialsPlanned: 4)
        orch.recordTrialOutcome(correct: false)
        orch.recordTrialOutcome(correct: false)
        orch.recordTrialOutcome(correct: false)
        orch.recordFridayFinalTrial(correct: false)
        XCTAssertEqual(orch.currentEncounter?.state, .carryover)
        let entries = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        XCTAssertTrue(entries.isEmpty)
    }
}
