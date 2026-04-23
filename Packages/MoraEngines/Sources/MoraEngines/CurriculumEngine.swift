import Foundation
import MoraCore

public struct CurriculumEngine: Sendable {
    public let skills: [Skill]
    public let baselineTaughtGraphemes: Set<Grapheme>

    public init(skills: [Skill], baselineTaughtGraphemes: Set<Grapheme>) {
        precondition(!skills.isEmpty, "CurriculumEngine needs at least one skill")
        self.skills = skills
        self.baselineTaughtGraphemes = baselineTaughtGraphemes
    }

    public func currentTarget(forWeekIndex week: Int, weekStart: Date = Date()) -> Target {
        let idx = max(0, min(week, skills.count - 1))
        return Target(weekStart: weekStart, skill: skills[idx])
    }

    /// Graphemes a learner is assumed to have mastered before the given
    /// week begins — i.e. baseline plus every skill grapheme from
    /// `skills[0..<week]`. Exclusive on the right: at `week == 0` only
    /// the baseline is returned (the week-0 target itself is not yet taught).
    /// Negative `week` clamps to 0.
    public func taughtGraphemes(beforeWeekIndex week: Int) -> Set<Grapheme> {
        var accumulated = baselineTaughtGraphemes
        let upperBound = min(max(0, week), skills.count)
        for i in 0..<upperBound {
            if let gp = skills[i].graphemePhoneme {
                accumulated.insert(gp.grapheme)
            }
        }
        return accumulated
    }

    /// Shared singleton used by HomeView and SessionContainerView so the ladder
    /// builder (and its ~30 static Grapheme allocations) runs once per launch
    /// rather than on every SwiftUI body evaluation or session bootstrap.
    public static let sharedV1: CurriculumEngine = defaultV1Ladder()

    public static func defaultV1Ladder() -> CurriculumEngine {
        let l2Alphabet: Set<Grapheme> = Set(
            "abcdefghijklmnopqrstuvwxyz".map { Grapheme(letters: String($0)) }
        )

        let l3Skills: [Skill] = [
            Skill(
                code: "sh_onset", level: .l3, displayName: "sh digraph",
                graphemePhoneme: .init(
                    grapheme: .init(letters: "sh"),
                    phoneme: .init(ipa: "ʃ")
                )
            ),
            Skill(
                code: "ch_onset", level: .l3, displayName: "ch digraph",
                graphemePhoneme: .init(
                    grapheme: .init(letters: "ch"),
                    phoneme: .init(ipa: "tʃ")
                )
            ),
            Skill(
                code: "th_voiceless", level: .l3, displayName: "voiceless th",
                graphemePhoneme: .init(
                    grapheme: .init(letters: "th"),
                    phoneme: .init(ipa: "θ")
                )
            ),
            Skill(
                code: "ck_coda", level: .l3, displayName: "ck digraph",
                graphemePhoneme: .init(
                    grapheme: .init(letters: "ck"),
                    phoneme: .init(ipa: "k")
                )
            ),
        ]

        return CurriculumEngine(skills: l3Skills, baselineTaughtGraphemes: l2Alphabet)
    }

    // MARK: - Test fixtures (internal; test targets only)

    /// Three ship-week decoding words with targetPhoneme set to /ʃ/.
    /// Used by tests to exercise the Engine A pipeline end-to-end without
    /// pulling in a full bundled-content fixture.
    static func testShipFixtureWords() -> [Word] {
        [
            Word(
                surface: "ship",
                graphemes: [
                    Grapheme(letters: "sh"),
                    Grapheme(letters: "i"),
                    Grapheme(letters: "p"),
                ],
                phonemes: [
                    Phoneme(ipa: "ʃ"),
                    Phoneme(ipa: "ɪ"),
                    Phoneme(ipa: "p"),
                ],
                targetPhoneme: Phoneme(ipa: "ʃ")
            ),
            Word(
                surface: "shop",
                graphemes: [
                    Grapheme(letters: "sh"),
                    Grapheme(letters: "o"),
                    Grapheme(letters: "p"),
                ],
                phonemes: [
                    Phoneme(ipa: "ʃ"),
                    Phoneme(ipa: "ɒ"),
                    Phoneme(ipa: "p"),
                ],
                targetPhoneme: Phoneme(ipa: "ʃ")
            ),
            Word(
                surface: "fish",
                graphemes: [
                    Grapheme(letters: "f"),
                    Grapheme(letters: "i"),
                    Grapheme(letters: "sh"),
                ],
                phonemes: [
                    Phoneme(ipa: "f"),
                    Phoneme(ipa: "ɪ"),
                    Phoneme(ipa: "ʃ"),
                ],
                targetPhoneme: Phoneme(ipa: "ʃ")
            ),
        ]
    }
}
