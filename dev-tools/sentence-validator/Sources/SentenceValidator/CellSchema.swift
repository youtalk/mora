import Foundation

/// Per-file payload for `SentenceLibrary/{phoneme}/{interest}_{ageBand}.json`.
/// Mirrors the spec § 6.5 schema. Field names are `snake_case`-free to keep
/// Swift `Codable` synthesis trivial; the JSON uses the same camelCase keys.
struct CellPayload: Decodable {
    let phoneme: String  // e.g. "sh" — matches the directory name
    let phonemeIPA: String  // e.g. "ʃ"
    let graphemeLetters: String  // e.g. "sh" — letters of the target Grapheme
    let interest: String  // e.g. "vehicles" — matches InterestCategory.key
    let ageBand: String  // "early" | "mid" | "late"
    let sentences: [CellSentencePayload]
}

struct CellSentencePayload: Decodable {
    let text: String
    let targetCount: Int
    let targetInitialContentWords: Int
    let interestWords: [String]
    let words: [WordPayload]
}

/// Reuses the shape of `MoraEngines.ScriptedContentProvider.WordPayload`
/// (file: `Packages/MoraEngines/Sources/MoraEngines/ScriptedContentProvider.swift`,
/// lines 114–138) so the runtime loader and the validator decode the same JSON.
/// `note` is omitted; the library does not author per-word coaching notes.
struct WordPayload: Decodable {
    let surface: String
    let graphemes: [String]
    let phonemes: [String]
}
