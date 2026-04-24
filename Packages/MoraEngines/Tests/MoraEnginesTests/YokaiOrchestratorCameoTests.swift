import Foundation
import SwiftData
import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiOrchestratorCameoTests: XCTestCase {
    func test_previouslyBefriendedGrapheme_triggersCameo() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        ctx.insert(BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date(timeIntervalSinceNow: -86_400)))
        try ctx.save()
        let sessionID = UUID()
        orch.maybeTriggerCameo(grapheme: "sh", sessionID: sessionID, pronunciationSuccess: true)
        XCTAssertEqual(orch.activeCutscene, .srsCameo(yokaiID: "sh"))
        let cameos = try ctx.fetch(FetchDescriptor<YokaiCameoEntity>())
        XCTAssertEqual(cameos.count, 1)
        XCTAssertEqual(cameos.first?.sessionID, sessionID)
        XCTAssertTrue(cameos.first?.pronunciationSuccess == true)
    }

    func test_nonBefriendedGrapheme_doesNotCameo() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        orch.maybeTriggerCameo(grapheme: "sh", sessionID: UUID(), pronunciationSuccess: true)
        XCTAssertNil(orch.activeCutscene)
    }

    func test_cameoDoesNotAffectMeter() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        ctx.insert(BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date(timeIntervalSinceNow: -86_400)))
        let before = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        orch.maybeTriggerCameo(grapheme: "sh", sessionID: UUID(), pronunciationSuccess: true)
        let after = try XCTUnwrap(orch.currentEncounter?.friendshipPercent)
        XCTAssertEqual(after, before, accuracy: 1e-9)
    }
}
