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
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        XCTAssertEqual(o.phase, .newRule)
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .decoding)
    }
}
