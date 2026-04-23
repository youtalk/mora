import Foundation

/// MoraStrings keys returned by any evaluator for a given (target, substitute)
/// or drift target. Single source of truth so both Engine A and Engine B
/// produce identical coaching output for identical diagnoses.
public enum CoachingKeyResolver {
    public static func substitution(target: String, substitute: String) -> String? {
        switch (target, substitute) {
        case ("ʃ", "s"): return "coaching.sh_sub_s"
        case ("r", "l"): return "coaching.r_sub_l"
        case ("l", "r"): return "coaching.l_sub_r"
        case ("f", "h"): return "coaching.f_sub_h"
        case ("v", "b"): return "coaching.v_sub_b"
        case ("θ", "s"): return "coaching.th_voiceless_sub_s"
        case ("θ", "t"): return "coaching.th_voiceless_sub_t"
        case ("æ", "ʌ"), ("ʌ", "æ"): return "coaching.ae_sub_schwa"
        default: return nil
        }
    }

    public static func drift(target: String) -> String? {
        switch target {
        case "ʃ": return "coaching.sh_drift"
        default: return nil
        }
    }
}
