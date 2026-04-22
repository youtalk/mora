import XCTest
import MoraCore
import MoraEngines
import MoraTesting

final class FakePronunciationEvaluatorTests: XCTestCase {
    func testFakeReturnsScriptedResponseForSupportedTarget() async {
        let fake = FakePronunciationEvaluator()
        fake.supportedTargets = ["ʃ"]
        fake.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .matched,
            score: 95,
            coachingKey: nil,
            features: [:],
            isReliable: true
        )
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")]
        )
        XCTAssertTrue(fake.supports(target: Phoneme(ipa: "ʃ"), in: word))
        let result = await fake.evaluate(
            audio: .empty,
            expected: word,
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        XCTAssertEqual(result.label, .matched)
        XCTAssertEqual(result.score, 95)
    }

    func testFakeReturnsUnclearForUnconfiguredTarget() async {
        let fake = FakePronunciationEvaluator()
        let word = Word(
            surface: "cat",
            graphemes: [Grapheme(letters: "c"), Grapheme(letters: "a"), Grapheme(letters: "t")],
            phonemes: [Phoneme(ipa: "k"), Phoneme(ipa: "æ"), Phoneme(ipa: "t")]
        )
        XCTAssertFalse(fake.supports(target: Phoneme(ipa: "k"), in: word))
        let result = await fake.evaluate(
            audio: .empty,
            expected: word,
            targetPhoneme: Phoneme(ipa: "k"),
            asr: ASRResult(transcript: "cat", confidence: 0.9)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
    }
}
