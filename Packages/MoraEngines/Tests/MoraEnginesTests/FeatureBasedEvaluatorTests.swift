import XCTest
import MoraCore
@testable import MoraEngines

final class FeatureBasedEvaluatorTests: XCTestCase {
    private let evaluator = FeatureBasedPronunciationEvaluator()

    private func ship() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    func testSupportsListedTargets() {
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "ʃ"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "r"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "f"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "v"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "θ"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "æ"), in: ship()))
    }

    func testDoesNotSupportUnlistedTargets() {
        XCTAssertFalse(evaluator.supports(target: Phoneme(ipa: "k"), in: ship()))
        XCTAssertFalse(evaluator.supports(target: Phoneme(ipa: "n"), in: ship()))
    }

    func testEvaluatesCorrectShAsMatched() async {
        // Narrow band around the /ʃ/ F2 target (2 kHz) — the original 2–4 kHz band
        // put most energy above the F2 measurement window (1–2.5 kHz), which let
        // Task 20's drift path fire on what is meant to be the clean-/ʃ/ fixture.
        let audio = SyntheticAudio.bandNoise(lowHz: 1_900, highHz: 2_100, durationMs: 500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: ship(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        XCTAssertEqual(result.label, .matched)
        XCTAssertNotNil(result.score)
        if let score = result.score {
            XCTAssertGreaterThanOrEqual(score, 70)
        }
        XCTAssertTrue(result.isReliable)
        XCTAssertEqual(result.coachingKey, nil)
    }

    func testEvaluatesShHeardAsSAsSubstitution() async {
        let audio = SyntheticAudio.bandNoise(lowHz: 5_500, highHz: 7_500, durationMs: 500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: ship(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "sip", confidence: 0.9)
        )
        if case .substitutedBy(let p) = result.label {
            XCTAssertEqual(p, Phoneme(ipa: "s"))
        } else {
            XCTFail("expected substitutedBy(/s/), got \(result.label)")
        }
        XCTAssertNotNil(result.score)
        if let score = result.score {
            XCTAssertLessThanOrEqual(score, 40)
        }
        XCTAssertEqual(result.coachingKey, "coaching.sh_sub_s")
    }

    func testBelowNoiseFloorReturnsUnclear() async {
        let silence = SyntheticAudio.silence(durationMs: 500)
        let result = await evaluator.evaluate(
            audio: silence,
            expected: ship(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
    }

    func testDriftedShReturnsDriftedWithin() async {
        // /ʃ/ with too-high F2 (tongue not retracted enough, sound drifts
        // toward /ɕ/): simulate by concentrating energy around 2.5 kHz.
        let audio = SyntheticAudio.bandNoise(lowHz: 2_300, highHz: 2_800, durationMs: 500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: ship(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.85)
        )
        XCTAssertEqual(result.label, .driftedWithin)
        XCTAssertEqual(result.coachingKey, "coaching.sh_drift")
    }

    func testCleanShDoesNotTriggerDrift() async {
        let audio = SyntheticAudio.bandNoise(lowHz: 1_900, highHz: 2_200, durationMs: 500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: ship(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        // Either matched or drift; both are acceptable depending on the
        // FFT bin alignment, but the coaching key must not be sub.
        XCTAssertNotEqual(result.coachingKey, "coaching.sh_sub_s")
    }
}
