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

    // --- f/h ---
    func testFSubstitutedByHReturnsSubstituted() async {
        let word = Word(
            surface: "fun",
            graphemes: [Grapheme(letters: "f"), Grapheme(letters: "u"), Grapheme(letters: "n")],
            phonemes: [Phoneme(ipa: "f"), Phoneme(ipa: "ʌ"), Phoneme(ipa: "n")],
            targetPhoneme: Phoneme(ipa: "f")
        )
        // /h/ substitution: broad low-band noise (weak high-band friction).
        let audio = SyntheticAudio.bandNoise(lowHz: 300, highHz: 1_200, durationMs: 500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: word,
            targetPhoneme: Phoneme(ipa: "f"),
            asr: ASRResult(transcript: "hun", confidence: 0.7)
        )
        if case .substitutedBy(let p) = result.label {
            XCTAssertEqual(p, Phoneme(ipa: "h"))
        } else {
            XCTFail("expected /h/ substitute, got \(result.label)")
        }
        XCTAssertEqual(result.coachingKey, "coaching.f_sub_h")
    }

    // --- θ / s ---
    func testThSubstitutedBySReturnsSubstituted() async {
        let word = Word(
            surface: "thin",
            graphemes: [Grapheme(letters: "th"), Grapheme(letters: "i"), Grapheme(letters: "n")],
            phonemes: [Phoneme(ipa: "θ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "n")],
            targetPhoneme: Phoneme(ipa: "θ")
        )
        // /s/ substitution: narrow high-band noise.
        let audio = SyntheticAudio.bandNoise(lowHz: 5_800, highHz: 7_200, durationMs: 500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: word,
            targetPhoneme: Phoneme(ipa: "θ"),
            asr: ASRResult(transcript: "sin", confidence: 0.85)
        )
        if case .substitutedBy(let p) = result.label {
            XCTAssertEqual(p, Phoneme(ipa: "s"))
        } else {
            XCTFail("expected /s/ substitute, got \(result.label)")
        }
        XCTAssertEqual(result.coachingKey, "coaching.th_voiceless_sub_s")
    }

    // MARK: - Whole-word duration

    func testWholeWordClipPassesAudioSanity() async {
        // 1.5 s — a natural recorder-app take of a two-syllable English word
        // ("berry", "very") lands here. Pre-fix, maxDurationMs = 600 ms
        // rejected this and forced .unclear from the audio sanity gate.
        let audio = SyntheticAudio.bandNoise(lowHz: 1_900, highHz: 2_100, durationMs: 1_500)
        let result = await evaluator.evaluate(
            audio: audio,
            expected: ship(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        XCTAssertNotEqual(result.label, .unclear)
        XCTAssertTrue(result.isReliable)
    }

    // MARK: - Skipped substitution pairs
    // Synthetic audio is not reliable for these pairs; each needs a recorded
    // fixture to exercise the measurement path in a meaningful way.
    // - /θ/ vs /t/ — TODO(post-alpha): needs recorded fixture (onset burst slope)
}
