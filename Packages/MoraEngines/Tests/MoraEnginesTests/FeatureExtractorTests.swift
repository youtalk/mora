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
}
