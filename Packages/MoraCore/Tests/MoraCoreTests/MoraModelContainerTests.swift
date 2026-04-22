import SwiftData
import XCTest

@testable import MoraCore

final class MoraModelContainerTests: XCTestCase {
    @MainActor
    func test_inMemoryContainer_seedsDefaultLearnerIfEmpty() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        try MoraModelContainer.seedIfEmpty(ctx)
        let learners = try ctx.fetch(FetchDescriptor<LearnerEntity>())
        XCTAssertEqual(learners.count, 1)
        XCTAssertEqual(learners.first?.l1Identifier, "ja")
    }

    @MainActor
    func test_seedIfEmpty_isIdempotent() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        try MoraModelContainer.seedIfEmpty(ctx)
        try MoraModelContainer.seedIfEmpty(ctx)
        let learners = try ctx.fetch(FetchDescriptor<LearnerEntity>())
        XCTAssertEqual(learners.count, 1)
    }
}
