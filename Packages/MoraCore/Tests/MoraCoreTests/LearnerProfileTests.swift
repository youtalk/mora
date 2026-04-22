import SwiftData
import XCTest

@testable import MoraCore

@MainActor
final class LearnerProfileTests: XCTestCase {
    func test_insertAndFetch_roundTrip() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let profile = LearnerProfile(
            displayName: "Hiro",
            l1Identifier: "ja",
            interests: ["dinosaurs", "space", "robots"],
            preferredFontKey: "openDyslexic"
        )
        ctx.insert(profile)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.displayName, "Hiro")
        XCTAssertEqual(fetched.first?.interests, ["dinosaurs", "space", "robots"])
    }

    func test_displayNameCanBeEmpty() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        ctx.insert(
            LearnerProfile(
                displayName: "",
                l1Identifier: "ja",
                interests: [],
                preferredFontKey: "openDyslexic"
            ))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(fetched.first?.displayName, "")
    }
}
