import Foundation

public enum FriendshipMeterMath {
    public static let correctTrialGain: Double = 0.02
    public static let sessionCompletionBonus: Double = 0.05
    public static let perDayCap: Double = 0.25

    public struct Result: Equatable, Sendable {
        public let percent: Double
        public let dayGain: Double
    }

    public static func applyTrialOutcome(
        percent: Double,
        correct: Bool,
        dayGainSoFar: Double
    ) -> Result {
        guard correct else { return Result(percent: percent, dayGain: dayGainSoFar) }
        let remainingDay = max(0, perDayCap - dayGainSoFar)
        let gain = min(correctTrialGain, remainingDay)
        let next = clamp(percent + gain)
        return Result(percent: next, dayGain: dayGainSoFar + gain)
    }

    public static func applySessionCompletion(
        percent: Double,
        dayGainSoFar: Double
    ) -> Result {
        let remainingDay = max(0, perDayCap - dayGainSoFar)
        let gain = min(sessionCompletionBonus, remainingDay)
        let next = clamp(percent + gain)
        return Result(percent: next, dayGain: dayGainSoFar + gain)
    }

    /// Per-trial gain magnitude that would guarantee the Friday floor of 100%
    /// given `trialsRemaining` trials in the Friday session.
    public static func floorBoostWeight(currentPercent: Double, trialsRemaining: Int) -> Double {
        guard trialsRemaining > 0 else { return 0 }
        let deficit = max(0, 1.0 - currentPercent)
        return deficit / Double(trialsRemaining)
    }

    private static func clamp(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
}
