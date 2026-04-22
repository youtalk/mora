import XCTest
@testable import MoraCore

final class PhonemeTests: XCTestCase {
    func test_phoneme_storesIPA() {
        let p = Phoneme(ipa: "ʃ")
        XCTAssertEqual(p.ipa, "ʃ")
    }

    func test_phoneme_equality_caseSensitiveIPA() {
        // IPA uses both Latin and non-Latin symbols and is case-sensitive.
        XCTAssertNotEqual(Phoneme(ipa: "S"), Phoneme(ipa: "s"))
    }

    func test_graphemePhoneme_pairsShWithShPhoneme() {
        let pair = GraphemePhoneme(
            grapheme: Grapheme(letters: "sh"),
            phoneme: Phoneme(ipa: "ʃ")
        )
        XCTAssertEqual(pair.grapheme.letters, "sh")
        XCTAssertEqual(pair.phoneme.ipa, "ʃ")
    }
}
