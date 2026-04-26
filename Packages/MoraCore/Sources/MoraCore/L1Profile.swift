// Packages/MoraCore/Sources/MoraCore/L1Profile.swift
import Foundation

public protocol L1Profile: Sendable {
    var identifier: String { get }
    var characterSystem: CharacterSystem { get }
    var interferencePairs: [PhonemeConfusionPair] { get }
    var interestCategories: [InterestCategory] { get }

    /// Example words that clearly demonstrate a phoneme. Returns an empty
    /// array when the phoneme is not in the curriculum.
    func exemplars(for phoneme: Phoneme) -> [String]

    /// Pre-authored UI-chrome strings at this difficulty level.
    /// Implementations choose how to interpret the level — JP varies its
    /// kanji budget; KO and EN return a single level-invariant table.
    /// See docs/superpowers/specs/2026-04-26-i18n-and-age-difficulty-design.md §5.2.
    func uiStrings(at level: LearnerLevel) -> MoraStrings

    /// Localized display name for an `InterestCategory` key. Separated from
    /// `uiStrings` so existing seed data on `LearnerProfile.interests` (which
    /// stores category keys) can be rendered at read time.
    func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String

    /// Per-level character budget for `LocaleScriptBudgetTests`. `nil` means
    /// the profile has no script ladder — the validator skips it. JP returns
    /// kanji-budget sets; KO and EN return `nil`.
    func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>?
}

extension L1Profile {
    /// Default: empty exemplars. JP overrides.
    public func exemplars(for phoneme: Phoneme) -> [String] { [] }

    /// Default: no script ladder. JP overrides; KO / EN inherit nil.
    public func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>? { nil }

    /// Default: return the key itself. Profiles localize per their own table.
    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
        key
    }

    public func matchInterference(expected: Phoneme, heard: Phoneme) -> PhonemeConfusionPair? {
        guard expected != heard else { return nil }
        for pair in interferencePairs where pair.from != pair.to {
            if pair.from == expected && pair.to == heard { return pair }
            if pair.bidirectional && pair.from == heard && pair.to == expected {
                return pair
            }
        }
        return nil
    }
}
