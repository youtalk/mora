#if canImport(Speech)
import XCTest

@testable import MoraEngines

final class AppleSpeechEngineTests: XCTestCase {
    /// An unsupported locale must make the initializer throw one of the
    /// pre-on-device errors. Use XCTAssertThrowsError so a regression
    /// where the initializer silently succeeds actually fails the suite
    /// (the previous `_ = try?` form passed either way).
    func test_initializer_throwsForUnsupportedLocale() {
        XCTAssertThrowsError(
            try AppleSpeechEngine(localeIdentifier: "zz-ZZ")
        ) { error in
            guard let typed = error as? AppleSpeechEngineError else {
                XCTFail("unexpected error: \(error)")
                return
            }
            XCTAssertTrue(
                typed == .recognizerUnavailable
                    || typed == .notSupportedOnDevice,
                "unexpected AppleSpeechEngineError: \(typed)"
            )
        }
    }

    func testPCMRingBufferAppendsAndDrains() {
        let buffer = PCMRingBuffer(capacitySeconds: 2.0, sampleRate: 16_000)
        let samples = Array(repeating: Float(0.1), count: 8_000)  // 0.5 s
        buffer.append(samples)
        let clip = buffer.drain()
        XCTAssertEqual(clip.samples.count, 8_000)
        XCTAssertEqual(clip.sampleRate, 16_000, accuracy: 0.001)
    }

    func testPCMRingBufferDropsOldestWhenOverCapacity() {
        let buffer = PCMRingBuffer(capacitySeconds: 1.0, sampleRate: 16_000)
        buffer.append(Array(repeating: Float(1.0), count: 20_000))  // 1.25 s — 4000 should drop
        let clip = buffer.drain()
        XCTAssertEqual(clip.samples.count, 16_000)  // capped at 1 s
    }
}
#endif
