import MoraCore
import XCTest

@testable import MoraEngines

@MainActor
final class SessionOrchestratorFullTests: XCTestCase {
    private func dw(_ s: String, graphemes: [String], phonemes: [String]) -> DecodeWord {
        DecodeWord(
            word: Word(
                surface: s,
                graphemes: graphemes.map { Grapheme(letters: $0) },
                phonemes: phonemes.map { Phoneme(ipa: $0) }
            )
        )
    }

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
            taughtGraphemes: [],
            warmupOptions: [
                .init(letters: "s"),
                .init(letters: "sh"),
                .init(letters: "ch"),
            ],
            words: [
                dw("ship", graphemes: ["sh", "i", "p"], phonemes: ["ʃ", "ɪ", "p"]),
                dw("shop", graphemes: ["sh", "o", "p"], phonemes: ["ʃ", "ɒ", "p"]),
                dw("fish", graphemes: ["f", "i", "sh"], phonemes: ["f", "ɪ", "ʃ"]),
            ],
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
        for _ in 0..<3 {
            await o.handle(
                .answerResult(
                    correct: true,
                    asr: ASRResult(transcript: "x", confidence: 1)
                )
            )
        }
        XCTAssertEqual(o.phase, .shortSentences)
        XCTAssertEqual(o.trials.count, 3)
    }

    func test_decodingMiss_isRecordedInTrials() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        // First word is "ship"; simulate a miss with transcript "sip".
        // This miss's L1 tagging is covered by AssessmentEngine tests;
        // the orchestrator's job here is just to record the trial.
        await o.handle(
            .answerResult(
                correct: false,
                asr: ASRResult(transcript: "sip", confidence: 0.5)
            )
        )
        XCTAssertEqual(o.trials.count, 1)
        XCTAssertEqual(o.trials.first?.correct, false)
        XCTAssertEqual(o.trials.first?.heard, "sip")
    }

    func test_shortSentences_advanceToCompletion() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        for _ in 0..<3 {
            await o.handle(
                .answerResult(
                    correct: true,
                    asr: ASRResult(transcript: "x", confidence: 1)
                )
            )
        }
        XCTAssertEqual(o.phase, .shortSentences)
        for _ in 0..<2 {
            await o.handle(
                .answerResult(
                    correct: true,
                    asr: ASRResult(transcript: "x", confidence: 1)
                )
            )
        }
        XCTAssertEqual(o.phase, .completion)
    }

    func test_summaryAfterCompletion_reportsTrialCounts() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        for i in 0..<3 {
            await o.handle(
                .answerResult(
                    correct: i != 1,  // one miss
                    asr: ASRResult(transcript: "x", confidence: 1)
                )
            )
        }
        for _ in 0..<2 {
            await o.handle(
                .answerResult(
                    correct: true,
                    asr: ASRResult(transcript: "x", confidence: 1)
                )
            )
        }
        XCTAssertEqual(o.phase, .completion)
        let summary = o.sessionSummary(endedAt: Date(timeIntervalSince1970: 900))
        XCTAssertEqual(summary.trialsTotal, 5)
        XCTAssertEqual(summary.trialsCorrect, 4)
        XCTAssertEqual(summary.targetSkillCode, "sh_onset")
        XCTAssertEqual(summary.sessionType, .coreDecoder)
        XCTAssertEqual(summary.durationSec, 900)
    }
}
