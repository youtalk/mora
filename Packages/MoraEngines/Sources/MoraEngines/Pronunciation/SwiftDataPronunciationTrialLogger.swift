// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/SwiftDataPronunciationTrialLogger.swift
import Foundation
import OSLog
import SwiftData
import MoraCore

/// Production `PronunciationTrialLogger` backed by SwiftData. Each call
/// serializes the entry and inserts one `PronunciationTrialLog` row. Runs
/// on a dedicated background actor; each `record` call creates a fresh
/// `ModelContext(container)` so writes do not contend with the main-actor
/// `ModelContext` used by the UI.
public actor SwiftDataPronunciationTrialLogger: PronunciationTrialLogger {
    private let container: ModelContainer
    private let log = Logger(subsystem: "tech.reenable.Mora", category: "PronunciationTrialLogger")

    public init(container: ModelContainer) {
        self.container = container
    }

    public func record(_ entry: PronunciationTrialLogEntry) async {
        let row = buildRow(from: entry)
        do {
            try await persist(row)
        } catch {
            log.error("shadow log write failed: \(String(describing: error))")
        }
    }

    private func persist(_ row: PronunciationTrialLog) async throws {
        let ctx = ModelContext(container)
        ctx.insert(row)
        try ctx.save()
    }

    private func buildRow(from entry: PronunciationTrialLogEntry) -> PronunciationTrialLog {
        let engineALabelJSON: String
        if let a = entry.engineA {
            engineALabelJSON = (try? Self.encodeLabel(a.label)) ?? "{}"
        } else {
            engineALabelJSON = "{}"
        }
        let engineAFeaturesJSON =
            (entry.engineA.flatMap { try? Self.encodeFeatures($0.features) })
            ?? "{}"

        let state: String
        var engineBLabelJSON: String?
        var engineBScore: Int?
        var engineBLatency: Int?

        switch entry.engineB {
        case .completed(let assessment, let latencyMs):
            state = "completed"
            engineBLabelJSON = try? Self.encodeLabel(assessment.label)
            engineBScore = assessment.score
            engineBLatency = latencyMs
        case .timedOut(let latencyMs):
            state = "timedOut"
            engineBLatency = latencyMs
        case .unsupported:
            state = "unsupported"
        }

        return PronunciationTrialLog(
            timestamp: entry.timestamp,
            wordSurface: entry.word.surface,
            targetPhonemeIPA: entry.targetPhoneme.ipa,
            engineALabel: engineALabelJSON,
            engineAScore: entry.engineA?.score,
            engineAFeaturesJSON: engineAFeaturesJSON,
            engineBState: state,
            engineBLabel: engineBLabelJSON,
            engineBScore: engineBScore,
            engineBLatencyMs: engineBLatency
        )
    }

    private static func encodeLabel(_ label: PhonemeAssessmentLabel) throws -> String {
        let data = try JSONEncoder().encode(label)
        return String(decoding: data, as: UTF8.self)
    }

    private static func encodeFeatures(_ features: [String: Double]) throws -> String {
        let data = try JSONEncoder().encode(features)
        return String(decoding: data, as: UTF8.self)
    }
}
