import MoraEngines
import XCTest

@testable import MoraUI

final class YokaiCutscenePredicatesTests: XCTestCase {
    func testIsMondayIntroTrueForMondayIntroCase() {
        let cutscene: YokaiCutscene = .mondayIntro(yokaiID: "sh")
        XCTAssertTrue(cutscene.isMondayIntro)
    }

    func testIsMondayIntroFalseForOtherCases() {
        XCTAssertFalse(YokaiCutscene.fridayClimax(yokaiID: "sh").isMondayIntro)
        XCTAssertFalse(YokaiCutscene.srsCameo(yokaiID: "sh").isMondayIntro)
        XCTAssertFalse(YokaiCutscene.sessionStart(yokaiID: "sh").isMondayIntro)
    }

    func testOptionalNilIsNotMondayIntro() {
        let cutscene: YokaiCutscene? = nil
        XCTAssertFalse(cutscene?.isMondayIntro ?? false)
    }

    func testOptionalSomeMondayIntro() {
        let cutscene: YokaiCutscene? = .mondayIntro(yokaiID: "th")
        XCTAssertTrue(cutscene?.isMondayIntro ?? false)
    }
}
