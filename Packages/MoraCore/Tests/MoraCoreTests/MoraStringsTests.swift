// Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift
import XCTest
@testable import MoraCore

final class MoraStringsTests: XCTestCase {
    private let profile = JapaneseL1Profile()
    private let ageReps = [4, 7, 8, 9, 12, 15]

    // MARK: - Completeness

    func test_uiStrings_returnsMidTableForEveryRepresentativeAge() {
        let tables = ageReps.map { profile.uiStrings(forAgeYears: $0) }
        // Alpha invariant: every bucket falls back to `mid`. Compare one
        // arbitrary plain-string field across ages to prove they're the
        // same underlying table.
        let first = tables[0].homeTodayQuest
        for t in tables {
            XCTAssertEqual(t.homeTodayQuest, first)
        }
        XCTAssertEqual(first, "今日の クエスト")
    }

    func test_everyPlainStringFieldIsNonEmpty() {
        let s = profile.uiStrings(forAgeYears: 8)
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
            ("homeTodayQuest", s.homeTodayQuest),
            ("homeStart", s.homeStart),
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
                profile.interestCategoryDisplayName(key: key, forAgeYears: 8),
                want
            )
        }
    }

    func test_interestCategoryDisplayName_returnsKeyForUnknown() {
        XCTAssertEqual(
            profile.interestCategoryDisplayName(key: "pokemon", forAgeYears: 8),
            "pokemon"
        )
    }

    // MARK: - Kanji audit

    func test_stringsMid_onlyUsesGrade1And2Kanji() {
        let s = profile.uiStrings(forAgeYears: 8)
        let fields = Self.allRenderedStrings(s)
        for (name, value) in fields {
            for scalar in value.unicodeScalars {
                guard isCJKIdeograph(scalar) else { continue }
                let char = Character(scalar)
                XCTAssertTrue(
                    JPKanjiLevel.grade1And2.contains(char),
                    "\(name) contains out-of-budget kanji '\(char)' (U+\(String(scalar.value, radix: 16, uppercase: true)))"
                )
            }
        }
    }

    func test_stringsMid_onlyUsesAllowedNonKanjiCharacters() {
        let s = profile.uiStrings(forAgeYears: 8)
        let fields = Self.allRenderedStrings(s)
        for (name, value) in fields {
            for scalar in value.unicodeScalars {
                if isCJKIdeograph(scalar) {
                    continue  // kanji gate is the other test
                }
                XCTAssertTrue(
                    Self.isAllowedNonKanji(scalar),
                    "\(name) contains disallowed codepoint U+\(String(scalar.value, radix: 16, uppercase: true)) '\(scalar)'"
                )
            }
        }
    }

    func test_closureOutputs_sweptAcrossBoundaries_stayInBudget() {
        let s = profile.uiStrings(forAgeYears: 8)
        let singleArgSamples: [Int] = [0, 1, 5, 16, 60, 99, 100, 999]
        let pairSamples: [(Int, Int)] = [
            (0, 0), (0, 5), (1, 1), (3, 5), (6, 7),
            (9, 10), (99, 100), (100, 100),
        ]
        for n in singleArgSamples {
            auditString("homeDurationPill(\(n))", s.homeDurationPill(n))
            auditString("homeWordsPill(\(n))", s.homeWordsPill(n))
            auditString("homeSentencesPill(\(n))", s.homeSentencesPill(n))
            auditString("a11yStreakChip(\(n))", s.a11yStreakChip(n))
        }
        for (a, b) in pairSamples {
            auditString("sessionWordCounter(\(a),\(b))", s.sessionWordCounter(a, b))
            auditString("sessionSentenceCounter(\(a),\(b))", s.sessionSentenceCounter(a, b))
            auditString("completionScore(\(a),\(b))", s.completionScore(a, b))
        }
    }

    func testMidCoachingStringsMatchSpec() {
        let strings = profile.uiStrings(forAgeYears: 8)
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

    private func auditString(_ name: String, _ value: String) {
        for scalar in value.unicodeScalars {
            if isCJKIdeograph(scalar) {
                let char = Character(scalar)
                XCTAssertTrue(
                    JPKanjiLevel.grade1And2.contains(char),
                    "\(name) contains out-of-budget kanji '\(char)' (U+\(String(scalar.value, radix: 16, uppercase: true)))"
                )
            } else {
                XCTAssertTrue(
                    Self.isAllowedNonKanji(scalar),
                    "\(name) contains disallowed codepoint U+\(String(scalar.value, radix: 16, uppercase: true)) '\(scalar)'"
                )
            }
        }
    }

    // MARK: - Helpers

    private static func allRenderedStrings(
        _ s: MoraStrings
    ) -> [(String, String)] {
        // Representative integer arguments for each closure-producing field.
        return [
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
            ("homeTodayQuest", s.homeTodayQuest),
            ("homeStart", s.homeStart),
            ("homeDurationPill(16)", s.homeDurationPill(16)),
            ("homeWordsPill(5)", s.homeWordsPill(5)),
            ("homeSentencesPill(2)", s.homeSentencesPill(2)),
            ("bestiaryLinkLabel", s.bestiaryLinkLabel),
            ("bestiaryPlayGreeting", s.bestiaryPlayGreeting),
            (
                "bestiaryBefriendedOn(epoch)",
                s.bestiaryBefriendedOn(Date(timeIntervalSince1970: 0))
            ),
            // voiceGate* intentionally omitted: those are parent-setup
            // strings that must match iOS Settings labels verbatim
            // (English / Settings / Spoken Content) and therefore sit
            // outside the grade1-2 kanji budget enforced by the kanji /
            // non-kanji audits.
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
            ("sentencesLongPressHint", s.sentencesLongPressHint),
            ("feedbackCorrect", s.feedbackCorrect),
            ("feedbackTryAgain", s.feedbackTryAgain),
            ("micIdlePrompt", s.micIdlePrompt),
            ("micListening", s.micListening),
            ("micAssessing", s.micAssessing),
            ("micDeniedBanner", s.micDeniedBanner),
            ("completionTitle", s.completionTitle),
            ("completionScore(6,7)", s.completionScore(6, 7)),
            ("completionComeBack", s.completionComeBack),
            ("a11yCloseSession", s.a11yCloseSession),
            ("a11yMicButton", s.a11yMicButton),
            ("a11yStreakChip(5)", s.a11yStreakChip(5)),
            ("coachingShSubS", s.coachingShSubS),
            ("coachingShDrift", s.coachingShDrift),
            ("coachingRSubL", s.coachingRSubL),
            ("coachingLSubR", s.coachingLSubR),
            ("coachingFSubH", s.coachingFSubH),
            ("coachingVSubB", s.coachingVSubB),
            ("coachingThVoicelessSubS", s.coachingThVoicelessSubS),
            ("coachingThVoicelessSubT", s.coachingThVoicelessSubT),
            ("coachingAeSubSchwa", s.coachingAeSubSchwa),
        ]
    }

    private func isCJKIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF: return true  // CJK Unified Extension A
        case 0x4E00...0x9FFF: return true  // CJK Unified
        case 0x20000...0x2A6DF: return true  // Ext B
        case 0xF900...0xFAFF: return true  // Compatibility Ideographs
        default: return false
        }
    }

    /// Non-kanji characters that the alpha JP strings are allowed to use:
    /// hiragana, katakana, ASCII digits + punctuation + letters (rare,
    /// e.g. '3' in a numeral), the allowlisted Japanese punctuation marks,
    /// spaces, a small set of UI symbols (arrow / speaker / play), Japanese
    /// corner quotes used in coaching strings, ASCII lowercase letters used
    /// in phoneme exemplars (e.g. "sh", "fff"), and the IPA symbol æ.
    private static func isAllowedNonKanji(_ scalar: Unicode.Scalar) -> Bool {
        let allowedSymbols: Set<Unicode.Scalar> = [
            Unicode.Scalar(0x3000)!,  // ideographic space
            Unicode.Scalar(0x3001)!,  // 、
            Unicode.Scalar(0x3002)!,  // 。
            Unicode.Scalar(0xFF1F)!,  // ？ full-width
            Unicode.Scalar(0xFF01)!,  // ！ full-width
            Unicode.Scalar(0x2026)!,  // …
            Unicode.Scalar(0x203A)!,  // ›
            Unicode.Scalar(0x25B6)!,  // ▶
            Unicode.Scalar(0x1F50A)!,  // 🔊
            Unicode.Scalar(0x300C)!,  // 「 — coaching exemplar open bracket
            Unicode.Scalar(0x300D)!,  // 」 — coaching exemplar close bracket
            Unicode.Scalar(0x00E6)!,  // æ — IPA vowel in coachingAeSubSchwa
        ]
        switch scalar.value {
        case 0x3040...0x309F: return true  // Hiragana
        case 0x30A0...0x30FF: return true  // Katakana
        case 0x0020: return true  // ASCII space — needed between tokens
        case 0x002F: return true  // '/' — used in "\(current)/\(total)" counters
        case 0x0030...0x0039: return true  // ASCII digits 0-9 for count/score closures
        case 0x0061...0x007A: return true  // ASCII lowercase a-z — phoneme exemplars in coaching strings
        default: return allowedSymbols.contains(scalar)
        }
    }
}
