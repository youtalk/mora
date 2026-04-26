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

    /// Loads the cells bundled with MoraEngines. Use this from app code and
    /// from tests living in the MoraEngines test target — `Bundle.module`
    /// resolved from a test file points at the test target's bundle, not at
    /// the MoraEngines resource bundle, so the explicit `init(bundle:)` form
    /// would lookup the wrong place.
    public init() throws {
        try self.init(bundle: .module)
    }

    public init(bundle: Bundle) throws {
        self.cells = try Self.loadCells(from: bundle)
    }

    /// Initialise directly from a root `SentenceLibrary/` directory URL.
    /// Intended for tests that need to inject a hand-crafted directory tree
    /// without constructing an `NSBundle`.
    init(rootURL: URL) throws {
        self.cells = try Self.loadCells(from: rootURL)
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
        guard let directory = Self.directoryForSkillCode[target] else {
            return []
        }
        let band = AgeBand.from(years: ageYears)

        // Empty interests → use all six (per spec § 6.6 step 3).
        let interestKeys = interests.isEmpty ? Self.allInterestKeys : interests

        // Look up every cell that exists for the resolved (directory, band)
        // across the learner's interests; missing cells are skipped silently.
        let cellsForTarget: [Cell] = interestKeys.compactMap { interest in
            cells[CellKey(phoneme: directory, interest: interest, ageBand: band)]
        }
        if cellsForTarget.isEmpty { return [] }

        let pool = cellsForTarget.flatMap(\.sentences)
        let filtered = pool.filter { !seenSurfaces.contains($0.text) }

        // Spec § 6.6 step 5/6: prefer the freshness-respecting pool; relax if
        // the filter starved the pool below `count`.
        let candidates = filtered.count >= count ? filtered : pool

        return Array(candidates.shuffled().prefix(count))
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

    /// Map from runtime `SkillCode` to the on-disk directory name used by
    /// `Resources/SentenceLibrary/<dir>/<interest>_<ageBand>.json`. Mirrors
    /// `dev-tools/sentence-validator`'s `PhonemeDirectoryMap.all`; the two
    /// cannot share because the validator target is outside the app build.
    /// Keep this in sync when the v1 ladder skill codes change.
    private static let directoryForSkillCode: [SkillCode: String] = [
        "sh_onset": "sh",
        "th_voiceless": "th",
        "f_onset": "f",
        "r_onset": "r",
        "short_a": "short_a",
    ]

    /// Interest keys derived from `JapaneseL1Profile.interestCategories`
    /// (the v1 source of truth). Used as the fallback set when a learner
    /// has no `interests` recorded (e.g. a profile from before the interest
    /// picker shipped — only the dev profile is in this state).
    private static let allInterestKeys: [String] =
        JapaneseL1Profile().interestCategories.map(\.key)

    private static let phonemeDirectories: [String] = [
        "sh", "th", "f", "r", "short_a",
    ]

    /// Errors surfaced during cell loading.
    private enum LoaderError: Error, CustomStringConvertible {
        case invalidAgeBand(url: URL, value: String)
        case payloadFilenameMismatch(url: URL, field: String, payloadValue: String, pathValue: String)

        var description: String {
            switch self {
            case let .invalidAgeBand(url, value):
                return
                    "SentenceLibrary: invalid ageBand '\(value)' in \(url.lastPathComponent) — expected early|mid|late"
            case let .payloadFilenameMismatch(url, field, payloadValue, pathValue):
                return
                    "SentenceLibrary: payload '\(field)' is '\(payloadValue)' but path implies '\(pathValue)' in \(url.path)"
            }
        }
    }

    private static func loadCells(from bundle: Bundle) throws -> [CellKey: Cell] {
        // `Bundle.url(forResource:withExtension:)` is documented for files;
        // its behavior for directory resources varies by macOS version. With
        // `.copy("Resources/SentenceLibrary")` in Package.swift the tree
        // lands at <bundle>/SentenceLibrary/ — fall back to that direct path
        // when the Bundle lookup misses (macos-15 CI, vs. macOS 16+ where the
        // lookup happens to find directories).
        if let root = bundle.url(forResource: "SentenceLibrary", withExtension: nil) {
            return try loadCells(from: root)
        }
        let direct = bundle.bundleURL.appendingPathComponent(
            "SentenceLibrary",
            isDirectory: true
        )
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: direct.path, isDirectory: &isDir),
            isDir.boolValue
        {
            return try loadCells(from: direct)
        }
        return [:]  // resource not present — cells map empty, callers fall back
    }

    private static func loadCells(from root: URL) throws -> [CellKey: Cell] {
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
                // Fix #2: Derive the cell identity from the file path so keys
                // are always authoritative and mismatches are caught early.
                let pathPhoneme = dir
                let stem = url.deletingPathExtension().lastPathComponent
                let (pathInterest, pathAgeBandString) = splitFileStem(stem)

                let data = try Data(contentsOf: url)
                let payload = try JSONDecoder().decode(CellPayload.self, from: data)

                // Fix #3: Throw instead of silently continuing when ageBand is
                // invalid — a silent `continue` produces a misleading zero-cell
                // result for that file.
                guard let band = AgeBand(rawValue: payload.ageBand) else {
                    throw LoaderError.invalidAgeBand(url: url, value: payload.ageBand)
                }

                // Fix #2: Validate payload fields against path-derived values.
                // The path is the authoritative source; throw on any mismatch.
                if let pi = pathInterest, payload.interest != pi {
                    throw LoaderError.payloadFilenameMismatch(
                        url: url,
                        field: "interest",
                        payloadValue: payload.interest,
                        pathValue: pi
                    )
                }
                if let pa = pathAgeBandString, payload.ageBand != pa {
                    throw LoaderError.payloadFilenameMismatch(
                        url: url,
                        field: "ageBand",
                        payloadValue: payload.ageBand,
                        pathValue: pa
                    )
                }
                if payload.phoneme != pathPhoneme {
                    throw LoaderError.payloadFilenameMismatch(
                        url: url,
                        field: "phoneme",
                        payloadValue: payload.phoneme,
                        pathValue: pathPhoneme
                    )
                }

                // Key is built from path-derived values (already validated to
                // match the payload above).
                let key = CellKey(phoneme: pathPhoneme, interest: payload.interest, ageBand: band)
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

    /// Splits `<interest>_<ageBand>` on the last underscore.
    /// Returns `(nil, nil)` when the stem contains no underscore (malformed filename).
    private static func splitFileStem(_ stem: String) -> (interest: String?, ageBand: String?) {
        guard let lastUnderscore = stem.lastIndex(of: "_") else {
            return (nil, nil)
        }
        let interest = String(stem[stem.startIndex..<lastUnderscore])
        let ageBand = String(stem[stem.index(after: lastUnderscore)...])
        return (interest.isEmpty ? nil : interest, ageBand.isEmpty ? nil : ageBand)
    }
}
