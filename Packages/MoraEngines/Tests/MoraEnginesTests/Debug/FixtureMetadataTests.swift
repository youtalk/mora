#if DEBUG
import XCTest
@testable import MoraEngines

final class FixtureMetadataTests: XCTestCase {

    func testRoundTripsThroughCodable() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "s",
            wordSurface: "ship",
            sampleRate: 16_000,
            durationSeconds: 0.84,
            speakerTag: .adult
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testSubstitutePhonemeIsNilForMatchedLabel() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            sampleRate: 16_000,
            durationSeconds: 0.5,
            speakerTag: .adult
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(FixtureMetadata.self, from: data)
        XCTAssertNil(decoded.substitutePhonemeIPA)
        XCTAssertEqual(decoded.expectedLabel, .matched)
    }
}
#endif
