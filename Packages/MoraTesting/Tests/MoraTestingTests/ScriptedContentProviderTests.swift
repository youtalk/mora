import XCTest
import MoraCore
import MoraEngines
@testable import MoraTesting

final class ScriptedContentProviderTests: XCTestCase {
    func test_decodeWords_returnsOnlyShTargetedWords() throws {
        let provider = try ScriptedContentProvider.bundledShWeek1()
        let request = ContentRequest(
            target: Grapheme(letters: "sh"),
            taughtGraphemes: ScriptedContentProvider.l2TaughtSet,
            interests: [],
            count: 5
        )
        let words = try provider.decodeWords(request)
        XCTAssertEqual(words.count, 5)
        XCTAssertTrue(words.allSatisfy { $0.word.graphemes.contains(Grapheme(letters: "sh")) })
    }

    func test_decodeSentences_allDecodableAndContainTargetOrVocab() throws {
        let provider = try ScriptedContentProvider.bundledShWeek1()
        let request = ContentRequest(
            target: Grapheme(letters: "sh"),
            taughtGraphemes: ScriptedContentProvider.l2TaughtSet,
            interests: [],
            count: 3
        )
        let sentences = try provider.decodeSentences(request)
        XCTAssertEqual(sentences.count, 3)
        for sentence in sentences {
            for word in sentence.words {
                XCTAssertTrue(word.isDecodable(
                    taughtGraphemes: ScriptedContentProvider.l2TaughtSet,
                    target: Grapheme(letters: "sh")
                ), "Undecodable word in sentence: \(sentence.text) — \(word.surface)")
            }
        }
    }
}
