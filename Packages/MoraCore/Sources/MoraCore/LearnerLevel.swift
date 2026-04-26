import Foundation

/// Difficulty tier consumed by every L1 profile. Each profile interprets
/// the cases according to its own pedagogy:
///
/// - `JapaneseL1Profile`:
///     - `.entry`    → hiragana only, no kanji
///     - `.core`     → hiragana + JP elementary G1 kanji (80)
///     - `.advanced` → hiragana + G1 + G2 kanji (240)
/// - `KoreanL1Profile`, `EnglishL1Profile`: every level returns the same
///   table — no script ladder applies at this age range.
///
/// Resolved from `LearnerProfile.ageYears` by `LearnerLevel.from(years:)`,
/// or read from `LearnerProfile.levelOverride` when a parental override is set.
public enum LearnerLevel: String, Sendable, Hashable, Codable, CaseIterable {
    case entry, core, advanced

    public static func from(years: Int) -> LearnerLevel {
        switch years {
        case ..<7: .entry
        case 7: .core
        default: .advanced
        }
    }
}
