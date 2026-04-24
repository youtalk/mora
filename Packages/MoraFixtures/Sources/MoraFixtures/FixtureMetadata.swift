import Foundation

/// Sidecar metadata written alongside each fixture WAV. The recorder
/// app writes this from catalog data; the bench reads it to ingest
/// fixtures.
///
/// Legacy sidecars produced before 2026-04-23 (under the in-main-app
/// DEBUG recorder) lack `phonemeSequenceIPA`, `targetPhonemeIndex`,
/// and `patternID` — those three fields decode as `nil` via
/// `decodeIfPresent`. New sidecars written by the recorder app always
/// have them populated from the `FixturePattern` that produced the
/// take.
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag
    public let phonemeSequenceIPA: [String]?
    public let targetPhonemeIndex: Int?
    public let patternID: String?

    public init(
        capturedAt: Date,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?,
        patternID: String?
    ) {
        self.capturedAt = capturedAt
        self.targetPhonemeIPA = targetPhonemeIPA
        self.expectedLabel = expectedLabel
        self.substitutePhonemeIPA = substitutePhonemeIPA
        self.wordSurface = wordSurface
        self.sampleRate = sampleRate
        self.durationSeconds = durationSeconds
        self.speakerTag = speakerTag
        self.phonemeSequenceIPA = phonemeSequenceIPA
        self.targetPhonemeIndex = targetPhonemeIndex
        self.patternID = patternID
    }

    private enum CodingKeys: String, CodingKey {
        case capturedAt
        case targetPhonemeIPA
        case expectedLabel
        case substitutePhonemeIPA
        case wordSurface
        case sampleRate
        case durationSeconds
        case speakerTag
        case phonemeSequenceIPA
        case targetPhonemeIndex
        case patternID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        capturedAt = try c.decode(Date.self, forKey: .capturedAt)
        targetPhonemeIPA = try c.decode(String.self, forKey: .targetPhonemeIPA)
        expectedLabel = try c.decode(ExpectedLabel.self, forKey: .expectedLabel)
        substitutePhonemeIPA = try c.decodeIfPresent(String.self, forKey: .substitutePhonemeIPA)
        wordSurface = try c.decode(String.self, forKey: .wordSurface)
        sampleRate = try c.decode(Double.self, forKey: .sampleRate)
        durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        speakerTag = try c.decode(SpeakerTag.self, forKey: .speakerTag)
        phonemeSequenceIPA = try c.decodeIfPresent([String].self, forKey: .phonemeSequenceIPA)
        targetPhonemeIndex = try c.decodeIfPresent(Int.self, forKey: .targetPhonemeIndex)
        patternID = try c.decodeIfPresent(String.self, forKey: .patternID)
    }
}
