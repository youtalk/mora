// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/GOPScorer.swift
import Foundation

/// Goodness-of-Pronunciation scorer.
///
/// GOP = mean over t ∈ range of [log p(target | t) − max_q log p(q | t)].
/// Upper bound is 0 (target is the argmax everywhere). The sigmoid maps
/// GOP to a 0–100 learner-facing score.
///
/// `k` and `gopZero` are **pre-calibration defaults**. They ship with
/// v1.5 but are expected to be retuned by a follow-up PR fed from
/// `dev-tools/pronunciation-bench/`. `k` and `gopZero` are `var` on
/// purpose so tuning does not need to touch consumers.
public struct GOPScorer: Sendable {
    public var k: Double
    public var gopZero: Double
    public var reliabilityThreshold: Double

    public init(k: Double = 5.0, gopZero: Double = -1.5, reliabilityThreshold: Double = -2.5) {
        self.k = k
        self.gopZero = gopZero
        self.reliabilityThreshold = reliabilityThreshold
    }

    public func gop(posterior: PhonemePosterior, range: Range<Int>, targetColumn: Int) -> Double {
        if range.isEmpty { return -.infinity }
        if targetColumn < 0 || targetColumn >= posterior.phonemeCount { return -.infinity }
        var total: Double = 0
        for t in range {
            let row = posterior.logProbabilities[t]
            var maxQ: Float = -Float.greatestFiniteMagnitude
            for v in row where v > maxQ { maxQ = v }
            let target = row[targetColumn]
            total += Double(target - maxQ)
        }
        return total / Double(range.count)
    }

    public func score0to100(gop: Double) -> Int {
        let sig = 1.0 / (1.0 + exp(-k * (gop - gopZero)))
        let raw = Int((100.0 * sig).rounded())
        return max(0, min(100, raw))
    }
}
