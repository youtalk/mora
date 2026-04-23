import Foundation
import MoraCore

public enum ScaffoldStep: Hashable, Sendable {
    case bounceBack
    case ttsHint
    case reducePool(correct: Grapheme, distractor: Grapheme)
    case autoFill
}

/// Pure ladder: `missCount` is the number of consecutive wrong drops on one
/// slot during one trial. Returns the intervention to apply *next*.
public enum ChainScaffoldLadder {
    public static func next(
        missCount: Int,
        correct: Grapheme,
        distractor: Grapheme
    ) -> ScaffoldStep {
        switch missCount {
        case ...1: return .bounceBack
        case 2: return .ttsHint
        case 3: return .reducePool(correct: correct, distractor: distractor)
        default: return .autoFill
        }
    }
}
