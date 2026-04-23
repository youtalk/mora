import Foundation
import MoraCore
import MoraEngines
import MoraFixtures

public struct EngineARunner {

    public init() {}

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        let evaluator = FeatureBasedPronunciationEvaluator()
        let target = Phoneme(ipa: loaded.metadata.targetPhonemeIPA)

        // Use the catalog-provided phoneme sequence + target index when
        // present (new sidecars, post-2026-04-23). Fall back to [target]
        // for legacy sidecars where the recorder did not yet carry the
        // sequence — PhonemeRegionLocalizer treats that as an onset-only
        // evaluation, matching the pre-Task-B1 behavior.
        let phonemes: [Phoneme]
        let targetIndex: Int
        if let seq = loaded.metadata.phonemeSequenceIPA,
           let idx = loaded.metadata.targetPhonemeIndex,
           seq.indices.contains(idx) {
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
            targetPhoneme: phonemes[targetIndex],
            asr: ASRResult(transcript: loaded.metadata.wordSurface, confidence: 1.0)
        )
    }
}
