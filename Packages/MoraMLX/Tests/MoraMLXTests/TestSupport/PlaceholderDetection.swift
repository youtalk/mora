// Packages/MoraMLX/Tests/MoraMLXTests/TestSupport/PlaceholderDetection.swift
import Foundation

/// Positive placeholder detection for the bundled CoreML model.
///
/// Historical guard from the pre-Release-migration Part 2 of Engine B
/// (see `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md`),
/// when the package bundled a 1-entry `["<pad>"]` `phoneme-labels.json`
/// alongside a stub `wav2vec2-phoneme.mlmodelc/` so the packaging path
/// could be exercised before the real model existed. That state no
/// longer ships on `main`: after PR #62 (`docs/superpowers/plans/2026-04-24-ci-lfs-to-releases.md`)
/// the real 392-entry `phoneme-labels.json` is committed directly, and
/// the `.mlmodelc` is hosted on the `models/wav2vec2-phoneme-int8-v1`
/// GitHub Release, fetched on demand by `tools/fetch-models.sh`.
///
/// In the current repo state `isPlaceholderModelBundled()` therefore
/// normally returns `false`. On a fresh clone where `swift test` runs
/// before `bash tools/fetch-models.sh` (or before an Xcode build that
/// triggers the Mora target's preBuildScript), the real labels file is
/// still present but the `.mlmodelc/` directory is absent, so
/// `MoraMLXModelCatalog.loadPhonemeEvaluator()` throws
/// `MoraMLXError.modelNotBundled`. Callers rethrow that (it is not a
/// placeholder case), and the resulting test FAIL is the intended
/// signal to run the bootstrap.
///
/// The check is retained so a hypothetical future placeholder revival
/// would still `XCTSkip` cleanly rather than FAIL on missing content.
enum PlaceholderDetection {
    /// Returns true iff the bundled `phoneme-labels.json` has at most one
    /// entry — the `<pad>` sentinel used by the historical placeholder.
    /// The real wav2vec2 vocabulary has 392 entries; on `main` this
    /// reliably returns `false`. A missing or unparseable labels file
    /// is also treated as placeholder-like so tests skip rather than
    /// FAIL in that degraded state.
    static func isPlaceholderModelBundled() -> Bool {
        guard
            let url = Bundle.module.url(forResource: "phoneme-labels", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let labels = try? JSONDecoder().decode([String].self, from: data)
        else {
            // If the labels file itself is missing we treat it as "not a
            // real model" — tests will still throw an error path but the
            // skip branch is the most honest outcome.
            return true
        }
        return labels.count <= 1
    }
}
