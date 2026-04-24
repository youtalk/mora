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
    private static let maxDurationMs: Double = 2_000

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

        // 1. Audio sanity — fails early to `.unclear`.
        if !isAudioUsable(audio) {
            return unreliable(targetPhoneme, label: .unclear)
        }

        // 2. Localize the phoneme region.
        guard let position = PhonemeRegionLocalizer.position(of: targetPhoneme, in: expected) else {
            return unreliable(targetPhoneme, label: .unclear)
        }
        let region = PhonemeRegionLocalizer.region(
            clip: audio,
            word: expected,
            phonemePosition: position
        )
        if region.clip.samples.isEmpty {
            return unreliable(targetPhoneme, label: .unclear)
        }

        // 3. Run the substitution check against every potential substitute.
        if let judgment = judgeSubstitution(region: region, target: targetPhoneme) {
            return judgment
        }

        // 4. Drift check for targets that support it.
        if Self.driftTargets.contains(targetPhoneme.ipa) {
            if let drift = judgeDrift(region: region, target: targetPhoneme) {
                return drift
            }
        }

        return matched(target: targetPhoneme, region: region, features: [:])
    }

    private func isAudioUsable(_ audio: AudioClip) -> Bool {
        let durationMs = audio.durationSeconds * 1000.0
        if durationMs < Self.minDurationMs || durationMs > Self.maxDurationMs { return false }
        let rms = sqrt(audio.samples.reduce(0) { $0 + $1 * $1 } / Float(max(1, audio.samples.count)))
        let db = 20 * log10(max(rms, 1e-6))
        return db >= Self.noiseFloorDbFS
    }

    private static let substituteCandidates: [String: [String]] = [
        "ʃ": ["s"],
        "r": ["l"],
        "l": ["r"],
        "f": ["h"],
        "v": ["b"],
        "θ": ["s", "t"],
        "æ": ["ʌ"],
        "ʌ": ["æ"],
    ]

    /// Evaluate every substitute candidate for `target`. Returns a
    /// `.substitutedBy(...)` assessment when a candidate's feature value
    /// lands on that candidate's side of the boundary.
    private func judgeSubstitution(
        region: LocalizedRegion,
        target: Phoneme
    ) -> PhonemeTrialAssessment? {
        guard let candidates = Self.substituteCandidates[target.ipa] else { return nil }
        for sub in candidates {
            guard let thresholds = PhonemeThresholds.primary(for: target.ipa, against: sub) else {
                continue
            }
            let measured = measure(feature: thresholds.feature, in: region.clip)
            let towardTarget = (thresholds.targetCentroid - thresholds.boundary)
            let measuredSide = measured - thresholds.boundary
            // Substitute side is the side of the boundary away from the target.
            let isSubstitute =
                (towardTarget >= 0 && measuredSide < 0)
                || (towardTarget < 0 && measuredSide > 0)
            if isSubstitute {
                let score = scoreValue(
                    measured: measured,
                    target: thresholds.targetCentroid,
                    boundary: thresholds.boundary
                )
                let features: [String: Double] = [
                    thresholds.feature.key: measured
                ]
                return PhonemeTrialAssessment(
                    targetPhoneme: target,
                    label: .substitutedBy(Phoneme(ipa: sub)),
                    score: region.isReliable ? score : nil,
                    coachingKey: coachingKey(target: target.ipa, substitute: sub),
                    features: features,
                    isReliable: region.isReliable
                )
            }
        }
        return nil
    }

    private func judgeDrift(
        region: LocalizedRegion,
        target: Phoneme
    ) -> PhonemeTrialAssessment? {
        guard let thresholds = PhonemeThresholds.drift(for: target.ipa) else { return nil }
        let measured = measure(feature: thresholds.feature, in: region.clip)
        if measured < thresholds.minReliable {
            // Feature is in a region where drift cannot be scored reliably.
            return nil
        }
        let distance = abs(measured - thresholds.targetCentroid)
        let threshold = thresholds.targetCentroid * 0.1  // 10% tolerance around center
        guard distance > threshold else { return nil }  // well inside target
        let score = max(0, min(100, 100 - Int(distance / thresholds.targetCentroid * 100)))
        let key = driftCoachingKey(target: target.ipa)
        return PhonemeTrialAssessment(
            targetPhoneme: target,
            label: .driftedWithin,
            score: region.isReliable ? score : nil,
            coachingKey: key,
            features: [thresholds.feature.key: measured],
            isReliable: region.isReliable
        )
    }

    private func driftCoachingKey(target: String) -> String? {
        CoachingKeyResolver.drift(target: target)
    }

    private func matched(
        target: Phoneme,
        region: LocalizedRegion,
        features: [String: Double]
    ) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: target,
            label: .matched,
            score: region.isReliable ? 100 : nil,
            coachingKey: nil,
            features: features,
            isReliable: region.isReliable
        )
    }

    private func unreliable(_ target: Phoneme, label: PhonemeAssessmentLabel) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: target,
            label: label,
            score: nil,
            coachingKey: nil,
            features: [:],
            isReliable: false
        )
    }

    private func measure(feature: AcousticFeature, in clip: AudioClip) -> Double {
        switch feature {
        case .spectralCentroidHz:
            return FeatureExtractor.spectralCentroid(clip: clip)
        case .highLowEnergyRatio:
            return FeatureExtractor.highLowBandEnergyRatio(clip: clip, splitHz: 3_000)
        case .zeroCrossingRateVariance:
            return FeatureExtractor.zeroCrossingRateVariance(clip: clip, windowMs: 20)
        case .voicingOnsetTimeMs:
            return FeatureExtractor.voicingOnsetTimeRelative(
                clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
            )
        case .onsetBurstSlope:
            return FeatureExtractor.onsetBurstSlope(clip: clip, windowMs: 30)
        case .spectralFlatness:
            return FeatureExtractor.spectralFlatness(clip: clip)
        case .formantF1Hz:
            let suppress = clip.durationSeconds < 0.2
            return FeatureExtractor.spectralPeakInBand(
                clip: clip, lowHz: 200, highHz: 1_000,
                suppressPitchHarmonics: suppress
            )
        case .formantF2Hz:
            let suppress = clip.durationSeconds < 0.2
            return FeatureExtractor.spectralPeakInBand(
                clip: clip, lowHz: 1_000, highHz: 2_500,
                suppressPitchHarmonics: suppress
            )
        case .formantF3Hz:
            return FeatureExtractor.spectralPeakInBand(clip: clip, lowHz: 1_500, highHz: 3_500)
        }
    }

    /// 0–100 score: linear distance from boundary toward target.
    /// Direction-independent so callers do not need to know which side
    /// of the boundary the target lives on.
    private func scoreValue(measured: Double, target: Double, boundary: Double) -> Int {
        let denom = target - boundary
        guard denom != 0 else { return 0 }
        let raw = (measured - boundary) / denom
        return max(0, min(100, Int((raw * 100).rounded())))
    }

    private func coachingKey(target: String, substitute: String) -> String? {
        CoachingKeyResolver.substitution(target: target, substitute: substitute)
    }
}
