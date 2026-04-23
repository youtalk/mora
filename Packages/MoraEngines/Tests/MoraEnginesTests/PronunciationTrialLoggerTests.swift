// PronunciationTrialLoggerTests.swift
import XCTest
import SwiftData
@testable import MoraEngines
import MoraCore

@MainActor
final class PronunciationTrialLoggerTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    private func assessment(label: PhonemeAssessmentLabel, score: Int?) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: label,
            score: score,
            coachingKey: nil,
            features: ["gop": -0.5, "avgLogProb": -0.3],
            isReliable: score != nil
        )
    }

    func testCompletedResultWritesRow() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .completed(assessment(label: .matched, score: 91), latencyMs: 220)
            )
        )
        let rows = try container.mainContext.fetch(
            FetchDescriptor<PronunciationTrialLog>()
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].wordSurface, "ship")
        XCTAssertEqual(rows[0].engineAScore, 88)
        XCTAssertEqual(rows[0].engineBState, "completed")
        XCTAssertEqual(rows[0].engineBScore, 91)
        XCTAssertEqual(rows[0].engineBLatencyMs, 220)
    }

    func testTimedOutResultWritesRowWithoutScore() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .timedOut(latencyMs: 1000)
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows[0].engineBState, "timedOut")
        XCTAssertNil(rows[0].engineBLabel)
        XCTAssertNil(rows[0].engineBScore)
        XCTAssertEqual(rows[0].engineBLatencyMs, 1000)
    }

    func testUnclearEngineBLogsAsCompleted() async throws {
        // Engine B surfaces internal failures (model load error, inference
        // throw, low-confidence alignment) as `.unclear` with a diagnostic
        // features dict. The composite wraps it in `.completed(...)`.
        // This test guards that contract.
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        let unclear = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: ["gop": -5.0],
            isReliable: false
        )
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .completed(unclear, latencyMs: 250)
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows[0].engineBState, "completed")
        XCTAssertNil(rows[0].engineBScore)
        XCTAssertEqual(rows[0].engineBLatencyMs, 250)
    }

    func testUnsupportedResultOmitsEngineBFields() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .unsupported
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows[0].engineBState, "unsupported")
        XCTAssertNil(rows[0].engineBLabel)
        XCTAssertNil(rows[0].engineBScore)
        XCTAssertNil(rows[0].engineBLatencyMs)
    }

    func testEngineANilStillWritesRow() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: nil,
                engineB: .completed(assessment(label: .matched, score: 91), latencyMs: 220)
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].engineAScore, nil)
        XCTAssertEqual(rows[0].engineBState, "completed")
    }
}
