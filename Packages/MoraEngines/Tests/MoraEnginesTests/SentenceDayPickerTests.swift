import XCTest
import MoraCore
@testable import MoraEngines

final class SentenceDayPickerTests: XCTestCase {
    private func word(_ s: String) -> Word {
        Word(surface: s, graphemes: [Grapheme(letters: s)], phonemes: [Phoneme(ipa: s)])
    }

    func testDayFiveReturnsFullSentence() {
        let full = DecodeSentence(
            text: "Adam and Anna had an Apollo and an axis.",
            words: ["Adam", "and", "Anna", "had", "an", "Apollo", "and", "an", "axis"].map(word)
        )
        let day1 = DecodeSentence(
            text: "Adam had an Apollo.",
            words: ["Adam", "had", "an", "Apollo"].map(word)
        )
        let result = SentenceDayPicker.pick(full: full, byDay: ["1": day1], dayInWeek: 5)
        XCTAssertEqual(result.text, full.text)
        XCTAssertEqual(result.words.count, 9)
    }

    func testDayOneReturnsAuthoredVariant() {
        let full = DecodeSentence(
            text: "Adam and Anna had an Apollo and an axis.",
            words: ["Adam", "and", "Anna", "had", "an", "Apollo", "and", "an", "axis"].map(word)
        )
        let day1 = DecodeSentence(
            text: "Adam had an Apollo.",
            words: ["Adam", "had", "an", "Apollo"].map(word)
        )
        let result = SentenceDayPicker.pick(full: full, byDay: ["1": day1], dayInWeek: 1)
        XCTAssertEqual(result.text, "Adam had an Apollo.")
        XCTAssertEqual(result.words.count, 4)
    }

    func testMissingVariantFallsThroughToFull() {
        let full = DecodeSentence(
            text: "Anna sat in an Apollo.",
            words: ["Anna", "sat", "in", "an", "Apollo"].map(word)
        )
        let result = SentenceDayPicker.pick(full: full, byDay: nil, dayInWeek: 1)
        XCTAssertEqual(result.text, full.text)

        let result2 = SentenceDayPicker.pick(full: full, byDay: ["2": full], dayInWeek: 1)
        XCTAssertEqual(result2.text, full.text, "Day 1 missing — should fall through to full")
    }
}
