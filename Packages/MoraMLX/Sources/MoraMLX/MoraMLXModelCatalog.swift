// Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift
import Foundation
import CoreML
import MoraEngines
import MoraCore

/// Loads the bundled wav2vec2-phoneme CoreML model and assembles a
/// production `PhonemeModelPronunciationEvaluator` wiring it through
/// `CoreMLPhonemePosteriorProvider` + `ForcedAligner` + `GOPScorer`.
///
/// The loaded `MLModel` and `PhonemeInventory` are cached for the
/// process lifetime so subsequent calls reuse the same model instance.
public enum MoraMLXModelCatalog {
    private static let cache = Cache()

    public static func loadPhonemeEvaluator(
        timeout: Duration = .milliseconds(1000)
    ) throws -> PhonemeModelPronunciationEvaluator {
        let (model, inventory) = try cache.loadOrGet()
        return Self.makeEvaluator(model: model, inventory: inventory, timeout: timeout)
    }

    /// Non-blocking accessor for the already-compiled evaluator.
    /// Returns `nil` when the background warmup has not yet finished
    /// `MLModel(contentsOf:)` — the caller must not wait for it.
    ///
    /// Used by `ShadowEvaluatorFactory` at session start so the first
    /// session after install does not stall the main actor for the full
    /// ~100 s ANE compile; Engine A runs alone in that session and the
    /// next session gets Engine B from the warm cache.
    public static func cachedPhonemeEvaluator(
        timeout: Duration = .milliseconds(1000)
    ) -> PhonemeModelPronunciationEvaluator? {
        guard let (model, inventory) = cache.peek() else { return nil }
        return Self.makeEvaluator(model: model, inventory: inventory, timeout: timeout)
    }

    private static func makeEvaluator(
        model: MLModel,
        inventory: PhonemeInventory,
        timeout: Duration
    ) -> PhonemeModelPronunciationEvaluator {
        let provider = CoreMLPhonemePosteriorProvider(model: model, inventory: inventory)
        return PhonemeModelPronunciationEvaluator(
            provider: provider,
            aligner: ForcedAligner(inventory: inventory),
            scorer: GOPScorer(),
            inventory: inventory,
            l1Profile: JapaneseL1Profile(),
            timeout: timeout
        )
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var loaded: (MLModel, PhonemeInventory)?

        func loadOrGet() throws -> (MLModel, PhonemeInventory) {
            lock.lock()
            defer { lock.unlock() }
            if let loaded { return loaded }
            let model = try loadModel()
            let labels = try loadLabels()
            let inventory = PhonemeInventory(
                espeakLabels: labels,
                supportedPhonemeIPA: PhonemeInventory.v15SupportedPhonemeIPA
            )
            let result = (model, inventory)
            loaded = result
            return result
        }

        /// Returns the cached pair without blocking if another thread is
        /// mid-load. `try?`-style lock acquisition keeps the caller's
        /// thread unblocked; a contended call simply yields `nil` and
        /// the caller falls back to the no-Engine-B path.
        func peek() -> (MLModel, PhonemeInventory)? {
            guard lock.try() else { return nil }
            defer { lock.unlock() }
            return loaded
        }

        private func loadModel() throws -> MLModel {
            guard let url = Bundle.module.url(forResource: "wav2vec2-phoneme", withExtension: "mlmodelc")
            else {
                throw MoraMLXError.modelNotBundled
            }
            do {
                return try MLModel(contentsOf: url)
            } catch {
                throw MoraMLXError.modelLoadFailed(String(describing: error))
            }
        }

        private func loadLabels() throws -> [String] {
            guard let url = Bundle.module.url(forResource: "phoneme-labels", withExtension: "json")
            else {
                throw MoraMLXError.inventoryUnavailable
            }
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                throw MoraMLXError.inventoryUnavailable
            }
        }
    }
}
