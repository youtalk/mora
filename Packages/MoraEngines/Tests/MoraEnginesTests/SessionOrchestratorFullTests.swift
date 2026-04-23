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
        try XCTSkip("Tile-board decoding wiring lands in 18b")
    }

    func test_decodingMiss_isRecordedInTrials() async {
        try XCTSkip("Tile-board decoding wiring lands in 18b")
    }

    func test_shortSentences_advanceToCompletion() async {
        try XCTSkip("Tile-board decoding wiring lands in 18b")
    }

    func test_summaryAfterCompletion_reportsTrialCounts() async {
        try XCTSkip("Tile-board decoding wiring lands in 18b")
    }
}
