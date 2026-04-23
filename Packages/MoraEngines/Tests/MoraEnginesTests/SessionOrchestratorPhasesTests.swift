import MoraCore
import XCTest

@testable import MoraEngines

@MainActor
final class SessionOrchestratorPhasesTests: XCTestCase {
    private func makeOrchestrator(
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
            taughtGraphemes: FixtureWordChains.shInventory(),
            warmupOptions: warmupOptions.isEmpty
                ? [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")]
                : warmupOptions,
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
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
        try XCTSkip("Tile-board decoding wiring lands in 18b")
    }

    func test_advance_outsideNewRule_isIgnored() async {
        let o = makeOrchestrator()
        await o.start()
        XCTAssertEqual(o.phase, .warmup)
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .warmup)  // gating preserved
    }

    func test_emptyDecodingQueue_skipsToShortSentences() async {
        let o = makeOrchestrator(sentences: [shipDS])
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)  // newRule → decoding (auto-skipped)
        XCTAssertEqual(o.phase, .shortSentences)
    }

    func test_emptyDecodingAndSentenceQueues_skipsToCompletion() async {
        let o = makeOrchestrator(sentences: [])
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .completion)
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
