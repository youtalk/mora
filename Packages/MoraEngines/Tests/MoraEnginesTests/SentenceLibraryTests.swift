import Foundation
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

    // Fix #3: A cell JSON with an unrecognised ageBand must throw rather than
    // silently being dropped.
    func test_init_throwsOnInvalidAgeBand() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let shDir = root.appendingPathComponent("sh", isDirectory: true)
        try FileManager.default.createDirectory(at: shDir, withIntermediateDirectories: true)
        let json = """
            {
              "phoneme": "sh",
              "phonemeIPA": "ʃ",
              "graphemeLetters": "sh",
              "interest": "vehicles",
              "ageBand": "bogus",
              "sentences": []
            }
            """
        try Data(json.utf8).write(to: shDir.appendingPathComponent("vehicles_bogus.json"))

        XCTAssertThrowsError(try SentenceLibrary(rootURL: root)) { error in
            let msg = String(describing: error)
            XCTAssertTrue(
                msg.contains("bogus"),
                "error should mention the bad ageBand value; got: \(msg)")
        }
    }

    // Fix #2: A cell JSON whose `interest` field disagrees with the filename
    // must throw rather than loading silently under the wrong key.
    func test_init_throwsOnPayloadFilenameMismatch() throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let shDir = root.appendingPathComponent("sh", isDirectory: true)
        try FileManager.default.createDirectory(at: shDir, withIntermediateDirectories: true)
        // Filename says "vehicles_mid" but payload says interest = "robots".
        let json = """
            {
              "phoneme": "sh",
              "phonemeIPA": "ʃ",
              "graphemeLetters": "sh",
              "interest": "robots",
              "ageBand": "mid",
              "sentences": []
            }
            """
        try Data(json.utf8).write(to: shDir.appendingPathComponent("vehicles_mid.json"))

        XCTAssertThrowsError(try SentenceLibrary(rootURL: root)) { error in
            let msg = String(describing: error)
            XCTAssertTrue(
                msg.contains("interest"),
                "error should mention the mismatched field; got: \(msg)")
        }
    }

    // MARK: - Helpers

    private func makeTempRoot() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SentenceLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }
}
