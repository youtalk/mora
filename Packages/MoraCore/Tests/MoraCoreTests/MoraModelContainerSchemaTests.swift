import SwiftData
import XCTest

@testable import MoraCore

final class MoraModelContainerSchemaTests: XCTestCase {
    /// The schema list is the canonical SwiftData registration. A @Model type
    /// added to the codebase but forgotten here would silently fail at runtime
    /// when queried. Enumerate the expected set so the next addition is
    /// caught by this test rather than by a crash on a user's device.
    func test_schema_registersEveryPersistedEntity() {
        let registered = Set(MoraModelContainer.schema.entities.map(\.name))
        let expected: Set<String> = [
            "LearnerEntity",
            "SkillEntity",
            "SessionSummaryEntity",
            "PerformanceEntity",
            "LearnerProfile",
            "DailyStreak",
            "PronunciationTrialLog",
        ]
        XCTAssertEqual(registered, expected)
    }

    @MainActor
    func test_inMemoryContainer_opensWithRegisteredSchema() throws {
        // Smoke: the container actually loads all six @Model types together.
        // Any attribute-level migration collision would throw here.
        _ = try MoraModelContainer.inMemory()
    }
}
