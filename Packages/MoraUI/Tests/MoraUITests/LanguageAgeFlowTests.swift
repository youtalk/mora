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

    func test_pickerRows_areActive_forJaKoEn() {
        let activeIDs = LanguageAgeFlow.activeLanguageIdentifiers
        XCTAssertEqual(Set(activeIDs), Set(["ja", "ko", "en"]))
        let disabledIDs = LanguageAgeFlow.comingSoonLanguageIdentifiers
        XCTAssertEqual(Set(disabledIDs), Set(["zh"]))
    }

    func test_defaultLanguageID_followsSystemLocale() {
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "ja_JP")), "ja")
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "ko_KR")), "ko")
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "en_US")), "en")
    }

    func test_defaultLanguageID_unsupportedLocale_fallsBackToEnglish() {
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "zh_CN")), "en")
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "es_ES")), "en")
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "vi_VN")), "en")
        XCTAssertEqual(
            LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "")), "en")
    }

    func test_state_initialLanguageID_followsSystemLocale() {
        XCTAssertEqual(
            LanguageAgeState(systemLocale: Locale(identifier: "ja_JP")).selectedLanguageID, "ja")
        XCTAssertEqual(
            LanguageAgeState(systemLocale: Locale(identifier: "ko_KR")).selectedLanguageID, "ko")
        XCTAssertEqual(
            LanguageAgeState(systemLocale: Locale(identifier: "vi_VN")).selectedLanguageID, "en")
    }

    func test_finalize_failsWhenLanguageIDEmpty() throws {
        let container = try MoraModelContainer.inMemory()
        let state = LanguageAgeState()
        state.selectedLanguageID = "   "  // whitespace trims to empty
        state.selectedAge = 8
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        let ok = state.finalize(in: container.mainContext, defaults: defaults)

        XCTAssertFalse(ok)
        XCTAssertFalse(defaults.bool(forKey: LanguageAgeState.onboardedKey))
        let profiles = try container.mainContext.fetch(
            FetchDescriptor<LearnerProfile>()
        )
        XCTAssertTrue(profiles.isEmpty)
    }

    func test_agePicker_showsThreeTiles_for6_7_8() {
        XCTAssertEqual(LanguageAgeFlow.ageOptions, [6, 7, 8])
    }

    func test_agePicker_defaultSelection_is7() {
        XCTAssertEqual(LanguageAgeFlow.defaultAge, 7)
    }
}
