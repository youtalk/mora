import Foundation
import SwiftData
import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiGoldenWeekTests: XCTestCase {
    func test_fiveStrongDays_befriendsByFriday() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())

        // Mon: seeded at 10%, plus session complete.
        orch.recordSessionCompletion()
        orch.beginDay()
        for _ in 0..<10 { orch.recordTrialOutcome(correct: true) }
        orch.recordSessionCompletion()
        orch.beginDay()
        for _ in 0..<10 { orch.recordTrialOutcome(correct: true) }
        orch.recordSessionCompletion()
        orch.beginDay()
        for _ in 0..<10 { orch.recordTrialOutcome(correct: true) }
        orch.recordSessionCompletion()

        orch.beginFridaySession(trialsPlanned: 10)
        for _ in 0..<9 { orch.recordTrialOutcome(correct: true) }
        orch.recordFridayFinalTrial(correct: true)

        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 1.0, accuracy: 1e-9)
        let entries = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        XCTAssertEqual(entries.count, 1)
    }
}
