import Foundation
import MoraCore

/// Local copy of the fixture word chains, mirroring
/// `MoraTesting.FixtureWordChains`. Lives here because `MoraEngines` test
/// targets cannot depend on `MoraTesting` (that package depends on
/// `MoraEngines`, which would create a cycle). Keep this in sync with the
/// authoritative copy in `MoraTesting/Sources/MoraTesting/FixtureWordChains.swift`.
enum FixtureWordChains {
    private static func word(_ surface: String, _ gs: [String]) -> Word {
        Word(surface: surface, graphemes: gs.map { Grapheme(letters: $0) }, phonemes: [])
    }

    static func shInventory() -> Set<Grapheme> {
        Set(
            ["c", "a", "t", "u", "h", "sh", "i", "o", "p", "f", "d", "w", "m", "s"].map {
                Grapheme(letters: $0)
            })
    }

    static func shPhase() -> [WordChain] {
        let inv = shInventory()
        return [
            WordChain(
                role: .warmup,
                head: BuildTarget(word: word("cat", ["c", "a", "t"])),
                successorWords: [
                    word("cut", ["c", "u", "t"]),
                    word("hut", ["h", "u", "t"]),
                    word("hat", ["h", "a", "t"]),
                ],
                inventory: inv
            )!,
            WordChain(
                role: .targetIntro,
                head: BuildTarget(word: word("ship", ["sh", "i", "p"])),
                successorWords: [
                    word("shop", ["sh", "o", "p"]),
                    word("shot", ["sh", "o", "t"]),
                    word("shut", ["sh", "u", "t"]),
                ],
                inventory: inv
            )!,
            WordChain(
                role: .mixedApplication,
                head: BuildTarget(word: word("fish", ["f", "i", "sh"])),
                successorWords: [
                    word("dish", ["d", "i", "sh"]),
                    word("wish", ["w", "i", "sh"]),
                    word("wash", ["w", "a", "sh"]),
                ],
                inventory: inv
            )!,
        ]
    }
}
