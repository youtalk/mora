import Foundation
import MoraCore
import MoraEngines

/// Maps a `SentenceLibrary/<dir>/...` directory name to the corresponding
/// `SkillCode`, target `Grapheme`, and the curriculum week index used to
/// resolve `taughtGraphemes(beforeWeekIndex:)`.
///
/// The five directories match `CurriculumEngine.defaultV1Ladder()` skills in
/// order. This table lives here (not in `MoraCore`) because the runtime never
/// needs the directory-name string; only the validator does.
struct PhonemeDirectoryMap {
    let directory: String
    let skillCode: SkillCode
    let target: Grapheme
    let weekIndex: Int

    static let all: [PhonemeDirectoryMap] = [
        .init(directory: "sh",      skillCode: "sh_onset",     target: .init(letters: "sh"), weekIndex: 0),
        .init(directory: "th",      skillCode: "th_voiceless", target: .init(letters: "th"), weekIndex: 1),
        .init(directory: "f",       skillCode: "f_onset",      target: .init(letters: "f"),  weekIndex: 2),
        .init(directory: "r",       skillCode: "r_onset",      target: .init(letters: "r"),  weekIndex: 3),
        .init(directory: "short_a", skillCode: "short_a",      target: .init(letters: "a"),  weekIndex: 4),
    ]

    static func lookup(directory: String) -> PhonemeDirectoryMap? {
        all.first { $0.directory == directory }
    }
}
