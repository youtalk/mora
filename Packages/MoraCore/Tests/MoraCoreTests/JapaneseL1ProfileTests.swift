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
}
