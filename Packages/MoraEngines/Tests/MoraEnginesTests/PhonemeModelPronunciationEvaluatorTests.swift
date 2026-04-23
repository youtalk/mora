import XCTest
@testable import MoraEngines
@testable import MoraTesting
import MoraCore

@MainActor
final class PhonemeModelPronunciationEvaluatorTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    private func inventory() -> PhonemeInventory {
        PhonemeInventory(
            espeakLabels: ["ʃ", "s", "ɪ", "p"],
            supportedPhonemeIPA: ["ʃ", "s", "ɪ", "p"]
        )
    }

    private func evaluator(
        fake: FakePhonemePosteriorProvider,
        timeout: Duration = .milliseconds(500)
    ) -> PhonemeModelPronunciationEvaluator {
        PhonemeModelPronunciationEvaluator(
            provider: fake,
            aligner: ForcedAligner(inventory: inventory()),
            scorer: GOPScorer(),
            inventory: inventory(),
            l1Profile: JapaneseL1Profile(),
            timeout: timeout
        )
    }

    private func posterior(
        shFrames: Int, iFrames: Int, pFrames: Int,
        substituteSForSh: Bool = false
    ) -> PhonemePosterior {
        let shRow: [Float] =
            substituteSForSh
            ? [Float(log(0.2)), Float(log(0.75)), Float(log(0.025)), Float(log(0.025))]
            : [Float(log(0.9)), Float(log(0.05)), Float(log(0.025)), Float(log(0.025))]
        let iRow: [Float] = [Float(log(0.025)), Float(log(0.025)), Float(log(0.9)), Float(log(0.05))]
        let pRow: [Float] = [Float(log(0.025)), Float(log(0.025)), Float(log(0.05)), Float(log(0.9))]
        let rows =
            Array(repeating: shRow, count: shFrames)
            + Array(repeating: iRow, count: iFrames)
            + Array(repeating: pRow, count: pFrames)
        return PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["ʃ", "s", "ɪ", "p"],
            logProbabilities: rows
        )
    }

    func testMatchedPath() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(posterior(shFrames: 8, iFrames: 4, pFrames: 4))
        let e = evaluator(fake: fake)
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        XCTAssertEqual(result.label, .matched)
        XCTAssertNotNil(result.score)
        XCTAssertTrue(result.isReliable)
    }

    func testSubstitutionPathReturnsCoachingKey() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(posterior(shFrames: 8, iFrames: 4, pFrames: 4, substituteSForSh: true))
        let e = evaluator(fake: fake)
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "sip", confidence: 0.8)
        )
        if case .substitutedBy(let p) = result.label {
            XCTAssertEqual(p.ipa, "s")
        } else {
            XCTFail("expected substitutedBy(/s/), got \(result.label)")
        }
        XCTAssertEqual(result.coachingKey, "coaching.sh_sub_s")
    }

    func testUnclearOnTimeout() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(.empty)
        fake.shouldBlock = true
        let e = evaluator(fake: fake, timeout: .milliseconds(30))
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
        XCTAssertNil(result.score)
        fake.release()
    }

    func testUnclearOnProviderError() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .failure(FakePhonemePosteriorProvider.ScriptedError.boom)
        let e = evaluator(fake: fake)
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
    }

    func testUnsupportedTargetReturnsUnclear() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(posterior(shFrames: 4, iFrames: 4, pFrames: 4))
        let e = evaluator(fake: fake)
        let unsupportedTarget = Phoneme(ipa: "ʒ")
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: unsupportedTarget,
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
    }

    func testSupportsReflectsInventory() {
        let fake = FakePhonemePosteriorProvider()
        let e = evaluator(fake: fake)
        XCTAssertTrue(e.supports(target: Phoneme(ipa: "ʃ"), in: word()))
        XCTAssertFalse(e.supports(target: Phoneme(ipa: "ʒ"), in: word()))
    }

    /// Each failure mode that routes through `unreliable(_:reason:)` writes a
    /// distinct numeric code into `features["reason"]`, so downstream shadow
    /// analysis can tell them apart in the persisted log.
    func testUnreliableReasonsCarryDistinctCodes() async {
        typealias Code = PhonemeModelPronunciationEvaluator.UnreliableReasonCode

        // 1) `unsupported` → target IPA is not in the inventory.
        let unsupportedFake = FakePhonemePosteriorProvider()
        unsupportedFake.nextResult = .success(posterior(shFrames: 4, iFrames: 4, pFrames: 4))
        let unsupportedEval = evaluator(fake: unsupportedFake)
        let unsupportedResult = await unsupportedEval.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʒ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(unsupportedResult.features["reason"], Code.unsupported.rawValue)

        // 2) `provider_unavailable` → provider returns empty posterior.
        let providerFake = FakePhonemePosteriorProvider()
        providerFake.nextResult = .success(.empty)
        let providerEval = evaluator(fake: providerFake)
        let providerResult = await providerEval.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(providerResult.features["reason"], Code.providerUnavailable.rawValue)

        // 3) `low_confidence` → average log-prob falls below
        // `GOPScorer.reliabilityThreshold`. We force that by using a scorer
        // whose threshold is tighter than the fake's top-class log-prob
        // (~log(0.9) ≈ -0.105).
        let lowConfFake = FakePhonemePosteriorProvider()
        lowConfFake.nextResult = .success(posterior(shFrames: 8, iFrames: 4, pFrames: 4))
        let lowConfEval = PhonemeModelPronunciationEvaluator(
            provider: lowConfFake,
            aligner: ForcedAligner(inventory: inventory()),
            scorer: GOPScorer(reliabilityThreshold: -0.01),
            inventory: inventory(),
            l1Profile: JapaneseL1Profile(),
            timeout: .milliseconds(500)
        )
        let lowConfResult = await lowConfEval.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        XCTAssertEqual(lowConfResult.features["reason"], Code.lowConfidence.rawValue)

        // Sanity: the three codes must differ — the bug being fixed
        // collapsed the non-unsupported cases all to `1`.
        XCTAssertNotEqual(unsupportedResult.features["reason"], providerResult.features["reason"])
        XCTAssertNotEqual(providerResult.features["reason"], lowConfResult.features["reason"])
        XCTAssertNotEqual(unsupportedResult.features["reason"], lowConfResult.features["reason"])
    }
}
