import XCTest
import SwiftData
@testable import MoraCore

@MainActor
final class LearnerProfileLevelTests: XCTestCase {
    func test_resolvedLevel_levelOverride_nil_age8_returnsAdvanced() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 8, levelOverride: nil,
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .advanced)
    }

    func test_resolvedLevel_levelOverride_core_age8_returnsCore() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 8, levelOverride: "core",
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .core)
    }

    func test_resolvedLevel_invalidOverride_fallsBackToAge() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 6, levelOverride: "fictional",
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .entry)
    }

    func test_resolvedLevel_nilAgeAndOverride_returnsAdvanced() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: nil, levelOverride: nil,
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .advanced)
    }

    func test_persistence_levelOverride_roundTrip() throws {
        let container = try MoraModelContainer.inMemory()
        let context = ModelContext(container)
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 7, levelOverride: "entry",
            interests: [], preferredFontKey: "openDyslexic"
        )
        context.insert(p)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LearnerProfile>()).first
        XCTAssertEqual(fetched?.levelOverride, "entry")
        XCTAssertEqual(fetched?.resolvedLevel, .entry)
    }
}
