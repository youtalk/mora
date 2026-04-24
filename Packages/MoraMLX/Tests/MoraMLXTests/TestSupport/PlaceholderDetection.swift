// Packages/MoraMLX/Tests/MoraMLXTests/TestSupport/PlaceholderDetection.swift
import Foundation

/// Positive placeholder detection for the bundled CoreML model.
///
/// The real `.mlmodelc` is hosted on the `models/wav2vec2-phoneme-int8-v1`
/// GitHub Release and materialized into the package's `Resources/`
/// directory by `tools/fetch-models.sh` (see
/// `docs/superpowers/plans/2026-04-24-ci-lfs-to-releases.md`). When
/// `fetch-models.sh` has not run — e.g. on a fresh clone before the Xcode
/// preBuildScript fires — `phoneme-labels.json` may still be the 1-entry
/// `["<pad>"]` placeholder and the model directory may be absent.
///
/// Tests use `isPlaceholderModelBundled()` to decide whether to `XCTSkip`
/// on MoraMLXError (placeholder detected) or FAIL (a real model is
/// bundled but the catalog still threw). This replaces an earlier
/// `catch MoraMLXError.inferenceFailed` blanket skip that would have
/// masked regressions once the real model is present.
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
