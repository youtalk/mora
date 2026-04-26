import XCTest
@testable import MoraCore

final class JapaneseL1ProfileTests: XCTestCase {
    private let profile = JapaneseL1Profile()

    func test_identifier_isJa() {
        XCTAssertEqual(profile.identifier, "ja")
    }

    func test_characterSystem_isMixed() {
        XCTAssertEqual(profile.characterSystem, .mixed)
    }

    func test_interferencePairs_includeAllPrimarySpecSix() {
        let tags = Set(profile.interferencePairs.map(\.tag))
        let required: Set<String> = [
            "r_l_swap", "f_h_sub", "v_b_sub",
            "th_voiceless_s_sub", "th_voiceless_t_sub",
            "ae_lax_conflate",
        ]
        XCTAssertTrue(
            required.isSubset(of: tags),
            "missing: \(required.subtracting(tags))")
    }

    func test_rLswap_isBidirectional() {
        let pair = profile.interferencePairs.first { $0.tag == "r_l_swap" }
        XCTAssertEqual(pair?.bidirectional, true)
    }

    func test_interestCategories_includeAtLeastSixBundled() {
        XCTAssertGreaterThanOrEqual(profile.interestCategories.count, 6)
        let keys = Set(profile.interestCategories.map(\.key))
        XCTAssertTrue(
            [
                "animals", "dinosaurs", "vehicles",
                "space", "sports", "robots",
            ]
            .allSatisfy(keys.contains))
    }

    func test_matchInterference_usesJapanesePairs() {
        let hit = profile.matchInterference(
            expected: .init(ipa: "r"),
            heard: .init(ipa: "l"))
        XCTAssertEqual(hit?.tag, "r_l_swap")
    }

    func test_exemplars_shDigraph() {
        XCTAssertEqual(
            profile.exemplars(for: Phoneme(ipa: "ʃ")),
            ["ship", "shop", "fish"]
        )
    }

    func test_exemplars_unknownPhonemeIsEmpty() {
        XCTAssertTrue(profile.exemplars(for: Phoneme(ipa: "ʒ")).isEmpty)
    }

    func test_uiStrings_advanced_isCurrentMidContent() {
        // Sanity check: stringsAdvancedG1G2 is the predecessor's stringsMid renamed.
        // Specific row from the predecessor spec §7.2 table.
        let s = JapaneseL1Profile().uiStrings(at: .advanced)
        XCTAssertEqual(s.homeTodayQuest, "今日の クエスト")
        XCTAssertEqual(s.feedbackTryAgain, "もう一回")
        XCTAssertEqual(s.permissionTitle, "声を 聞くよ")
    }

    func test_uiStrings_core_collapsesG2KanjiToHira() {
        let s = JapaneseL1Profile().uiStrings(at: .core)
        XCTAssertEqual(s.homeTodayQuest, "きょうの クエスト")  // 今 G2 → きょう
        XCTAssertEqual(s.feedbackTryAgain, "もういちど")  // 一回 → all-hira
        XCTAssertEqual(s.permissionTitle, "こえを きくよ")  // 声 G2, 聞 G2 → hira
    }

    func test_uiStrings_entry_collapsesAllKanjiToHira() {
        let s = JapaneseL1Profile().uiStrings(at: .entry)
        XCTAssertEqual(s.welcomeTitle, "えいごの おとを いっしょに")  // 音 G1 → おと
        XCTAssertEqual(s.homeTodayQuest, "きょうの クエスト")
    }

    func test_allowedScriptBudget_perLevel() {
        let p = JapaneseL1Profile()
        XCTAssertEqual(p.allowedScriptBudget(at: .entry), JPKanjiLevel.empty)
        XCTAssertEqual(p.allowedScriptBudget(at: .core), JPKanjiLevel.grade1)
        XCTAssertEqual(p.allowedScriptBudget(at: .advanced), JPKanjiLevel.grade1And2)
    }

    func test_interestCategoryDisplayName_isLevelInvariant() {
        let p = JapaneseL1Profile()
        for level in LearnerLevel.allCases {
            XCTAssertEqual(p.interestCategoryDisplayName(key: "animals", at: level), "どうぶつ")
            XCTAssertEqual(p.interestCategoryDisplayName(key: "robots", at: level), "ロボット")
            XCTAssertEqual(p.interestCategoryDisplayName(key: "unknown_key", at: level), "unknown_key")
        }
    }
}
