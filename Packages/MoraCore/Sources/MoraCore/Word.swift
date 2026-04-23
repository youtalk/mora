import Foundation

public struct Word: Hashable, Codable, Sendable {
    public let surface: String
    public let graphemes: [Grapheme]
    public let phonemes: [Phoneme]
    /// Set by `CurriculumEngine` when the curriculum is rehearsing a specific
    /// phoneme within this word; the pronunciation evaluator keys its region
    /// localization and threshold lookup off this field. When nil, acoustic
    /// evaluation is skipped and the transcript-only path runs.
    public let targetPhoneme: Phoneme?

    public init(
        surface: String,
        graphemes: [Grapheme],
        phonemes: [Phoneme],
        targetPhoneme: Phoneme? = nil
    ) {
        self.surface = surface
        self.graphemes = graphemes
        self.phonemes = phonemes
        self.targetPhoneme = targetPhoneme
    }

    public func isDecodable(
        taughtGraphemes: Set<Grapheme>,
        target: Grapheme?
    ) -> Bool {
        for g in graphemes {
            if taughtGraphemes.contains(g) { continue }
            if let target, g == target { continue }
            return false
        }
        return true
    }
}
