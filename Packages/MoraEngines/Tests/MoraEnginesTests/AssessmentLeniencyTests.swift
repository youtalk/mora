import MoraCore
import XCTest

@testable import MoraEngines

final class AssessmentLeniencyTests: XCTestCase {
    private let ship = Word(
        surface: "ship",
        graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
        phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
    )

    private func engine() -> AssessmentEngine {
        AssessmentEngine(l1Profile: JapaneseL1Profile())
    }

    func test_nearMissWithinEditDistance1_isCorrectUnderNewWord() {
        // "shi" — single omission, within one edit of "ship".
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shi", confidence: 0.5),
            leniency: .newWord
        )
        XCTAssertTrue(result.correct)
    }

    func test_sameNearMiss_isWrongUnderMastered() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shi", confidence: 0.5),
            leniency: .mastered
        )
        XCTAssertFalse(result.correct)
    }

    func test_lowConfidence_blocksLenientAccept() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shi", confidence: 0.1),
            leniency: .newWord
        )
        XCTAssertFalse(result.correct)
    }

    func test_twoEditDistance_rejectsUnderNewWord() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "si", confidence: 0.9),
            leniency: .newWord
        )
        XCTAssertFalse(result.correct)
    }
}
