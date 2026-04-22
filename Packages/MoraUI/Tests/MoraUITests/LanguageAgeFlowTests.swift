// Packages/MoraUI/Tests/MoraUITests/LanguageAgeFlowTests.swift
import MoraCore
import SwiftData
import XCTest
@testable import MoraUI

@MainActor
final class LanguageAgeFlowTests: XCTestCase {
    func test_advance_steps() {
        let state = LanguageAgeState()
        XCTAssertEqual(state.step, .language)
        state.advance()
        XCTAssertEqual(state.step, .age)
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func test_finalize_insertsProfileAndSetsFlag_onFreshInstall() throws {
        let container = try MoraModelContainer.inMemory()
        let state = LanguageAgeState()
        state.selectedLanguageID = "ja"
        state.selectedAge = 8
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.removeObject(forKey: LanguageAgeState.onboardedKey)

        let ok = state.finalize(in: container.mainContext, defaults: defaults)

        XCTAssertTrue(ok)
        XCTAssertTrue(defaults.bool(forKey: LanguageAgeState.onboardedKey))

        let profiles = try container.mainContext.fetch(
            FetchDescriptor<LearnerProfile>()
        )
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.l1Identifier, "ja")
        XCTAssertEqual(profiles.first?.ageYears, 8)
        XCTAssertEqual(profiles.first?.displayName, "")
    }

    func test_finalize_upsertsExistingProfile() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let existing = LearnerProfile(
            displayName: "hiro",
            l1Identifier: "ja",
            ageYears: nil,
            interests: ["animals", "robots"],
            preferredFontKey: "openDyslexic"
        )
        ctx.insert(existing)
        try ctx.save()

        let state = LanguageAgeState()
        state.selectedLanguageID = "ja"
        state.selectedAge = 8
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        let ok = state.finalize(in: ctx, defaults: defaults)

        XCTAssertTrue(ok)
        let profiles = try ctx.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.displayName, "hiro")  // preserved
        XCTAssertEqual(profiles.first?.ageYears, 8)  // backfilled
        XCTAssertEqual(
            Set(profiles.first?.interests ?? []), ["animals", "robots"]
        )  // preserved
    }

    func test_finalize_failsWhenAgeNotSelected() throws {
        let container = try MoraModelContainer.inMemory()
        let state = LanguageAgeState()
        state.selectedAge = nil
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        let ok = state.finalize(in: container.mainContext, defaults: defaults)
        XCTAssertFalse(ok)
        XCTAssertFalse(defaults.bool(forKey: LanguageAgeState.onboardedKey))
    }
}
