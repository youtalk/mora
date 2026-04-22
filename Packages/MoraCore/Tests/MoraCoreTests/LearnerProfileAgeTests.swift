// Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileAgeTests.swift
import SwiftData
import XCTest
@testable import MoraCore

@MainActor
final class LearnerProfileAgeTests: XCTestCase {
    func test_newProfileWithoutAge_persistsAsNil() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let profile = LearnerProfile(
            displayName: "hiro",
            l1Identifier: "ja",
            interests: ["animals"],
            preferredFontKey: "openDyslexic"
        )
        ctx.insert(profile)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertNil(fetched.first?.ageYears)
    }

    func test_setAgeYears_roundtrips() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let profile = LearnerProfile(
            displayName: "hiro",
            l1Identifier: "ja",
            ageYears: 8,
            interests: [],
            preferredFontKey: "openDyslexic"
        )
        ctx.insert(profile)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<LearnerProfile>()).first!
        XCTAssertEqual(fetched.ageYears, 8)

        fetched.ageYears = 13
        try ctx.save()

        let reread = try ctx.fetch(FetchDescriptor<LearnerProfile>()).first!
        XCTAssertEqual(reread.ageYears, 13)
    }
}
