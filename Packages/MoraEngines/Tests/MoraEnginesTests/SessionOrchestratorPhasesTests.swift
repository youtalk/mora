import MoraCore
import XCTest

@testable import MoraEngines

@MainActor
final class SessionOrchestratorPhasesTests: XCTestCase {
    private func makeOrchestrator(
        words: [DecodeWord] = [],
        sentences: [DecodeSentence] = [],
        warmupOptions: [Grapheme] = []
    ) -> SessionOrchestrator {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(
                grapheme: .init(letters: "sh"),
                phoneme: .init(ipa: "ʃ")
            )
        )
        return SessionOrchestrator(
            target: Target(weekStart: Date(), skill: skill),
            taughtGraphemes: [],
            warmupOptions: warmupOptions.isEmpty
                ? [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")]
                : warmupOptions,
            words: words,
            sentences: sentences,
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
    }

    func test_start_beginsInWarmup() async {
        let o = makeOrchestrator()
        await o.start()
        XCTAssertEqual(o.phase, .warmup)
    }

    func test_warmup_correctTap_advancesToNewRule() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        XCTAssertEqual(o.phase, .newRule)
    }

    func test_warmup_incorrectTap_staysInWarmupAndCountsMiss() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "s")))
        XCTAssertEqual(o.phase, .warmup)
        XCTAssertEqual(o.warmupMissCount, 1)
    }

    func test_newRule_next_advancesToDecoding() async {
        let o = makeOrchestrator(words: [shipDW])
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        XCTAssertEqual(o.phase, .newRule)
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .decoding)
    }

    func test_advance_outsideNewRule_isIgnored() async {
        let o = makeOrchestrator(words: [shipDW])
        await o.start()
        XCTAssertEqual(o.phase, .warmup)
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .warmup)  // gating preserved
    }

    func test_emptyDecodingQueue_skipsToShortSentences() async {
        let o = makeOrchestrator(words: [], sentences: [shipDS])
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)  // newRule → decoding (auto-skipped)
        XCTAssertEqual(o.phase, .shortSentences)
    }

    func test_emptyDecodingAndSentenceQueues_skipsToCompletion() async {
        let o = makeOrchestrator(words: [], sentences: [])
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .completion)
    }

    private var shipDW: DecodeWord {
        DecodeWord(
            word: Word(
                surface: "ship",
                graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
                phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
            )
        )
    }

    private var shipDS: DecodeSentence {
        DecodeSentence(
            text: "Ship.",
            words: [
                Word(
                    surface: "ship",
                    graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
                    phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
                )
            ]
        )
    }
}
