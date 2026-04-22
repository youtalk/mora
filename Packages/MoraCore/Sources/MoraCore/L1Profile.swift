// Packages/MoraCore/Sources/MoraCore/L1Profile.swift
import Foundation

public protocol L1Profile: Sendable {
    var identifier: String { get }
    var characterSystem: CharacterSystem { get }
    var interferencePairs: [PhonemeConfusionPair] { get }
    var interestCategories: [InterestCategory] { get }
    /// Example words that clearly demonstrate a phoneme. Returns an empty
    /// array when the phoneme is not in the curriculum. Used by TTS (for
    /// "sh, as in ship") and by UI worked-example tiles.
    func exemplars(for phoneme: Phoneme) -> [String]

    /// Pre-authored UI-chrome strings at this learner's age. Implementations
    /// may bucket ages internally; callers always pass raw years.
    /// See docs/superpowers/specs/2026-04-22-native-language-and-age-selection-design.md §5.1.
    func uiStrings(forAgeYears years: Int) -> MoraStrings

    /// Localized display name for an `InterestCategory` key. Separated from
    /// `uiStrings` so existing seed data on `LearnerProfile.interests` (which
    /// stores category keys) can be rendered at read time.
    func interestCategoryDisplayName(key: String, forAgeYears years: Int) -> String
}

extension L1Profile {
    /// Default implementation returns an empty list so existing profiles
    /// (and test stubs) keep compiling; `JapaneseL1Profile` overrides this
    /// with the curated exemplar set for the v1 curriculum.
    public func exemplars(for phoneme: Phoneme) -> [String] { [] }

    public func matchInterference(expected: Phoneme, heard: Phoneme) -> PhonemeConfusionPair? {
        guard expected != heard else { return nil }
        for pair in interferencePairs {
            if pair.from == expected && pair.to == heard { return pair }
            if pair.bidirectional && pair.from == heard && pair.to == expected {
                return pair
            }
        }
        return nil
    }

    /// Default falls back to the category key so a profile that forgets to
    /// localize a category renders at least something recognizable. Tests
    /// in `MoraStringsTests` assert `JapaneseL1Profile` overrides every
    /// seeded key.
    public func interestCategoryDisplayName(key: String, forAgeYears years: Int) -> String {
        key
    }
}
