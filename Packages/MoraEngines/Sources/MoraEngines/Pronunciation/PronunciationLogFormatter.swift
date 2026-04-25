// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationLogFormatter.swift
import Foundation
import MoraCore

/// Single source of truth for how phoneme assessments and engine outcomes
/// render in the OS console. Centralizing this avoids the drift that
/// happens when each callsite (the cross-engine shadow log, the
/// orchestrator-level sentence-trial log, and any future debug overlay)
/// rolls its own label switch and reliability spelling. Add new render
/// shapes here as needed instead of inlining them at the callsite.
enum PronunciationLogFormatter {
    /// `matched`, `sub(<ipa>)`, `drifted`, or `unclear`. The single switch
    /// that every other helper in this file routes through, so any future
    /// rename or addition of an assessment label changes the console
    /// rendering in exactly one place.
    static func label(_ label: PhonemeAssessmentLabel) -> String {
        switch label {
        case .matched: return "matched"
        case .substitutedBy(let p): return "sub(\(p.ipa))"
        case .driftedWithin: return "drifted"
        case .unclear: return "unclear"
        }
    }

    /// Trial-level rendering for Engine A used in the cross-engine shadow
    /// log: `<label>:<score> <latency>ms <reliable>{<features>}`. Returns
    /// the literal `unsupported` when Engine A's `supports` returned false
    /// for the trial's target phoneme. `latencyMs == nil` is rendered as
    /// `-` so the field stays positional.
    static func engineALine(
        _ assessment: PhonemeTrialAssessment?,
        latencyMs: Int?
    ) -> String {
        guard let a = assessment else { return "unsupported" }
        let score = a.score.map { String($0) } ?? "-"
        let lat = latencyMs.map { "\($0)ms" } ?? "-"
        let reliable = a.isReliable ? "reliable" : "unreliable"
        return "\(label(a.label)):\(score) \(lat) \(reliable)\(features(a.features))"
    }

    /// Trial-level rendering for Engine B used in the cross-engine shadow
    /// log. Each `EngineBLogResult` case explains why Engine B did or
    /// did not produce a score for this trial, so the dev can tell
    /// "warmup pending" from "phoneme outside inventory" from "model
    /// took too long" from "real result".
    static func engineBLine(_ result: EngineBLogResult) -> String {
        switch result {
        case .completed(let assessment, let latencyMs):
            let score = assessment.score.map { String($0) } ?? "-"
            let reliable = assessment.isReliable ? "reliable" : "unreliable"
            return """
                \(label(assessment.label)):\(score) \(latencyMs)ms \(reliable)\
                \(features(assessment.features))
                """
        case .timedOut(let latencyMs):
            return "timedOut \(latencyMs)ms"
        case .unsupported:
            return "unsupported"
        case .notReady:
            return "notReady"
        }
    }

    /// Compact rendering used by the orchestrator's sentence-trial log
    /// where features and latency are not needed. Returns the empty
    /// string when no phoneme assessment is attached, so callers can
    /// concatenate unconditionally without an extra `if let` branch.
    /// Format: ` phoneme=<label>:<score>(<unreliable?>)` — note the
    /// leading space so the suffix slots into a longer log line.
    static func sentenceTrialPhonemeSuffix(_ assessment: PhonemeTrialAssessment?) -> String {
        guard let a = assessment else { return "" }
        let score = a.score.map { String($0) } ?? "-"
        let reliability = a.isReliable ? "" : "(unreliable)"
        return " phoneme=\(label(a.label)):\(score)\(reliability)"
    }

    /// Renders the evaluator-specific `features` payload into a compact
    /// `{key=val, ...}` suffix for the shadow log line. Engine A keys are
    /// acoustic-feature names ("spectralCentroidHz", "voicingOnsetTimeMs",
    /// ...); Engine B keys are GOP-pipeline diagnostics ("gop",
    /// "avgLogProb", "frameCount", or "reason" when the trial
    /// short-circuited to `.unclear`). Sorted by key so log output is
    /// deterministic across runs and `%.2f` so floats stay narrow.
    static func features(_ features: [String: Double]) -> String {
        if features.isEmpty { return "" }
        let parts = features.sorted { $0.key < $1.key }
            .map { "\($0.key)=\(String(format: "%.2f", $0.value))" }
        return " {\(parts.joined(separator: ", "))}"
    }
}
