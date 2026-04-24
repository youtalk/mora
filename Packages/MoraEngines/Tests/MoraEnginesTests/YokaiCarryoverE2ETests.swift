import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — carryover E2E")
struct YokaiCarryoverE2ETests {
    @Test("carryover encounter re-used on next Monday")
    func carryoverMonday() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)

        // Week 1: set up a near-complete encounter that fails at the Friday final trial.
        try orch.startWeek(yokaiID: "sh", weekStart: Date(timeIntervalSince1970: 1_000_000))
        orch.currentEncounter?.friendshipPercent = 0.30
        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordFridayFinalTrial(correct: false)
        #expect(orch.currentEncounter?.state == .carryover)

        // Week 2: same yokai reused — new encounter becomes active, previous is preserved.
        try orch.startWeek(yokaiID: "sh", weekStart: Date(timeIntervalSince1970: 1_604_800 + 1_000_000))
        #expect(orch.currentEncounter?.yokaiID == "sh")
        #expect(orch.currentEncounter?.state == .active)

        // Carryover flag preserved in history.
        let past = try ctx.fetch(
            FetchDescriptor<YokaiEncounterEntity>(
                predicate: #Predicate { $0.storedRolloverFlag == true }
            )
        )
        #expect(past.count == 1)
    }
}
