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

    func test_bundledShWeek1_wordsCarryTargetPhoneme() throws {
        let provider = try ScriptedContentProvider.bundledShWeek1()
        XCTAssertFalse(provider.words.isEmpty)
        for dw in provider.words {
            XCTAssertEqual(dw.word.targetPhoneme, Phoneme(ipa: "ʃ"))
        }
        XCTAssertFalse(provider.sentences.isEmpty)
        for sentence in provider.sentences {
            for w in sentence.words {
                XCTAssertEqual(w.targetPhoneme, Phoneme(ipa: "ʃ"))
            }
        }
    }

    func test_bundledFor_returnsProviderForEveryV1SkillCode() throws {
        let codes: [SkillCode] = ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"]
        for code in codes {
            let provider = try ScriptedContentProvider.bundled(for: code)
            XCTAssertFalse(
                provider.words.isEmpty,
                "\(code.rawValue) should bundle decode words"
            )
            XCTAssertFalse(
                provider.sentences.isEmpty,
                "\(code.rawValue) should bundle sentences"
            )
        }
    }

    func test_bundledFor_unknownCode_throws() {
        XCTAssertThrowsError(try ScriptedContentProvider.bundled(for: "no_such_skill"))
    }

    func test_bundledFor_thWeek_targetPhonemeIsVoicelessTh() throws {
        let provider = try ScriptedContentProvider.bundled(for: "th_voiceless")
        XCTAssertEqual(provider.target, Grapheme(letters: "th"))
        let request = ContentRequest(
            target: provider.target,
            taughtGraphemes: provider.taughtGraphemes,
            interests: [],
            count: 10
        )
        let words = try provider.decodeWords(request)
        XCTAssertFalse(words.isEmpty)
        for w in words {
            XCTAssertTrue(
                w.word.phonemes.contains(Phoneme(ipa: "θ")),
                "\(w.word.surface) expected to contain /θ/"
            )
        }
    }
}
