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

    func testMedialFlagsUnreliable() {
        let clip = AudioClip(samples: Array(repeating: Float(0), count: 8_000), sampleRate: 16_000)
        let region = PhonemeRegionLocalizer.region(
            clip: clip,
            word: word,
            phonemePosition: .medial(position: 1, count: 3)
        )
        XCTAssertFalse(region.isReliable)
    }
}
