import Foundation

public enum CharacterSystem: String, Hashable, Codable, Sendable, CaseIterable {
    case alphabetic
    case logographic
    case mixed
}

/// Describes an L1-to-L2 confusion the assessment engine watches for.
///
/// Usually `from != to` and the pair represents a substitution (e.g. /ʃ/ →
/// /s/ for Japanese learners). A `from == to` entry is a reserved **drift
/// target sentinel**: the learner is producing the right phoneme category
/// but the articulation drifts away from the L2 acoustic target (e.g. /ʃ/
/// realized with insufficient lip-rounding, drifting toward /ɕ/).
///
/// `L1Profile.matchInterference(expected:heard:)` skips sentinel entries by
/// construction — they never match as substitutions. The pronunciation
/// evaluator (`FeatureBasedPronunciationEvaluator`) inspects sentinel
/// entries separately to drive drift scoring.
///
/// See `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md`
/// §6.4 for the rationale behind reusing this type rather than introducing a
/// dedicated `PhonemeAcousticTarget`.
public struct PhonemeConfusionPair: Hashable, Codable, Sendable {
    public let tag: String
    public let from: Phoneme
    public let to: Phoneme
    public let examples: [String]
    public let bidirectional: Bool

    public init(
        tag: String, from: Phoneme, to: Phoneme,
        examples: [String] = [], bidirectional: Bool = false
    ) {
        self.tag = tag
        self.from = from
        self.to = to
        self.examples = examples
        self.bidirectional = bidirectional
    }
}
