// Packages/MoraTesting/Sources/MoraTesting/InMemoryPronunciationTrialLogger.swift
import Foundation
import MoraEngines

/// Collects `PronunciationTrialLogEntry` values in memory. Thread-safe.
/// Used by `ShadowLoggingPronunciationEvaluatorTests` and any other test
/// that wants to assert on the shadow-log side effect without standing up
/// a SwiftData container.
public actor InMemoryPronunciationTrialLogger: PronunciationTrialLogger {
    public private(set) var entries: [PronunciationTrialLogEntry] = []

    public init() {}

    public func record(_ entry: PronunciationTrialLogEntry) async {
        entries.append(entry)
    }
}
