import XCTest
import MoraCore
@testable import MoraEngines

final class ContentProviderShapeTests: XCTestCase {
    func test_decodeWord_wrapsWordAndOptionalNote() {
        let word = Word(surface: "ship",
                        graphemes: [.init(letters: "sh"),
                                    .init(letters: "i"),
                                    .init(letters: "p")],
                        phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")])
        let dw = DecodeWord(word: word, note: "sh digraph at start")
        XCTAssertEqual(dw.word.surface, "ship")
        XCTAssertEqual(dw.note, "sh digraph at start")
    }

    func test_decodeSentence_carriesTextAndWordList() {
        let w1 = Word(surface: "the",
                      graphemes: [.init(letters: "t"), .init(letters: "h"), .init(letters: "e")],
                      phonemes: [.init(ipa: "ð"), .init(ipa: "ə")])
        let ds = DecodeSentence(text: "The ship.", words: [w1])
        XCTAssertEqual(ds.text, "The ship.")
        XCTAssertEqual(ds.words.count, 1)
    }
}
