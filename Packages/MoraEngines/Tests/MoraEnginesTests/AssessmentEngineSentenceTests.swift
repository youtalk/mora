import MoraCore
import XCTest

@testable import MoraEngines

/// Coverage for the sentence-level assessment path the orchestrator uses
/// when grading a learner's full read-aloud of a `DecodeSentence`. The
/// per-word `assess(...)` API is unchanged; this file only exercises the
/// new token-coverage path that compares the entire ASR transcript to the
/// entire expected sentence.
final class AssessmentEngineSentenceTests: XCTestCase {
    private func engine() -> AssessmentEngine {
        AssessmentEngine(l1Profile: JapaneseL1Profile())
    }

    private let theShipCanHop: DecodeSentence = .init(
        text: "The ship can hop.",
        words: [
            .init(
                surface: "the",
                graphemes: [.init(letters: "t"), .init(letters: "h"), .init(letters: "e")],
                phonemes: [.init(ipa: "ð"), .init(ipa: "ə")]
            ),
            .init(
                surface: "ship",
                graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
                phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
            ),
            .init(
                surface: "can",
                graphemes: [.init(letters: "c"), .init(letters: "a"), .init(letters: "n")],
                phonemes: [.init(ipa: "k"), .init(ipa: "æ"), .init(ipa: "n")]
            ),
            .init(
                surface: "hop",
                graphemes: [.init(letters: "h"), .init(letters: "o"), .init(letters: "p")],
                phonemes: [.init(ipa: "h"), .init(ipa: "ɒ"), .init(ipa: "p")]
            ),
        ]
    )

    private func asr(_ transcript: String, confidence: Double = 0.9) -> ASRResult {
        ASRResult(transcript: transcript, confidence: confidence)
    }

    func test_exactMatch_isCorrect() {
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("The ship can hop."),
            leniency: .newWord
        )
        XCTAssertTrue(r.correct)
        XCTAssertEqual(r.matchedTokenCount, 4)
        XCTAssertEqual(r.expectedTokenCount, 4)
    }

    func test_oneSubstitutionWithinEditDistanceOne_isCorrect() {
        // "chip" is one edit from "ship"; rest matches.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the chip can hop"),
            leniency: .newWord
        )
        XCTAssertTrue(r.correct, "coverage 4/4 with edit-1 substitution should be accepted")
    }

    func test_oneMissingWord_isCorrectAtThreshold() {
        // Drop one word: 3/4 = 0.75 ≥ 0.7.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the ship hop"),
            leniency: .newWord
        )
        XCTAssertTrue(r.correct)
        XCTAssertEqual(r.matchedTokenCount, 3)
    }

    func test_twoMissingWords_isWrong() {
        // Only 2/4 = 0.5 < 0.7.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the hop"),
            leniency: .newWord
        )
        XCTAssertFalse(r.correct)
    }

    func test_lowConfidence_blocksAcceptEvenWithFullCoverage() {
        // 0.05 sits below the .newWord confidence floor (0.10). 0.10 itself
        // is the boundary and should pass — see the boundary case below.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the ship can hop", confidence: 0.05),
            leniency: .newWord
        )
        XCTAssertFalse(r.correct)
    }

    func test_confidenceAtFloor_acceptsWithFullCoverage() {
        // Apple ASR's confidence collapses to 0.0–0.1 whenever the silence
        // timeout cancels the request — but the transcript itself can still
        // cover the sentence. Anything ≥ 0.10 should clear the floor under
        // .newWord so a complete read is not rejected for that quirk alone.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the ship can hop", confidence: 0.10),
            leniency: .newWord
        )
        XCTAssertTrue(r.correct)
    }

    func test_emptyTranscript_isWrong() {
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr(""),
            leniency: .newWord
        )
        XCTAssertFalse(r.correct)
        XCTAssertEqual(r.matchedTokenCount, 0)
    }

    func test_punctuationDoesNotBlockMatch() {
        // ASR with stray punctuation per token still tokenizes cleanly.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the, ship; can. hop!"),
            leniency: .newWord
        )
        XCTAssertTrue(r.correct)
    }

    func test_extraTokensInTranscript_doNotPenalize() {
        // Learner said the sentence and added a filler — coverage still 4/4.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("um the ship can hop yeah"),
            leniency: .newWord
        )
        XCTAssertTrue(r.correct)
    }

    func test_singleTargetWordOnly_isWrongUnderSentenceScale() {
        // The UI showed a four-word sentence; saying only the target word
        // should not satisfy the sentence-level rubric. Coverage 1/4.
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("ship"),
            leniency: .newWord
        )
        XCTAssertFalse(r.correct)
    }

    func test_masteredLeniency_isStricterThanNewWord() {
        // 3/4 coverage passes .newWord but should fail .mastered (≥ 0.85).
        let r = engine().assessSentence(
            expected: theShipCanHop,
            asr: asr("the ship hop"),
            leniency: .mastered
        )
        XCTAssertFalse(r.correct)
    }

    func test_singleWordSentence_requiresExactOrEditOne() {
        let oneWord = DecodeSentence(
            text: "Ship.",
            words: [
                .init(
                    surface: "ship",
                    graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
                    phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
                )
            ]
        )
        XCTAssertTrue(
            engine().assessSentence(
                expected: oneWord, asr: asr("ship"), leniency: .newWord
            ).correct
        )
        XCTAssertTrue(
            engine().assessSentence(
                expected: oneWord, asr: asr("shi"), leniency: .newWord
            ).correct,
            "edit distance 1 should still pass for a one-word sentence"
        )
        XCTAssertFalse(
            engine().assessSentence(
                expected: oneWord, asr: asr("cat"), leniency: .newWord
            ).correct
        )
    }
}
