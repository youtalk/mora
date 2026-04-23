import Foundation

/// Label the fixture author intended to produce. Mirrors
/// `PhonemeAssessmentLabel` but is its own type — the bench compares
/// "what the author intended" against "what Engine A said" per fixture.
public enum ExpectedLabel: String, Codable, Sendable, Hashable {
    case matched
    case substitutedBy
    case driftedWithin
}
