import XCTest

@testable import MoraEngines

final class PronunciationTypesTests: XCTestCase {
    func testAudioClipRoundTripsThroughCodable() throws {
        let clip = AudioClip(samples: [0.1, -0.2, 0.3], sampleRate: 16_000)
        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(AudioClip.self, from: data)
        XCTAssertEqual(decoded, clip)
    }

    func testAudioClipDurationSeconds() {
        let clip = AudioClip(samples: Array(repeating: 0, count: 16_000), sampleRate: 16_000)
        XCTAssertEqual(clip.durationSeconds, 1.0, accuracy: 0.001)
    }
}
