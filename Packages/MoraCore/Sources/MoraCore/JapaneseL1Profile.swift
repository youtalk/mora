import Foundation

public struct JapaneseL1Profile: L1Profile {
    public let identifier = "ja"
    public let characterSystem: CharacterSystem = .mixed

    public let interferencePairs: [PhonemeConfusionPair] = [
        PhonemeConfusionPair(
            tag: "r_l_swap",
            from: Phoneme(ipa: "r"), to: Phoneme(ipa: "l"),
            examples: ["right/light", "rock/lock", "grass/glass"],
            bidirectional: true
        ),
        PhonemeConfusionPair(
            tag: "f_h_sub",
            from: Phoneme(ipa: "f"), to: Phoneme(ipa: "h"),
            examples: ["fat/hat", "fair/hair"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "v_b_sub",
            from: Phoneme(ipa: "v"), to: Phoneme(ipa: "b"),
            examples: ["vat/bat", "van/ban"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "th_voiceless_s_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "s"),
            examples: ["thin/sin", "thick/sick"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "th_voiceless_t_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "t"),
            examples: ["thin/tin", "three/tree"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "ae_lax_conflate",
            from: Phoneme(ipa: "æ"), to: Phoneme(ipa: "ʌ"),
            examples: ["cat/cut", "bag/bug"],
            bidirectional: true
        ),
    ]

    public let interestCategories: [InterestCategory] = [
        InterestCategory(key: "animals", displayName: "Animals"),
        InterestCategory(key: "dinosaurs", displayName: "Dinosaurs"),
        InterestCategory(key: "vehicles", displayName: "Vehicles"),
        InterestCategory(key: "space", displayName: "Space"),
        InterestCategory(key: "sports", displayName: "Sports"),
        InterestCategory(key: "robots", displayName: "Robots"),
    ]

    public init() {}
}
