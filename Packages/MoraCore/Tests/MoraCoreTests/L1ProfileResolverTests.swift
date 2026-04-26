import XCTest
@testable import MoraCore

final class L1ProfileResolverTests: XCTestCase {
    func test_profile_for_ja_returnsJapaneseProfile() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "ja").identifier, "ja")
    }

    func test_profile_for_unknown_fallsBackToJapanese() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "").identifier, "ja")
        XCTAssertEqual(L1ProfileResolver.profile(for: "zh").identifier, "ja")
        XCTAssertEqual(L1ProfileResolver.profile(for: "xx").identifier, "ja")
    }

    // PR 2 adds: profile_for_ko, profile_for_en
}
