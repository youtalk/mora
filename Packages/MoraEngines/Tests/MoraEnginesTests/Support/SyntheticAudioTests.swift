import XCTest

@testable import MoraEngines

final class SyntheticAudioTests: XCTestCase {
    func testSineMixHasExpectedLength() {
        let clip = SyntheticAudio.sineMix(frequencies: [1_000], durationMs: 200)
        XCTAssertEqual(clip.samples.count, 3_200)  // 0.2 s * 16 kHz
        XCTAssertEqual(clip.sampleRate, 16_000)
    }

    func testBandNoiseProducesNonzeroOutput() {
        let clip = SyntheticAudio.bandNoise(lowHz: 2_000, highHz: 4_000, durationMs: 200)
        let rms = sqrt(clip.samples.reduce(0) { $0 + $1 * $1 } / Float(clip.samples.count))
        XCTAssertGreaterThan(rms, 0.01)
    }
}
