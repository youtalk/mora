// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ShadowLoggingPronunciationEvaluator.swift
import Foundation
import MoraCore
import OSLog

private let trialLog = Logger(subsystem: "tech.reenable.Mora", category: "Pronunciation")

/// The composite decorator `AssessmentEngine` receives in shadow mode.
/// Runs the primary evaluator (Engine A) synchronously, returns its result
/// to the caller, and fires the shadow evaluator (Engine B) in a detached
/// background task. Both results are written to the logger.
///
/// Invariants (see `docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md` §6.8):
/// - UI path is never blocked by the shadow evaluator.
/// - `supports(target:in:)` returns true if either evaluator supports the
///   target; the `AssessmentEngine` then routes through `evaluate`, and
///   the decorator is responsible for producing a useful UI result and
///   a log row.
/// - The `PronunciationEvaluator` protocol is non-throwing, so any Engine
///   B internal failure (model load error, provider throw, low-confidence
///   alignment) surfaces as a `.unclear` assessment with a diagnostic
///   `features` dict. The composite logs that as `.completed` and does
///   **not** synthesize a `.failed` log variant.
public struct ShadowLoggingPronunciationEvaluator: PronunciationEvaluator {
    public let primary: any PronunciationEvaluator
    /// Resolves Engine B on each call. Returning `nil` means the background
    /// warmup has not yet compiled the CoreML model for the Neural Engine
    /// (first install can take ~100 s on A-series iPads); the composite
    /// still runs and logs the trial with `engineB = .notReady`. Once the
    /// resolver starts returning a non-`nil` evaluator, subsequent trials
    /// in the same session transparently pick up Engine B.
    public let shadowResolver: @Sendable () -> (any PronunciationEvaluator)?
    public let logger: any PronunciationTrialLogger
    public let timeout: Duration

    public init(
        primary: any PronunciationEvaluator,
        shadowResolver: @escaping @Sendable () -> (any PronunciationEvaluator)?,
        logger: any PronunciationTrialLogger,
        timeout: Duration = .milliseconds(1000)
    ) {
        self.primary = primary
        self.shadowResolver = shadowResolver
        self.logger = logger
        self.timeout = timeout
    }

    public func supports(target: Phoneme, in word: Word) -> Bool {
        if primary.supports(target: target, in: word) { return true }
        if let shadow = shadowResolver(),
            shadow.supports(target: target, in: word) {
            return true
        }
        return false
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        let primarySupports = primary.supports(target: targetPhoneme, in: expected)
        // Snapshot shadow at the start of this trial. Using the same
        // instance for both the supports-check and the detached evaluate
        // call keeps the log row consistent if the warmup happens to
        // finish partway through.
        let shadowSnapshot = shadowResolver()
        let shadowSupports =
            shadowSnapshot?.supports(target: targetPhoneme, in: expected) ?? false

        // Neither evaluator can produce useful data — there's nothing to
        // correlate, so skip the log row entirely and don't consume FIFO
        // slots in the retention cap. `shadowSupports` is already false
        // when `shadowSnapshot == nil` (warmup pending), so this single
        // check covers both "shadow unavailable" and "shadow present but
        // doesn't know this phoneme".
        if !primarySupports && !shadowSupports {
            return Self.placeholder(target: targetPhoneme)
        }

        let uiResult: PhonemeTrialAssessment
        let engineAForLog: PhonemeTrialAssessment?
        if primarySupports {
            let a = await primary.evaluate(
                audio: audio, expected: expected,
                targetPhoneme: targetPhoneme, asr: asr
            )
            uiResult = a
            engineAForLog = a
        } else {
            uiResult = Self.placeholder(target: targetPhoneme)
            engineAForLog = nil
        }

        // Fire shadow + logger on a detached background task so the caller's
        // path never waits on it. `shadow.evaluate(...)` is non-throwing by
        // protocol contract (any internal provider failure surfaces as an
        // `.unclear` PhonemeTrialAssessment with a diagnostic features
        // dict), so the composite can only observe "got a value within the
        // timeout" (log as .completed), "timed out" (log as .timedOut),
        // "shadow doesn't support this target" (log as .unsupported), or
        // "warmup still in flight" (log as .notReady).
        let shadow = shadowSnapshot
        let logger = self.logger
        let timeout = self.timeout
        Task.detached(priority: .background) {
            let start = ContinuousClock.now
            let engineB: EngineBLogResult
            if shadow == nil {
                engineB = .notReady
            } else if !shadowSupports {
                engineB = .unsupported
            } else if let shadow {
                let captured = await withTimeout(timeout) { () async throws -> PhonemeTrialAssessment in
                    await shadow.evaluate(
                        audio: audio, expected: expected,
                        targetPhoneme: targetPhoneme, asr: asr
                    )
                }
                let elapsed = start.duration(to: .now)
                let ms = Self.millis(elapsed)
                if let b = captured {
                    engineB = .completed(b, latencyMs: ms)
                } else {
                    engineB = .timedOut(latencyMs: ms)
                }
            } else {
                // Unreachable: the branches above cover every `shadow`
                // state. This fallback keeps the compiler satisfied
                // without widening the enum.
                engineB = .unsupported
            }
            let entry = PronunciationTrialLogEntry(
                timestamp: Date(),
                word: expected,
                targetPhoneme: targetPhoneme,
                engineA: engineAForLog,
                engineB: engineB
            )
            Self.logTrial(entry)
            await logger.record(entry)
        }

        return uiResult
    }

    /// Emits one line per trial to `Logger(subsystem: "tech.reenable.Mora",
    /// category: "Pronunciation")` so on-device testing (Xcode console,
    /// Console.app with an attached debugger) can see both evaluators'
    /// decisions side by side. DEBUG builds use `privacy: .public` so the
    /// body is readable in an unattached `log stream` or Console.app while
    /// the developer is iterating on-device; Release builds revert to
    /// `privacy: .private` to uphold the "no per-trial details leave the
    /// device" invariant (sysdiagnose and TestFlight feedback redact the
    /// line). The SwiftData row remains the authoritative log either way.
    private static func logTrial(_ entry: PronunciationTrialLogEntry) {
        let word = entry.word.surface
        let ipa = entry.targetPhoneme.ipa
        let a = formatEngineA(entry.engineA)
        let b = formatEngineB(entry.engineB)
        let line = "trial \"\(word)\" /\(ipa)/  A=\(a)  B=\(b)"
        #if DEBUG
        trialLog.info("\(line, privacy: .public)")
        #else
        trialLog.info("\(line, privacy: .private)")
        #endif
    }

    private static func formatEngineA(_ a: PhonemeTrialAssessment?) -> String {
        guard let a else { return "unsupported" }
        let score = a.score.map { String($0) } ?? "-"
        let reliable = a.isReliable ? "" : " unreliable"
        return "\(formatLabel(a.label)):\(score)\(reliable)"
    }

    private static func formatEngineB(_ b: EngineBLogResult) -> String {
        switch b {
        case .completed(let assessment, let latencyMs):
            let score = assessment.score.map { String($0) } ?? "-"
            return "\(formatLabel(assessment.label)):\(score) \(latencyMs)ms"
        case .timedOut(let latencyMs):
            return "timedOut \(latencyMs)ms"
        case .unsupported:
            return "unsupported"
        case .notReady:
            return "notReady"
        }
    }

    private static func formatLabel(_ label: PhonemeAssessmentLabel) -> String {
        switch label {
        case .matched: return "matched"
        case .substitutedBy(let p): return "sub(\(p.ipa))"
        case .driftedWithin: return "drifted"
        case .unclear: return "unclear"
        }
    }

    private static func placeholder(target: Phoneme) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: target,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: [:],
            isReliable: false
        )
    }

    private static func millis(_ duration: Duration) -> Int {
        let (s, attos) = duration.components
        let msPart = attos / 1_000_000_000_000_000
        return Int(s) * 1000 + Int(msPart)
    }
}
