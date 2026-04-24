import AVFoundation
import MoraCore
import XCTest
@testable import MoraEngines

final class FeatureBasedEvaluatorFixtureTests: XCTestCase {

    private let evaluator = FeatureBasedPronunciationEvaluator()

    // MARK: - r / l

    func testRightCorrectMatchesR() async throws {
        let assessment = try await evaluate(
            "rl/right-correct.wav",
            target: "r", word: "right")
        XCTAssertEqual(assessment.label, .matched)
        XCTAssertTrue(assessment.isReliable, "onset fixture should be reliable after B1")
        let score = try XCTUnwrap(assessment.score)
        XCTAssertGreaterThanOrEqual(score, 70)
    }

    func testRightAsLightSubstitutedByL() async throws {
        let assessment = try await evaluate(
            "rl/right-as-light.wav",
            target: "r", word: "right")
        XCTAssertEqual(assessment.label, .substitutedBy(Phoneme(ipa: "l")))
        XCTAssertTrue(assessment.isReliable, "onset fixture should be reliable after B1")
        let score = try XCTUnwrap(assessment.score)
        XCTAssertLessThanOrEqual(score, 40)
    }

    func testLightCorrectMatchesL() async throws {
        let assessment = try await evaluate(
            "rl/light-correct.wav",
            target: "l", word: "light")
        XCTAssertEqual(assessment.label, .matched)
        XCTAssertTrue(assessment.isReliable, "onset fixture should be reliable after B1")
        let score = try XCTUnwrap(assessment.score)
        XCTAssertGreaterThanOrEqual(score, 70)
    }

    func testLightAsRightSubstitutedByR() async throws {
        let assessment = try await evaluate(
            "rl/light-as-right.wav",
            target: "l", word: "light")
        XCTAssertEqual(assessment.label, .substitutedBy(Phoneme(ipa: "r")))
        XCTAssertTrue(assessment.isReliable, "onset fixture should be reliable after B1")
        let score = try XCTUnwrap(assessment.score)
        XCTAssertLessThanOrEqual(score, 40)
    }

    // MARK: - v / b

    func testVeryCorrectMatchesV() async throws {
        let a = try await evaluate("vb/very-correct.wav", target: "v", word: "very")
        XCTAssertEqual(a.label, .matched)
        XCTAssertTrue(a.isReliable, "onset fixture should be reliable after B1")
        let s = try XCTUnwrap(a.score)
        XCTAssertGreaterThanOrEqual(s, 70)
    }

    func testVeryAsBerrySubstitutedByB() async throws {
        let a = try await evaluate("vb/very-as-berry.wav", target: "v", word: "very")
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "b")))
        XCTAssertTrue(a.isReliable, "onset fixture should be reliable after B1")
        let s = try XCTUnwrap(a.score)
        XCTAssertLessThanOrEqual(s, 40)
    }

    func testBerryCorrectMatchesB() async throws {
        let a = try await evaluate("vb/berry-correct.wav", target: "b", word: "berry")
        XCTAssertEqual(a.label, .matched)
        XCTAssertTrue(a.isReliable, "onset fixture should be reliable after B1")
        let s = try XCTUnwrap(a.score)
        XCTAssertGreaterThanOrEqual(s, 70)
    }

    func testBerryAsVerySubstitutedByV() async throws {
        let a = try await evaluate("vb/berry-as-very.wav", target: "b", word: "berry")
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "v")))
        XCTAssertTrue(a.isReliable, "onset fixture should be reliable after B1")
        let s = try XCTUnwrap(a.score)
        XCTAssertLessThanOrEqual(s, 40)
    }

    // MARK: - æ / ʌ

    func testCatCorrectMatchesAe() async throws {
        let a = try await evaluate(
            "aeuh/cat-correct.wav",
            target: "æ", word: "cat",
            phonemes: ["k", "æ", "t"], targetIndex: 1
        )
        XCTAssertEqual(a.label, .matched)
        XCTAssertTrue(a.isReliable, "medial fixture should be reliable after localizer fix")
        let s = try XCTUnwrap(a.score)
        XCTAssertGreaterThanOrEqual(s, 70)
    }

    func testCatAsCutSubstitutedByUh() async throws {
        let a = try await evaluate(
            "aeuh/cat-as-cut.wav",
            target: "æ", word: "cat",
            phonemes: ["k", "æ", "t"], targetIndex: 1
        )
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "ʌ")))
        XCTAssertTrue(a.isReliable, "medial fixture should be reliable after localizer fix")
        let s = try XCTUnwrap(a.score)
        XCTAssertLessThanOrEqual(s, 40)
    }

    func testCutCorrectMatchesUh() async throws {
        let a = try await evaluate(
            "aeuh/cut-correct.wav",
            target: "ʌ", word: "cut",
            phonemes: ["k", "ʌ", "t"], targetIndex: 1
        )
        XCTAssertEqual(a.label, .matched)
        XCTAssertTrue(a.isReliable, "medial fixture should be reliable after localizer fix")
        let s = try XCTUnwrap(a.score)
        XCTAssertGreaterThanOrEqual(s, 70)
    }

    func testCutAsCatSubstitutedByAe() async throws {
        let a = try await evaluate(
            "aeuh/cut-as-cat.wav",
            target: "ʌ", word: "cut",
            phonemes: ["k", "ʌ", "t"], targetIndex: 1
        )
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "æ")))
        XCTAssertTrue(a.isReliable, "medial fixture should be reliable after localizer fix")
        let s = try XCTUnwrap(a.score)
        XCTAssertLessThanOrEqual(s, 40)
    }

    // MARK: - Loader

    private func evaluate(
        _ relative: String, target ipa: String, word surface: String,
        phonemes: [String]? = nil, targetIndex: Int? = nil
    ) async throws -> PhonemeTrialAssessment {
        let relNS = relative as NSString
        let basename = (relNS.deletingPathExtension as NSString).lastPathComponent
        let subdir = "Fixtures/" + relNS.deletingLastPathComponent
        guard
            let url = Bundle.module.url(
                forResource: basename,
                withExtension: "wav",
                subdirectory: subdir
            )
        else {
            throw XCTSkip("fixture not found: \(relative)")
        }

        let (samples, sampleRate) = try readMono16k(from: url)
        let audio = AudioClip(samples: samples, sampleRate: sampleRate)
        let target = Phoneme(ipa: ipa)
        // Mirror EngineARunner.evaluate's defensive fallback: only honour a
        // caller-supplied sequence when it's non-empty and the provided
        // index is in-range. Any other shape (nil, empty, out-of-range)
        // silently falls back to `[target]` so the array subscript
        // `phonemeList[idx]` is safe.
        let phonemeList: [Phoneme]
        let idx: Int
        if let phonemes, !phonemes.isEmpty,
            let targetIndex, targetIndex >= 0, targetIndex < phonemes.count
        {
            phonemeList = phonemes.map { Phoneme(ipa: $0) }
            idx = targetIndex
        } else {
            phonemeList = [target]
            idx = 0
        }
        let word = Word(
            surface: surface,
            graphemes: [Grapheme(letters: surface)],
            phonemes: phonemeList,
            targetPhoneme: phonemeList[idx]
        )
        return await evaluator.evaluate(
            audio: audio, expected: word, targetPhoneme: phonemeList[idx],
            asr: ASRResult(transcript: surface, confidence: 0.9)
        )
    }

    private func readMono16k(from url: URL) throws -> ([Float], Double) {
        let file = try AVAudioFile(forReading: url)
        let hardwareFormat = file.processingFormat
        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                channels: 1, interleaved: false
            ), let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat),
            let inBuf = AVAudioPCMBuffer(
                pcmFormat: hardwareFormat, frameCapacity: AVAudioFrameCount(file.length)
            )
        else {
            throw fixtureLoadError(
                reason: "could not prepare 16 kHz mono Float32 decode stack", url: url
            )
        }

        try file.read(into: inBuf)
        let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 16
        guard
            let outBuf = AVAudioPCMBuffer(
                pcmFormat: targetFormat, frameCapacity: capacity
            )
        else {
            throw fixtureLoadError(
                reason: "could not allocate \(capacity)-frame output buffer", url: url
            )
        }

        var done = false
        var err: NSError?
        _ = converter.convert(to: outBuf, error: &err) { _, s in
            if done { s.pointee = .noDataNow; return nil }
            done = true; s.pointee = .haveData; return inBuf
        }
        if let err { throw err }
        guard let ch = outBuf.floatChannelData else {
            throw fixtureLoadError(
                reason: "floatChannelData unavailable after convert", url: url
            )
        }
        let samples = Array(
            UnsafeBufferPointer(
                start: ch[0],
                count: Int(outBuf.frameLength)))
        return (samples, targetFormat.sampleRate)
    }

    private func fixtureLoadError(reason: String, url: URL) -> NSError {
        NSError(
            domain: "FixtureLoad", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "\(reason): \(url.lastPathComponent)"]
        )
    }
}
