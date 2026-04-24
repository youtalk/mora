import Foundation
import MoraCore
import MoraEngines

/// Deterministic PronunciationRunning double for recorder tests. Calls
/// are recorded and resolved against `nextResult`. Isolated to an actor
/// so stored state is thread-safe when tests await across MainActor hops.
actor FakeRunner: PronunciationRunning {
    var nextResult: PhonemeTrialAssessment = PhonemeTrialAssessment(
        targetPhoneme: Phoneme(ipa: "a"),
        label: .matched,
        score: 100,
        coachingKey: nil,
        features: [:],
        isReliable: true
    )
    private(set) var callCount: Int = 0
    private(set) var lastSamples: [Float] = []

    /// Continuation used by tests to block evaluator resolution until
    /// they explicitly call `resume()`, modelling the "evaluation still
    /// running when Record is tapped again" race.
    private var pendingCompletion: CheckedContinuation<Void, Never>?
    /// When true, the next `evaluate()` call suspends itself until `resume()`.
    private var shouldSuspend = false

    func setNextResult(_ r: PhonemeTrialAssessment) {
        nextResult = r
    }

    /// Arms the fake so the next `evaluate()` call will block until
    /// `resume()` is called. Returns immediately after setting the flag.
    func waitForNextEvaluateAndSuspend() {
        shouldSuspend = true
    }

    /// Releases a blocked `evaluate()` call.
    func resume() {
        pendingCompletion?.resume()
        pendingCompletion = nil
    }

    func evaluate(
        samples: [Float],
        sampleRate: Double,
        wordSurface: String,
        targetPhonemeIPA: String,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?
    ) async -> PhonemeTrialAssessment {
        callCount += 1
        lastSamples = samples
        if shouldSuspend {
            shouldSuspend = false
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                pendingCompletion = c
            }
        }
        return nextResult
    }
}
