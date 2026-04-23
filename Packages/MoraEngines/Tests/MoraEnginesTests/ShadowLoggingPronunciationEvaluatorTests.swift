// ShadowLoggingPronunciationEvaluatorTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraTesting
import MoraCore

@MainActor
final class ShadowLoggingPronunciationEvaluatorTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    private func asr() -> ASRResult {
        ASRResult(transcript: "ship", confidence: 0.9)
    }

    private func assessment(label: PhonemeAssessmentLabel, score: Int?) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: label,
            score: score,
            coachingKey: nil,
            features: [:],
            isReliable: score != nil
        )
    }

    private func waitForLogger(
        _ logger: InMemoryPronunciationTrialLogger,
        count: Int,
        timeout: TimeInterval = 2.0
    ) async throws -> [PronunciationTrialLogEntry] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let entries = await logger.entries
            if entries.count >= count { return entries }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("logger never received \(count) entries")
        return await logger.entries
    }

    func testPrimarySupportsAndShadowSupportsBothLogged() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = assessment(label: .matched, score: 91)

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.score, 88)
        let entries = try await waitForLogger(logger, count: 1)
        XCTAssertNotNil(entries[0].engineA)
        if case .completed(let a, _) = entries[0].engineB {
            XCTAssertEqual(a.score, 91)
        } else {
            XCTFail("expected completed, got \(entries[0].engineB)")
        }
    }

    func testPrimaryUnsupportsShadowFiresRegardless() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = []

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = assessment(label: .matched, score: 75)

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.label, .unclear)
        let entries = try await waitForLogger(logger, count: 1)
        XCTAssertNil(entries[0].engineA)
        if case .completed(let b, _) = entries[0].engineB {
            XCTAssertEqual(b.score, 75)
        } else {
            XCTFail("expected completed, got \(entries[0].engineB)")
        }
    }

    func testShadowTimeoutLoggedAsTimedOut() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = BlockingPronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(30)
        )
        _ = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        let entries = try await waitForLogger(logger, count: 1)
        if case .timedOut(let ms) = entries[0].engineB {
            XCTAssertGreaterThanOrEqual(ms, 30)
        } else {
            XCTFail("expected timedOut, got \(entries[0].engineB)")
        }
        shadow.release()
    }

    func testShadowUnclearLogsAsCompleted() async throws {
        // Engine B surfaces internal failures (model load error, inference
        // throw, low confidence) as `.unclear` from its own evaluator, and
        // the composite logs that as `.completed` — there is no `.failed`
        // variant because the PronunciationEvaluator protocol is
        // non-throwing. Diagnostic reason lives in `features`.
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .unclear, score: nil, coachingKey: nil,
            features: ["reason": 1],
            isReliable: false
        )

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        _ = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        let entries = try await waitForLogger(logger, count: 1)
        if case .completed(let b, _) = entries[0].engineB {
            XCTAssertEqual(b.label, .unclear)
        } else {
            XCTFail("expected completed, got \(entries[0].engineB)")
        }
    }

    func testPrimarySupportsShadowUnsupports() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = []

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.score, 88)
        let entries = try await waitForLogger(logger, count: 1)
        XCTAssertNotNil(entries[0].engineA)
        if case .unsupported = entries[0].engineB {
            // ok
        } else {
            XCTFail("expected unsupported, got \(entries[0].engineB)")
        }
    }

    func testNeitherSupportsSkipsLogger() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = []
        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = []
        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary, shadow: shadow, logger: logger, timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.label, .unclear)
        // Give any detached work time to run; no log row should appear.
        try await Task.sleep(for: .milliseconds(100))
        let entries = await logger.entries
        XCTAssertTrue(entries.isEmpty)
    }
}

private final class BlockingPronunciationEvaluator: PronunciationEvaluator, @unchecked Sendable {
    private let lock = NSLock()
    private var c: CheckedContinuation<Void, Never>?
    var supportedTargets: Set<String> = []
    func release() {
        lock.lock()
        let cc = c
        c = nil
        lock.unlock()
        cc?.resume()
    }
    func supports(target: Phoneme, in word: Word) -> Bool {
        supportedTargets.contains(target.ipa)
    }
    func evaluate(
        audio: AudioClip, expected: Word,
        targetPhoneme: Phoneme, asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        // `withTimeout` relies on cooperative cancellation to abandon a
        // blocked operation task — a plain `withCheckedContinuation` would
        // leak its continuation and the surrounding `withTaskGroup` would
        // never complete, hanging the detached shadow task. Mirror the
        // pattern in `FakePhonemePosteriorProvider` and resume the
        // continuation when the task is cancelled.
        await withTaskCancellationHandler(
            operation: {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    lock.lock()
                    c = cont
                    lock.unlock()
                }
            },
            onCancel: { [self] in
                lock.lock()
                let cc = c
                c = nil
                lock.unlock()
                cc?.resume()
            }
        )
        return PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: .unclear, score: nil, coachingKey: nil,
            features: [:], isReliable: false
        )
    }
}
