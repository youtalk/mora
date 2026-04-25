import Foundation
import MoraCore

/// Bundled decodable-sentence library. Each cell is identified by
/// `(phoneme, interest, ageBand)` and contains up to 20 sentences whose
/// authoring rules are enforced at PR time by
/// `dev-tools/sentence-validator/`.
///
/// Track B-1 ships only one populated cell (`sh × vehicles × mid`); B-2
/// fills the remaining 89 cells via additional JSON commits with no code
/// changes. The selector method body is a `fatalError` placeholder filled
/// by Track B-3.
public actor SentenceLibrary {
    public struct Cell: Sendable {
        public let phoneme: String
        public let phonemeIPA: String
        public let graphemeLetters: String
        public let interest: String
        public let ageBand: AgeBand
        public let sentences: [DecodeSentence]
    }

    private let cells: [CellKey: Cell]

    public init(bundle: Bundle) throws {
        self.cells = try Self.loadCells(from: bundle)
    }

    /// Number of populated cells. Test-only convenience.
    public var cellCount: Int { cells.count }

    /// Lookup a cell by `(phoneme directory name, interest key, ageBand)`.
    /// Returns nil for empty cells (i.e. cells whose JSON file does not exist).
    public func cell(phoneme: String, interest: String, ageBand: AgeBand) -> Cell? {
        cells[CellKey(phoneme: phoneme, interest: interest, ageBand: ageBand)]
    }

    /// Selector — Track B-3 fills the body. The signature here matches spec
    /// sec 6.6 so B-3 lands as a body-only change.
    public func sentences(
        target: SkillCode,
        interests: [String],
        ageYears: Int,
        excluding seenSurfaces: Set<String> = [],
        count: Int
    ) async -> [DecodeSentence] {
        fatalError("SentenceLibrary.sentences — selector wiring is Track B-3")
    }
}

// MARK: - Cell loading

extension SentenceLibrary {
    private struct CellKey: Hashable {
        let phoneme: String
        let interest: String
        let ageBand: AgeBand
    }

    private struct CellPayload: Decodable {
        let phoneme: String
        let phonemeIPA: String
        let graphemeLetters: String
        let interest: String
        let ageBand: String
        let sentences: [SentencePayload]
    }

    private struct SentencePayload: Decodable {
        let text: String
        let words: [WordPayload]
    }

    private struct WordPayload: Decodable {
        let surface: String
        let graphemes: [String]
        let phonemes: [String]
    }

    private static let phonemeDirectories: [String] = [
        "sh", "th", "f", "r", "short_a",
    ]

    private static func loadCells(from bundle: Bundle) throws -> [CellKey: Cell] {
        guard let root = bundle.url(forResource: "SentenceLibrary", withExtension: nil) else {
            return [:]  // resource not present — cells map empty, callers fall back
        }
        var out: [CellKey: Cell] = [:]
        let fm = FileManager.default
        for dir in phonemeDirectories {
            let phonemeURL = root.appendingPathComponent(dir, isDirectory: true)
            guard
                let entries = try? fm.contentsOfDirectory(
                    at: phonemeURL,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
            else {
                continue
            }
            for url in entries where url.pathExtension == "json" {
                let data = try Data(contentsOf: url)
                let payload = try JSONDecoder().decode(CellPayload.self, from: data)
                guard let band = AgeBand(rawValue: payload.ageBand) else {
                    continue
                }
                let key = CellKey(phoneme: payload.phoneme, interest: payload.interest, ageBand: band)
                out[key] = Cell(
                    phoneme: payload.phoneme,
                    phonemeIPA: payload.phonemeIPA,
                    graphemeLetters: payload.graphemeLetters,
                    interest: payload.interest,
                    ageBand: band,
                    sentences: payload.sentences.map { p in
                        DecodeSentence(
                            text: p.text,
                            words: p.words.map { w in
                                Word(
                                    surface: w.surface,
                                    graphemes: w.graphemes.map { Grapheme(letters: $0) },
                                    phonemes: w.phonemes.map { Phoneme(ipa: $0) }
                                )
                            }
                        )
                    }
                )
            }
        }
        return out
    }
}
