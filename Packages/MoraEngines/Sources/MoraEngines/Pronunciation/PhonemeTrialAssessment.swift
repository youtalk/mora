import Foundation
import MoraCore

public enum PhonemeAssessmentLabel: Sendable, Hashable, Codable {
    case matched
    case substitutedBy(Phoneme)
    case driftedWithin
    case unclear
}

/// Per-phoneme evaluation payload carried inside `TrialAssessment.phoneme`.
/// `score` and `coachingKey` are nil when `isReliable` is false or the label
/// is `.matched`/`.unclear`. `features` is kept for offline analysis and
/// shadow-mode logging, never shown to the learner.
public struct PhonemeTrialAssessment: Sendable, Hashable, Codable {
    public let targetPhoneme: Phoneme
    public let label: PhonemeAssessmentLabel
    public let score: Int?
    public let coachingKey: String?
    public let features: [String: Double]
    public let isReliable: Bool

    public init(
        targetPhoneme: Phoneme,
        label: PhonemeAssessmentLabel,
        score: Int?,
        coachingKey: String?,
        features: [String: Double],
        isReliable: Bool
    ) {
        self.targetPhoneme = targetPhoneme
        self.label = label
        self.score = score
        self.coachingKey = coachingKey
        self.features = features
        self.isReliable = isReliable
    }
}
