// PronunciationLogFormatterTests.swift
import XCTest
@testable import MoraEngines
import MoraCore

/// Locks the rendered shape of the trial-level OS-log lines that
/// `ShadowLoggingPronunciationEvaluator` and `SessionOrchestrator` both
/// emit through `PronunciationLogFormatter`. A future format change will
/// break these tests visibly, which is the whole point — once tooling or
/// muscle memory grows around a particular console line shape, drift is
/// a footgun.
final class PronunciationLogFormatterTests: XCTestCase {
    private func assessment(
        label: PhonemeAssessmentLabel,
        score: Int?,
        isReliable: Bool,
        features: [String: Double] = [:]
    ) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: label,
            score: score,
            coachingKey: nil,
            features: features,
            isReliable: isReliable
        )
    }

    // MARK: label

    func testLabelMatched() {
        XCTAssertEqual(PronunciationLogFormatter.label(.matched), "matched")
    }

    func testLabelSubstituted() {
        XCTAssertEqual(
            PronunciationLogFormatter.label(.substitutedBy(Phoneme(ipa: "s"))),
            "sub(s)"
        )
    }

    func testLabelDrifted() {
        XCTAssertEqual(PronunciationLogFormatter.label(.driftedWithin), "drifted")
    }

    func testLabelUnclear() {
        XCTAssertEqual(PronunciationLogFormatter.label(.unclear), "unclear")
    }

    // MARK: engineALine

    func testEngineALineUnsupportedWhenAssessmentNil() {
        let line = PronunciationLogFormatter.engineALine(nil, latencyMs: nil)
        XCTAssertEqual(line, "unsupported")
    }

    func testEngineALineMatchedWithLatencyAndFeatures() {
        let a = assessment(
            label: .matched, score: 88, isReliable: true,
            features: ["spectralCentroidHz": 2841.2]
        )
        let line = PronunciationLogFormatter.engineALine(a, latencyMs: 18)
        XCTAssertEqual(line, "matched:88 18ms reliable {spectralCentroidHz=2841.20}")
    }

    func testEngineALineUnclearWithoutScoreOrLatency() {
        let a = assessment(label: .unclear, score: nil, isReliable: false)
        let line = PronunciationLogFormatter.engineALine(a, latencyMs: nil)
        XCTAssertEqual(line, "unclear:- - unreliable")
    }

    // MARK: engineBLine

    func testEngineBLineCompleted() {
        let a = assessment(
            label: .matched, score: 91, isReliable: true,
            features: ["gop": -0.31, "avgLogProb": -0.84, "frameCount": 12]
        )
        let line = PronunciationLogFormatter.engineBLine(.completed(a, latencyMs: 240))
        XCTAssertEqual(
            line,
            "matched:91 240ms reliable {avgLogProb=-0.84, frameCount=12.00, gop=-0.31}"
        )
    }

    func testEngineBLineCompletedUnclearWithReason() {
        let a = assessment(
            label: .unclear, score: nil, isReliable: false,
            features: ["reason": 3]
        )
        let line = PronunciationLogFormatter.engineBLine(.completed(a, latencyMs: 312))
        XCTAssertEqual(line, "unclear:- 312ms unreliable {reason=3.00}")
    }

    func testEngineBLineTimedOut() {
        XCTAssertEqual(
            PronunciationLogFormatter.engineBLine(.timedOut(latencyMs: 1003)),
            "timedOut 1003ms"
        )
    }

    func testEngineBLineUnsupported() {
        XCTAssertEqual(PronunciationLogFormatter.engineBLine(.unsupported), "unsupported")
    }

    func testEngineBLineNotReady() {
        XCTAssertEqual(PronunciationLogFormatter.engineBLine(.notReady), "notReady")
    }

    // MARK: sentenceTrialPhonemeSuffix

    func testSentenceSuffixEmptyWhenNil() {
        XCTAssertEqual(PronunciationLogFormatter.sentenceTrialPhonemeSuffix(nil), "")
    }

    func testSentenceSuffixReliable() {
        let a = assessment(label: .matched, score: 88, isReliable: true)
        XCTAssertEqual(
            PronunciationLogFormatter.sentenceTrialPhonemeSuffix(a),
            " phoneme=matched:88"
        )
    }

    func testSentenceSuffixUnreliableTagged() {
        let a = assessment(label: .unclear, score: nil, isReliable: false)
        XCTAssertEqual(
            PronunciationLogFormatter.sentenceTrialPhonemeSuffix(a),
            " phoneme=unclear:-(unreliable)"
        )
    }

    // MARK: features

    func testFeaturesEmptyReturnsEmptyString() {
        XCTAssertEqual(PronunciationLogFormatter.features([:]), "")
    }

    func testFeaturesSortedByKey() {
        let s = PronunciationLogFormatter.features([
            "gop": -0.31,
            "avgLogProb": -0.84,
            "frameCount": 12,
        ])
        XCTAssertEqual(s, " {avgLogProb=-0.84, frameCount=12.00, gop=-0.31}")
    }
}
