import MoraCore
import XCTest

@testable import MoraEngines

@MainActor
final class SessionOrchestratorFullTests: XCTestCase {
    private func ds(_ t: String, words: [(String, [String], [String])]) -> DecodeSentence {
        DecodeSentence(
            text: t,
            words: words.map { (s, g, p) in
                Word(
                    surface: s,
                    graphemes: g.map { Grapheme(letters: $0) },
                    phonemes: p.map { Phoneme(ipa: $0) }
                )
            }
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

    private func makeOrchestrator() -> SessionOrchestrator {
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
            warmupOptions: [
                .init(letters: "s"),
                .init(letters: "sh"),
                .init(letters: "ch"),
            ],
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
            sentences: [
                ds(
                    "The ship can hop.",
                    words: [
                        ("the", ["t", "h", "e"], ["ð", "ə"]),
                        ("ship", ["sh", "i", "p"], ["ʃ", "ɪ", "p"]),
                        ("can", ["c", "a", "n"], ["k", "æ", "n"]),
                        ("hop", ["h", "o", "p"], ["h", "ɒ", "p"]),
                    ]
                ),
                ds(
                    "A fish can wish.",
                    words: [
                        ("a", ["a"], ["ə"]),
                        ("fish", ["f", "i", "sh"], ["f", "ɪ", "ʃ"]),
                        ("can", ["c", "a", "n"], ["k", "æ", "n"]),
                        ("wish", ["w", "i", "sh"], ["w", "ɪ", "ʃ"]),
                    ]
                ),
            ],
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
    }

    func test_decoding_advancesWordIndexUntilDone() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)  // newRule → decoding
        XCTAssertEqual(o.phase, .decoding)
        for chain in FixtureWordChains.shPhase() {
            for word in chain.allWords {
                o.consumeTileBoardTrial(clean(word))
            }
        }
        XCTAssertEqual(o.phase, .shortSentences)
        XCTAssertEqual(o.trials.count, 12)
    }

    func test_decodingMiss_isRecordedInTrials() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        // A trial with an incorrect build attempt — the word was auto-filled.
        let word = FixtureWordChains.shPhase()[0].head.word
        let missedAttempt = BuildAttemptRecord(
            slotIndex: 0,
            tileDropped: Grapheme(letters: "x"),
            wasCorrect: false,
            timestampOffset: 0.5
        )
        let result = TileBoardTrialResult(
            word: word,
            buildAttempts: [missedAttempt],
            scaffoldLevel: 1,
            ttsHintIssued: false,
            poolReducedToTwo: false,
            autoFilled: false
        )
        o.consumeTileBoardTrial(result)
        XCTAssertEqual(o.trials.count, 1)
        XCTAssertTrue(o.trials.first?.correct ?? false)
    }

    func test_shortSentences_advanceToCompletion() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        for chain in FixtureWordChains.shPhase() {
            for word in chain.allWords {
                o.consumeTileBoardTrial(clean(word))
            }
        }
        XCTAssertEqual(o.phase, .shortSentences)
        for _ in 0..<2 {
            await o.handle(.answerManual(correct: true))
        }
        XCTAssertEqual(o.phase, .completion)
    }

    func test_summaryAfterCompletion_reportsTrialCounts() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        for chain in FixtureWordChains.shPhase() {
            for word in chain.allWords {
                o.consumeTileBoardTrial(clean(word))
            }
        }
        for _ in 0..<2 {
            await o.handle(.answerManual(correct: true))
        }
        XCTAssertEqual(o.phase, .completion)
        let summary = o.sessionSummary(endedAt: Date(timeIntervalSince1970: 900))
        XCTAssertEqual(summary.trialsTotal, 14)  // 12 decoding + 2 sentences
        XCTAssertEqual(summary.trialsCorrect, 14)
        XCTAssertEqual(summary.targetSkillCode, "sh_onset")
        XCTAssertEqual(summary.sessionType, .coreDecoder)
        XCTAssertEqual(summary.durationSec, 900)
    }
}
