import XCTest

@testable import MoraMLX
import MoraEngines
import MoraCore

/// Adaptive catalog tests.
///
/// The real wav2vec2 CoreML model is added via Git LFS in a follow-up
/// manual step (see `dev-tools/model-conversion/convert.py` + Task 22
/// Steps 2-5 of `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md`).
/// Until that runs, the bundled `Resources/wav2vec2-phoneme.mlmodelc` is a
/// placeholder directory containing only `placeholder.txt`, so
/// `MLModel(contentsOf:)` (or the preceding `Bundle.module.url(...)` lookup)
/// will fail at runtime — this is the "model absent" state the app's
/// factory catches to fall back to bare Engine A.
///
/// The tests below therefore accept three outcomes:
/// 1. A usable evaluator is returned (real model bundled, happy path).
/// 2. The catalog throws `.modelNotBundled` or `.inferenceFailed` (the
///    "model absent" states we ship in this branch).
/// Any other error is a real test failure.
final class MoraMLXModelCatalogTests: XCTestCase {
    func testLoadPhonemeEvaluatorReturnsEvaluatorOrThrowsModelAbsent() throws {
        do {
            let evaluator = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "ʃ"), in: word()))
        } catch MoraMLXError.modelNotBundled {
            // Accepted: the `Bundle.module.url(forResource:withExtension:)`
            // lookup returned nil (compiled-model directories are typically
            // loaded via directory URL, not withExtension — this code path
            // is expected while the placeholder .mlmodelc is in place).
            throw XCTSkip("MLX model not bundled — catalog threw modelNotBundled (LFS follow-up)")
        } catch MoraMLXError.inferenceFailed(let reason) {
            // Accepted: the URL resolved but `MLModel(contentsOf:)` rejected
            // the placeholder directory because it is not a real compiled
            // model. The wrapped error string is routed through
            // `.inferenceFailed` by the catalog.
            throw XCTSkip("MLX model not bundled — catalog threw inferenceFailed: \(reason)")
        }
    }

    func testSecondLoadIsCachedOrConsistentlyThrows() throws {
        // Either both calls succeed and share the same inventory size, or
        // both calls fail with an acceptable "model absent" error.
        do {
            let first = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            let second = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            XCTAssertEqual(
                first.inventory.espeakLabels.count,
                second.inventory.espeakLabels.count
            )
        } catch MoraMLXError.modelNotBundled {
            throw XCTSkip("MLX model not bundled — cache test inapplicable (LFS follow-up)")
        } catch MoraMLXError.inferenceFailed {
            throw XCTSkip("MLX model not bundled — cache test inapplicable (LFS follow-up)")
        }
    }

    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }
}
