import XCTest

@testable import MoraFixtures

final class FixturePatternTests: XCTestCase {

    func testDisplayLabelForMatchedPattern() {
        let pattern = FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        )
        XCTAssertEqual(pattern.displayLabel, "right — /r/ matched")
    }

    func testDisplayLabelForSubstitutedPattern() {
        let pattern = FixturePattern(
            id: "rl-right-as-light",
            targetPhonemeIPA: "r",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l",
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-as-light"
        )
        XCTAssertEqual(pattern.displayLabel, "right — /r/ substituted by /l/")
    }

    func testHumanTextCoversEveryExpectedLabel() {
        XCTAssertEqual(ExpectedLabel.matched.humanText, "matched")
        XCTAssertEqual(ExpectedLabel.substitutedBy.humanText, "substituted by")
        XCTAssertEqual(ExpectedLabel.driftedWithin.humanText, "drifted within")
    }
}
