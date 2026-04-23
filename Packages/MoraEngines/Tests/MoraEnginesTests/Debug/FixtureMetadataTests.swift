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

    func testRoundTripsPhonemeSequenceAndIndex() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            sampleRate: 16_000,
            durationSeconds: 0.6,
            speakerTag: .adult,
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded.phonemeSequenceIPA, ["k", "æ", "t"])
        XCTAssertEqual(decoded.targetPhonemeIndex, 1)
    }

    func testDecodesLegacyPayloadWithoutPhonemeSequence() throws {
        // Sidecar files recorded before B1 won't have the new fields;
        // decode must still succeed with nil defaults so old fixtures load.
        let legacy = #"""
            {
                "capturedAt" : "2026-04-22T10:00:00Z",
                "targetPhonemeIPA" : "r",
                "expectedLabel" : "matched",
                "wordSurface" : "right",
                "sampleRate" : 16000,
                "durationSeconds" : 0.5,
                "speakerTag" : "adult"
            }
            """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: legacy)
        XCTAssertNil(decoded.phonemeSequenceIPA)
        XCTAssertNil(decoded.targetPhonemeIndex)
    }
}
#endif
