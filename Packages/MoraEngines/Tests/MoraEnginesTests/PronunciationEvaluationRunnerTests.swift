import MoraCore
import MoraEngines
import XCTest

@MainActor
final class PronunciationEvaluationRunnerTests: XCTestCase {

    // When the full phoneme sequence + valid index is provided, the runner
    // constructs a medial-vowel Word and produces an assessment whose
    // target matches `targetPhonemeIPA`. Uses the existing synthetic audio
    // helper to generate a spectrally-clean /æ/ vowel region; F1 around
    // 700 Hz should land on the /æ/ side of the 590 Hz boundary.
    func testEvaluatesMedialVowelWithSequence() async {
        let runner = PronunciationEvaluationRunner()
        let samples = SyntheticAudio.sineMix(
            frequencies: [700, 1400], gains: [0.5, 0.3],
            durationMs: 600
        ).samples

        let assessment = await runner.evaluate(
            samples: samples,
            sampleRate: 16_000,
            wordSurface: "cat",
            targetPhonemeIPA: "æ",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1
        )

        XCTAssertEqual(assessment.targetPhoneme.ipa, "æ")
        XCTAssertEqual(assessment.label, .matched)
    }

    // Legacy-sidecar fallback: sequence absent, runner builds Word with
    // phonemes == [target] and evaluates onset-only. Output target phoneme
    // must still match the requested IPA.
    func testFallbackOnsetOnlyWhenSequenceAbsent() async {
        let runner = PronunciationEvaluationRunner()
        let samples = SyntheticAudio.sineMix(
            frequencies: [700, 1400], gains: [0.5, 0.3],
            durationMs: 300
        ).samples

        let assessment = await runner.evaluate(
            samples: samples,
            sampleRate: 16_000,
            wordSurface: "cat",
            targetPhonemeIPA: "æ",
            phonemeSequenceIPA: nil,
            targetPhonemeIndex: nil
        )

        XCTAssertEqual(assessment.targetPhoneme.ipa, "æ")
    }

    // Malformed index: sequence present but index out of range falls back
    // to onset-only, identical to the fully-absent case. Never crashes.
    func testFallbackOnOutOfRangeTargetIndex() async {
        let runner = PronunciationEvaluationRunner()
        let samples = SyntheticAudio.sineMix(
            frequencies: [700, 1400], gains: [0.5, 0.3],
            durationMs: 300
        ).samples

        let assessment = await runner.evaluate(
            samples: samples,
            sampleRate: 16_000,
            wordSurface: "cat",
            targetPhonemeIPA: "æ",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 7
        )

        XCTAssertEqual(assessment.targetPhoneme.ipa, "æ")
    }
}
