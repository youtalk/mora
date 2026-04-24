import XCTest
@testable import MoraCore

final class SkillTests: XCTestCase {
    func test_skillCode_wrapsRawString() {
        let c = SkillCode("sh_onset")
        XCTAssertEqual(c.rawValue, "sh_onset")
    }

    func test_ogLevel_rawValues_matchPrimarySpec() {
        XCTAssertEqual(OGLevel.l1.rawValue, 1)
        XCTAssertEqual(OGLevel.l4.rawValue, 4)
    }

    func test_skillState_defaultInitialStateIsNew() {
        XCTAssertEqual(SkillState.new.rawValue, "new")
    }

    func test_skill_composesRuleWithCodeAndLevel() {
        let skill = Skill(
            code: SkillCode("sh_onset"),
            level: .l3,
            displayName: "sh digraph",
            graphemePhoneme: GraphemePhoneme(
                grapheme: Grapheme(letters: "sh"),
                phoneme: Phoneme(ipa: "ʃ")
            )
        )
        XCTAssertEqual(skill.code, SkillCode("sh_onset"))
        XCTAssertEqual(skill.level, .l3)
        XCTAssertEqual(skill.graphemePhoneme?.grapheme, Grapheme(letters: "sh"))
    }

    func test_skill_exposesWarmupCandidatesAndYokaiID() {
        let g = Grapheme(letters: "sh")
        let skill = Skill(
            code: "sh_onset",
            level: .l3,
            displayName: "sh digraph",
            graphemePhoneme: .init(grapheme: g, phoneme: .init(ipa: "ʃ")),
            warmupCandidates: [
                Grapheme(letters: "s"),
                Grapheme(letters: "sh"),
                Grapheme(letters: "ch"),
            ],
            yokaiID: "sh"
        )
        XCTAssertEqual(skill.warmupCandidates.count, 3)
        XCTAssertTrue(skill.warmupCandidates.contains(g))
        XCTAssertEqual(skill.yokaiID, "sh")
    }

    func test_skill_defaultsAreEmpty_whenOmitted() {
        let skill = Skill(
            code: "x",
            level: .l2,
            displayName: "test"
        )
        XCTAssertTrue(skill.warmupCandidates.isEmpty)
        XCTAssertNil(skill.yokaiID)
    }
}
