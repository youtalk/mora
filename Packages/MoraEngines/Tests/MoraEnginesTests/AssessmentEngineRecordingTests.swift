import MoraCore
import XCTest

@testable import MoraEngines

final class AssessmentEngineRecordingTests: XCTestCase {

    func testRecordingPathUsesEvaluatorWhenTargetPhonemeIsSupported() async {
        let fake = ScriptedPronunciationEvaluator()
        fake.supportedTargets = ["ʃ"]
        fake.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .substitutedBy(Phoneme(ipa: "s")),
            score: 25,
            coachingKey: "coaching.sh_sub_s",
            features: ["spectralCentroidHz": 6200],
            isReliable: true
        )
        let engine = AssessmentEngine(
            l1Profile: JapaneseL1Profile(),
            evaluator: fake,
            leniency: 0.5
        )
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
        let recording = TrialRecording(
            asr: ASRResult(transcript: "sip", confidence: 0.85),
            audio: AudioClip(samples: Array(repeating: Float(0.1), count: 8_000), sampleRate: 16_000)
        )
        let trial = await engine.assess(
            expected: word,
            recording: recording,
            leniency: .newWord
        )
        XCTAssertEqual(trial.phoneme?.label, .substitutedBy(Phoneme(ipa: "s")))
        XCTAssertEqual(trial.phoneme?.score, 25)
    }

    func testRecordingPathFallsBackToTranscriptWhenTargetUnsupported() async {
        let fake = ScriptedPronunciationEvaluator()
        // No target configured, supports returns false.
        let engine = AssessmentEngine(
            l1Profile: JapaneseL1Profile(),
            evaluator: fake,
            leniency: 0.5
        )
        let word = Word(
            surface: "cat",
            graphemes: [Grapheme(letters: "c"), Grapheme(letters: "a"), Grapheme(letters: "t")],
            phonemes: [Phoneme(ipa: "k"), Phoneme(ipa: "æ"), Phoneme(ipa: "t")],
            targetPhoneme: Phoneme(ipa: "k")
        )
        let recording = TrialRecording(
            asr: ASRResult(transcript: "cat", confidence: 0.9),
            audio: .empty
        )
        let trial = await engine.assess(
            expected: word,
            recording: recording,
            leniency: .newWord
        )
        XCTAssertTrue(trial.correct)
        XCTAssertNil(trial.phoneme)
    }

    func testRecordingPathFallsBackWhenTargetPhonemeIsNil() async {
        let fake = ScriptedPronunciationEvaluator()
        let engine = AssessmentEngine(
            l1Profile: JapaneseL1Profile(),
            evaluator: fake,
            leniency: 0.5
        )
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: nil
        )
        let trial = await engine.assess(
            expected: word,
            recording: TrialRecording(asr: ASRResult(transcript: "ship", confidence: 0.9), audio: .empty),
            leniency: .newWord
        )
        XCTAssertNil(trial.phoneme)
    }
}
