import MoraCore
import MoraEngines
import SwiftData
import SwiftUI
import XCTest

@testable import MoraUI

@MainActor
final class SessionContainerBootstrapTests: XCTestCase {
    func test_bootstrapSurface_activeEncounterYieldsYokaiOrchestrator() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: Date(),
            state: .active,
            friendshipPercent: 0.1,
            sessionCompletionCount: 0
        )
        ctx.insert(encounter)
        try ctx.save()

        let ladder = CurriculumEngine.sharedV1
        let resolution = try WeekRotation.resolve(context: ctx, ladder: ladder)
        XCTAssertNotNil(resolution)
        XCTAssertEqual(resolution?.skill.code, "sh_onset")

        let store = try BundledYokaiStore()
        let progression = ClosureYokaiProgressionSource { id in
            ladder.skills.first(where: { $0.yokaiID == id })
                .flatMap { ladder.nextSkill(after: $0.code) }
                .flatMap(\.yokaiID)
        }
        let yokai = YokaiOrchestrator(
            store: store, modelContext: ctx, progressionSource: progression
        )
        yokai.resume(encounter: resolution!.encounter)

        XCTAssertEqual(yokai.currentYokai?.id, "sh")
        XCTAssertEqual(yokai.currentEncounter?.yokaiID, "sh")
    }
}
