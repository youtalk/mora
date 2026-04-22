import MoraCore
import XCTest

@testable import MoraEngines

final class ScriptedContentProviderTests: XCTestCase {
    func test_bundledShWeek1_exposesTargetAndTaughtGraphemesFromJSON() throws {
        let provider = try ScriptedContentProvider.bundledShWeek1()
        XCTAssertEqual(provider.target, Grapheme(letters: "sh"))
        XCTAssertEqual(provider.taughtGraphemes.count, 26)
        XCTAssertTrue(provider.taughtGraphemes.contains(Grapheme(letters: "a")))
        XCTAssertTrue(provider.taughtGraphemes.contains(Grapheme(letters: "z")))
    }

    func test_decodeWords_returnsOnlyShTargetedWords() throws {
        let provider = try ScriptedContentProvider.bundledShWeek1()
        let request = ContentRequest(
            target: provider.target,
            taughtGraphemes: provider.taughtGraphemes,
            interests: [],
            count: 5
        )
        let words = try provider.decodeWords(request)
        XCTAssertEqual(words.count, 5)
        XCTAssertTrue(words.allSatisfy { $0.word.graphemes.contains(provider.target) })
    }

    func test_decodeSentences_areDecodableAndContainTargetGrapheme() throws {
        let provider = try ScriptedContentProvider.bundledShWeek1()
        let request = ContentRequest(
            target: provider.target,
            taughtGraphemes: provider.taughtGraphemes,
            interests: [],
            count: 3
        )
        let sentences = try provider.decodeSentences(request)
        XCTAssertEqual(sentences.count, 3)
        for sentence in sentences {
            XCTAssertTrue(
                sentence.words.contains { $0.graphemes.contains(provider.target) },
                "Sentence does not contain target grapheme: \(sentence.text)"
            )
            for word in sentence.words {
                XCTAssertTrue(
                    word.isDecodable(
                        taughtGraphemes: provider.taughtGraphemes,
                        target: provider.target
                    ), "Undecodable word in sentence: \(sentence.text) — \(word.surface)")
            }
        }
    }
}
