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
        let shRow: [Float] = substituteSForSh
            ? [Float(log(0.2)), Float(log(0.75)), Float(log(0.025)), Float(log(0.025))]
            : [Float(log(0.9)), Float(log(0.05)), Float(log(0.025)), Float(log(0.025))]
        let iRow: [Float] = [Float(log(0.025)), Float(log(0.025)), Float(log(0.9)), Float(log(0.05))]
        let pRow: [Float] = [Float(log(0.025)), Float(log(0.025)), Float(log(0.05)), Float(log(0.9))]
        let rows = Array(repeating: shRow, count: shFrames)
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
}
