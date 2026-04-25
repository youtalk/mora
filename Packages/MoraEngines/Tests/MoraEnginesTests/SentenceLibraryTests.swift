import XCTest

@testable import MoraCore
@testable import MoraEngines

final class SentenceLibraryTests: XCTestCase {
    func test_init_loadsBundledCells() async throws {
        let library = try SentenceLibrary()

        let count = await library.cellCount
        XCTAssertGreaterThanOrEqual(
            count, 1,
            "expected at least the sample cell sh/vehicles_mid.json to load"
        )
    }

    func test_cell_returnsTwentySentencesForSampleCell() async throws {
        let library = try SentenceLibrary()
        let cell = await library.cell(
            phoneme: "sh",
            interest: "vehicles",
            ageBand: .mid
        )

        XCTAssertNotNil(cell, "sample cell sh/vehicles_mid.json must load")
        XCTAssertEqual(cell?.sentences.count, 20)
    }

    func test_cell_returnsNilForUnpopulatedCell() async throws {
        let library = try SentenceLibrary()
        let cell = await library.cell(
            phoneme: "th",
            interest: "robots",
            ageBand: .late
        )

        XCTAssertNil(cell, "Track B-1 only ships sh/vehicles_mid; others are absent")
    }
}
