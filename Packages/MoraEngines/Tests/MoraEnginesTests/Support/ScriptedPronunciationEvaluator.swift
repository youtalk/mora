import Foundation
import MoraCore

@testable import MoraEngines

/// Scripted `PronunciationEvaluator` double used by `MoraEnginesTests`. This
/// mirrors `FakePronunciationEvaluator` in `MoraTesting`; we keep a second
/// copy here because `MoraTesting` depends on `MoraEngines` at the SPM package
/// level, which would make it a cyclic dependency for `MoraEnginesTests` to
/// import. Remove when `MoraTesting` is restructured to break the cycle.
///
/// Tests under Task 23 and Task 31 drive `evaluate(...)` concurrently, so the
/// `NSLock`-based guards are forward-protection for that shared usage.
final class ScriptedPronunciationEvaluator: PronunciationEvaluator, @unchecked Sendable {
    private let lock = NSLock()
    private var _supported: Set<String> = []
    private var _responses: [String: PhonemeTrialAssessment] = [:]

    var supportedTargets: Set<String> {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _supported
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _supported = newValue
        }
    }

    var responses: [String: PhonemeTrialAssessment] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _responses
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _responses = newValue
        }
    }

    func supports(target: Phoneme, in word: Word) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _supported.contains(target.ipa)
    }

    func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        lock.lock()
        defer { lock.unlock() }
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
