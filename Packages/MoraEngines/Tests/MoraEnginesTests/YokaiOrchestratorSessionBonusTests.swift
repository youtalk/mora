import Foundation
import SwiftData
import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiOrchestratorSessionBonusTests: XCTestCase {
    func test_sessionCompletionAddsFivePp() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.recordSessionCompletion()
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 0.15, accuracy: 1e-9)
        XCTAssertEqual(orch.currentEncounter?.sessionCompletionCount, 1)
    }

    func test_beginDayResetsPerDayCap() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        for _ in 0..<13 { orch.recordTrialOutcome(correct: true) }
        let percentAfterCap = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percentAfterCap, 0.35, accuracy: 1e-9)
        orch.beginDay()
        orch.recordTrialOutcome(correct: true)
        let percentAfterReset = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percentAfterReset, 0.37, accuracy: 1e-9)
    }
}
