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
/// Placeholder detection is *positive* (see `PlaceholderDetection`): the
/// test inspects the bundled `phoneme-labels.json` and only skips when
/// the labels file looks like the placeholder (≤1 entry). A real model
/// with a throwing catalog will fail the test instead of silently
/// skipping — that regression guard matters once Task 22 lands the
/// actual artifacts.
final class MoraMLXModelCatalogTests: XCTestCase {
    func testLoadPhonemeEvaluatorReturnsEvaluatorOrThrowsModelAbsent() throws {
        do {
            let evaluator = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "ʃ"), in: word()))
        } catch let error as MoraMLXError {
            try skipOrRethrowOnPlaceholder(error)
        }
    }

    func testSecondLoadIsCachedOrConsistentlyThrows() throws {
        do {
            let first = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            let second = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            XCTAssertEqual(
                first.inventory.espeakLabels.count,
                second.inventory.espeakLabels.count
            )
        } catch let error as MoraMLXError {
            try skipOrRethrowOnPlaceholder(error)
        }
    }

    /// `cachedPhonemeEvaluator()` is the non-blocking path
    /// `ShadowEvaluatorFactory` uses at session start: it must return the
    /// loaded evaluator once the blocking loader has populated the cache,
    /// so the session gets Engine B instead of falling through to the
    /// Engine-A-only path. Doesn't exercise the "before first load"
    /// nil case — the process-wide static cache is shared across tests
    /// and may already be warmed by a sibling test in the same run.
    func testCachedPhonemeEvaluatorMirrorsLoadedEvaluator() throws {
        do {
            let loaded = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            guard let cached = MoraMLXModelCatalog.cachedPhonemeEvaluator() else {
                XCTFail("cachedPhonemeEvaluator() returned nil after a successful load")
                return
            }
            XCTAssertEqual(
                cached.inventory.espeakLabels.count,
                loaded.inventory.espeakLabels.count
            )
            XCTAssertTrue(cached.supports(target: Phoneme(ipa: "ʃ"), in: word()))
        } catch let error as MoraMLXError {
            try skipOrRethrowOnPlaceholder(error)
        }
    }

    /// Skips when the bundled model is a placeholder; otherwise re-throws
    /// so the failure is visible.
    private func skipOrRethrowOnPlaceholder(_ error: MoraMLXError) throws -> Never {
        if PlaceholderDetection.isPlaceholderModelBundled() {
            throw XCTSkip(
                "placeholder model bundled — run dev-tools/model-conversion/convert.py "
                    + "to enable this test (saw \(error))"
            )
        }
        throw error
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
