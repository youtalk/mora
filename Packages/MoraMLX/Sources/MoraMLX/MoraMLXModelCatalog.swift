import Foundation
import MoraEngines

/// Production entry point that wires a real `PhonemeModelPronunciationEvaluator`.
/// In Part 1 of the Engine B rollout this is a stub that always throws
/// `MoraMLXError.modelNotBundled` — the `.mlmodelc` is added in Part 2 and
/// the body is replaced then.
public enum MoraMLXModelCatalog {
    public static func loadPhonemeEvaluator(
        timeout: Duration = .milliseconds(1000)
    ) throws -> PhonemeModelPronunciationEvaluator {
        throw MoraMLXError.modelNotBundled
    }
}
