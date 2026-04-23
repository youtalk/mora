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
        let input = try Self.makeInput(audio: audio)
        let output: MLFeatureProvider
        do {
            output = try await model.prediction(from: input)
        } catch {
            throw MoraMLXError.inferenceFailed(String(describing: error))
        }
        guard
            let firstName = output.featureNames.sorted().first,
            let logProbsArray = output.featureValue(for: firstName)?.multiArrayValue
        else {
            throw MoraMLXError.inferenceFailed("no multiArray output")
        }
        return Self.convert(
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
    ) -> PhonemePosterior {
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
            log.error("unexpected output shape: \(shape)")
            return PhonemePosterior(
                framesPerSecond: framesPerSecond,
                phonemeLabels: labels,
                logProbabilities: []
            )
        }
        var rows: [[Float]] = []
        rows.reserveCapacity(frameCount)
        let ptr = logProbs.dataPointer.bindMemory(
            to: Float.self, capacity: frameCount * phonemeCount
        )
        for t in 0..<frameCount {
            let base = t * phonemeCount
            var row = [Float](repeating: 0, count: phonemeCount)
            for c in 0..<phonemeCount {
                row[c] = ptr[base + c]
            }
            rows.append(row)
        }
        return PhonemePosterior(
            framesPerSecond: framesPerSecond,
            phonemeLabels: labels,
            logProbabilities: rows
        )
    }
}
