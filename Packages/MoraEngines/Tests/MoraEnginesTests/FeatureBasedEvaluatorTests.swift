import XCTest
import MoraCore
@testable import MoraEngines

final class FeatureBasedEvaluatorTests: XCTestCase {
    private let evaluator = FeatureBasedPronunciationEvaluator()

    private func ship() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    func testSupportsListedTargets() {
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "ʃ"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "r"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "f"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "v"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "θ"), in: ship()))
        XCTAssertTrue(evaluator.supports(target: Phoneme(ipa: "æ"), in: ship()))
    }

    func testDoesNotSupportUnlistedTargets() {
        XCTAssertFalse(evaluator.supports(target: Phoneme(ipa: "k"), in: ship()))
        XCTAssertFalse(evaluator.supports(target: Phoneme(ipa: "n"), in: ship()))
    }
}
