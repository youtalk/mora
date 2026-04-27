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

    func test_profile_for_ko_returnsKoreanProfile() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "ko").identifier, "ko")
    }

    func test_profile_for_en_returnsEnglishProfile() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "en").identifier, "en")
    }
}
