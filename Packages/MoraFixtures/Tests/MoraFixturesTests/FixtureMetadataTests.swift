import XCTest

@testable import MoraFixtures

final class FixtureMetadataTests: XCTestCase {

    func testRoundTripsThroughCodable() throws {
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
            targetPhonemeIndex: 1,
            patternID: "aeuh-cat-correct"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testSubstitutePhonemeNilForMatchedLabel() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            sampleRate: 16_000,
            durationSeconds: 0.5,
            speakerTag: .adult,
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            patternID: "rl-right-correct"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertNil(decoded.substitutePhonemeIPA)
        XCTAssertEqual(decoded.expectedLabel, .matched)
    }

    func testDecodesLegacyPayloadWithoutTaskB1Fields() throws {
        // Sidecar JSON from before the 2026-04-23 schema extension — it
        // does not include phonemeSequenceIPA, targetPhonemeIndex, or
        // patternID. The decoder must tolerate the absence.
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
        XCTAssertEqual(decoded.targetPhonemeIPA, "r")
        XCTAssertNil(decoded.substitutePhonemeIPA)
        XCTAssertNil(decoded.phonemeSequenceIPA)
        XCTAssertNil(decoded.targetPhonemeIndex)
        XCTAssertNil(decoded.patternID)
    }
}
