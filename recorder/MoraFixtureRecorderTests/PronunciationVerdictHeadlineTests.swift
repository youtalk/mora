import MoraCore
import MoraEngines
import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

final class PronunciationVerdictHeadlineTests: XCTestCase {

    private func pattern(
        id: String,
        target: String,
        expected: ExpectedLabel,
        sub: String? = nil
    ) -> FixturePattern {
        FixturePattern(
            id: id,
            targetPhonemeIPA: target,
            expectedLabel: expected,
            substitutePhonemeIPA: sub,
            wordSurface: "w",
            phonemeSequenceIPA: [target],
            targetPhonemeIndex: 0,
            outputSubdirectory: "x",
            filenameStem: "stem"
        )
    }

    private func assessment(
        target: String,
        label: PhonemeAssessmentLabel,
        reliable: Bool = true
    ) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: target),
            label: label,
            score: label == .matched ? 100 : 50,
            coachingKey: nil,
            features: [:],
            isReliable: reliable
        )
    }

    func testMatched_expectedMatched_pass() {
        let p = pattern(id: "a", target: "æ", expected: .matched)
        let a = assessment(target: "æ", label: .matched)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .pass)
        XCTAssertEqual(h.title, "matched")
    }

    func testMatched_expectedSub_fail_tooClean() {
        let p = pattern(id: "b", target: "v", expected: .substitutedBy, sub: "b")
        let a = assessment(target: "v", label: .matched)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertTrue(h.title.contains("matched"))
        XCTAssertEqual(h.subtitle, "expected substitution /b/ — re-record with clearer /b/")
    }

    func testSub_expectedMatched_fail() {
        let p = pattern(id: "c", target: "l", expected: .matched)
        let a = assessment(target: "l", label: .substitutedBy(Phoneme(ipa: "r")))
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertEqual(h.title, "heard /r/")
        XCTAssertEqual(h.subtitle, "expected matched /l/")
    }

    func testSub_expectedSameSub_pass() {
        let p = pattern(id: "d", target: "l", expected: .substitutedBy, sub: "r")
        let a = assessment(target: "l", label: .substitutedBy(Phoneme(ipa: "r")))
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .pass)
        XCTAssertEqual(h.title, "heard /r/")
        XCTAssertEqual(h.subtitle, "matches expected substitution")
    }

    func testSub_expectedDifferentSub_fail() {
        let p = pattern(id: "e", target: "r", expected: .substitutedBy, sub: "l")
        let a = assessment(target: "r", label: .substitutedBy(Phoneme(ipa: "w")))
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertEqual(h.title, "heard /w/")
        XCTAssertEqual(h.subtitle, "expected substitution /l/")
    }

    func testDrifted_expectedMatched_fail() {
        let p = pattern(id: "f", target: "ʃ", expected: .matched)
        let a = assessment(target: "ʃ", label: .driftedWithin)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertEqual(h.title, "drifted")
    }

    func testUnclear_warn() {
        let p = pattern(id: "g", target: "æ", expected: .matched)
        let a = assessment(target: "æ", label: .unclear)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .warn)
        XCTAssertEqual(h.title, "audio unclear")
        XCTAssertEqual(h.subtitle, "re-record longer/louder")
    }

    func testUnreliableAnnotatesHeadline() {
        let p = pattern(id: "h", target: "æ", expected: .matched)
        let a = assessment(target: "æ", label: .matched, reliable: false)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .warn)
        XCTAssertTrue(h.title.contains("unreliable"))
    }
}
