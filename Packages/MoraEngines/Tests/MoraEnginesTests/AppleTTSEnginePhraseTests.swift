import MoraCore
import XCTest

@testable import MoraEngines

final class AppleTTSEnginePhraseTests: XCTestCase {
    private let profile = JapaneseL1Profile()

    func test_shPhoneme_producesShLeadWithExemplar() {
        let phrase = AppleTTSEngine.phoneticLeadPhrase(
            for: Phoneme(ipa: "ʃ"), using: profile
        )
        // JapaneseL1Profile exposes "ship" as the first /ʃ/ exemplar; if that
        // ever changes, the assertion below updates and the test stays green.
        let firstExemplar = profile.exemplars(for: Phoneme(ipa: "ʃ")).first ?? ""
        XCTAssertEqual(phrase, "sh, as in \(firstExemplar).")
    }

    func test_chPhoneme_usesChLead() {
        let phrase = AppleTTSEngine.phoneticLeadPhrase(
            for: Phoneme(ipa: "tʃ"), using: profile
        )
        XCTAssertTrue(phrase.hasPrefix("ch, as in "))
    }

    func test_thVoicelessPhoneme_usesThLead() {
        let phrase = AppleTTSEngine.phoneticLeadPhrase(
            for: Phoneme(ipa: "θ"), using: profile
        )
        XCTAssertTrue(phrase.hasPrefix("th, as in "))
    }

    func test_unmappedPhonemeWithoutExemplars_fallsBackToIpa() {
        // A phoneme with no exemplar in JapaneseL1Profile (and not in the
        // sh/ch/th special-case list) should use its IPA as the lead and the
        // "the X sound." fallback phrasing.
        let phrase = AppleTTSEngine.phoneticLeadPhrase(
            for: Phoneme(ipa: "ʒ"), using: profile
        )
        XCTAssertEqual(phrase, "the ʒ sound.")
    }

    func test_exemplarless_profile_usesFallbackPhrasing() {
        struct NoExemplarsProfile: L1Profile {
            let identifier = "none"
            let characterSystem: CharacterSystem = .alphabetic
            let interferencePairs: [PhonemeConfusionPair] = []
            let interestCategories: [InterestCategory] = []
            func uiStrings(forAgeYears years: Int) -> MoraStrings { JapaneseL1Profile().uiStrings(forAgeYears: years) }
        }
        let phrase = AppleTTSEngine.phoneticLeadPhrase(
            for: Phoneme(ipa: "ʃ"), using: NoExemplarsProfile()
        )
        XCTAssertEqual(phrase, "the sh sound.")
    }
}
