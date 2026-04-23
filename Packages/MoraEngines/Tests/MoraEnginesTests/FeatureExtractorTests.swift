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
}
