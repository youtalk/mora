import Foundation
import MoraCore
import MoraEngines

public struct EngineARunner {

    public init() {}

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        let evaluator = FeatureBasedPronunciationEvaluator()
        let target = Phoneme(ipa: loaded.metadata.targetPhonemeIPA)

        // Prefer the full phoneme sequence + index when the sidecar provides
        // them — PhonemeRegionLocalizer needs the target's position in the
        // word to pick the right region. Fall back to `[target]` for legacy
        // sidecars and onset-only fixtures where that approximation is fine.
        let phonemes: [Phoneme]
        let targetIndex: Int
        if let seq = loaded.metadata.phonemeSequenceIPA,
            let idx = loaded.metadata.targetPhonemeIndex,
            idx >= 0, idx < seq.count
        {
            phonemes = seq.map { Phoneme(ipa: $0) }
            targetIndex = idx
        } else {
            phonemes = [target]
            targetIndex = 0
        }

        let word = Word(
            surface: loaded.metadata.wordSurface,
            graphemes: [Grapheme(letters: loaded.metadata.wordSurface)],
            phonemes: phonemes,
            targetPhoneme: phonemes[targetIndex]
        )
        let audio = AudioClip(samples: loaded.samples, sampleRate: loaded.sampleRate)
        return await evaluator.evaluate(
            audio: audio, expected: word,
            targetPhoneme: target,
            asr: ASRResult(transcript: loaded.metadata.wordSurface, confidence: 1.0)
        )
    }
}
