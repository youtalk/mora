import Foundation

/// Maps IPA characters to ASCII filename components.
/// Unmapped characters pass through unchanged.
public enum FilenameSlug {
    public static func ascii(ipa: String) -> String {
        switch ipa {
        case "ʃ": return "sh"
        case "θ": return "th"
        case "æ": return "ae"
        case "ʌ": return "uh"
        case "ɪ": return "ih"
        case "ɛ": return "eh"
        case "ɔ": return "aw"
        case "ɑ": return "ah"
        case "ɜ": return "er"
        case "ɚ": return "er"
        case "ŋ": return "ng"
        case "ʒ": return "zh"
        default: return ipa
        }
    }
}
