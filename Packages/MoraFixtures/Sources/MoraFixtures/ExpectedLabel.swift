import Foundation

/// Label the fixture author intended to produce. Mirrors
/// `PhonemeAssessmentLabel` but is its own type — the bench compares
/// "what the author intended" against "what Engine A said" per fixture.
public enum ExpectedLabel: String, Codable, Sendable, Hashable {
    case matched
    case substitutedBy
    case driftedWithin

    /// Human-readable phrase for UI text. The raw value stays camelCase for
    /// JSON stability; this is the surface the recorder and bench show users.
    public var humanText: String {
        switch self {
        case .matched: return "matched"
        case .substitutedBy: return "substituted by"
        case .driftedWithin: return "drifted within"
        }
    }
}
