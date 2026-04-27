import XCTest

@testable import MoraCore

final class EnglishL1ProfileTests: XCTestCase {
    func test_identifier_is_en() {
        XCTAssertEqual(EnglishL1Profile().identifier, "en")
    }

    func test_characterSystem_is_alphabetic() {
        XCTAssertEqual(EnglishL1Profile().characterSystem, .alphabetic)
    }

    func test_interferencePairs_isEmpty() {
        XCTAssertTrue(EnglishL1Profile().interferencePairs.isEmpty)
    }

    func test_uiStrings_is_levelInvariant() {
        let p = EnglishL1Profile()
        XCTAssertEqual(
            p.uiStrings(at: .entry).homeTodayQuest,
            p.uiStrings(at: .core).homeTodayQuest)
        XCTAssertEqual(
            p.uiStrings(at: .core).homeTodayQuest,
            p.uiStrings(at: .advanced).homeTodayQuest)
        XCTAssertEqual(p.uiStrings(at: .core).homeTodayQuest, "Today's quest")
    }

    func test_interestCategoryDisplayName_returnsEnglish() {
        let p = EnglishL1Profile()
        XCTAssertEqual(p.interestCategoryDisplayName(key: "animals", at: .core), "Animals")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "dinosaurs", at: .core), "Dinosaurs")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "vehicles", at: .core), "Vehicles")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "space", at: .core), "Space")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "sports", at: .core), "Sports")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "robots", at: .core), "Robots")
    }

    func test_allowedScriptBudget_isNil_atAllLevels() {
        let p = EnglishL1Profile()
        for level in LearnerLevel.allCases {
            XCTAssertNil(p.allowedScriptBudget(at: level))
        }
    }

    /// Smoke: every rendered field uses only ASCII letters / digits /
    /// punctuation / whitespace + ▶ / 🔊 / … / æ. Catches accidental locale
    /// leakage (e.g. Japanese punctuation slipping into the EN table).
    func test_stringsKidEn_isAsciiPlusEmojiOnly() {
        let strings = EnglishL1Profile().uiStrings(at: .core)
        for (fieldName, value) in everyStringField(strings) {
            for char in value {
                for scalar in char.unicodeScalars {
                    let v = scalar.value
                    let ok =
                        (0x0020...0x007E).contains(v)  // printable ASCII
                        || v == 0x000A || v == 0x000D  // newline / CR
                        || v == 0x25B6  // ▶
                        || v == 0x1F50A  // 🔊
                        || v == 0x2026  // …
                        || v == 0x2014  // em-dash (—)
                        || v == 0x00E6  // æ — IPA vowel in coachingAeSubSchwa
                    XCTAssertTrue(
                        ok,
                        "[en] '\(fieldName)' contains non-ASCII U+\(String(v, radix: 16, uppercase: true))"
                    )
                }
            }
        }
    }
}
