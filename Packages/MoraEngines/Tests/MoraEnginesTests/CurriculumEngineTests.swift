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

    func test_emittedWordsCarryTargetPhonemeMatchingSkill() {
        let words = CurriculumEngine.testShipFixtureWords()
        XCTAssertFalse(words.isEmpty)
        for w in words {
            XCTAssertEqual(w.targetPhoneme, Phoneme(ipa: "ʃ"))
        }
    }

    func test_defaultV1Ladder_has5SkillsAlignedToYokaiCast() {
        let ladder = CurriculumEngine.defaultV1Ladder()
        let codes = ladder.skills.map(\.code.rawValue)
        XCTAssertEqual(codes, ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"])
        let yokaiIDs = ladder.skills.map(\.yokaiID)
        XCTAssertEqual(yokaiIDs, ["sh", "th", "f", "r", "short_a"])
    }

    func test_eachV1Skill_hasThreeWarmupCandidatesIncludingTarget() {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            let target = skill.graphemePhoneme!.grapheme
            XCTAssertEqual(
                skill.warmupCandidates.count, 3,
                "\(skill.code.rawValue) should expose 3 warmup candidates"
            )
            XCTAssertTrue(
                skill.warmupCandidates.contains(target),
                "\(skill.code.rawValue) warmup candidates must include target \(target.letters)"
            )
        }
    }

    func test_nextSkill_returnsSuccessor_thenNil() {
        let ladder = CurriculumEngine.defaultV1Ladder()
        XCTAssertEqual(ladder.nextSkill(after: "sh_onset")?.code.rawValue, "th_voiceless")
        XCTAssertEqual(ladder.nextSkill(after: "r_onset")?.code.rawValue, "short_a")
        XCTAssertNil(ladder.nextSkill(after: "short_a"))
        XCTAssertNil(ladder.nextSkill(after: "unknown_code"))
    }

    func test_indexOf_returnsZeroBased_orNilIfAbsent() {
        let ladder = CurriculumEngine.defaultV1Ladder()
        XCTAssertEqual(ladder.indexOf(code: "sh_onset"), 0)
        XCTAssertEqual(ladder.indexOf(code: "short_a"), 4)
        XCTAssertNil(ladder.indexOf(code: "nonsense"))
    }
}
