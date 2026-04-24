import MoraCore
import MoraEngines
import XCTest

@testable import MoraUI

final class PronunciationFeedbackOverlayTests: XCTestCase {

    private func strings() -> MoraStrings {
        JapaneseL1Profile().uiStrings(forAgeYears: 8)
    }

    func testMatchedDoesNotShowCoaching() {
        let vm = PronunciationFeedbackViewModel(
            assessment: PhonemeTrialAssessment(
                targetPhoneme: Phoneme(ipa: "ʃ"),
                label: .matched,
                score: 95,
                coachingKey: nil,
                features: [:],
                isReliable: true
            ),
            strings: strings()
        )
        XCTAssertEqual(vm.categoryText, "")
        XCTAssertTrue(vm.showScore)
        XCTAssertEqual(vm.scoreFraction, 0.95, accuracy: 0.001)
        XCTAssertEqual(vm.coachingText, "")
    }

    func testSubstitutionShowsCategoryAndCoaching() {
        let vm = PronunciationFeedbackViewModel(
            assessment: PhonemeTrialAssessment(
                targetPhoneme: Phoneme(ipa: "ʃ"),
                label: .substitutedBy(Phoneme(ipa: "s")),
                score: 28,
                coachingKey: "coaching.sh_sub_s",
                features: [:],
                isReliable: true
            ),
            strings: strings()
        )
        XCTAssertTrue(vm.categoryText.contains("sh"))
        XCTAssertTrue(vm.showScore)
        XCTAssertEqual(vm.coachingText, strings().coachingShSubS)
    }

    func testUnreliableHidesScore() {
        let vm = PronunciationFeedbackViewModel(
            assessment: PhonemeTrialAssessment(
                targetPhoneme: Phoneme(ipa: "ʃ"),
                label: .substitutedBy(Phoneme(ipa: "s")),
                score: 28,
                coachingKey: "coaching.sh_sub_s",
                features: [:],
                isReliable: false
            ),
            strings: strings()
        )
        XCTAssertFalse(vm.showScore)
    }

    func testTSubThVoicelessShowsCoachingAndLetters() {
        let vm = PronunciationFeedbackViewModel(
            assessment: PhonemeTrialAssessment(
                targetPhoneme: Phoneme(ipa: "t"),
                label: .substitutedBy(Phoneme(ipa: "θ")),
                score: 30,
                coachingKey: "coaching.t_sub_th_voiceless",
                features: [:],
                isReliable: true
            ),
            strings: strings()
        )
        XCTAssertTrue(vm.categoryText.contains("t"))
        XCTAssertTrue(vm.categoryText.contains("th"))
        XCTAssertEqual(vm.coachingText, strings().coachingTSubThVoiceless)
    }

    func testUnclearEmitsNoContent() {
        let vm = PronunciationFeedbackViewModel(
            assessment: PhonemeTrialAssessment(
                targetPhoneme: Phoneme(ipa: "ʃ"),
                label: .unclear,
                score: nil,
                coachingKey: nil,
                features: [:],
                isReliable: false
            ),
            strings: strings()
        )
        XCTAssertEqual(vm.categoryText, "")
        XCTAssertFalse(vm.showScore)
        XCTAssertEqual(vm.coachingText, "")
    }
}
