import MoraCore
import XCTest

@testable import MoraEngines

final class CurriculumEngineTests: XCTestCase {
    func test_defaultLadder_firstSkillIsShOnsetForWeekZero() {
        let engine = CurriculumEngine.defaultV1Ladder()
        let target = engine.currentTarget(forWeekIndex: 0)
        XCTAssertEqual(target.skill.code, "sh_onset")
        XCTAssertEqual(
            target.skill.graphemePhoneme?.grapheme,
            Grapheme(letters: "sh")
        )
    }

    func test_taughtGraphemes_beforeWeekZero_isFullL2Alphabet() {
        let engine = CurriculumEngine.defaultV1Ladder()
        let taught = engine.taughtGraphemes(beforeWeekIndex: 0)
        // All 26 L2 single letters are "taught" before the sh week begins.
        XCTAssertEqual(taught.count, 26)
        XCTAssertTrue(taught.contains(Grapheme(letters: "a")))
        XCTAssertFalse(taught.contains(Grapheme(letters: "sh")))
    }

    func test_outOfRangeWeek_clampsToLastSkill() {
        let engine = CurriculumEngine.defaultV1Ladder()
        let target = engine.currentTarget(forWeekIndex: 9999)
        XCTAssertEqual(target.skill.code, engine.skills.last?.code)
    }

    func test_negativeWeekIndex_taughtGraphemesIsBaselineOnly() {
        let engine = CurriculumEngine.defaultV1Ladder()
        let taught = engine.taughtGraphemes(beforeWeekIndex: -1)
        XCTAssertEqual(taught.count, 26)
        XCTAssertFalse(taught.contains(Grapheme(letters: "sh")))
    }

    func test_negativeWeekIndex_currentTargetClampsToFirstSkill() {
        let engine = CurriculumEngine.defaultV1Ladder()
        let target = engine.currentTarget(forWeekIndex: -5)
        XCTAssertEqual(target.skill.code, "sh_onset")
    }
}
