// SessionOrchestratorShadowLoggingTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraTesting
import MoraCore

@MainActor
final class SessionOrchestratorShadowLoggingTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    func testSingleTrialProducesOneLogRow() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .matched, score: 88, coachingKey: nil,
            features: [:], isReliable: true
        )
        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .matched, score: 91, coachingKey: nil,
            features: [:], isReliable: true
        )
        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary, shadow: shadow,
            logger: logger, timeout: .milliseconds(500)
        )
        let engine = AssessmentEngine(
            l1Profile: JapaneseL1Profile(),
            evaluator: composite
        )
        let recording = TrialRecording(
            asr: ASRResult(transcript: "ship", confidence: 0.95),
            audio: AudioClip(samples: [0.1], sampleRate: 16_000)
        )
        let assessment = await engine.assess(
            expected: word(), recording: recording, leniency: .newWord
        )
        XCTAssertEqual(assessment.phoneme?.score, 88)

        // Wait for the detached shadow task to finish writing.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            let entries = await logger.entries
            if !entries.isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let entries = await logger.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].word.surface, "ship")
    }
}
