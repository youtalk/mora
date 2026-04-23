import XCTest

@testable import MoraCore

final class WordTargetPhonemeTests: XCTestCase {
    func testTargetPhonemeDefaultsToNil() {
        let w = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")]
        )
        XCTAssertNil(w.targetPhoneme)
    }

    func testTargetPhonemeSetsExplicitly() {
        let w = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
        XCTAssertEqual(w.targetPhoneme, Phoneme(ipa: "ʃ"))
    }
}
