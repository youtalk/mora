import Foundation

/// Coarse age bucket used by `SentenceLibrary` (and any future content
/// selector) to vary vocabulary breadth and sentence length without
/// over-fitting to a single year-of-age.
///
/// Boundaries reflect spec § 6.1: `early` 4–7, `mid` 8–10, `late` 11+.
public enum AgeBand: String, Sendable, CaseIterable, Codable {
    case early
    case mid
    case late

    public static func from(years: Int) -> AgeBand {
        switch years {
        case ..<8: .early
        case 8...10: .mid
        default: .late
        }
    }
}
