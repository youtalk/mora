// Packages/MoraEngines/Tests/MoraEnginesTests/WeekRotationTests.swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class WeekRotationTests: XCTestCase {
    private func freshContainer() throws -> ModelContainer {
        try MoraModelContainer.inMemory()
    }

    func test_resolve_emptyStore_createsInitialShEncounter() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        XCTAssertNotNil(res)
        XCTAssertEqual(res?.skill.code, "sh_onset")
        XCTAssertEqual(res?.encounter.yokaiID, "sh")
        XCTAssertEqual(res?.encounter.state, .active)
        XCTAssertTrue(res?.isNewEncounter == true)

        let saved = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.yokaiID, "sh")
    }

    func test_resolve_existingActiveEncounter_returnsMatchingSkill() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let existing = YokaiEncounterEntity(
            yokaiID: "th",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            state: .active,
            friendshipPercent: 0.4,
            sessionCompletionCount: 2
        )
        ctx.insert(existing)
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date() }
        )

        XCTAssertEqual(res?.skill.code, "th_voiceless")
        XCTAssertEqual(res?.encounter.yokaiID, "th")
        XCTAssertFalse(res?.isNewEncounter == true)
        XCTAssertEqual(res?.encounter.sessionCompletionCount, 2)
    }

    func test_resolve_allBefriended_returnsNil() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        for id in ["sh", "th", "f", "r", "short_a"] {
            ctx.insert(
                BestiaryEntryEntity(yokaiID: id, befriendedAt: Date())
            )
        }
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date() }
        )

        XCTAssertNil(res)
    }

    func test_resolve_someBefriendedNoActive_createsNextUnfinishedEncounter() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        ctx.insert(BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date()))
        ctx.insert(BestiaryEntryEntity(yokaiID: "th", befriendedAt: Date()))
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        XCTAssertEqual(res?.skill.code, "f_onset")
        XCTAssertTrue(res?.isNewEncounter == true)
    }

    func test_resolve_carryoverEncounter_resumesSameYokai() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let carry = YokaiEncounterEntity(
            yokaiID: "f",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            state: .carryover,
            friendshipPercent: 0.88,
            sessionCompletionCount: 5
        )
        ctx.insert(carry)
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date() }
        )

        XCTAssertEqual(res?.skill.code, "f_onset")
        XCTAssertEqual(res?.encounter.state, .carryover)
    }
}
