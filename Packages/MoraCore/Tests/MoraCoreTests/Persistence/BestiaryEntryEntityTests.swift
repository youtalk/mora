import SwiftData
import XCTest

@testable import MoraCore

@MainActor
final class BestiaryEntryEntityTests: XCTestCase {
    func test_records_aBefriendedYokai() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let entry = BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date(timeIntervalSince1970: 0))
        ctx.insert(entry)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.yokaiID, "sh")
        XCTAssertEqual(fetched.first?.playbackCount, 0)
    }

    func test_increments_playbackCount() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let entry = BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date())
        ctx.insert(entry)
        entry.playbackCount += 1
        entry.lastPlayedAt = Date()
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>()).first
        XCTAssertEqual(fetched?.playbackCount, 1)
        XCTAssertNotNil(fetched?.lastPlayedAt)
    }
}
