// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationTrialLogger.swift
import Foundation
import MoraCore

/// Shadow-mode outcome for Engine B on a single trial. Drives what ends up
/// in `PronunciationTrialLog.engineBState` and its adjacent fields.
public enum EngineBLogResult: Sendable, Hashable {
    /// Engine B finished within the timeout. Carries both the result and
    /// the elapsed-time measurement. `.unclear` assessments (from model
    /// load failure, inference error, or low-confidence alignment) land
    /// here too — the `PhonemeTrialAssessment.features` dict carries the
    /// diagnostic reason. See design spec §6.8 "Failure handling".
    case completed(PhonemeTrialAssessment, latencyMs: Int)
    /// Engine B did not finish before the shadow-mode timeout elapsed.
    case timedOut(latencyMs: Int)
    /// Engine B does not support the target phoneme (its inventory set
    /// does not contain the target IPA). No provider call was made.
    case unsupported
}

/// The composite decorator passes this to the logger after both evaluators
/// have returned. `engineA` is nil when Engine A's `supports` returned
/// false — Engine A still produces an `.unclear` placeholder for the UI
/// path, but the log row records the absence explicitly rather than
/// claiming A ran.
public struct PronunciationTrialLogEntry: Sendable {
    public let timestamp: Date
    public let word: Word
    public let targetPhoneme: Phoneme
    public let engineA: PhonemeTrialAssessment?
    public let engineB: EngineBLogResult

    public init(
        timestamp: Date,
        word: Word,
        targetPhoneme: Phoneme,
        engineA: PhonemeTrialAssessment?,
        engineB: EngineBLogResult
    ) {
        self.timestamp = timestamp
        self.word = word
        self.targetPhoneme = targetPhoneme
        self.engineA = engineA
        self.engineB = engineB
    }
}

public protocol PronunciationTrialLogger: Sendable {
    func record(_ entry: PronunciationTrialLogEntry) async
}
