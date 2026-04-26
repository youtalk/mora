// Packages/MoraCore/Tests/MoraCoreTests/JPKanjiLevelTests.swift
import XCTest
@testable import MoraCore

final class JPKanjiLevelTests: XCTestCase {
    func test_grade1HasExactly80Kanji() {
        XCTAssertEqual(JPKanjiLevel.grade1.count, 80)
    }

    func test_grade2HasExactly160Kanji() {
        XCTAssertEqual(JPKanjiLevel.grade2.count, 160)
    }

    func test_grade1AndGrade2AreDisjoint() {
        let overlap = JPKanjiLevel.grade1.intersection(JPKanjiLevel.grade2)
        XCTAssertTrue(overlap.isEmpty, "Unexpected overlap: \(overlap)")
    }

    func test_grade1And2IsUnion() {
        XCTAssertEqual(JPKanjiLevel.grade1And2.count, 240)
    }

    func test_wellKnownSamples() {
        // Spot-check a few characters from each grade and a few that
        // must NOT be present (G3+ kanji the UI is forbidden from using).
        XCTAssertTrue(JPKanjiLevel.grade1.contains("日"))
        XCTAssertTrue(JPKanjiLevel.grade2.contains("今"))
        XCTAssertTrue(JPKanjiLevel.grade1And2.contains("読"))
        XCTAssertFalse(JPKanjiLevel.grade1And2.contains("始"))  // G3
        XCTAssertFalse(JPKanjiLevel.grade1And2.contains("終"))  // G3
        XCTAssertFalse(JPKanjiLevel.grade1And2.contains("解"))  // G5
    }

    func test_empty_isEmptySet() {
        XCTAssertTrue(JPKanjiLevel.empty.isEmpty)
        XCTAssertEqual(JPKanjiLevel.empty.count, 0)
    }

    func test_grade1_isSubset_of_grade1And2() {
        XCTAssertTrue(JPKanjiLevel.grade1.isSubset(of: JPKanjiLevel.grade1And2))
    }
}
