import XCTest
import MoraCore
@testable import MoraEngines

final class PhonemeRegionLocalizerTests: XCTestCase {
    private let word = Word(
        surface: "ship",
        graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
        phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
        targetPhoneme: Phoneme(ipa: "ʃ")
    )

    func testOnsetSlicesFirstHalfOfShortWord() {
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 8_000), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip,
            word: word,
            phonemePosition: .onset
        )
        XCTAssertEqual(region.clip.samples.count, 2_000)  // 125 ms of 500 ms word = 25%
        XCTAssertTrue(region.isReliable)
    }

    func testCodaSlicesLastRegion() {
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 8_000), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip,
            word: word,
            phonemePosition: .coda
        )
        XCTAssertEqual(region.clip.samples.count, 2_000)
        XCTAssertTrue(region.isReliable)
    }

    func testMedialReliableAndCenteredForCVC() {
        // 600 ms clip at 16 kHz = 9_600 samples; medial of 3 phonemes →
        // unit = 200 ms = 3_200 samples starting at 200 ms = 3_200 samples.
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 9_600), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip,
            word: word,
            phonemePosition: .medial(position: 1, count: 3)
        )
        XCTAssertEqual(region.startMs, 200, accuracy: 0.01)
        XCTAssertEqual(region.durationMs, 200, accuracy: 0.01)
        XCTAssertEqual(region.clip.samples.count, 3_200)
        XCTAssertTrue(region.isReliable)
    }

    func testMedialOutOfBoundsFlagsUnreliable() {
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 8_000), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip,
            word: word,
            phonemePosition: .medial(position: 5, count: 3)
        )
        XCTAssertFalse(region.isReliable)
    }

    func testLiquidOnsetUsesShorterWindow() {
        // 1 s clip at 16 kHz = 16_000 samples. /l/ onset → 60 ms = 960 samples.
        let lightWord = Word(
            surface: "light",
            graphemes: [Grapheme(letters: "l"), Grapheme(letters: "i"), Grapheme(letters: "ght")],
            phonemes: [Phoneme(ipa: "l"), Phoneme(ipa: "aɪ"), Phoneme(ipa: "t")],
            targetPhoneme: Phoneme(ipa: "l")
        )
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 16_000), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip, word: lightWord, phonemePosition: .onset
        )
        XCTAssertEqual(region.clip.samples.count, 960)
        XCTAssertEqual(region.durationMs, 60, accuracy: 0.01)
        XCTAssertTrue(region.isReliable)
    }

    func testNonLiquidOnsetKeepsExistingWindow() {
        // Regression guard: /ʃ/ onset stays at the existing 150 ms / 25%-of-clip rule.
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 16_000), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip, word: word, phonemePosition: .onset
        )
        XCTAssertEqual(region.clip.samples.count, 2_400)  // 150 ms of 1 s = 2_400 samples
        XCTAssertEqual(region.durationMs, 150, accuracy: 0.01)
    }
}
