import Foundation
import SwiftData
import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiOrchestratorMeterTests: XCTestCase {
    private func makeSubject() throws -> YokaiOrchestrator {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = FakeYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date(timeIntervalSince1970: 1_746_403_200))
        return orch
    }

    func test_startsAtTenPercent_onGreeting() throws {
        let orch = try makeSubject()
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 0.10, accuracy: 1e-9)
    }

    func test_correctTrialAddsTwoPp() throws {
        let orch = try makeSubject()
        orch.recordTrialOutcome(correct: true)
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 0.12, accuracy: 1e-9)
    }

    func test_missedTrialLeavesMeterUnchanged() throws {
        let orch = try makeSubject()
        orch.recordTrialOutcome(correct: false)
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 0.10, accuracy: 1e-9)
    }

    func test_dayCapStopsFurtherCreditWithinSingleDay() throws {
        let orch = try makeSubject()
        // 13 correct trials -> would be 26pp, but day cap 25pp halts at index 12.
        for _ in 0..<13 { orch.recordTrialOutcome(correct: true) }
        let percent = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(percent, 0.35, accuracy: 1e-9)
    }

    func test_startWeekThrowsForUnknownYokai() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        XCTAssertThrowsError(try orch.startWeek(yokaiID: "nope", weekStart: Date())) { error in
            XCTAssertEqual(error as? YokaiOrchestratorError, .unknownYokai("nope"))
        }
        XCTAssertNil(orch.currentEncounter)
        XCTAssertNil(orch.currentYokai)
    }
}
