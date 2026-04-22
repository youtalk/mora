import MoraCore
import XCTest

@testable import MoraEngines

final class AssessmentEngineL1Tests: XCTestCase {
    private let engine = AssessmentEngine(
        l1Profile: JapaneseL1Profile(),
        leniency: 0.5
    )

    // "light" misread as "right" → r/l swap.
    // Both words have 5 graphemes / 5 chars, so the length-diff classifier
    // must report substitution; asserting it here guards against accidental
    // regressions in scoring that would otherwise still leave the L1 tag intact.
    func test_rightForLight_tagsRLSwap() {
        let light = Word(
            surface: "light",
            graphemes: [
                .init(letters: "l"), .init(letters: "i"),
                .init(letters: "g"), .init(letters: "h"), .init(letters: "t"),
            ],
            phonemes: [.init(ipa: "l"), .init(ipa: "aɪ"), .init(ipa: "t")]
        )
        let a = engine.assess(
            expected: light,
            asr: ASRResult(transcript: "right", confidence: 0.8)
        )
        XCTAssertFalse(a.correct)
        XCTAssertEqual(a.errorKind, .substitution)
        XCTAssertEqual(a.l1InterferenceTag, "r_l_swap")
    }

    // "fat" misread as "hat" → f → h. Same length, so substitution.
    func test_hatForFat_tagsFHSub() {
        let fat = Word(
            surface: "fat",
            graphemes: [.init(letters: "f"), .init(letters: "a"), .init(letters: "t")],
            phonemes: [.init(ipa: "f"), .init(ipa: "æ"), .init(ipa: "t")]
        )
        let a = engine.assess(
            expected: fat,
            asr: ASRResult(transcript: "hat", confidence: 0.7)
        )
        XCTAssertEqual(a.errorKind, .substitution)
        XCTAssertEqual(a.l1InterferenceTag, "f_h_sub")
    }

    // "hat" misread as "fat" → not tagged (f_h is one-direction).
    // Still a substitution at the scoring layer; the tag is what changes.
    func test_fatForHat_notTagged() {
        let hat = Word(
            surface: "hat",
            graphemes: [.init(letters: "h"), .init(letters: "a"), .init(letters: "t")],
            phonemes: [.init(ipa: "h"), .init(ipa: "æ"), .init(ipa: "t")]
        )
        let a = engine.assess(
            expected: hat,
            asr: ASRResult(transcript: "fat", confidence: 0.7)
        )
        XCTAssertEqual(a.errorKind, .substitution)
        XCTAssertNil(a.l1InterferenceTag)
    }

    // correct word → no tag
    func test_exactMatch_noTag() {
        let ship = Word(
            surface: "ship",
            graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
            phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
        )
        let a = engine.assess(
            expected: ship,
            asr: ASRResult(transcript: "ship", confidence: 1.0)
        )
        XCTAssertNil(a.l1InterferenceTag)
    }
}
