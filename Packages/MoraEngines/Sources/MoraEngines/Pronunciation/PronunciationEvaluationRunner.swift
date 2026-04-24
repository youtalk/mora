import Foundation
import MoraCore

/// Shared entry point for Engine A evaluation. Both the Fixture Recorder
/// (in-app pre-Save verdict) and the Mac bench CLI (`EngineARunner`) route
/// through this runner so iPad and Mac produce identical assessments for
/// the same audio + pattern primitives.
public protocol PronunciationRunning: Sendable {
    func evaluate(
        samples: [Float],
        sampleRate: Double,
        wordSurface: String,
        targetPhonemeIPA: String,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?
    ) async -> PhonemeTrialAssessment
}

public struct PronunciationEvaluationRunner: PronunciationRunning {
    private let evaluator: FeatureBasedPronunciationEvaluator

    public init(evaluator: FeatureBasedPronunciationEvaluator = .init()) {
        self.evaluator = evaluator
    }

    public func evaluate(
        samples: [Float],
        sampleRate: Double,
        wordSurface: String,
        targetPhonemeIPA: String,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?
    ) async -> PhonemeTrialAssessment {
        let target = Phoneme(ipa: targetPhonemeIPA)
        let phonemes: [Phoneme]
        let targetIndex: Int
        if let seq = phonemeSequenceIPA,
            let idx = targetPhonemeIndex,
            seq.indices.contains(idx)
        {
            phonemes = seq.map { Phoneme(ipa: $0) }
            targetIndex = idx
        } else {
            phonemes = [target]
            targetIndex = 0
        }
        let word = Word(
            surface: wordSurface,
            graphemes: [Grapheme(letters: wordSurface)],
            phonemes: phonemes,
            targetPhoneme: phonemes[targetIndex]
        )
        let audio = AudioClip(samples: samples, sampleRate: sampleRate)
        return await evaluator.evaluate(
            audio: audio, expected: word,
            targetPhoneme: phonemes[targetIndex],
            asr: ASRResult(transcript: wordSurface, confidence: 1.0)
        )
    }
}
