import XCTest
import MoraCore
import MoraEngines
@testable import SentenceValidator

final class ValidatorTests: XCTestCase {
    private let curriculum = CurriculumEngine.defaultV1Ladder()
    private let sightWords: Set<String> = ["the", "a", "and", "is", "to", "on", "at"]

    private func shCellMap() -> PhonemeDirectoryMap {
        PhonemeDirectoryMap.lookup(directory: "sh")!
    }

    func test_validate_passesGoldenSentence() throws {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen and Sharon shop for a ship at the shed.",
            targetCount: 5,
            targetInitialContentWords: 5,
            interestWords: ["ship"],
            words: [
                .init(surface: "Shen", graphemes: ["sh", "e", "n"], phonemes: ["ʃ", "ɛ", "n"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "Sharon", graphemes: ["sh", "a", "r", "o", "n"], phonemes: ["ʃ", "æ", "r", "ə", "n"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
                .init(surface: "for", graphemes: ["f", "o", "r"], phonemes: ["f", "ɔ", "r"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "ship", graphemes: ["sh", "i", "p"], phonemes: ["ʃ", "ɪ", "p"]),
                .init(surface: "at", graphemes: ["a", "t"], phonemes: ["æ", "t"]),
                .init(surface: "the", graphemes: ["t", "h", "e"], phonemes: ["ð", "ə"]),
                .init(surface: "shed", graphemes: ["sh", "e", "d"], phonemes: ["ʃ", "ɛ", "d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertEqual(violations, [])
    }

    func test_validate_flagsUntaughtGrapheme() {
        let map = shCellMap()
        // "thin" contains the "th" digraph which is NOT in the sh-cell's
        // taught set (taught set: L2 alphabet ∪ {sh}). Word still has the
        // sh trigger via the other words but the th word is not decodable.
        let sentence = CellSentencePayload(
            text: "Shen had a thin ship and a shop and a shed.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: ["ship"],
            words: [
                .init(surface: "Shen", graphemes: ["sh", "e", "n"], phonemes: ["ʃ", "ɛ", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "thin", graphemes: ["th", "i", "n"], phonemes: ["θ", "ɪ", "n"]),
                .init(surface: "ship", graphemes: ["sh", "i", "p"], phonemes: ["ʃ", "ɪ", "p"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shed", graphemes: ["sh", "e", "d"], phonemes: ["ʃ", "ɛ", "d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(where: {
                if case .undecodableGrapheme(let word, let grapheme) = $0,
                    word == "thin", grapheme == "th"
                {
                    return true
                }
                return false
            }),
            "expected an .undecodableGrapheme violation for 'thin'/'th'; got \(violations)"
        )
    }

    func test_validate_flagsTargetCountTooLow() {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen had a shop and a hat and a hen.",
            targetCount: 2,
            targetInitialContentWords: 2,
            interestWords: ["cab"],
            words: [
                .init(surface: "Shen", graphemes: ["sh", "e", "n"], phonemes: ["ʃ", "ɛ", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "hat", graphemes: ["h", "a", "t"], phonemes: ["h", "æ", "t"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "hen", graphemes: ["h", "e", "n"], phonemes: ["h", "ɛ", "n"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(.targetCountTooLow(actual: 2, minimum: 4)),
            "expected .targetCountTooLow(2, 4); got \(violations)"
        )
    }

    func test_validate_flagsInitialContentTooLow() {
        let map = shCellMap()
        // 4 sh occurrences but only 2 are word-initial in content words —
        // "fish" and "cash" both put sh in the coda.
        let sentence = CellSentencePayload(
            text: "A ship had a fish and a cash and a shop.",
            targetCount: 4,
            targetInitialContentWords: 2,
            interestWords: ["ship"],
            words: [
                .init(surface: "A", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "ship", graphemes: ["sh", "i", "p"], phonemes: ["ʃ", "ɪ", "p"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "fish", graphemes: ["f", "i", "sh"], phonemes: ["f", "ɪ", "ʃ"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "cash", graphemes: ["c", "a", "sh"], phonemes: ["k", "æ", "ʃ"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(.targetInitialContentWordsTooLow(actual: 2, minimum: 3)),
            "expected .targetInitialContentWordsTooLow(2, 3); got \(violations)"
        )
    }

    func test_validate_flagsEmptyInterestWords() {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen had a shop and Sharon had a shed.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: [],  // empty — should fire
            words: [
                .init(surface: "Shen", graphemes: ["sh", "e", "n"], phonemes: ["ʃ", "ɛ", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "Sharon", graphemes: ["sh", "a", "r", "o", "n"], phonemes: ["ʃ", "æ", "r", "ə", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shed", graphemes: ["sh", "e", "d"], phonemes: ["ʃ", "ɛ", "d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(violations.contains(.interestWordsEmpty), "got \(violations)")
    }

    func test_validate_flagsInterestWordNotInSentence() {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen had a shop and Sharon had a shed.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: ["van"],  // van is not in the sentence
            words: [
                .init(surface: "Shen", graphemes: ["sh", "e", "n"], phonemes: ["ʃ", "ɛ", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
                .init(surface: "and", graphemes: ["a", "n", "d"], phonemes: ["æ", "n", "d"]),
                .init(surface: "Sharon", graphemes: ["sh", "a", "r", "o", "n"], phonemes: ["ʃ", "æ", "r", "ə", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "shed", graphemes: ["sh", "e", "d"], phonemes: ["ʃ", "ɛ", "d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(violations.contains(.interestWordNotInSentence(interestWord: "van")), "got \(violations)")
    }

    func test_validate_flagsLengthOutOfRange() {
        let map = shCellMap()
        // 5 words — under the 6-word minimum.
        let sentence = CellSentencePayload(
            text: "Shen had a ship shop.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: ["ship"],
            words: [
                .init(surface: "Shen", graphemes: ["sh", "e", "n"], phonemes: ["ʃ", "ɛ", "n"]),
                .init(surface: "had", graphemes: ["h", "a", "d"], phonemes: ["h", "æ", "d"]),
                .init(surface: "a", graphemes: ["a"], phonemes: ["ə"]),
                .init(surface: "ship", graphemes: ["sh", "i", "p"], phonemes: ["ʃ", "ɪ", "p"]),
                .init(surface: "shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(.lengthOutOfRange(actual: 5, minimum: 6, maximum: 10)),
            "got \(violations)"
        )
    }
}
