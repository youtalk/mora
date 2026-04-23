// InMemoryPronunciationTrialLoggerTests.swift
import XCTest
@testable import MoraTesting
import MoraEngines
import MoraCore

final class InMemoryPronunciationTrialLoggerTests: XCTestCase {
    func testRecordAppendsEntries() async {
        let logger = InMemoryPronunciationTrialLogger()
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")]
        )
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word,
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: nil,
                engineB: .unsupported
            )
        )
        let entries = await logger.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].word.surface, "ship")
    }
}
