// Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift
import XCTest
@testable import MoraCore

final class LocaleScriptBudgetTests: XCTestCase {
    /// Iterates every (profile, level) pair and asserts every rendered
    /// string field stays within the declared script budget. Profiles
    /// that return `nil` from `allowedScriptBudget(at:)` are skipped.
    func test_all_profile_level_combinations_respect_script_budget() {
        let profiles: [any L1Profile] = [
            JapaneseL1Profile(),
            KoreanL1Profile(),
            EnglishL1Profile(),
        ]

        for profile in profiles {
            for level in LearnerLevel.allCases {
                let strings = profile.uiStrings(at: level)
                guard let budget = profile.allowedScriptBudget(at: level) else {
                    continue  // no script ladder applies
                }
                for (fieldName, value) in everyStringField(strings) {
                    for char in value {
                        XCTAssertTrue(
                            isAllowed(char, budget: budget),
                            "[\(profile.identifier) @ \(level.rawValue)] '\(fieldName)' contains '\(char)' (U+\(char.unicodeScalars.first.map { String($0.value, radix: 16, uppercase: true) } ?? "?")) outside the budget"
                        )
                    }
                }
            }
        }
    }

    private func isAllowed(_ char: Character, budget: Set<Character>) -> Bool {
        if budget.contains(char) { return true }
        for scalar in char.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x309F: continue  // Hiragana
            case 0x30A0...0x30FF: continue  // Katakana
            case 0x0030...0x0039: continue  // ASCII digits
            case 0x0041...0x005A: continue  // ASCII A-Z
            case 0x0061...0x007A: continue  // ASCII a-z
            case 0x0020, 0x000A, 0x000D: continue  // whitespace, newline, CR
            case 0x0021, 0x0022, 0x0028, 0x0029: continue  // ! " ( )
            case 0x002C, 0x002E, 0x002F: continue  // , . /
            case 0x003A, 0x003F, 0x005F: continue  // : ? _
            case 0x3001, 0x3002, 0x300C, 0x300D: continue  // 、 。 「 」
            case 0xFF01, 0xFF1F: continue  // ！ ？ (fullwidth, e.g. なんさい？ せいかい！)
            case 0x2026, 0x203A, 0x25B6: continue  // … › ▶
            case 0x1F50A: continue  // 🔊
            case 0x00E6: continue  // æ — IPA vowel in coachingAeSubSchwa
            case 0x3000: continue  // ideographic space
            default: return false
            }
        }
        return true
    }
}

/// Hand-enumerated key-path list with closure-valued fields invoked at
/// representative arguments. Memory-stable: changes to MoraStrings's field
/// list require explicit edits here, surfacing accidental field additions
/// in code review.
func everyStringField(_ s: MoraStrings) -> [(name: String, value: String)] {
    [
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
        ("homeDurationPill(16)", s.homeDurationPill(16)),
        ("homeWordsPill(5)", s.homeWordsPill(5)),
        ("homeSentencesPill(2)", s.homeSentencesPill(2)),
        ("bestiaryLinkLabel", s.bestiaryLinkLabel),
        ("bestiaryPlayGreeting", s.bestiaryPlayGreeting),
        ("bestiaryBefriendedOn", s.bestiaryBefriendedOn(Date(timeIntervalSince1970: 1_761_475_200))),
        ("homeRecapLink", s.homeRecapLink),
        // voiceGate* intentionally omitted: parent-setup copy that must mirror
        // iOS Settings labels verbatim — these strings intentionally use kanji
        // outside the child-facing script budget.
        ("sessionCloseTitle", s.sessionCloseTitle),
        ("sessionCloseMessage", s.sessionCloseMessage),
        ("sessionCloseKeepGoing", s.sessionCloseKeepGoing),
        ("sessionCloseEnd", s.sessionCloseEnd),
        ("sessionWordCounter(3,5)", s.sessionWordCounter(3, 5)),
        ("sessionSentenceCounter(1,2)", s.sessionSentenceCounter(1, 2)),
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
        ("sentencesListenAgain", s.sentencesListenAgain),
        ("feedbackCorrect", s.feedbackCorrect),
        ("feedbackTryAgain", s.feedbackTryAgain),
        ("micButtonLabel", s.micButtonLabel),
        ("micIdlePrompt", s.micIdlePrompt),
        ("micListening", s.micListening),
        ("micAssessing", s.micAssessing),
        ("micDeniedBanner", s.micDeniedBanner),
        ("coachingShSubS", s.coachingShSubS),
        ("coachingShDrift", s.coachingShDrift),
        ("coachingRSubL", s.coachingRSubL),
        ("coachingLSubR", s.coachingLSubR),
        ("coachingFSubH", s.coachingFSubH),
        ("coachingVSubB", s.coachingVSubB),
        ("coachingThVoicelessSubS", s.coachingThVoicelessSubS),
        ("coachingThVoicelessSubT", s.coachingThVoicelessSubT),
        ("coachingTSubThVoiceless", s.coachingTSubThVoiceless),
        ("coachingAeSubSchwa", s.coachingAeSubSchwa),
        ("categorySubstitutionBanner", s.categorySubstitutionBanner("sh", "s")),
        ("categoryDriftBanner", s.categoryDriftBanner("sh")),
        ("completionTitle", s.completionTitle),
        ("completionScore(6,7)", s.completionScore(6, 7)),
        ("completionComeBack", s.completionComeBack),
        ("a11yCloseSession", s.a11yCloseSession),
        ("a11yMicButton", s.a11yMicButton),
        ("a11yStreakChip(5)", s.a11yStreakChip(5)),
    ]
}
