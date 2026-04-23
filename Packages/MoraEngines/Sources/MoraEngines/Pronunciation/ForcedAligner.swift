// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ForcedAligner.swift
import Foundation
import MoraCore

/// Result of aligning an expected phoneme sequence to a posterior matrix.
/// `startFrame..<endFrame` is half-open. `averageLogProb` is the mean
/// log-probability of the aligned phoneme's column across the range; it
/// doubles as a coarse confidence signal downstream.
public struct PhonemeAlignment: Sendable, Hashable {
    public let phoneme: Phoneme
    public let startFrame: Int
    public let endFrame: Int
    public let averageLogProb: Float

    public init(phoneme: Phoneme, startFrame: Int, endFrame: Int, averageLogProb: Float) {
        self.phoneme = phoneme
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.averageLogProb = averageLogProb
    }
}

/// Forced alignment via Viterbi on a left-to-right HMM whose states are
/// the expected phoneme sequence. Self-loop and forward transitions only;
/// no skips. Unknown phonemes fall back to uniform-prior scoring and a
/// positional frame slice.
public struct ForcedAligner: Sendable {
    public let inventory: PhonemeInventory

    public init(inventory: PhonemeInventory) {
        self.inventory = inventory
    }

    public func align(
        posterior: PhonemePosterior,
        phonemes: [Phoneme]
    ) -> [PhonemeAlignment] {
        if phonemes.isEmpty { return [] }
        let frameCount = posterior.frameCount
        let stateCount = phonemes.count
        guard frameCount > 0 else {
            return positionalFallback(frameCount: 0, phonemes: phonemes)
        }
        if frameCount < stateCount {
            return positionalFallback(frameCount: frameCount, phonemes: phonemes)
        }

        // Column lookups per phoneme. Nil means "unknown — penalize".
        let cols: [Int?] = phonemes.map { inventory.ipaToColumn[$0.ipa] }
        let unknownLogProb: Float = Float(-log(Double(max(1, inventory.espeakLabels.count))))

        // Viterbi: dp[t][n] = best log-prob to reach state n at frame t.
        let negInf = -Float.greatestFiniteMagnitude
        var dp = Array(repeating: Array(repeating: negInf, count: stateCount), count: frameCount)
        var back = Array(repeating: Array(repeating: 0, count: stateCount), count: frameCount)

        func emit(_ t: Int, _ n: Int) -> Float {
            if let c = cols[n] {
                return posterior.logProbabilities[t][c]
            }
            return unknownLogProb
        }

        dp[0][0] = emit(0, 0)
        for t in 1..<frameCount {
            for n in 0..<stateCount {
                // Stay in state n (self-loop) or advance from state n-1.
                let stay = dp[t - 1][n]
                let advance = n > 0 ? dp[t - 1][n - 1] : negInf
                let best: Float
                let prev: Int
                if advance > stay {
                    best = advance
                    prev = n - 1
                } else {
                    best = stay
                    prev = n
                }
                dp[t][n] = best + emit(t, n)
                back[t][n] = prev
            }
        }

        // Backtrack from (frameCount-1, stateCount-1).
        var boundaries = Array(repeating: 0, count: stateCount + 1)
        boundaries[stateCount] = frameCount
        var state = stateCount - 1
        var t = frameCount - 1
        var path = Array(repeating: 0, count: frameCount)
        while t >= 0 {
            path[t] = state
            if t == 0 { break }
            state = back[t][state]
            t -= 1
        }
        // Derive boundaries from the path.
        var currentState = path[0]
        for i in 1..<frameCount {
            if path[i] != currentState {
                boundaries[path[i]] = i
                currentState = path[i]
            }
        }

        // Emit alignments with per-range averaged log-prob.
        var out: [PhonemeAlignment] = []
        out.reserveCapacity(stateCount)
        for n in 0..<stateCount {
            let startFrame = boundaries[n]
            let endFrame = boundaries[n + 1]
            let avg: Float
            if startFrame >= endFrame {
                avg = -.infinity
            } else if let c = cols[n] {
                var sum: Float = 0
                for f in startFrame..<endFrame {
                    sum += posterior.logProbabilities[f][c]
                }
                avg = sum / Float(endFrame - startFrame)
            } else {
                avg = unknownLogProb
            }
            out.append(
                PhonemeAlignment(
                    phoneme: phonemes[n],
                    startFrame: startFrame,
                    endFrame: endFrame,
                    averageLogProb: avg
                )
            )
        }
        return out
    }

    private func positionalFallback(
        frameCount: Int,
        phonemes: [Phoneme]
    ) -> [PhonemeAlignment] {
        let stateCount = phonemes.count
        var out: [PhonemeAlignment] = []
        out.reserveCapacity(stateCount)
        for n in 0..<stateCount {
            let start = frameCount * n / stateCount
            let end = frameCount * (n + 1) / stateCount
            out.append(
                PhonemeAlignment(
                    phoneme: phonemes[n],
                    startFrame: start,
                    endFrame: end,
                    averageLogProb: -.infinity
                )
            )
        }
        return out
    }
}
