// Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfilePronunciationTests.swift
import XCTest
@testable import MoraCore

final class JapaneseL1ProfilePronunciationTests: XCTestCase {
    private let profile = JapaneseL1Profile()

    func testShSSubIsRegistered() {
        let pair = profile.interferencePairs.first { $0.tag == "sh_s_sub" }
        XCTAssertNotNil(pair, "JapaneseL1Profile must register sh_s_sub")
        XCTAssertEqual(pair?.from, Phoneme(ipa: "ʃ"))
        XCTAssertEqual(pair?.to, Phoneme(ipa: "s"))
        XCTAssertFalse(pair?.bidirectional ?? true)
    }

    func testShDriftTargetIsRegistered() {
        let pair = profile.interferencePairs.first { $0.tag == "sh_drift_target" }
        XCTAssertNotNil(pair, "JapaneseL1Profile must register sh_drift_target")
        XCTAssertEqual(pair?.from, Phoneme(ipa: "ʃ"))
        XCTAssertEqual(pair?.to, Phoneme(ipa: "ʃ"))
    }

    func testMatchInterferenceFindsShSSub() {
        let pair = profile.matchInterference(
            expected: Phoneme(ipa: "ʃ"),
            heard: Phoneme(ipa: "s")
        )
        XCTAssertEqual(pair?.tag, "sh_s_sub")
    }

    func testMatchInterferenceIgnoresDriftSentinel() {
        // A `from == to` sentinel must not be treated as a substitution match.
        let pair = profile.matchInterference(
            expected: Phoneme(ipa: "ʃ"),
            heard: Phoneme(ipa: "ʃ")
        )
        XCTAssertNil(pair)
    }
}
