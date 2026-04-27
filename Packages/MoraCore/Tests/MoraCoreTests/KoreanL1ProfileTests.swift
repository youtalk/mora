import XCTest

@testable import MoraCore

final class KoreanL1ProfileTests: XCTestCase {
    func test_identifier_is_ko() {
        XCTAssertEqual(KoreanL1Profile().identifier, "ko")
    }

    func test_characterSystem_is_alphabetic() {
        XCTAssertEqual(KoreanL1Profile().characterSystem, .alphabetic)
    }

    func test_uiStrings_is_levelInvariant() {
        let p = KoreanL1Profile()
        let entryStrings = p.uiStrings(at: .entry)
        let coreStrings = p.uiStrings(at: .core)
        let advStrings = p.uiStrings(at: .advanced)
        XCTAssertEqual(entryStrings.homeTodayQuest, coreStrings.homeTodayQuest)
        XCTAssertEqual(coreStrings.homeTodayQuest, advStrings.homeTodayQuest)
        XCTAssertEqual(entryStrings.homeTodayQuest, "오늘의 퀘스트")
    }

    func test_interestCategoryDisplayName_returnsKorean() {
        let p = KoreanL1Profile()
        XCTAssertEqual(p.interestCategoryDisplayName(key: "animals", at: .core), "동물")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "dinosaurs", at: .core), "공룡")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "vehicles", at: .core), "탈것")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "space", at: .core), "우주")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "sports", at: .core), "스포츠")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "robots", at: .core), "로봇")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "unknown", at: .core), "unknown")
    }

    func test_allowedScriptBudget_isNil_atAllLevels() {
        let p = KoreanL1Profile()
        for level in LearnerLevel.allCases {
            XCTAssertNil(p.allowedScriptBudget(at: level))
        }
    }

    func test_interferencePairs_count_is8() {
        XCTAssertEqual(KoreanL1Profile().interferencePairs.count, 8)
    }

    func test_interferencePairs_allHaveKoPrefix() {
        for pair in KoreanL1Profile().interferencePairs {
            XCTAssertTrue(pair.tag.hasPrefix("ko_"), "pair \(pair.tag) does not have ko_ prefix")
        }
    }

    func test_interferencePairs_includesKnownTransfers() {
        let tags = Set(KoreanL1Profile().interferencePairs.map(\.tag))
        XCTAssertTrue(tags.contains("ko_f_p_sub"))
        XCTAssertTrue(tags.contains("ko_v_b_sub"))
        XCTAssertTrue(tags.contains("ko_th_voiceless_s_sub"))
        XCTAssertTrue(tags.contains("ko_r_l_swap"))
        XCTAssertTrue(tags.contains("ko_ae_e_conflate"))
    }

    /// Hangul-purity: every field is verified to contain no CJK Unified
    /// Ideographs (U+4E00..U+9FFF) or CJK Compatibility Ideographs
    /// (U+F900..U+FAFF). KO kid texts should be 순한글 — Hanja insertion
    /// is a regression.
    func test_stringsKidKo_containsNoCJKIdeographs() {
        let strings = KoreanL1Profile().uiStrings(at: .core)
        for (fieldName, value) in everyStringField(strings) {
            for char in value {
                for scalar in char.unicodeScalars {
                    let v = scalar.value
                    XCTAssertFalse(
                        (0x4E00...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v),
                        "[ko] '\(fieldName)' contains CJK ideograph U+\(String(v, radix: 16, uppercase: true))"
                    )
                }
            }
        }
    }
}
