import XCTest
@testable import MoraCore

final class TargetTests: XCTestCase {
    func test_interestCategory_rememberKeyDisplayName() {
        let c = InterestCategory(
            key: "animals", displayName: "Animals",
            parentAuthored: false)
        XCTAssertEqual(c.key, "animals")
        XCTAssertFalse(c.parentAuthored)
    }

    func test_sessionType_rawValuesStableForPersistence() {
        XCTAssertEqual(SessionType.coreDecoder.rawValue, "coreDecoder")
        XCTAssertEqual(SessionType.readingAdventure.rawValue, "readingAdventure")
    }

    func test_target_carriesSkillAndWeekStart() {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(
                grapheme: .init(letters: "sh"),
                phoneme: .init(ipa: "ʃ")
            )
        )
        let date = Date(timeIntervalSince1970: 1_713_974_400)  // 2024-04-24
        let target = Target(weekStart: date, skill: skill)
        XCTAssertEqual(target.skill.code, "sh_onset")
        XCTAssertEqual(target.weekStart, date)
    }
}
