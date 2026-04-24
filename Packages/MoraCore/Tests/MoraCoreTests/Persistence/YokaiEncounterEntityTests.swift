import SwiftData
import XCTest

@testable import MoraCore

@MainActor
final class YokaiEncounterEntityTests: XCTestCase {
    func test_persists_andRetrievesAnEncounter() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let monday = Date(timeIntervalSince1970: 1_746_403_200)
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: monday,
            state: .active,
            friendshipPercent: 0.1
        )
        ctx.insert(encounter)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.yokaiID, "sh")
        XCTAssertEqual(fetched.first?.state, .active)
    }
}
