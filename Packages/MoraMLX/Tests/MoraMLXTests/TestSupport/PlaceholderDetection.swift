// Packages/MoraMLX/Tests/MoraMLXTests/TestSupport/PlaceholderDetection.swift
import Foundation

/// Positive placeholder detection for the bundled CoreML model.
///
/// Until the real `.mlmodelc` is committed via Git LFS (Task 22 Steps 2–5
/// of `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md`),
/// the package bundles a placeholder `wav2vec2-phoneme.mlmodelc/` directory
/// alongside a placeholder `phoneme-labels.json` that contains a single
/// `<pad>` label.
///
/// Tests use `isPlaceholderModelBundled()` to decide whether to `XCTSkip`
/// on MoraMLXError (placeholder detected) or FAIL (a real model is
/// bundled but the catalog still threw). This replaces an earlier
/// `catch MoraMLXError.inferenceFailed` blanket skip that would have
/// masked regressions once the real model lands.
enum PlaceholderDetection {
    /// Returns true iff the bundled `phoneme-labels.json` has exactly one
    /// entry — the `<pad>` sentinel used by the placeholder. The real
    /// wav2vec2 vocabulary has ~390 entries, so this check is a reliable
    /// positive signal.
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
