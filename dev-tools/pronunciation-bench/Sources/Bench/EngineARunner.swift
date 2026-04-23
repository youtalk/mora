import Foundation
import MoraCore
import MoraEngines

public struct EngineARunner {

    public init() {}

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        let evaluator = FeatureBasedPronunciationEvaluator()
        let target = Phoneme(ipa: loaded.metadata.targetPhonemeIPA)
        let word = Word(
            surface: loaded.metadata.wordSurface,
            graphemes: [Grapheme(letters: loaded.metadata.wordSurface)],
            phonemes: [target],
            targetPhoneme: target
        )
        let audio = AudioClip(samples: loaded.samples, sampleRate: loaded.sampleRate)
        return await evaluator.evaluate(
            audio: audio, expected: word,
            targetPhoneme: target,
            asr: ASRResult(transcript: loaded.metadata.wordSurface, confidence: 1.0)
        )
    }
}
