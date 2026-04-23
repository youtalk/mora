// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeInventory.swift
import Foundation

/// Maps between the wav2vec2 model's espeak IPA columns and the IPA labels
/// carried by `MoraCore.Phoneme`. Constructed at MoraMLX load time with the
/// label list from `phoneme-labels.json`; in tests, built with hand-written
/// label arrays.
public struct PhonemeInventory: Sendable, Hashable {
    public let espeakLabels: [String]
    public let supportedPhonemeIPA: Set<String>
    public let ipaToColumn: [String: Int]

    public init(espeakLabels: [String], supportedPhonemeIPA: Set<String>) {
        self.espeakLabels = espeakLabels
        self.supportedPhonemeIPA = supportedPhonemeIPA
        var map: [String: Int] = [:]
        map.reserveCapacity(espeakLabels.count)
        for (index, label) in espeakLabels.enumerated() {
            map[label] = index
        }
        self.ipaToColumn = map
    }

    /// v1.5 MVP phoneme set. Covers Engine A's 12 curated pairs plus common
    /// neighbors the curriculum is expected to exercise in the first month
    /// of TestFlight. Expanding the set is a data-only change.
    public static let v15SupportedPhonemeIPA: Set<String> = [
        "ʃ", "s", "r", "l", "f", "h", "v", "b", "θ", "t", "æ", "ʌ",
        "i", "ɪ", "e", "ɛ", "ə", "ʊ", "u", "ɑ", "ɔ",
        "p", "k", "d", "g", "m", "n", "ŋ", "j", "w",
        "z", "ʒ", "dʒ", "tʃ",
    ]
}
