// Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift
import Foundation

/// Single dispatch point from a stored `LearnerProfile.l1Identifier` to a
/// concrete `L1Profile` instance. Unknown identifiers fall back to
/// `JapaneseL1Profile` — the alpha originator. This is the only legitimate
/// place to switch on `l1Identifier`; per canonical product spec §9, no
/// other site may branch on locale.
public enum L1ProfileResolver {
    public static func profile(for identifier: String) -> any L1Profile {
        switch identifier {
        case "ja": return JapaneseL1Profile()
        // PR 2 will add cases "ko" → KoreanL1Profile(), "en" → EnglishL1Profile()
        default:   return JapaneseL1Profile()
        }
    }
}
