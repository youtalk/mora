import Foundation
import MoraCore
import MoraEngines

/// Scripted double for `PronunciationEvaluator`. Configure `supportedTargets`
/// and `responses` in test setup; the fake is thread-safe and `Sendable`.
public final class FakePronunciationEvaluator: PronunciationEvaluator, @unchecked Sendable {
    private let lock = NSLock()
    private var _supported: Set<String> = []
    private var _responses: [String: PhonemeTrialAssessment] = [:]

    public var supportedTargets: Set<String> {
        get { lock.lock(); defer { lock.unlock() }; return _supported }
        set { lock.lock(); defer { lock.unlock() }; _supported = newValue }
    }

    public var responses: [String: PhonemeTrialAssessment] {
        get { lock.lock(); defer { lock.unlock() }; return _responses }
        set { lock.lock(); defer { lock.unlock() }; _responses = newValue }
    }

    public init() {}

    public func supports(target: Phoneme, in word: Word) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return _supported.contains(target.ipa)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        lock.lock(); defer { lock.unlock() }
        if let scripted = _responses[targetPhoneme.ipa] {
            return scripted
        }
        return PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: [:],
            isReliable: false
        )
    }
}
