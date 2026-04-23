import Foundation
import MoraCore

public protocol PronunciationEvaluator: Sendable {
    func supports(target: Phoneme, in word: Word) -> Bool

    func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment
}
