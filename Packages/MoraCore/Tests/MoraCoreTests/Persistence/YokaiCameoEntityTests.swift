import SwiftData
import XCTest

@testable import MoraCore

@MainActor
final class YokaiCameoEntityTests: XCTestCase {
    func test_logs_aCameoWithOutcome() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let sid = UUID()
        let cameo = YokaiCameoEntity(
            yokaiID: "sh",
            sessionID: sid,
            triggeredAt: Date(),
            pronunciationSuccess: true
        )
        ctx.insert(cameo)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<YokaiCameoEntity>()).first
        XCTAssertEqual(fetched?.yokaiID, "sh")
        XCTAssertEqual(fetched?.sessionID, sid)
        XCTAssertTrue(fetched?.pronunciationSuccess == true)
    }
}
