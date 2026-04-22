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
}
