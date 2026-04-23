import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class SessionOrchestratorTileBoardFlowTests: XCTestCase {
    private func makeOrchestrator() -> SessionOrchestrator {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(grapheme: .init(letters: "sh"), phoneme: .init(ipa: "ʃ"))
        )
        // Provide one sentence so .shortSentences is not immediately skipped,
        // allowing assertions on the phase after decoding completes.
        let sentence = DecodeSentence(
            text: "The ship can hop.",
            words: [
                Word(
                    surface: "ship",
                    graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
                    phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
                )
            ]
        )
        return SessionOrchestrator(
            target: Target(weekStart: Date(), skill: skill),
            taughtGraphemes: FixtureWordChains.shInventory(),
            warmupOptions: [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")],
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
            sentences: [sentence],
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
    }

    private func clean(_ word: Word) -> TileBoardTrialResult {
        TileBoardTrialResult(
            word: word,
            buildAttempts: [],
            scaffoldLevel: 0,
            ttsHintIssued: false,
            poolReducedToTwo: false,
            autoFilled: false
        )
    }

    func testTwelveCleanTrialsAdvanceToShortSentences() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .decoding)
        for chain in FixtureWordChains.shPhase() {
            for word in chain.allWords {
                o.consumeTileBoardTrial(clean(word))
            }
        }
        XCTAssertEqual(o.phase, .shortSentences)
        XCTAssertEqual(o.trials.count, 12)
        XCTAssertEqual(o.completedTrialCount, 12)
    }

    func testChainBoundaryEmitsChainFinished() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        var observedEvents: [OrchestratorEvent] = []
        o.onTileBoardEvent = { event in observedEvents.append(event) }
        for word in FixtureWordChains.shPhase()[0].allWords {
            o.consumeTileBoardTrial(clean(word))
        }
        XCTAssertTrue(observedEvents.contains(.chainFinished(.warmup)))
    }
}
