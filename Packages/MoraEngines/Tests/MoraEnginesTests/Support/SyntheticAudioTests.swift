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

    func testVoicedFricativeHasContinuousVoicingThenVowel() {
        // 200 ms total: 80 ms low-band voiced fricative + 120 ms vowel.
        // Both regions should have RMS above the noise floor; no silence gap.
        let clip = SyntheticAudio.voicedFricative(durationMs: 200, burstStartMs: 80)
        XCTAssertEqual(clip.samples.count, 3_200)  // 200 ms at 16 kHz

        // Both halves should be above noise floor (no internal silence).
        let firstHalf = clip.samples.prefix(1_600)
        let secondHalf = clip.samples.suffix(1_600)
        let rms1 = sqrt(firstHalf.reduce(0) { $0 + $1 * $1 } / Float(firstHalf.count))
        let rms2 = sqrt(secondHalf.reduce(0) { $0 + $1 * $1 } / Float(secondHalf.count))
        XCTAssertGreaterThan(rms1, 0.01)
        XCTAssertGreaterThan(rms2, 0.01)
    }

    func testVoicedStopHasSilencePauseBeforeBurst() {
        // 200 ms total. The synth lays down 80 samples (= 5 ms at 16 kHz) of
        // closure right before the burst at burstStartMs. With burstStartMs=90
        // the closure window is 85..90 ms.
        let clip = SyntheticAudio.voicedStop(durationMs: 200, burstStartMs: 90, vowelStartMs: 95)
        XCTAssertEqual(clip.samples.count, 3_200)

        // Window the silence region: samples 1_360..1_440 = 85..90 ms.
        let silenceWindow = clip.samples[1_360..<1_440]
        let rmsSilence = sqrt(silenceWindow.reduce(0) { $0 + $1 * $1 } / Float(silenceWindow.count))
        XCTAssertLessThan(rmsSilence, 0.005)
    }
}
