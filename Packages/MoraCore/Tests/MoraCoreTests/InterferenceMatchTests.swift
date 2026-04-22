import XCTest
@testable import MoraCore

private struct JaStub: L1Profile {
    let identifier = "ja"
    let characterSystem: CharacterSystem = .mixed
    let interestCategories: [InterestCategory] = []
    let interferencePairs: [PhonemeConfusionPair] = [
        .init(tag: "r_l_swap",
              from: .init(ipa: "r"), to: .init(ipa: "l"),
              bidirectional: true),
        .init(tag: "f_h_sub",
              from: .init(ipa: "f"), to: .init(ipa: "h"),
              bidirectional: false),
    ]
}

final class InterferenceMatchTests: XCTestCase {
    private let p = JaStub()

    func test_match_directSubstitution() {
        let hit = p.matchInterference(expected: .init(ipa: "f"),
                                      heard:    .init(ipa: "h"))
        XCTAssertEqual(hit?.tag, "f_h_sub")
    }

    func test_bidirectional_matchesBothDirections() {
        XCTAssertEqual(p.matchInterference(expected: .init(ipa: "r"),
                                           heard:    .init(ipa: "l"))?.tag,
                       "r_l_swap")
        XCTAssertEqual(p.matchInterference(expected: .init(ipa: "l"),
                                           heard:    .init(ipa: "r"))?.tag,
                       "r_l_swap")
    }

    func test_nonBidirectional_doesNotReverseMatch() {
        XCTAssertNil(p.matchInterference(expected: .init(ipa: "h"),
                                         heard:    .init(ipa: "f")))
    }

    func test_noMatch_whenPhonemesIdentical() {
        XCTAssertNil(p.matchInterference(expected: .init(ipa: "s"),
                                         heard:    .init(ipa: "s")))
    }
}
