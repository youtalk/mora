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
        // The bundled corpus has every (phoneme, interest, ageBand) cell
        // populated, so we inject a temp root that holds only one cell and
        // query for a distinct (interest, ageBand) within the same phoneme.
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
              "ageBand": "mid",
              "sentences": []
            }
            """
        try Data(json.utf8).write(to: shDir.appendingPathComponent("vehicles_mid.json"))

        let library = try SentenceLibrary(rootURL: root)
        let cell = await library.cell(
            phoneme: "sh",
            interest: "robots",
            ageBand: .late
        )

        XCTAssertNil(cell, "expected nil when no JSON exists for the (phoneme, interest, ageBand) triple")
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

    func test_byDayLookupReturnsTrimmedSentenceForDayOne() async throws {
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
              "ageBand": "mid",
              "sentences": [
                {
                  "text": "She shoves a sharp ship to shore.",
                  "targetCount": 4, "targetInitialContentWords": 4,
                  "interestWords": ["ship"],
                  "words": [
                    {"surface":"She","graphemes":["sh","e"],"phonemes":["ʃ","i"]},
                    {"surface":"shoves","graphemes":["sh","o","v","e","s"],"phonemes":["ʃ","ʌ","v","z"]},
                    {"surface":"a","graphemes":["a"],"phonemes":["ə"]},
                    {"surface":"sharp","graphemes":["sh","a","r","p"],"phonemes":["ʃ","ɑ","r","p"]},
                    {"surface":"ship","graphemes":["sh","i","p"],"phonemes":["ʃ","ɪ","p"]},
                    {"surface":"to","graphemes":["t","o"],"phonemes":["t","ə"]},
                    {"surface":"shore","graphemes":["sh","o","r","e"],"phonemes":["ʃ","ɔ","r"]}
                  ],
                  "byDay": {
                    "1": {
                      "text": "She shoves sharp ship.",
                      "words": [
                        {"surface":"She","graphemes":["sh","e"],"phonemes":["ʃ","i"]},
                        {"surface":"shoves","graphemes":["sh","o","v","e","s"],"phonemes":["ʃ","ʌ","v","z"]},
                        {"surface":"sharp","graphemes":["sh","a","r","p"],"phonemes":["ʃ","ɑ","r","p"]},
                        {"surface":"ship","graphemes":["sh","i","p"],"phonemes":["ʃ","ɪ","p"]}
                      ]
                    }
                  }
                }
              ]
            }
            """
        try Data(json.utf8).write(to: shDir.appendingPathComponent("vehicles_mid.json"))
        let library = try SentenceLibrary(rootURL: root)

        let day1 = await library.sentences(
            target: "sh_onset", interests: ["vehicles"], ageYears: 8,
            dayInWeek: 1, excluding: [], count: 1
        )
        XCTAssertEqual(day1.first?.text, "She shoves sharp ship.")
        XCTAssertEqual(day1.first?.words.count, 4)

        let day5 = await library.sentences(
            target: "sh_onset", interests: ["vehicles"], ageYears: 8,
            dayInWeek: 5, excluding: [], count: 1
        )
        XCTAssertEqual(day5.first?.text, "She shoves a sharp ship to shore.")
        XCTAssertEqual(day5.first?.words.count, 7)
    }

    func test_defaultDayOverloadReturnsFullSentences() async throws {
        // Existing API (no dayInWeek arg) returns full sentences regardless.
        let library = try SentenceLibrary()
        let result = await library.sentences(
            target: "sh_onset", interests: ["vehicles"], ageYears: 8,
            excluding: [], count: 1
        )
        XCTAssertNotNil(result.first)
    }

    // MARK: - Helpers

    private func makeTempRoot() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SentenceLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        return tmp
    }
}
