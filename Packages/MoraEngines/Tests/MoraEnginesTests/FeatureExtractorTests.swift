import XCTest

@testable import MoraEngines

final class FeatureExtractorTests: XCTestCase {
    func testSpectralCentroidOfSingleSineMatchesFrequency() {
        let clip = SyntheticAudio.sineMix(frequencies: [3_000], durationMs: 200)
        let hz = FeatureExtractor.spectralCentroid(clip: clip)
        XCTAssertEqual(hz, 3_000, accuracy: 250)  // ±8%
    }

    func testSpectralCentroidOfTwoSinesIsNearMean() {
        let clip = SyntheticAudio.sineMix(frequencies: [2_000, 4_000], durationMs: 200)
        let hz = FeatureExtractor.spectralCentroid(clip: clip)
        XCTAssertEqual(hz, 3_000, accuracy: 300)
    }

    func testSpectralCentroidOfLowBandNoise() {
        let clip = SyntheticAudio.bandNoise(lowHz: 500, highHz: 1_500, durationMs: 200)
        let hz = FeatureExtractor.spectralCentroid(clip: clip)
        // Widened from 300: 2-pole biquad has soft rolloff, centroid lands ~1586 Hz.
        XCTAssertEqual(hz, 1_000, accuracy: 600)
    }

    func testHighLowBandEnergyRatioOfHighToneIsLarge() {
        let clip = SyntheticAudio.sineMix(frequencies: [7_000], durationMs: 200)
        let ratio = FeatureExtractor.highLowBandEnergyRatio(clip: clip, splitHz: 3_000)
        XCTAssertGreaterThan(ratio, 3.0)
    }

    func testHighLowBandEnergyRatioOfLowToneIsSmall() {
        let clip = SyntheticAudio.sineMix(frequencies: [500], durationMs: 200)
        let ratio = FeatureExtractor.highLowBandEnergyRatio(clip: clip, splitHz: 3_000)
        XCTAssertLessThan(ratio, 0.3)
    }

    func testSpectralFlatnessOfSineIsLow() {
        let clip = SyntheticAudio.sineMix(frequencies: [3_000], durationMs: 200)
        let flatness = FeatureExtractor.spectralFlatness(clip: clip)
        XCTAssertLessThan(flatness, 0.3)
    }

    func testSpectralFlatnessOfBroadNoiseIsHigher() {
        let clip = SyntheticAudio.bandNoise(lowHz: 500, highHz: 7_000, durationMs: 200)
        let flatness = FeatureExtractor.spectralFlatness(clip: clip)
        XCTAssertGreaterThan(flatness, 0.2)
    }

    func testZeroCrossingVarianceOfSteadyToneIsLow() {
        let clip = SyntheticAudio.sineMix(frequencies: [1_000], durationMs: 200)
        let variance = FeatureExtractor.zeroCrossingRateVariance(clip: clip, windowMs: 20)
        XCTAssertLessThan(variance, 0.005)
    }

    func testZeroCrossingVarianceAcrossSilenceAndToneIsHigh() {
        let mix = SyntheticAudio.concat(
            SyntheticAudio.silence(durationMs: 100),
            SyntheticAudio.sineMix(frequencies: [1_000], durationMs: 100)
        )
        let variance = FeatureExtractor.zeroCrossingRateVariance(clip: mix, windowMs: 20)
        // Half the windows are silent (ZCR≈0), half are 1 kHz sine (ZCR≈0.125);
        // analytic variance ≈ 0.0039. Threshold is set well below that.
        XCTAssertGreaterThan(variance, 0.003)
    }

    func testOnsetBurstSlopeOfAbruptToneIsSteeper() {
        // windowMs: 60 → firstHalf covers the 30 ms silence, secondHalf the onset.
        let burst = SyntheticAudio.concat(
            SyntheticAudio.silence(durationMs: 30),
            SyntheticAudio.sineMix(frequencies: [2_000], durationMs: 50)
        )
        let gradual = SyntheticAudio.sineMix(frequencies: [2_000], durationMs: 80)
        let burstSlope = FeatureExtractor.onsetBurstSlope(clip: burst, windowMs: 60)
        let gradualSlope = FeatureExtractor.onsetBurstSlope(clip: gradual, windowMs: 60)
        XCTAssertGreaterThan(burstSlope, gradualSlope)
    }

    func testVoicingOnsetTimeIsNearZeroForImmediateTone() {
        let clip = SyntheticAudio.sineMix(frequencies: [2_000], durationMs: 100)
        let vot = FeatureExtractor.voicingOnsetTime(clip: clip, threshold: 0.05)
        XCTAssertEqual(vot, 0, accuracy: 10)  // ms
    }

    func testVoicingOnsetTimeCountsLeadingSilence() {
        let clip = SyntheticAudio.concat(
            SyntheticAudio.silence(durationMs: 40),
            SyntheticAudio.sineMix(frequencies: [2_000], durationMs: 80)
        )
        let vot = FeatureExtractor.voicingOnsetTime(clip: clip, threshold: 0.05)
        XCTAssertEqual(vot, 40, accuracy: 15)
    }

    func testSpectralPeakInBandFindsSine() {
        let clip = SyntheticAudio.sineMix(
            frequencies: [1_700, 3_500], gains: [0.5, 0.5], durationMs: 200)
        let peakLow = FeatureExtractor.spectralPeakInBand(clip: clip, lowHz: 1_000, highHz: 2_500)
        let peakHigh = FeatureExtractor.spectralPeakInBand(clip: clip, lowHz: 2_500, highHz: 5_000)
        XCTAssertEqual(peakLow, 1_700, accuracy: 250)
        XCTAssertEqual(peakHigh, 3_500, accuracy: 350)
    }

    func testRelativeVOTNegativeForVoicedFricative() {
        // Voiced fricative: voicing throughout, no burst → VOT should be
        // strongly negative (voicing precedes any "burst-like" event by a lot,
        // or the extractor reports the burst as never-found and falls back to
        // a sentinel negative value that lands well below the v/b boundary).
        let clip = SyntheticAudio.voicedFricative(durationMs: 200, burstStartMs: 80)
        let vot = FeatureExtractor.voicingOnsetTimeRelative(
            clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
        )
        XCTAssertLessThan(vot, -10, "/v/-like signal should produce VOT well below the v/b boundary (-5)")
    }

    func testRelativeVOTSmallPositiveForVoicedStop() {
        // Voiced stop: pre-burst voicing → silence → burst at 90 ms → vowel
        // at 95 ms. Burst at 90 ms; voicing resumes at 95 ms → VOT ≈ +5 ms.
        let clip = SyntheticAudio.voicedStop(durationMs: 200, burstStartMs: 90, vowelStartMs: 95)
        let vot = FeatureExtractor.voicingOnsetTimeRelative(
            clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
        )
        XCTAssertGreaterThan(vot, 0)
        XCTAssertLessThan(vot, 30, "/b/-like signal should produce small positive VOT")
    }

    func testRelativeVOTBoundsForVoicelessStop() {
        // Voiceless stop: silence → burst at 50 ms → vowel at 100 ms (50 ms
        // aspiration gap). VOT should be ~50 ms — comfortably positive.
        let clip = SyntheticAudio.voicedStop(
            durationMs: 200, burstStartMs: 50, vowelStartMs: 100
        )
        let vot = FeatureExtractor.voicingOnsetTimeRelative(
            clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
        )
        XCTAssertGreaterThan(vot, 30)
    }

    func testF1SuppressesPitchHarmonic() {
        // 100 ms clip with a strong 220 Hz pitch (3rd harmonic at 660 Hz),
        // a true F1 at 800 Hz with lower amplitude. Without suppression the
        // 660 Hz harmonic wins; with suppression the 800 Hz peak should be
        // selected. The search band starts at 500 Hz to exclude the 220 Hz
        // fundamental itself from the comparison window.
        let clip = SyntheticAudio.sineMix(
            frequencies: [220, 660, 800],
            gains: [1.0, 1.0, 0.6],
            durationMs: 100
        )

        let withoutSuppress = FeatureExtractor.spectralPeakInBand(
            clip: clip, lowHz: 500, highHz: 1_000
        )
        XCTAssertEqual(withoutSuppress, 660, accuracy: 80, "harmonic dominates without suppression")

        let withSuppress = FeatureExtractor.spectralPeakInBand(
            clip: clip, lowHz: 500, highHz: 1_000, suppressPitchHarmonics: true
        )
        XCTAssertEqual(withSuppress, 800, accuracy: 80, "true F1 selected with suppression")
    }
}
