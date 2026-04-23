import MoraCore
import MoraEngines
import SwiftUI

private func previewSkill() -> Skill {
    Skill(
        code: "sh_onset",
        level: .l3,
        displayName: "sh",
        graphemePhoneme: .init(
            grapheme: .init(letters: "sh"),
            phoneme: .init(ipa: "ʃ")
        )
    )
}

#Preview("Build trial") {
    let word = Word(
        surface: "ship",
        graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
        phonemes: []
    )
    let trial = TileBoardTrial.build(
        target: BuildTarget(word: word),
        pool: [
            Tile(grapheme: Grapheme(letters: "sh")),
            Tile(grapheme: Grapheme(letters: "i")),
            Tile(grapheme: Grapheme(letters: "p")),
            Tile(grapheme: Grapheme(letters: "ch")),
        ]
    )
    return DecodeBoardView(
        engine: TileBoardEngine(trial: trial),
        target: Target(weekStart: .now, skill: previewSkill()),
        chainPipStates: Array(repeating: .pending, count: 12),
        incomingRole: .targetIntro
    )
}

#Preview("Change trial") {
    let pred = Word(
        surface: "ship",
        graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
        phonemes: []
    )
    let succ = Word(
        surface: "shop",
        graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "o"), Grapheme(letters: "p")],
        phonemes: []
    )
    let change = ChangeTarget(predecessor: pred, successor: succ)!
    let trial = TileBoardTrial.change(
        target: change,
        lockedSlots: pred.graphemes,
        pool: [
            Tile(grapheme: Grapheme(letters: "o")),
            Tile(grapheme: Grapheme(letters: "a")),
            Tile(grapheme: Grapheme(letters: "u")),
        ]
    )
    return DecodeBoardView(
        engine: TileBoardEngine(trial: trial),
        target: Target(weekStart: .now, skill: previewSkill()),
        chainPipStates: Array(repeating: .done, count: 5) + [.active]
            + Array(repeating: .pending, count: 6),
        incomingRole: .targetIntro
    )
}
