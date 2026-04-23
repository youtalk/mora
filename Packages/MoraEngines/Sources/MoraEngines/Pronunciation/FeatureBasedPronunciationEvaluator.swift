import Foundation
import MoraCore

public struct FeatureBasedPronunciationEvaluator: PronunciationEvaluator {

    /// Phonemes Engine A can score. Each maps to a primary substitution
    /// threshold in `PhonemeThresholds`; drift is additionally handled for
    /// targets listed in `driftTargets`.
    private static let supportedIPAs: Set<String> = [
        "ʃ", "r", "l", "f", "h", "v", "b", "θ", "s", "t", "æ", "ʌ",
    ]

    /// Targets for which drift (within-phoneme articulation error) is scored.
    private static let driftTargets: Set<String> = ["ʃ"]

    /// Audio-sanity thresholds.
    private static let noiseFloorDbFS: Float = -42
    private static let minDurationMs: Double = 40
    private static let maxDurationMs: Double = 600

    public init() {}

    public func supports(target: Phoneme, in word: Word) -> Bool {
        Self.supportedIPAs.contains(target.ipa)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        // Stubbed — Task 19 fills in the substitution path.
        PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: [:],
            isReliable: false
        )
    }
}
