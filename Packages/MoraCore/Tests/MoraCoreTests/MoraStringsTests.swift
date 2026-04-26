// Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift
import XCTest
@testable import MoraCore

final class MoraStringsTests: XCTestCase {
    private let profile = JapaneseL1Profile()

    // MARK: - Completeness

    func test_uiStrings_advancedTable_homeTodayQuest_usesKanji() {
        // Advanced tier uses G1+G2 kanji: `今日` is G2.
        let s = profile.uiStrings(at: .advanced)
        XCTAssertEqual(s.homeTodayQuest, "今日の クエスト")
    }

    func test_uiStrings_coreTable_homeTodayQuest_isAllHiragana() {
        // Core tier (Task 1.5): `今` is G2 → all-hira per partial-mix rule.
        let s = profile.uiStrings(at: .core)
        XCTAssertEqual(s.homeTodayQuest, "きょうの クエスト")
    }

    func test_everyPlainStringFieldIsNonEmpty() {
        let s = profile.uiStrings(at: .advanced)
        let plain: [(String, String)] = [
            ("ageOnboardingPrompt", s.ageOnboardingPrompt),
            ("ageOnboardingCTA", s.ageOnboardingCTA),
            ("welcomeTitle", s.welcomeTitle),
            ("welcomeCTA", s.welcomeCTA),
            ("namePrompt", s.namePrompt),
            ("nameSkip", s.nameSkip),
            ("nameCTA", s.nameCTA),
            ("interestPrompt", s.interestPrompt),
            ("interestCTA", s.interestCTA),
            ("permissionTitle", s.permissionTitle),
            ("permissionBody", s.permissionBody),
            ("permissionAllow", s.permissionAllow),
            ("permissionNotNow", s.permissionNotNow),
            ("yokaiIntroConceptTitle", s.yokaiIntroConceptTitle),
            ("yokaiIntroConceptBody", s.yokaiIntroConceptBody),
            ("yokaiIntroTodayTitle", s.yokaiIntroTodayTitle),
            ("yokaiIntroTodayBody", s.yokaiIntroTodayBody),
            ("yokaiIntroSessionTitle", s.yokaiIntroSessionTitle),
            ("yokaiIntroSessionBody", s.yokaiIntroSessionBody),
            ("yokaiIntroSessionStep1", s.yokaiIntroSessionStep1),
            ("yokaiIntroSessionStep2", s.yokaiIntroSessionStep2),
            ("yokaiIntroSessionStep3", s.yokaiIntroSessionStep3),
            ("yokaiIntroProgressTitle", s.yokaiIntroProgressTitle),
            ("yokaiIntroProgressBody", s.yokaiIntroProgressBody),
            ("yokaiIntroNext", s.yokaiIntroNext),
            ("yokaiIntroBegin", s.yokaiIntroBegin),
            ("yokaiIntroClose", s.yokaiIntroClose),
            ("homeTodayQuest", s.homeTodayQuest),
            ("homeStart", s.homeStart),
            ("homeRecapLink", s.homeRecapLink),
            ("voiceGateTitle", s.voiceGateTitle),
            ("voiceGateBody", s.voiceGateBody),
            ("voiceGateOpenSettings", s.voiceGateOpenSettings),
            ("voiceGateRecheck", s.voiceGateRecheck),
            ("voiceGateInstalledVoicesTitle", s.voiceGateInstalledVoicesTitle),
            ("voiceGateNoVoicesPlaceholder", s.voiceGateNoVoicesPlaceholder),
            ("sessionCloseTitle", s.sessionCloseTitle),
            ("sessionCloseMessage", s.sessionCloseMessage),
            ("sessionCloseKeepGoing", s.sessionCloseKeepGoing),
            ("sessionCloseEnd", s.sessionCloseEnd),
            ("warmupListenAgain", s.warmupListenAgain),
            ("newRuleGotIt", s.newRuleGotIt),
            ("newRuleListenAgain", s.newRuleListenAgain),
            ("decodingLongPressHint", s.decodingLongPressHint),
            ("decodingBuildPrompt", s.decodingBuildPrompt),
            ("decodingListenAgain", s.decodingListenAgain),
            ("tileTutorialSlotTitle", s.tileTutorialSlotTitle),
            ("tileTutorialSlotBody", s.tileTutorialSlotBody),
            ("tileTutorialAudioTitle", s.tileTutorialAudioTitle),
            ("tileTutorialAudioBody", s.tileTutorialAudioBody),
            ("tileTutorialNext", s.tileTutorialNext),
            ("tileTutorialTry", s.tileTutorialTry),
            ("decodingHelpLabel", s.decodingHelpLabel),
            ("sentencesLongPressHint", s.sentencesLongPressHint),
            ("feedbackCorrect", s.feedbackCorrect),
            ("feedbackTryAgain", s.feedbackTryAgain),
            ("micIdlePrompt", s.micIdlePrompt),
            ("micListening", s.micListening),
            ("micAssessing", s.micAssessing),
            ("micDeniedBanner", s.micDeniedBanner),
            ("completionTitle", s.completionTitle),
            ("completionComeBack", s.completionComeBack),
            ("a11yCloseSession", s.a11yCloseSession),
            ("a11yMicButton", s.a11yMicButton),
        ]
        for (name, value) in plain {
            XCTAssertFalse(
                value.trimmingCharacters(in: .whitespaces).isEmpty,
                "\(name) is empty"
            )
        }
    }

    // MARK: - Interest categories

    func test_interestCategoryDisplayName_returnsJapaneseForSeededKeys() {
        let seeded = ["animals", "dinosaurs", "vehicles", "space", "sports", "robots"]
        let expected = ["どうぶつ", "きょうりゅう", "のりもの", "うちゅう", "スポーツ", "ロボット"]
        for (key, want) in zip(seeded, expected) {
            XCTAssertEqual(
                profile.interestCategoryDisplayName(key: key, at: .advanced),
                want
            )
        }
    }

    func test_interestCategoryDisplayName_returnsKeyForUnknown() {
        XCTAssertEqual(
            profile.interestCategoryDisplayName(key: "pokemon", at: .advanced),
            "pokemon"
        )
    }

    func testMidCoachingStringsMatchSpec() {
        let strings = profile.uiStrings(at: .advanced)
        XCTAssertEqual(strings.coachingShSubS, "くちびるをまるめて、したのおくをもちあげてみよう。「sh」。")
        XCTAssertEqual(strings.coachingShDrift, "もうすこしくちをまるくして、ながくのばしてみよう。「shhhh」。")
        XCTAssertEqual(strings.coachingRSubL, "したのさきはどこにもつけないで、おくだけすこし上に。「r」。")
        XCTAssertEqual(strings.coachingLSubR, "したのさきを上のはのうらにつけて、そのまま「l」。")
        XCTAssertEqual(strings.coachingFSubH, "上のはでしたくちびるに、かるくふれて「fff」。")
        XCTAssertEqual(strings.coachingVSubB, "上のはでしたくちびるにふれて、のどをふるわせて「vvv」。")
        XCTAssertEqual(strings.coachingThVoicelessSubS, "したのさきをはのあいだにそっと出して「thhh」。")
        XCTAssertEqual(strings.coachingThVoicelessSubT, "したのさきをはのあいだにそっと出して、とめずに「thhh」。")
        XCTAssertEqual(strings.coachingAeSubSchwa, "口をよこにひろげて、あごを下げて「æ」。")
    }

}
