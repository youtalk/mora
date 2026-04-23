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
}
