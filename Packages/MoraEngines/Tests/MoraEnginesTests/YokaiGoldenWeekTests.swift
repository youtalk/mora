import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class YokaiGoldenWeekTests: XCTestCase {
    private struct Scenario { let yokaiID: String; let next: String? }

    private let scenarios: [Scenario] = [
        .init(yokaiID: "sh", next: "th"),
        .init(yokaiID: "th", next: "f"),
        .init(yokaiID: "f", next: "r"),
        .init(yokaiID: "r", next: "short_a"),
        .init(yokaiID: "short_a", next: nil),
    ]

    func test_goldenWeek_eachYokai_reachesBefriendAndHandsOff() throws {
        for scenario in scenarios {
            let ctx = ModelContext(try MoraModelContainer.inMemory())
            let store = try BundledYokaiStore()
            let progression = ClosureYokaiProgressionSource { id in
                id == scenario.yokaiID ? scenario.next : nil
            }
            let orch = YokaiOrchestrator(
                store: store, modelContext: ctx, progressionSource: progression
            )
            try orch.startWeek(yokaiID: scenario.yokaiID, weekStart: Date())
            orch.dismissCutscene()

            for _ in 0..<4 {
                orch.beginDay()
                for _ in 0..<20 { orch.recordTrialOutcome(correct: true) }
                orch.recordSessionCompletion()
            }

            orch.beginFridaySession(trialsPlanned: 1)
            orch.recordTrialOutcome(correct: true)

            XCTAssertEqual(
                orch.currentEncounter?.state, .befriended,
                "\(scenario.yokaiID) should befriend by session 5"
            )

            let encounters = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
            let nextActive = encounters.first { $0.state == .active }
            if let nextID = scenario.next {
                XCTAssertEqual(
                    nextActive?.yokaiID, nextID,
                    "\(scenario.yokaiID) should hand off to \(nextID)")
            } else {
                XCTAssertNil(
                    nextActive,
                    "\(scenario.yokaiID) is last — no further active encounter")
            }
        }
    }
}
