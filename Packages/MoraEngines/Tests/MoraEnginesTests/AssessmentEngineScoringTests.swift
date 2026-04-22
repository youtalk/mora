import MoraCore
import XCTest

@testable import MoraEngines

final class AssessmentEngineScoringTests: XCTestCase {
    private let ship = Word(
        surface: "ship",
        graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
        phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
    )

    private func engine() -> AssessmentEngine {
        AssessmentEngine(l1Profile: JapaneseL1Profile(), leniency: 0.5)
    }

    func test_exactMatch_isCorrect() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "ship", confidence: 0.95)
        )
        XCTAssertTrue(result.correct)
        XCTAssertEqual(result.errorKind, .none)
        XCTAssertNil(result.l1InterferenceTag)
    }

    func test_caseAndWhitespace_normalizedBeforeMatching() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "  Ship.  ", confidence: 0.9)
        )
        XCTAssertTrue(result.correct)
    }

    func test_emptyTranscript_isOmission() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "", confidence: 0.0)
        )
        XCTAssertFalse(result.correct)
        XCTAssertEqual(result.errorKind, .omission)
    }

    func test_substitution_ofSingleLetter() {
        // "sip" → edit distance 1 substitution of "sh" with "s"
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "sip", confidence: 0.7)
        )
        XCTAssertFalse(result.correct)
        XCTAssertEqual(result.errorKind, .substitution)
    }

    func test_insertion_extraPhoneme() {
        // "shipa"
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shipa", confidence: 0.6)
        )
        XCTAssertFalse(result.correct)
        XCTAssertEqual(result.errorKind, .insertion)
    }
}
