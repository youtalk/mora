#if DEBUG
import Foundation

/// Label the fixture author intended to produce. Mirrors
/// `PhonemeAssessmentLabel` but is its own type — the bench compares
/// "what Yutaka intended" against "what Engine A said" per fixture.
public enum ExpectedLabel: String, Codable, Sendable, Hashable {
    case matched
    case substitutedBy
    case driftedWithin
}

/// Who produced the fixture. Adult fixtures are committed as regression
/// test input; child fixtures stay on Yutaka's laptop (see spec §9.3).
public enum SpeakerTag: String, Codable, Sendable, Hashable {
    case adult
    case child
}

/// Sidecar metadata written alongside each fixture WAV. Bench tools read
/// this file to know what the fixture represents; regression tests on the
/// committed adult fixtures read labels from filename instead and do not
/// rely on sidecar JSON being present.
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag
    /// Full phoneme sequence for the word, in the same order as
    /// `Word.phonemes`. `nil` on legacy sidecar files recorded before
    /// 2026-04-23 — callers must fall back to `phonemes: [target]`.
    public let phonemeSequenceIPA: [String]?
    /// Index of the target phoneme within `phonemeSequenceIPA`. `nil`
    /// on legacy sidecar files; must be in-bounds when non-nil.
    public let targetPhonemeIndex: Int?

    public init(
        capturedAt: Date,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag,
        phonemeSequenceIPA: [String]? = nil,
        targetPhonemeIndex: Int? = nil
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
    }
}
#endif
