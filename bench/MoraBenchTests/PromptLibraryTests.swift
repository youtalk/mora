import XCTest
@testable import MoraBench

final class PromptLibraryTests: XCTestCase {
    func testAllPromptsLoaded() {
        XCTAssertEqual(PromptLibrary.all.count, 4)
    }

    func testPromptIDsAreUnique() {
        let ids = PromptLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEveryPromptHasNonEmptyBody() {
        for p in PromptLibrary.all {
            XCTAssertFalse(p.systemPrompt.isEmpty, "system prompt empty for \(p.id)")
            XCTAssertFalse(p.userPrompt.isEmpty, "user prompt empty for \(p.id)")
        }
    }

    func testFrozenSnapshotLoadedIntoSlotFill() {
        let slotFill = PromptLibrary.all.first { $0.id == "slot-fill-short" }!
        // Assert on a concrete vocabulary token from templates-frozen.json —
        // `.empty` fallback wouldn't contain these, so this catches missed bundling.
        XCTAssertTrue(slotFill.userPrompt.contains("ship"), "slot-fill should contain a subject from the frozen vocabulary")
        XCTAssertTrue(slotFill.userPrompt.contains("vocabulary.verb:"), "slot-fill should list vocabulary.verb lines")
    }
}
