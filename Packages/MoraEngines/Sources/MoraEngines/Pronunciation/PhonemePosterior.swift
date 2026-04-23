// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosterior.swift
import Foundation

/// A phoneme posterior matrix: one row per audio frame, one column per
/// phoneme in the model's vocabulary. Values are natural-log probabilities.
/// Produced by a `PhonemePosteriorProvider`; consumed by `ForcedAligner`
/// and `GOPScorer`.
public struct PhonemePosterior: Sendable, Hashable, Codable {
    public let framesPerSecond: Double
    public let phonemeLabels: [String]
    public let logProbabilities: [[Float]]

    public init(
        framesPerSecond: Double,
        phonemeLabels: [String],
        logProbabilities: [[Float]]
    ) {
        self.framesPerSecond = framesPerSecond
        self.phonemeLabels = phonemeLabels
        self.logProbabilities = logProbabilities
    }

    public var frameCount: Int { logProbabilities.count }
    public var phonemeCount: Int { phonemeLabels.count }

    public func frameIndex(forSecond second: Double) -> Int {
        Int((second * framesPerSecond).rounded(.down))
    }

    public func second(forFrame index: Int) -> Double {
        framesPerSecond > 0 ? Double(index) / framesPerSecond : 0
    }

    public static let empty = PhonemePosterior(
        framesPerSecond: 50, phonemeLabels: [], logProbabilities: []
    )
}
