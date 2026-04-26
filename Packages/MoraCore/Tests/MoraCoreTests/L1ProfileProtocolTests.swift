import XCTest
@testable import MoraCore

private struct StubProfile: L1Profile {
    let identifier = "stub"
    let characterSystem: CharacterSystem = .alphabetic
    let interferencePairs: [PhonemeConfusionPair] = []
    let interestCategories: [InterestCategory] = []
    func uiStrings(at level: LearnerLevel) -> MoraStrings { JapaneseL1Profile().uiStrings(at: level) }
}

final class L1ProfileProtocolTests: XCTestCase {
    func test_confusionPair_storesTagFromTo() {
        let pair = PhonemeConfusionPair(
            tag: "r_l_swap",
            from: Phoneme(ipa: "r"),
            to: Phoneme(ipa: "l"),
            examples: ["right/light"],
            bidirectional: true
        )
        XCTAssertEqual(pair.tag, "r_l_swap")
        XCTAssertTrue(pair.bidirectional)
    }

    func test_characterSystem_hasExpectedCases() {
        XCTAssertEqual(
            Set(CharacterSystem.allCases),
            Set([.alphabetic, .logographic, .mixed]))
    }

    func test_profile_exposesIdentifierAndEmptyInterference() {
        let p = StubProfile()
        XCTAssertEqual(p.identifier, "stub")
        XCTAssertEqual(p.interferencePairs.count, 0)
    }
}
