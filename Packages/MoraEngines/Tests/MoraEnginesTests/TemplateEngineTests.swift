import XCTest
import MoraCore
@testable import MoraEngines

final class TemplateEngineTests: XCTestCase {
    private func word(_ surface: String, graphemes: [String], phonemes: [String]) -> Word {
        Word(surface: surface,
             graphemes: graphemes.map { Grapheme(letters: $0) },
             phonemes: phonemes.map { Phoneme(ipa: $0) })
    }

    private lazy var vocab: [VocabularyItem] = [
        // "ship" uses sh, i, p — requires sh as target for decodability
        VocabularyItem(word: word("ship", graphemes: ["sh","i","p"],
                                  phonemes: ["ʃ","ɪ","p"]),
                       slotKinds: [.subject, .noun]),
        // "cat" uses c, a, t — fully taught L2
        VocabularyItem(word: word("cat", graphemes: ["c","a","t"],
                                  phonemes: ["k","æ","t"]),
                       slotKinds: [.subject, .noun]),
        // "hop" uses h, o, p — fully taught L2
        VocabularyItem(word: word("hop", graphemes: ["h","o","p"],
                                  phonemes: ["h","ɒ","p"]),
                       slotKinds: [.verb]),
        // "run" uses r, u, n — not taught here; should get filtered out
        VocabularyItem(word: word("run", graphemes: ["r","u","n"],
                                  phonemes: ["r","ʌ","n"]),
                       slotKinds: [.verb]),
    ]

    private let taughtL2: Set<Grapheme> = [
        .init(letters: "a"), .init(letters: "c"), .init(letters: "h"),
        .init(letters: "i"), .init(letters: "o"), .init(letters: "p"),
        .init(letters: "t"),
    ]

    private let templates: [Template] = [
        Template(skeleton: "The {subject} can {verb}.",
                 slotKinds: ["subject": .subject, "verb": .verb])
    ]

    func test_generate_producesSentenceUsingOnlyDecodableWords() throws {
        let engine = TemplateEngine(templates: templates, vocabulary: vocab)
        var rng = SeededRNG(seed: 42)
        let result = try XCTUnwrap(engine.generateSentence(
            target: Grapheme(letters: "sh"),
            taughtGraphemes: taughtL2,
            interests: [],
            rng: &rng
        ))
        XCTAssertTrue(result.text.hasPrefix("The "))
        XCTAssertTrue(result.text.hasSuffix("."))
        for word in result.words {
            XCTAssertTrue(
                word.isDecodable(taughtGraphemes: taughtL2,
                                 target: Grapheme(letters: "sh"))
            )
        }
    }

    func test_generate_filtersOutUndecodableRunVerb() throws {
        let engine = TemplateEngine(templates: templates, vocabulary: vocab)
        var rng = SeededRNG(seed: 1)
        // Draw many sentences; "run" (uses untaught "r") must never appear.
        for _ in 0..<25 {
            let sentence = try XCTUnwrap(engine.generateSentence(
                target: Grapheme(letters: "sh"),
                taughtGraphemes: taughtL2,
                interests: [],
                rng: &rng
            ))
            XCTAssertFalse(sentence.text.contains("run"))
        }
    }

    func test_generate_returnsNilWhenNoDecodableVocab() {
        let engine = TemplateEngine(templates: templates, vocabulary: vocab)
        var rng = SeededRNG(seed: 1)
        let result = engine.generateSentence(
            target: Grapheme(letters: "sh"),
            taughtGraphemes: [], // nothing taught, no fallback verb "hop"
            interests: [],
            rng: &rng
        )
        XCTAssertNil(result)
    }
}
