import Foundation

/// One entry in `FixtureCatalog.v1Patterns`. Owns every metadata field
/// the recorder would otherwise have asked the user for — target phoneme,
/// expected label, substitute phoneme, word, phoneme sequence, target
/// index, output subdirectory, and filename stem. The recorder writes
/// a WAV + sidecar JSON per take; filename is
/// `<filenameStem>-take<N>.wav` under `<speaker>/<outputSubdirectory>/`.
public struct FixturePattern: Sendable, Hashable, Identifiable {
    public let id: String
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let phonemeSequenceIPA: [String]
    public let targetPhonemeIndex: Int
    public let outputSubdirectory: String
    public let filenameStem: String

    public init(
        id: String,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        phonemeSequenceIPA: [String],
        targetPhonemeIndex: Int,
        outputSubdirectory: String,
        filenameStem: String
    ) {
        self.id = id
        self.targetPhonemeIPA = targetPhonemeIPA
        self.expectedLabel = expectedLabel
        self.substitutePhonemeIPA = substitutePhonemeIPA
        self.wordSurface = wordSurface
        self.phonemeSequenceIPA = phonemeSequenceIPA
        self.targetPhonemeIndex = targetPhonemeIndex
        self.outputSubdirectory = outputSubdirectory
        self.filenameStem = filenameStem
    }

    /// Human-readable label the catalog list row displays. Format:
    /// "<word> — /<target>/ <expectedLabel>[ by /<substitute>/]".
    public var displayLabel: String {
        let base = "\(wordSurface) — /\(targetPhonemeIPA)/ \(expectedLabel.rawValue)"
        if let sub = substitutePhonemeIPA {
            return "\(base) by /\(sub)/"
        }
        return base
    }

    /// Builds `FixtureMetadata` for a new take. Fields derived from this
    /// pattern (target, expected, substitute, word, sequence, index,
    /// patternID) are taken from self; runtime fields are supplied by
    /// the recorder.
    public func metadata(
        capturedAt: Date,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag
    ) -> FixtureMetadata {
        FixtureMetadata(
            capturedAt: capturedAt,
            targetPhonemeIPA: targetPhonemeIPA,
            expectedLabel: expectedLabel,
            substitutePhonemeIPA: substitutePhonemeIPA,
            wordSurface: wordSurface,
            sampleRate: sampleRate,
            durationSeconds: durationSeconds,
            speakerTag: speakerTag,
            phonemeSequenceIPA: phonemeSequenceIPA,
            targetPhonemeIndex: targetPhonemeIndex,
            patternID: id
        )
    }
}
