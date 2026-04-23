// Packages/MoraMLX/Sources/MoraMLX/CoreMLPhonemePosteriorProvider.swift
import Foundation
import CoreML
import OSLog
import MoraEngines

/// Production `PhonemePosteriorProvider` backed by the bundled wav2vec2
/// CoreML model. The loader lives in `MoraMLXModelCatalog`; this type
/// assumes the model and inventory are already loaded.
///
/// `@unchecked Sendable` because `MLModel` is a reference type that is
/// not formally `Sendable`; per Apple's docs, `MLModel.prediction(from:)`
/// is thread-safe for a single model instance, which is what this struct
/// wraps. The wrapping struct is otherwise immutable.
public struct CoreMLPhonemePosteriorProvider: PhonemePosteriorProvider, @unchecked Sendable {
    public let model: MLModel
    public let inventory: PhonemeInventory
    /// Model frame stride in seconds. wav2vec2 outputs one frame per
    /// 20 ms of 16 kHz audio — 50 frames per second.
    public let framesPerSecond: Double

    /// The wav2vec2 model was exported at 16 kHz; any other rate produces
    /// garbage output because the convolutional frontend assumes that
    /// fixed sample rate.
    private static let expectedSampleRate: Double = 16_000

    private static let log = Logger(subsystem: "tech.reenable.Mora", category: "CoreMLProvider")

    public init(
        model: MLModel,
        inventory: PhonemeInventory,
        framesPerSecond: Double = 50.0
    ) {
        self.model = model
        self.inventory = inventory
        self.framesPerSecond = framesPerSecond
    }

    public func posterior(for audio: AudioClip) async throws -> PhonemePosterior {
        if audio.samples.isEmpty {
            throw MoraMLXError.inferenceFailed("empty audio")
        }
        guard audio.sampleRate == Self.expectedSampleRate else {
            throw MoraMLXError.inferenceFailed(
                "unexpected sample rate: \(audio.sampleRate) Hz (expected \(Self.expectedSampleRate) Hz)"
            )
        }
        let input = try Self.makeInput(audio: audio)
        let output: MLFeatureProvider
        do {
            output = try await model.prediction(from: input)
        } catch {
            throw MoraMLXError.inferenceFailed(String(describing: error))
        }
        // The exported wav2vec2 model has exactly one output feature — the
        // log-posterior MLMultiArray. Asserting that explicitly guards
        // against contract drift if the conversion script changes.
        guard output.featureNames.count == 1, let featureName = output.featureNames.first else {
            throw MoraMLXError.inferenceFailed(
                "expected exactly one output feature, got \(output.featureNames.count): "
                    + "\(output.featureNames.sorted())"
            )
        }
        guard let logProbsArray = output.featureValue(for: featureName)?.multiArrayValue else {
            throw MoraMLXError.inferenceFailed(
                "output feature \(featureName) is not an MLMultiArray"
            )
        }
        return try Self.convert(
            logProbs: logProbsArray,
            labels: inventory.espeakLabels,
            framesPerSecond: framesPerSecond
        )
    }

    private static func makeInput(audio: AudioClip) throws -> MLFeatureProvider {
        let sampleCount = audio.samples.count
        guard
            let array = try? MLMultiArray(
                shape: [1, NSNumber(value: sampleCount)], dataType: .float32
            )
        else {
            throw MoraMLXError.inferenceFailed("MLMultiArray alloc failed")
        }
        audio.samples.withUnsafeBufferPointer { buffer in
            memcpy(array.dataPointer, buffer.baseAddress!, sampleCount * MemoryLayout<Float>.size)
        }
        return try MLDictionaryFeatureProvider(
            dictionary: ["audio": MLFeatureValue(multiArray: array)]
        )
    }

    private static func convert(
        logProbs: MLMultiArray,
        labels: [String],
        framesPerSecond: Double
    ) throws -> PhonemePosterior {
        let shape = logProbs.shape.map { $0.intValue }
        let frameCount: Int
        let phonemeCount: Int
        switch shape.count {
        case 2:
            frameCount = shape[0]
            phonemeCount = shape[1]
        case 3 where shape[0] == 1:
            frameCount = shape[1]
            phonemeCount = shape[2]
        default:
            throw MoraMLXError.inferenceFailed("unexpected output shape: \(shape)")
        }
        // The iOS 17 mlprogram target emits Float16 outputs on ANE for
        // efficiency, while older conversions and CPU-only runs produce
        // Float32. Handle both rather than forcing one via compute-precision
        // overrides — that would cost ANE acceleration (see the p95 budget
        // in docs/superpowers/plans/2026-04-23-engine-b-followup-real-model-bundling.md#device-verification).
        //
        // TODO: handle non-contiguous strides if a future CoreML conversion
        // produces strided output. The current wav2vec2 export is contiguous
        // (stride[last] == 1, stride[t] == phonemeCount), so plain row-major
        // indexing is safe.
        let totalCount = frameCount * phonemeCount
        let flat: [Float]
        switch logProbs.dataType {
        case .float32:
            let ptr = logProbs.dataPointer.bindMemory(to: Float.self, capacity: totalCount)
            flat = Array(UnsafeBufferPointer(start: ptr, count: totalCount))
        case .float16:
            let ptr = logProbs.dataPointer.bindMemory(to: Float16.self, capacity: totalCount)
            flat = (0..<totalCount).map { Float(ptr[$0]) }
        default:
            throw MoraMLXError.inferenceFailed(
                "unsupported MLMultiArray dataType: \(logProbs.dataType.rawValue) "
                    + "(supported: float32=\(MLMultiArrayDataType.float32.rawValue), "
                    + "float16=\(MLMultiArrayDataType.float16.rawValue))"
            )
        }
        var rows: [[Float]] = []
        rows.reserveCapacity(frameCount)
        for t in 0..<frameCount {
            let base = t * phonemeCount
            rows.append(Array(flat[base..<(base + phonemeCount)]))
        }
        return PhonemePosterior(
            framesPerSecond: framesPerSecond,
            phonemeLabels: labels,
            logProbabilities: rows
        )
    }
}
