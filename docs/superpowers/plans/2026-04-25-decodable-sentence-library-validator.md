# Decodable Sentence Library — Validator + Sample Bundle (Track B-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the JSON schema, the Swift CLI validator, the in-app `SentenceLibrary` loader (selector stubbed), and one fully-validated sample cell (`sh × vehicles × mid`, 20 sentences) so Track B-2 can fill the remaining 89 cells incrementally without further code changes.

**Architecture:** A new `dev-tools/sentence-validator/` Swift Package executable validates `Resources/SentenceLibrary/{phoneme}/{interest}_{ageBand}.json` files against decodability + density rules computed from `MoraEngines.CurriculumEngine`. A new `MoraCore.AgeBand` enum and `MoraEngines.SentenceLibrary` actor expose the loaded library to the runtime; the selector method body is left empty (Track B-3 fills it). Sample-cell content is generated in-conversation by Claude Code per spec § 6.3 — **no Claude API calls, no Python LLM client** — validated, and committed.

**Tech Stack:** Swift 6 (language mode 5), `swift-argument-parser`, `XCTest`, `swift-format`, `Bundle.module` resources, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6, § 9 PR 2.

---

## Deviations from spec (read first)

1. **Validator location is `dev-tools/sentence-validator/`, not `tools/sentence-validator/`.** Spec § 11 Open Question 4 picked `tools/` to parallel `tools/yokai-forge/`, but `tools/yokai-forge/` is a **Python** project (not a Swift package). The repo's existing **Swift** CLI lives at `dev-tools/pronunciation-bench/`. Following house style; spec intent ("external, out of app build") is preserved either way.
2. **Per-sentence `interestWords` is author-provided.** Spec § 6.5's example shows `"interestWords": ["ship"]` per sentence. The validator checks the list is non-empty AND every entry appears as a word in the sentence text — it does not maintain a separate `(interest, ageBand) → vocabulary` table for v1. If mistagging proves to be a problem during B-2 generation, a centralized table is a natural follow-up.
3. **`SentenceLibrary.sentences(...)` body is `fatalError("selector — Track B-3")`.** B-1 ships only `init(bundle:)` + cell-count and cell-iteration helpers needed by tests. Wiring into `SessionContainerView.bootstrap` is B-3.

---

## File Structure

### Files to Create

| Path | Responsibility |
|------|----------------|
| `dev-tools/sentence-validator/Package.swift` | SPM manifest for the executable; depends on MoraCore + MoraEngines + ArgumentParser |
| `dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift` | `@main` entry, CLI option parsing, walks the bundle directory, prints report |
| `dev-tools/sentence-validator/Sources/SentenceValidator/CellSchema.swift` | Codable types matching the per-cell JSON (mirrors existing `WordPayload` shape) |
| `dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift` | Pure validation logic; no IO; takes parsed cell + curriculum + sight-word set, returns `[Violation]` |
| `dev-tools/sentence-validator/Sources/SentenceValidator/PhonemeDirectoryMap.swift` | Maps `sh/`, `th/`, `f/`, `r/`, `short_a/` → `SkillCode` and target `Grapheme` |
| `dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift` | Unit tests for each violation type + happy path |
| `dev-tools/sentence-validator/Tests/SentenceValidatorTests/CLITests.swift` | End-to-end fixture-driven tests of the binary (valid + invalid bundle dirs) |
| `dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/valid/sh/vehicles_mid.json` | Validator green-path fixture (3-sentence pared-down cell) |
| `dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/invalid/sh/vehicles_mid.json` | Validator red-path fixture with 1 of each violation type |
| `dev-tools/sentence-validator/README.md` | One-page usage doc |
| `Packages/MoraCore/Sources/MoraCore/AgeBand.swift` | `enum AgeBand` + `from(years:)` |
| `Packages/MoraCore/Tests/MoraCoreTests/AgeBandTests.swift` | Boundary tests (per spec § 6.10) |
| `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift` | `actor SentenceLibrary`; `init(bundle:)` + cell lookup; selector `fatalError`'d |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_mid.json` | The single fully-populated sample cell (20 sentences, all validated) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{sh,th,f,r,short_a}/.gitkeep` | Pin the 5-phoneme directory layout for B-2 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift` | Tests for loader + cell lookup |

### Files to Modify

| Path | Change |
|------|--------|
| `.github/workflows/ci.yml` | Add a `sentence-validator` job that runs `swift run --package-path dev-tools/sentence-validator sentence-validator --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary` after the SPM test loop |

---

## Task 1: Scaffold `dev-tools/sentence-validator/` package

**Files:**
- Create: `dev-tools/sentence-validator/Package.swift`
- Create: `dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift`
- Create: `dev-tools/sentence-validator/README.md`

- [ ] **Step 1: Verify the parent directory exists**

Run:
```sh
ls dev-tools/
```

Expected: lists `pronunciation-bench/` and the README. If the directory is missing, create it with `mkdir -p dev-tools`.

- [ ] **Step 2: Write `Package.swift`**

Write `dev-tools/sentence-validator/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sentence-validator",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "sentence-validator", targets: ["SentenceValidator"]),
    ],
    dependencies: [
        .package(path: "../../Packages/MoraEngines"),
        .package(path: "../../Packages/MoraCore"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "SentenceValidator",
            dependencies: [
                .product(name: "MoraEngines", package: "MoraEngines"),
                .product(name: "MoraCore", package: "MoraCore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/SentenceValidator"
        ),
        .testTarget(
            name: "SentenceValidatorTests",
            dependencies: ["SentenceValidator"],
            path: "Tests/SentenceValidatorTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
```

- [ ] **Step 3: Write the bare CLI entry point**

Write `dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift`:

```swift
import ArgumentParser
import Foundation

@main
struct SentenceValidatorCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sentence-validator",
        abstract: "Validates the bundled decodable-sentence library."
    )

    @Option(name: .long, help: "Path to the SentenceLibrary resource directory.")
    var bundle: String

    func run() throws {
        FileHandle.standardError.write(
            Data("sentence-validator: not yet wired (Task 6 fills this in)\n".utf8)
        )
        throw ExitCode(2)
    }
}
```

- [ ] **Step 4: Write `README.md`**

Write `dev-tools/sentence-validator/README.md`:

```markdown
# sentence-validator

Standalone Swift CLI that validates the bundled decodable-sentence library
(`Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/`) against
the rules in
[`docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md`](../../docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md)
§ 6.4.

## Usage

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Exits 0 if every cell file validates; non-zero with a per-violation report
otherwise. Wired into CI after the SPM test loop.

## What it checks

For every `{interest}_{ageBand}.json` under each phoneme directory:

- Every sentence's words decompose into graphemes drawn from
  `CurriculumEngine.taughtGraphemes(beforeWeekIndex:) ∪ {target}` plus the
  sight-word whitelist (`the, a, and, is, to, on, at`).
- The target phoneme appears word-initial in ≥3 content words and
  ≥4 times total per sentence.
- Each sentence has ≥1 entry in its `interestWords` list, and every
  `interestWords` entry matches a word in the sentence text.
- Sentence length is 6–10 words.
```

- [ ] **Step 5: Build to verify the package compiles**

Run:
```sh
(cd dev-tools/sentence-validator && swift build)
```

Expected: success. Warnings about the unused `bundle` field are acceptable at this stage.

- [ ] **Step 6: Verify the binary runs**

Run:
```sh
(cd dev-tools/sentence-validator && swift run sentence-validator --help 2>&1 | head -10)
```

Expected: `USAGE: sentence-validator --bundle <bundle>` appears in the help output.

- [ ] **Step 7: Commit**

```sh
git add dev-tools/sentence-validator/Package.swift \
        dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift \
        dev-tools/sentence-validator/README.md
git commit -m "tools(sentence-validator): scaffold Swift CLI package skeleton

Mirrors dev-tools/pronunciation-bench layout. CLI parses --bundle and
exits 2 with a 'not yet wired' message; subsequent commits add the
schema types, the validator logic, and the directory walker.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Define the cell JSON schema types

**Files:**
- Create: `dev-tools/sentence-validator/Sources/SentenceValidator/CellSchema.swift`

- [ ] **Step 1: Write the schema types**

Write `dev-tools/sentence-validator/Sources/SentenceValidator/CellSchema.swift`:

```swift
import Foundation

/// Per-file payload for `SentenceLibrary/{phoneme}/{interest}_{ageBand}.json`.
/// Mirrors the spec § 6.5 schema. Field names are `snake_case`-free to keep
/// Swift `Codable` synthesis trivial; the JSON uses the same camelCase keys.
struct CellPayload: Decodable {
    let phoneme: String           // e.g. "sh" — matches the directory name
    let phonemeIPA: String        // e.g. "ʃ"
    let graphemeLetters: String   // e.g. "sh" — letters of the target Grapheme
    let interest: String          // e.g. "vehicles" — matches InterestCategory.key
    let ageBand: String           // "early" | "mid" | "late"
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
```

- [ ] **Step 2: Build to verify**

Run:
```sh
(cd dev-tools/sentence-validator && swift build)
```

Expected: success.

- [ ] **Step 3: Commit**

```sh
git add dev-tools/sentence-validator/Sources/SentenceValidator/CellSchema.swift
git commit -m "tools(sentence-validator): cell JSON schema types

CellPayload + CellSentencePayload + WordPayload mirror spec § 6.5 and
reuse the WordPayload shape from MoraEngines.ScriptedContentProvider so
the runtime loader and the validator decode identical JSON.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Phoneme-directory → SkillCode mapping

**Files:**
- Create: `dev-tools/sentence-validator/Sources/SentenceValidator/PhonemeDirectoryMap.swift`

- [ ] **Step 1: Write the mapping**

Write `dev-tools/sentence-validator/Sources/SentenceValidator/PhonemeDirectoryMap.swift`:

```swift
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
```

- [ ] **Step 2: Build to verify**

Run:
```sh
(cd dev-tools/sentence-validator && swift build)
```

Expected: success.

- [ ] **Step 3: Commit**

```sh
git add dev-tools/sentence-validator/Sources/SentenceValidator/PhonemeDirectoryMap.swift
git commit -m "tools(sentence-validator): map phoneme dir name to SkillCode + Grapheme

Five-row lookup table parallels CurriculumEngine.defaultV1Ladder. Lives
in the validator (not MoraCore) because runtime code never needs to map
from directory-name strings.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: TDD — `Validator` decodability check

**Files:**
- Create: `dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift`
- Create: `dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift`

- [ ] **Step 1: Write the failing test**

Write `dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift`:

```swift
import XCTest
import MoraCore
import MoraEngines
@testable import SentenceValidator

final class ValidatorTests: XCTestCase {
    private let curriculum = CurriculumEngine.defaultV1Ladder()
    private let sightWords: Set<String> = ["the", "a", "and", "is", "to", "on", "at"]

    private func shCellMap() -> PhonemeDirectoryMap {
        PhonemeDirectoryMap.lookup(directory: "sh")!
    }

    func test_validate_passesGoldenSentence() throws {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen and Sharon shop for a ship at the shed.",
            targetCount: 5,
            targetInitialContentWords: 5,
            interestWords: ["ship"],
            words: [
                .init(surface: "Shen",   graphemes: ["sh","e","n"],         phonemes: ["ʃ","ɛ","n"]),
                .init(surface: "and",    graphemes: ["a","n","d"],          phonemes: ["æ","n","d"]),
                .init(surface: "Sharon", graphemes: ["sh","a","r","o","n"], phonemes: ["ʃ","æ","r","ə","n"]),
                .init(surface: "shop",   graphemes: ["sh","o","p"],         phonemes: ["ʃ","ɒ","p"]),
                .init(surface: "for",    graphemes: ["f","o","r"],          phonemes: ["f","ɔ","r"]),
                .init(surface: "a",      graphemes: ["a"],                  phonemes: ["ə"]),
                .init(surface: "ship",   graphemes: ["sh","i","p"],         phonemes: ["ʃ","ɪ","p"]),
                .init(surface: "at",     graphemes: ["a","t"],              phonemes: ["æ","t"]),
                .init(surface: "the",    graphemes: ["t","h","e"],          phonemes: ["ð","ə"]),
                .init(surface: "shed",   graphemes: ["sh","e","d"],         phonemes: ["ʃ","ɛ","d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertEqual(violations, [])
    }

    func test_validate_flagsUntaughtGrapheme() {
        let map = shCellMap()
        // "thin" contains the "th" digraph which is NOT in the sh-cell's
        // taught set (taught set: L2 alphabet ∪ {sh}). Word still has the
        // sh trigger via the other words but the th word is not decodable.
        let sentence = CellSentencePayload(
            text: "Shen had a thin ship and a shop and a shed.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: ["ship"],
            words: [
                .init(surface: "Shen",  graphemes: ["sh","e","n"], phonemes: ["ʃ","ɛ","n"]),
                .init(surface: "had",   graphemes: ["h","a","d"],  phonemes: ["h","æ","d"]),
                .init(surface: "a",     graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "thin",  graphemes: ["th","i","n"], phonemes: ["θ","ɪ","n"]),
                .init(surface: "ship",  graphemes: ["sh","i","p"], phonemes: ["ʃ","ɪ","p"]),
                .init(surface: "and",   graphemes: ["a","n","d"],  phonemes: ["æ","n","d"]),
                .init(surface: "a",     graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "shop",  graphemes: ["sh","o","p"], phonemes: ["ʃ","ɒ","p"]),
                .init(surface: "and",   graphemes: ["a","n","d"],  phonemes: ["æ","n","d"]),
                .init(surface: "a",     graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "shed",  graphemes: ["sh","e","d"], phonemes: ["ʃ","ɛ","d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(where: {
                if case .undecodableGrapheme(let word, let grapheme) = $0,
                    word == "thin", grapheme == "th"
                {
                    return true
                }
                return false
            }),
            "expected an .undecodableGrapheme violation for 'thin'/'th'; got \(violations)"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter ValidatorTests)
```

Expected: build error — `cannot find 'Validator' in scope`.

- [ ] **Step 3: Implement the minimal `Validator`**

Write `dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift`:

```swift
import Foundation
import MoraCore
import MoraEngines

/// One reason a sentence failed validation. Future tasks add more cases;
/// keep `Equatable` synthesis clean by using only stored-value associated
/// data (no closures, no functions).
enum Violation: Equatable {
    case undecodableGrapheme(word: String, grapheme: String)
    case targetCountTooLow(actual: Int, minimum: Int)
    case targetInitialContentWordsTooLow(actual: Int, minimum: Int)
    case interestWordsEmpty
    case interestWordNotInSentence(interestWord: String)
    case lengthOutOfRange(actual: Int, minimum: Int, maximum: Int)
}

enum Validator {
    /// Validate a single sentence against its cell's rules.
    /// `map` selects the phoneme-specific allowed grapheme set; `curriculum`
    /// resolves the taught set; `sightWords` is the global whitelist.
    static func validate(
        sentence: CellSentencePayload,
        map: PhonemeDirectoryMap,
        curriculum: CurriculumEngine,
        sightWords: Set<String>
    ) -> [Violation] {
        var violations: [Violation] = []

        let allowed: Set<Grapheme> =
            curriculum.taughtGraphemes(beforeWeekIndex: map.weekIndex)
                .union([map.target])

        for word in sentence.words {
            if sightWords.contains(word.surface.lowercased()) { continue }
            for letters in word.graphemes {
                let g = Grapheme(letters: letters)
                if allowed.contains(g) { continue }
                violations.append(.undecodableGrapheme(word: word.surface, grapheme: letters))
            }
        }

        return violations
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter ValidatorTests)
```

Expected: PASS for both tests (golden sentence has zero violations; `thin` test surfaces `.undecodableGrapheme(word: "thin", grapheme: "th")`).

- [ ] **Step 5: Commit**

```sh
git add dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift \
        dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift
git commit -m "tools(sentence-validator): decodability check + first two tests

Validator.validate enforces decodability: every grapheme of every
non-sight-word must be in CurriculumEngine.taughtGraphemes(beforeWeekIndex:)
union the cell's target. Two tests pin the happy path (spec § 6.5
example sentence) and one failure mode (a word containing 'th' in the
sh-cell where 'th' is not yet taught).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: TDD — density checks (target count + initial-in-content)

**Files:**
- Modify: `dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift`
- Modify: `dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside the `ValidatorTests` class:

```swift
    func test_validate_flagsTargetCountTooLow() {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen had a shop and a hat and a hen.",
            targetCount: 2,                  // author-claimed count
            targetInitialContentWords: 2,    // author-claimed
            interestWords: ["cab"],          // we'll silence the interest violation in another test
            words: [
                .init(surface: "Shen", graphemes: ["sh","e","n"], phonemes: ["ʃ","ɛ","n"]),
                .init(surface: "had",  graphemes: ["h","a","d"],  phonemes: ["h","æ","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh","o","p"], phonemes: ["ʃ","ɒ","p"]),
                .init(surface: "and",  graphemes: ["a","n","d"],  phonemes: ["æ","n","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "hat",  graphemes: ["h","a","t"],  phonemes: ["h","æ","t"]),
                .init(surface: "and",  graphemes: ["a","n","d"],  phonemes: ["æ","n","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "hen",  graphemes: ["h","e","n"],  phonemes: ["h","ɛ","n"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(.targetCountTooLow(actual: 2, minimum: 4)),
            "expected .targetCountTooLow(2, 4); got \(violations)"
        )
    }

    func test_validate_flagsInitialContentTooLow() {
        let map = shCellMap()
        // 4 sh occurrences but only 2 are word-initial in content words —
        // "fish" and "cash" both put sh in the coda.
        let sentence = CellSentencePayload(
            text: "A ship had a fish and a cash and a shop.",
            targetCount: 4,
            targetInitialContentWords: 2,
            interestWords: ["ship"],
            words: [
                .init(surface: "A",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "ship", graphemes: ["sh","i","p"], phonemes: ["ʃ","ɪ","p"]),
                .init(surface: "had",  graphemes: ["h","a","d"],  phonemes: ["h","æ","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "fish", graphemes: ["f","i","sh"], phonemes: ["f","ɪ","ʃ"]),
                .init(surface: "and",  graphemes: ["a","n","d"],  phonemes: ["æ","n","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "cash", graphemes: ["c","a","sh"], phonemes: ["k","æ","ʃ"]),
                .init(surface: "and",  graphemes: ["a","n","d"],  phonemes: ["æ","n","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "shop", graphemes: ["sh","o","p"], phonemes: ["ʃ","ɒ","p"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(.targetInitialContentWordsTooLow(actual: 2, minimum: 3)),
            "expected .targetInitialContentWordsTooLow(2, 3); got \(violations)"
        )
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter ValidatorTests.test_validate_flagsTargetCount)
```

Expected: PASS-zero (no `.targetCountTooLow` in violations) — the assertion will fail with the actual violations array printed.

- [ ] **Step 3: Add the density checks to `Validator`**

Edit `dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift`. Replace the `validate(...)` body with:

```swift
    static func validate(
        sentence: CellSentencePayload,
        map: PhonemeDirectoryMap,
        curriculum: CurriculumEngine,
        sightWords: Set<String>
    ) -> [Violation] {
        var violations: [Violation] = []

        let allowed: Set<Grapheme> =
            curriculum.taughtGraphemes(beforeWeekIndex: map.weekIndex)
                .union([map.target])

        for word in sentence.words {
            if sightWords.contains(word.surface.lowercased()) { continue }
            for letters in word.graphemes {
                let g = Grapheme(letters: letters)
                if allowed.contains(g) { continue }
                violations.append(.undecodableGrapheme(word: word.surface, grapheme: letters))
            }
        }

        let targetLetters = map.target.letters
        let totalTargetCount = sentence.words.reduce(0) { acc, word in
            acc + word.graphemes.filter { $0 == targetLetters }.count
        }
        if totalTargetCount < 4 {
            violations.append(.targetCountTooLow(actual: totalTargetCount, minimum: 4))
        }

        let initialInContent = sentence.words.reduce(0) { acc, word in
            // "Content word" = anything not in the sight-word whitelist. Proper
            // nouns, regular nouns, verbs, adjectives all count; only the seven
            // sight words are excluded.
            guard !sightWords.contains(word.surface.lowercased()) else { return acc }
            guard let first = word.graphemes.first, first == targetLetters else { return acc }
            return acc + 1
        }
        if initialInContent < 3 {
            violations.append(.targetInitialContentWordsTooLow(actual: initialInContent, minimum: 3))
        }

        return violations
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter ValidatorTests)
```

Expected: PASS for all four tests so far.

- [ ] **Step 5: Commit**

```sh
git add dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift \
        dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift
git commit -m "tools(sentence-validator): density checks (>=4 total, >=3 word-initial)

Counts target-grapheme occurrences across all words for the >=4 total
rule, then the subset where the target is the first grapheme of a
non-sight-word for the >=3 word-initial-in-content rule. Sight-word
whitelist excluded from both counts.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: TDD — interest tag + length checks

**Files:**
- Modify: `dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift`
- Modify: `dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside the `ValidatorTests` class:

```swift
    func test_validate_flagsEmptyInterestWords() {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen had a shop and Sharon had a shed.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: [],   // empty — should fire
            words: [
                .init(surface: "Shen",   graphemes: ["sh","e","n"],         phonemes: ["ʃ","ɛ","n"]),
                .init(surface: "had",    graphemes: ["h","a","d"],          phonemes: ["h","æ","d"]),
                .init(surface: "a",      graphemes: ["a"],                  phonemes: ["ə"]),
                .init(surface: "shop",   graphemes: ["sh","o","p"],         phonemes: ["ʃ","ɒ","p"]),
                .init(surface: "and",    graphemes: ["a","n","d"],          phonemes: ["æ","n","d"]),
                .init(surface: "Sharon", graphemes: ["sh","a","r","o","n"], phonemes: ["ʃ","æ","r","ə","n"]),
                .init(surface: "had",    graphemes: ["h","a","d"],          phonemes: ["h","æ","d"]),
                .init(surface: "a",      graphemes: ["a"],                  phonemes: ["ə"]),
                .init(surface: "shed",   graphemes: ["sh","e","d"],         phonemes: ["ʃ","ɛ","d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(violations.contains(.interestWordsEmpty), "got \(violations)")
    }

    func test_validate_flagsInterestWordNotInSentence() {
        let map = shCellMap()
        let sentence = CellSentencePayload(
            text: "Shen had a shop and Sharon had a shed.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: ["van"],   // van is not in the sentence
            words: [
                .init(surface: "Shen",   graphemes: ["sh","e","n"],         phonemes: ["ʃ","ɛ","n"]),
                .init(surface: "had",    graphemes: ["h","a","d"],          phonemes: ["h","æ","d"]),
                .init(surface: "a",      graphemes: ["a"],                  phonemes: ["ə"]),
                .init(surface: "shop",   graphemes: ["sh","o","p"],         phonemes: ["ʃ","ɒ","p"]),
                .init(surface: "and",    graphemes: ["a","n","d"],          phonemes: ["æ","n","d"]),
                .init(surface: "Sharon", graphemes: ["sh","a","r","o","n"], phonemes: ["ʃ","æ","r","ə","n"]),
                .init(surface: "had",    graphemes: ["h","a","d"],          phonemes: ["h","æ","d"]),
                .init(surface: "a",      graphemes: ["a"],                  phonemes: ["ə"]),
                .init(surface: "shed",   graphemes: ["sh","e","d"],         phonemes: ["ʃ","ɛ","d"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(violations.contains(.interestWordNotInSentence(interestWord: "van")), "got \(violations)")
    }

    func test_validate_flagsLengthOutOfRange() {
        let map = shCellMap()
        // 5 words — under the 6-word minimum.
        let sentence = CellSentencePayload(
            text: "Shen had a ship shop.",
            targetCount: 4,
            targetInitialContentWords: 4,
            interestWords: ["ship"],
            words: [
                .init(surface: "Shen", graphemes: ["sh","e","n"], phonemes: ["ʃ","ɛ","n"]),
                .init(surface: "had",  graphemes: ["h","a","d"],  phonemes: ["h","æ","d"]),
                .init(surface: "a",    graphemes: ["a"],          phonemes: ["ə"]),
                .init(surface: "ship", graphemes: ["sh","i","p"], phonemes: ["ʃ","ɪ","p"]),
                .init(surface: "shop", graphemes: ["sh","o","p"], phonemes: ["ʃ","ɒ","p"]),
            ]
        )

        let violations = Validator.validate(
            sentence: sentence,
            map: map,
            curriculum: curriculum,
            sightWords: sightWords
        )

        XCTAssertTrue(
            violations.contains(.lengthOutOfRange(actual: 5, minimum: 6, maximum: 10)),
            "got \(violations)"
        )
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter ValidatorTests)
```

Expected: 3 new failures.

- [ ] **Step 3: Add interest + length checks to `Validator`**

Edit `Validator.swift`. Append the following block to the end of the `validate(...)` body, just before `return violations`:

```swift
        if sentence.interestWords.isEmpty {
            violations.append(.interestWordsEmpty)
        } else {
            // Loose check: each interestWords entry must appear in the
            // sentence's word surfaces (case-insensitive). Rejects authoring
            // typos like "vans" tagged when only "van" appears.
            let surfaces = Set(sentence.words.map { $0.surface.lowercased() })
            for tag in sentence.interestWords {
                if !surfaces.contains(tag.lowercased()) {
                    violations.append(.interestWordNotInSentence(interestWord: tag))
                }
            }
        }

        let length = sentence.words.count
        if length < 6 || length > 10 {
            violations.append(.lengthOutOfRange(actual: length, minimum: 6, maximum: 10))
        }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter ValidatorTests)
```

Expected: PASS for all seven tests.

- [ ] **Step 5: Commit**

```sh
git add dev-tools/sentence-validator/Sources/SentenceValidator/Validator.swift \
        dev-tools/sentence-validator/Tests/SentenceValidatorTests/ValidatorTests.swift
git commit -m "tools(sentence-validator): interest tag + length checks

interestWords must be non-empty and every entry must surface in the
sentence's word list. Sentence length must fall in [6, 10] inclusive.
Together with Tasks 4-5 these cover the four cell-validation rules in
spec sec 6.4.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Wire the CLI — directory walker + structured report

**Files:**
- Modify: `dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift`

- [ ] **Step 1: Replace the stub `run()` with the real walker**

Rewrite `dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift`:

```swift
import ArgumentParser
import Foundation
import MoraCore
import MoraEngines

@main
struct SentenceValidatorCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sentence-validator",
        abstract: "Validates the bundled decodable-sentence library."
    )

    @Option(name: .long, help: "Path to the SentenceLibrary resource directory.")
    var bundle: String

    func run() throws {
        let bundleURL = URL(fileURLWithPath: bundle, isDirectory: true)
        let curriculum = CurriculumEngine.defaultV1Ladder()
        let sightWords: Set<String> = ["the", "a", "and", "is", "to", "on", "at"]

        var report = ValidationReport()
        let fm = FileManager.default

        for map in PhonemeDirectoryMap.all {
            let phonemeDir = bundleURL.appendingPathComponent(map.directory, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(
                at: phonemeDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                continue   // missing phoneme dir is OK before B-2 fills cells in
            }
            for url in entries where url.pathExtension == "json" {
                report.cellsExamined += 1
                do {
                    let data = try Data(contentsOf: url)
                    let cell = try JSONDecoder().decode(CellPayload.self, from: data)
                    report.sentencesExamined += cell.sentences.count
                    for (idx, sentence) in cell.sentences.enumerated() {
                        let violations = Validator.validate(
                            sentence: sentence,
                            map: map,
                            curriculum: curriculum,
                            sightWords: sightWords
                        )
                        for v in violations {
                            report.violations.append(.init(
                                file: url.path,
                                sentenceIndex: idx,
                                sentenceText: sentence.text,
                                violation: v
                            ))
                        }
                    }
                } catch {
                    report.violations.append(.init(
                        file: url.path,
                        sentenceIndex: -1,
                        sentenceText: "<decode-error>",
                        violation: .undecodableGrapheme(word: "<file>", grapheme: "\(error)")
                    ))
                }
            }
        }

        FileHandle.standardOutput.write(Data(report.render().utf8))
        if !report.violations.isEmpty {
            throw ExitCode(1)
        }
    }
}

struct ValidationReport {
    struct Entry {
        let file: String
        let sentenceIndex: Int
        let sentenceText: String
        let violation: Violation
    }

    var cellsExamined: Int = 0
    var sentencesExamined: Int = 0
    var violations: [Entry] = []

    func render() -> String {
        var out = ""
        out += "sentence-validator: \(cellsExamined) cells, \(sentencesExamined) sentences\n"
        if violations.isEmpty {
            out += "  PASS\n"
        } else {
            out += "  FAIL — \(violations.count) violation(s):\n"
            for entry in violations {
                out += "    \(entry.file)#\(entry.sentenceIndex): \(entry.violation)\n"
                out += "      \"\(entry.sentenceText)\"\n"
            }
        }
        return out
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```sh
(cd dev-tools/sentence-validator && swift build)
```

Expected: success.

- [ ] **Step 3: Smoke test the CLI on a non-existent bundle**

Run:
```sh
(cd dev-tools/sentence-validator && swift run sentence-validator --bundle /tmp/nonexistent-bundle 2>&1 | head -5)
```

Expected: prints `sentence-validator: 0 cells, 0 sentences` and `PASS` (no cells means no violations); exit code 0. The `try?` on `contentsOfDirectory` makes missing phoneme directories silent — this matches B-2's incremental-fill workflow.

- [ ] **Step 4: Commit**

```sh
git add dev-tools/sentence-validator/Sources/SentenceValidator/SentenceValidatorCLI.swift
git commit -m "tools(sentence-validator): walk bundle dir, validate every cell, print report

CLI walks Resources/SentenceLibrary/{phoneme}/*.json across the five
v1 phonemes, dispatches Validator on every sentence, accumulates
violations with file path + sentence index + text + reason, prints a
structured report, and exits non-zero when any violation is recorded.
Missing phoneme directories are silent so B-2's incremental cell-fill
workflow does not need to keep dummy files.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: TDD — CLI end-to-end fixture tests

**Files:**
- Create: `dev-tools/sentence-validator/Tests/SentenceValidatorTests/CLITests.swift`
- Create: `dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/valid/sh/vehicles_mid.json`
- Create: `dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/invalid/sh/vehicles_mid.json`

- [ ] **Step 1: Write the green-path fixture**

Write `dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/valid/sh/vehicles_mid.json`:

```json
{
  "phoneme": "sh",
  "phonemeIPA": "ʃ",
  "graphemeLetters": "sh",
  "interest": "vehicles",
  "ageBand": "mid",
  "sentences": [
    {
      "text": "Shen and Sharon shop for a ship at the shed.",
      "targetCount": 5,
      "targetInitialContentWords": 5,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen",   "graphemes": ["sh","e","n"],         "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],         "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "for",    "graphemes": ["f","o","r"],          "phonemes": ["f","ɔ","r"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "at",     "graphemes": ["a","t"],              "phonemes": ["æ","t"] },
        { "surface": "the",    "graphemes": ["t","h","e"],          "phonemes": ["ð","ə"] },
        { "surface": "shed",   "graphemes": ["sh","e","d"],         "phonemes": ["ʃ","ɛ","d"] }
      ]
    }
  ]
}
```

- [ ] **Step 2: Write the red-path fixture (one violation per category)**

Write `dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/invalid/sh/vehicles_mid.json`:

```json
{
  "phoneme": "sh",
  "phonemeIPA": "ʃ",
  "graphemeLetters": "sh",
  "interest": "vehicles",
  "ageBand": "mid",
  "sentences": [
    {
      "text": "Shen had a thin ship and a shop and a shed.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen",  "graphemes": ["sh","e","n"], "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "had",   "graphemes": ["h","a","d"],  "phonemes": ["h","æ","d"] },
        { "surface": "a",     "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "thin",  "graphemes": ["th","i","n"], "phonemes": ["θ","ɪ","n"] },
        { "surface": "ship",  "graphemes": ["sh","i","p"], "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",   "graphemes": ["a","n","d"],  "phonemes": ["æ","n","d"] },
        { "surface": "a",     "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "shop",  "graphemes": ["sh","o","p"], "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "and",   "graphemes": ["a","n","d"],  "phonemes": ["æ","n","d"] },
        { "surface": "a",     "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "shed",  "graphemes": ["sh","e","d"], "phonemes": ["ʃ","ɛ","d"] }
      ]
    },
    {
      "text": "A ship can hop.",
      "targetCount": 1,
      "targetInitialContentWords": 1,
      "interestWords": [],
      "words": [
        { "surface": "A",    "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "ship", "graphemes": ["sh","i","p"], "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "can",  "graphemes": ["c","a","n"],  "phonemes": ["k","æ","n"] },
        { "surface": "hop",  "graphemes": ["h","o","p"],  "phonemes": ["h","ɒ","p"] }
      ]
    }
  ]
}
```

This file is intentionally polluted: sentence 1 has the `th`-undecodable violation; sentence 2 has length-too-short, target-count-too-low, target-initial-too-low, and interest-empty.

- [ ] **Step 3: Write the CLI tests**

Write `dev-tools/sentence-validator/Tests/SentenceValidatorTests/CLITests.swift`:

```swift
import XCTest
@testable import SentenceValidator

final class CLITests: XCTestCase {
    /// `Bundle.module` resolves resources for the test target. Since the
    /// fixtures live under `Tests/SentenceValidatorTests/Fixtures/{valid,invalid}/`
    /// they're addressable as relative paths inside the test bundle.
    private func fixtureBundleURL(_ subdir: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: subdir, withExtension: nil) else {
            XCTFail("Missing fixture bundle '\(subdir)'")
            throw NSError(domain: "Fixture", code: 0)
        }
        return url
    }

    func test_run_passesValidBundle() throws {
        let url = try fixtureBundleURL("Fixtures/valid")
        var cli = SentenceValidatorCLI()
        cli.bundle = url.path
        try cli.run()  // throws ExitCode(non-zero) on failure
    }

    func test_run_failsInvalidBundle() throws {
        let url = try fixtureBundleURL("Fixtures/invalid")
        var cli = SentenceValidatorCLI()
        cli.bundle = url.path

        do {
            try cli.run()
            XCTFail("expected validation to fail")
        } catch let exit as ExitCode {
            XCTAssertEqual(exit.rawValue, 1, "expected exit code 1, got \(exit.rawValue)")
        }
    }
}
```

- [ ] **Step 4: Run the CLI tests**

Run:
```sh
(cd dev-tools/sentence-validator && swift test --filter CLITests)
```

Expected: PASS for both. The valid bundle reports `1 cells, 1 sentences, PASS`; the invalid bundle reports several violations and the test catches `ExitCode(1)`.

- [ ] **Step 5: Commit**

```sh
git add dev-tools/sentence-validator/Tests/SentenceValidatorTests/CLITests.swift \
        dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/valid/sh/vehicles_mid.json \
        dev-tools/sentence-validator/Tests/SentenceValidatorTests/Fixtures/invalid/sh/vehicles_mid.json
git commit -m "tools(sentence-validator): end-to-end fixture-driven CLI tests

Two fixture bundles ('valid' with one good cell, 'invalid' with four
violations across two sentences) exercise the directory walker, JSON
decode, validator dispatch, and exit-code behavior. Locks the CLI's
contract so the CI gate can be added in Task 12 with confidence.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: `AgeBand` enum + boundary tests

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/AgeBand.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/AgeBandTests.swift`

- [ ] **Step 1: Write the failing tests**

Write `Packages/MoraCore/Tests/MoraCoreTests/AgeBandTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class AgeBandTests: XCTestCase {
    func test_from_yearsBucketsCorrectly() {
        XCTAssertEqual(AgeBand.from(years: 3), .early)
        XCTAssertEqual(AgeBand.from(years: 4), .early)
        XCTAssertEqual(AgeBand.from(years: 7), .early)
        XCTAssertEqual(AgeBand.from(years: 8), .mid)
        XCTAssertEqual(AgeBand.from(years: 10), .mid)
        XCTAssertEqual(AgeBand.from(years: 11), .late)
        XCTAssertEqual(AgeBand.from(years: 13), .late)
        XCTAssertEqual(AgeBand.from(years: 99), .late)
    }

    func test_rawValuesAreStable() {
        // Bundled JSON files key cells on these strings; renaming requires a
        // bundle migration and is breaking. Lock the names here so a careless
        // rename trips this test.
        XCTAssertEqual(AgeBand.early.rawValue, "early")
        XCTAssertEqual(AgeBand.mid.rawValue, "mid")
        XCTAssertEqual(AgeBand.late.rawValue, "late")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```sh
(cd Packages/MoraCore && swift test --filter AgeBandTests)
```

Expected: build error — `cannot find 'AgeBand' in scope`.

- [ ] **Step 3: Implement `AgeBand`**

Write `Packages/MoraCore/Sources/MoraCore/AgeBand.swift`:

```swift
import Foundation

/// Coarse age bucket used by `SentenceLibrary` (and any future content
/// selector) to vary vocabulary breadth and sentence length without
/// over-fitting to a single year-of-age.
///
/// Boundaries reflect spec § 6.1: `early` 4–7, `mid` 8–10, `late` 11+.
public enum AgeBand: String, Sendable, CaseIterable, Codable {
    case early
    case mid
    case late

    public static func from(years: Int) -> AgeBand {
        switch years {
        case ..<8: .early
        case 8...10: .mid
        default: .late
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```sh
(cd Packages/MoraCore && swift test --filter AgeBandTests)
```

Expected: PASS for both tests.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/AgeBand.swift \
        Packages/MoraCore/Tests/MoraCoreTests/AgeBandTests.swift
git commit -m "core: AgeBand enum with from(years:) bucketing

Three buckets per spec sec 6.1: early (4-7), mid (8-10), late (11+).
The selector in MoraEngines.SentenceLibrary (next commit) keys on
these. Raw values are pinned by a separate test because they appear
in bundled JSON filenames and any rename is a breaking change.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 10: `SentenceLibrary` actor — load + cell lookup; selector stub

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift`

- [ ] **Step 1: Confirm the `Content/` subdirectory does not yet exist**

Run:
```sh
ls Packages/MoraEngines/Sources/MoraEngines/ | grep -i content || echo "no content dir"
```

Expected: `no content dir` — the subdirectory will be created with this commit.

- [ ] **Step 2: Write the failing tests**

Write `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift`:

```swift
import XCTest
@testable import MoraCore
@testable import MoraEngines

final class SentenceLibraryTests: XCTestCase {
    func test_init_loadsBundledCells() async throws {
        let library = try SentenceLibrary(bundle: .module)

        let count = await library.cellCount
        XCTAssertGreaterThanOrEqual(
            count, 1,
            "expected at least the sample cell sh/vehicles_mid.json to load"
        )
    }

    func test_cell_returnsTwentySentencesForSampleCell() async throws {
        let library = try SentenceLibrary(bundle: .module)
        let cell = await library.cell(
            phoneme: "sh",
            interest: "vehicles",
            ageBand: .mid
        )

        XCTAssertNotNil(cell, "sample cell sh/vehicles_mid.json must load")
        XCTAssertEqual(cell?.sentences.count, 20)
    }

    func test_cell_returnsNilForUnpopulatedCell() async throws {
        let library = try SentenceLibrary(bundle: .module)
        let cell = await library.cell(
            phoneme: "th",
            interest: "robots",
            ageBand: .late
        )

        XCTAssertNil(cell, "Track B-1 only ships sh/vehicles_mid; others are absent")
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter SentenceLibraryTests)
```

Expected: build error — `cannot find 'SentenceLibrary' in scope`.

- [ ] **Step 4: Implement the actor**

Write `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`:

```swift
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
            return [:]   // resource not present — cells map empty, callers fall back
        }
        var out: [CellKey: Cell] = [:]
        let fm = FileManager.default
        for dir in phonemeDirectories {
            let phonemeURL = root.appendingPathComponent(dir, isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(
                at: phonemeURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
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
```

- [ ] **Step 5: Confirm `DecodeSentence` exists in the package**

Run:
```sh
grep -rn "public struct DecodeSentence" Packages/MoraEngines/Sources/MoraEngines/
```

Expected: at least one match (it's used by `ScriptedContentProvider`). If it doesn't exist, halt and surface to the user — the spec assumes this type is shared. Likely match: `Packages/MoraEngines/Sources/MoraEngines/ContentProvider.swift` or similar.

- [ ] **Step 6: Run the tests**

Note: at this point only `test_init_loadsBundledCells` and `test_cell_returnsNilForUnpopulatedCell` should pass. `test_cell_returnsTwentySentencesForSampleCell` will FAIL because the sample cell is created in Task 12 — this is the planned TDD red-light for the next task.

Run:
```sh
(cd Packages/MoraEngines && swift test --filter SentenceLibraryTests)
```

Expected: 2 PASS, 1 FAIL on `test_cell_returnsTwentySentencesForSampleCell`. The third test passes after Task 12.

- [ ] **Step 7: Commit (the failing test stays — it pins the contract for Task 12)**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift
git commit -m "engines(content): SentenceLibrary actor — load + cell lookup; selector stubbed

Loads Resources/SentenceLibrary/{phoneme}/{interest}_{ageBand}.json into
an in-memory map keyed by (phoneme dir, interest key, AgeBand). Selector
sentences(target:interests:ageYears:excluding:count:) signature matches
spec sec 6.6 and fatalErrors so Track B-3 lands as a body-only change.

The 'twenty sentences' test fails until Task 11+12 author the sample
cell — this red light pins the cell-content contract.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 11: Author the sample cell `sh/vehicles_mid.json` (20 sentences)

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_mid.json`
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{sh,th,f,r,short_a}/.gitkeep`

This is the only **content authoring** task in B-1. The 20 sentences below were drafted in-conversation by Claude Code (per spec § 6.3) against the cell's allowed grapheme set (L2 alphabet ∪ {sh}) plus the sight-word whitelist (`the, a, and, is, to, on, at`), and every sentence satisfies the four validator rules (decodability, ≥4 sh occurrences, ≥3 sh-initial in content words, ≥1 vehicle-tag word, length ∈ [6, 10]). Subsequent cells in B-2 follow the same procedure: Claude Code drafts → validator checks → re-draft failures → commit.

- [ ] **Step 1: Create the five phoneme directory placeholders**

Run:
```sh
mkdir -p Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{sh,th,f,r,short_a}
for d in Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{th,f,r,short_a}; do
  : > "$d/.gitkeep"
done
```

(`sh/` will get the actual JSON file in the next step, so it does not need a `.gitkeep`.)

- [ ] **Step 2: Write the sample cell**

Write `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_mid.json`:

```json
{
  "phoneme": "sh",
  "phonemeIPA": "ʃ",
  "graphemeLetters": "sh",
  "interest": "vehicles",
  "ageBand": "mid",
  "sentences": [
    {
      "text": "Shen and Sharon shop for a ship at the shed.",
      "targetCount": 5,
      "targetInitialContentWords": 5,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen",   "graphemes": ["sh","e","n"],         "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],         "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "for",    "graphemes": ["f","o","r"],          "phonemes": ["f","ɔ","r"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "at",     "graphemes": ["a","t"],              "phonemes": ["æ","t"] },
        { "surface": "the",    "graphemes": ["t","h","e"],          "phonemes": ["ð","ə"] },
        { "surface": "shed",   "graphemes": ["sh","e","d"],         "phonemes": ["ʃ","ɛ","d"] }
      ]
    },
    {
      "text": "Shep has a shiny ship and a shop.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shep",  "graphemes": ["sh","e","p"],     "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "has",   "graphemes": ["h","a","s"],      "phonemes": ["h","æ","z"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shiny", "graphemes": ["sh","i","n","y"], "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "ship",  "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",   "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shop",  "graphemes": ["sh","o","p"],     "phonemes": ["ʃ","ɒ","p"] }
      ]
    },
    {
      "text": "Shen had a shiny shed and a swish tram.",
      "targetCount": 4,
      "targetInitialContentWords": 3,
      "interestWords": ["tram"],
      "words": [
        { "surface": "Shen",  "graphemes": ["sh","e","n"],     "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "had",   "graphemes": ["h","a","d"],      "phonemes": ["h","æ","d"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shiny", "graphemes": ["sh","i","n","y"], "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "shed",  "graphemes": ["sh","e","d"],     "phonemes": ["ʃ","ɛ","d"] },
        { "surface": "and",   "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "swish", "graphemes": ["s","w","i","sh"], "phonemes": ["s","w","ɪ","ʃ"] },
        { "surface": "tram",  "graphemes": ["t","r","a","m"],  "phonemes": ["t","r","æ","m"] }
      ]
    },
    {
      "text": "Sharon shut the shop and Shep had a ship.",
      "targetCount": 5,
      "targetInitialContentWords": 5,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "shut",   "graphemes": ["sh","u","t"],         "phonemes": ["ʃ","ʌ","t"] },
        { "surface": "the",    "graphemes": ["t","h","e"],          "phonemes": ["ð","ə"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],         "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Shep",   "graphemes": ["sh","e","p"],         "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "had",    "graphemes": ["h","a","d"],          "phonemes": ["h","æ","d"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] }
      ]
    },
    {
      "text": "Shep can shop and a ship has fish and cash.",
      "targetCount": 5,
      "targetInitialContentWords": 3,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shep", "graphemes": ["sh","e","p"], "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "can",  "graphemes": ["c","a","n"], "phonemes": ["k","æ","n"] },
        { "surface": "shop", "graphemes": ["sh","o","p"], "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "and",  "graphemes": ["a","n","d"], "phonemes": ["æ","n","d"] },
        { "surface": "a",    "graphemes": ["a"],         "phonemes": ["ə"] },
        { "surface": "ship", "graphemes": ["sh","i","p"], "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "has",  "graphemes": ["h","a","s"], "phonemes": ["h","æ","z"] },
        { "surface": "fish", "graphemes": ["f","i","sh"], "phonemes": ["f","ɪ","ʃ"] },
        { "surface": "and",  "graphemes": ["a","n","d"], "phonemes": ["æ","n","d"] },
        { "surface": "cash", "graphemes": ["c","a","sh"], "phonemes": ["k","æ","ʃ"] }
      ]
    },
    {
      "text": "A shiny ship can dash to the shop and back.",
      "targetCount": 4,
      "targetInitialContentWords": 3,
      "interestWords": ["ship"],
      "words": [
        { "surface": "A",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shiny", "graphemes": ["sh","i","n","y"], "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "ship",  "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "can",   "graphemes": ["c","a","n"],      "phonemes": ["k","æ","n"] },
        { "surface": "dash",  "graphemes": ["d","a","sh"],     "phonemes": ["d","æ","ʃ"] },
        { "surface": "to",    "graphemes": ["t","o"],          "phonemes": ["t","u"] },
        { "surface": "the",   "graphemes": ["t","h","e"],      "phonemes": ["ð","ə"] },
        { "surface": "shop",  "graphemes": ["sh","o","p"],     "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "and",   "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "back",  "graphemes": ["b","a","c","k"],  "phonemes": ["b","æ","k"] }
      ]
    },
    {
      "text": "Shen and Sharon ran a shop with a big ship.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen",   "graphemes": ["sh","e","n"],         "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "ran",    "graphemes": ["r","a","n"],          "phonemes": ["r","æ","n"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],         "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "with",   "graphemes": ["w","i","t","h"],      "phonemes": ["w","ɪ","θ"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "big",    "graphemes": ["b","i","g"],          "phonemes": ["b","ɪ","g"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] }
      ]
    },
    {
      "text": "The ship can shut and Shep has a shed.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "The",  "graphemes": ["t","h","e"], "phonemes": ["ð","ə"] },
        { "surface": "ship", "graphemes": ["sh","i","p"], "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "can",  "graphemes": ["c","a","n"], "phonemes": ["k","æ","n"] },
        { "surface": "shut", "graphemes": ["sh","u","t"], "phonemes": ["ʃ","ʌ","t"] },
        { "surface": "and",  "graphemes": ["a","n","d"], "phonemes": ["æ","n","d"] },
        { "surface": "Shep", "graphemes": ["sh","e","p"], "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "has",  "graphemes": ["h","a","s"], "phonemes": ["h","æ","z"] },
        { "surface": "a",    "graphemes": ["a"],         "phonemes": ["ə"] },
        { "surface": "shed", "graphemes": ["sh","e","d"], "phonemes": ["ʃ","ɛ","d"] }
      ]
    },
    {
      "text": "Sharon shops at the shed and Shep got a ship.",
      "targetCount": 5,
      "targetInitialContentWords": 5,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "shops",  "graphemes": ["sh","o","p","s"],     "phonemes": ["ʃ","ɒ","p","s"] },
        { "surface": "at",     "graphemes": ["a","t"],              "phonemes": ["æ","t"] },
        { "surface": "the",    "graphemes": ["t","h","e"],          "phonemes": ["ð","ə"] },
        { "surface": "shed",   "graphemes": ["sh","e","d"],         "phonemes": ["ʃ","ɛ","d"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Shep",   "graphemes": ["sh","e","p"],         "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "got",    "graphemes": ["g","o","t"],          "phonemes": ["g","ɒ","t"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] }
      ]
    },
    {
      "text": "A ship can swish and Shep can crush a shed.",
      "targetCount": 5,
      "targetInitialContentWords": 3,
      "interestWords": ["ship"],
      "words": [
        { "surface": "A",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "ship",  "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "can",   "graphemes": ["c","a","n"],      "phonemes": ["k","æ","n"] },
        { "surface": "swish", "graphemes": ["s","w","i","sh"], "phonemes": ["s","w","ɪ","ʃ"] },
        { "surface": "and",   "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "Shep",  "graphemes": ["sh","e","p"],     "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "can",   "graphemes": ["c","a","n"],      "phonemes": ["k","æ","n"] },
        { "surface": "crush", "graphemes": ["c","r","u","sh"], "phonemes": ["k","r","ʌ","ʃ"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shed",  "graphemes": ["sh","e","d"],     "phonemes": ["ʃ","ɛ","d"] }
      ]
    },
    {
      "text": "Shen got a shiny ship and a cab to shop.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship", "cab"],
      "words": [
        { "surface": "Shen",  "graphemes": ["sh","e","n"],     "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "got",   "graphemes": ["g","o","t"],      "phonemes": ["g","ɒ","t"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shiny", "graphemes": ["sh","i","n","y"], "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "ship",  "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",   "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "cab",   "graphemes": ["c","a","b"],      "phonemes": ["k","æ","b"] },
        { "surface": "to",    "graphemes": ["t","o"],          "phonemes": ["t","u"] },
        { "surface": "shop",  "graphemes": ["sh","o","p"],     "phonemes": ["ʃ","ɒ","p"] }
      ]
    },
    {
      "text": "Shep washed a van and a ship in a shed.",
      "targetCount": 4,
      "targetInitialContentWords": 3,
      "interestWords": ["van", "ship"],
      "words": [
        { "surface": "Shep",   "graphemes": ["sh","e","p"],         "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "washed", "graphemes": ["w","a","sh","e","d"], "phonemes": ["w","ɒ","ʃ","t"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "van",    "graphemes": ["v","a","n"],          "phonemes": ["v","æ","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "in",     "graphemes": ["i","n"],              "phonemes": ["ɪ","n"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "shed",   "graphemes": ["sh","e","d"],         "phonemes": ["ʃ","ɛ","d"] }
      ]
    },
    {
      "text": "Shen has a shiny jet and Sharon has a ship.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["jet", "ship"],
      "words": [
        { "surface": "Shen",   "graphemes": ["sh","e","n"],         "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "has",    "graphemes": ["h","a","s"],          "phonemes": ["h","æ","z"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "shiny",  "graphemes": ["sh","i","n","y"],     "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "jet",    "graphemes": ["j","e","t"],          "phonemes": ["dʒ","ɛ","t"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "has",    "graphemes": ["h","a","s"],          "phonemes": ["h","æ","z"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] }
      ]
    },
    {
      "text": "Sharon and Shep got on a ship to the shop.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Shep",   "graphemes": ["sh","e","p"],         "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "got",    "graphemes": ["g","o","t"],          "phonemes": ["g","ɒ","t"] },
        { "surface": "on",     "graphemes": ["o","n"],              "phonemes": ["ɒ","n"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "to",     "graphemes": ["t","o"],              "phonemes": ["t","u"] },
        { "surface": "the",    "graphemes": ["t","h","e"],          "phonemes": ["ð","ə"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],         "phonemes": ["ʃ","ɒ","p"] }
      ]
    },
    {
      "text": "A shiny ship dashed to a shop in a flash.",
      "targetCount": 5,
      "targetInitialContentWords": 3,
      "interestWords": ["ship"],
      "words": [
        { "surface": "A",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "shiny",  "graphemes": ["sh","i","n","y"],     "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "dashed", "graphemes": ["d","a","sh","e","d"], "phonemes": ["d","æ","ʃ","t"] },
        { "surface": "to",     "graphemes": ["t","o"],              "phonemes": ["t","u"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],         "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "in",     "graphemes": ["i","n"],              "phonemes": ["ɪ","n"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "flash",  "graphemes": ["f","l","a","sh"],     "phonemes": ["f","l","æ","ʃ"] }
      ]
    },
    {
      "text": "Shen took a cab to wash the ship and shed.",
      "targetCount": 4,
      "targetInitialContentWords": 3,
      "interestWords": ["cab", "ship"],
      "words": [
        { "surface": "Shen", "graphemes": ["sh","e","n"],     "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "took", "graphemes": ["t","o","o","k"],  "phonemes": ["t","ʊ","k"] },
        { "surface": "a",    "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "cab",  "graphemes": ["c","a","b"],      "phonemes": ["k","æ","b"] },
        { "surface": "to",   "graphemes": ["t","o"],          "phonemes": ["t","u"] },
        { "surface": "wash", "graphemes": ["w","a","sh"],     "phonemes": ["w","ɒ","ʃ"] },
        { "surface": "the",  "graphemes": ["t","h","e"],      "phonemes": ["ð","ə"] },
        { "surface": "ship", "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",  "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "shed", "graphemes": ["sh","e","d"],     "phonemes": ["ʃ","ɛ","d"] }
      ]
    },
    {
      "text": "Shen and Shep sat in a ship in the shop.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen", "graphemes": ["sh","e","n"], "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "and",  "graphemes": ["a","n","d"], "phonemes": ["æ","n","d"] },
        { "surface": "Shep", "graphemes": ["sh","e","p"], "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "sat",  "graphemes": ["s","a","t"], "phonemes": ["s","æ","t"] },
        { "surface": "in",   "graphemes": ["i","n"],     "phonemes": ["ɪ","n"] },
        { "surface": "a",    "graphemes": ["a"],         "phonemes": ["ə"] },
        { "surface": "ship", "graphemes": ["sh","i","p"], "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "in",   "graphemes": ["i","n"],     "phonemes": ["ɪ","n"] },
        { "surface": "the",  "graphemes": ["t","h","e"], "phonemes": ["ð","ə"] },
        { "surface": "shop", "graphemes": ["sh","o","p"], "phonemes": ["ʃ","ɒ","p"] }
      ]
    },
    {
      "text": "A shiny ship and a cab made Shen rush.",
      "targetCount": 4,
      "targetInitialContentWords": 3,
      "interestWords": ["ship", "cab"],
      "words": [
        { "surface": "A",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "shiny", "graphemes": ["sh","i","n","y"], "phonemes": ["ʃ","aɪ","n","i"] },
        { "surface": "ship",  "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",   "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "a",     "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "cab",   "graphemes": ["c","a","b"],      "phonemes": ["k","æ","b"] },
        { "surface": "made",  "graphemes": ["m","a","d","e"],  "phonemes": ["m","e","d"] },
        { "surface": "Shen",  "graphemes": ["sh","e","n"],     "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "rush",  "graphemes": ["r","u","sh"],     "phonemes": ["r","ʌ","ʃ"] }
      ]
    },
    {
      "text": "Sharon and Shep wash a ship and a cab.",
      "targetCount": 4,
      "targetInitialContentWords": 3,
      "interestWords": ["ship", "cab"],
      "words": [
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Shep",   "graphemes": ["sh","e","p"],         "phonemes": ["ʃ","ɛ","p"] },
        { "surface": "wash",   "graphemes": ["w","a","sh"],         "phonemes": ["w","ɒ","ʃ"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "cab",    "graphemes": ["c","a","b"],          "phonemes": ["k","æ","b"] }
      ]
    },
    {
      "text": "Shen had a fast ship and Sharon had a shed.",
      "targetCount": 4,
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen",   "graphemes": ["sh","e","n"],         "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "had",    "graphemes": ["h","a","d"],          "phonemes": ["h","æ","d"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "fast",   "graphemes": ["f","a","s","t"],      "phonemes": ["f","æ","s","t"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],         "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "had",    "graphemes": ["h","a","d"],          "phonemes": ["h","æ","d"] },
        { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
        { "surface": "shed",   "graphemes": ["sh","e","d"],         "phonemes": ["ʃ","ɛ","d"] }
      ]
    }
  ]
}
```

- [ ] **Step 3: Run the validator on the bundle to confirm all 20 sentences pass**

Run:
```sh
(cd dev-tools/sentence-validator && \
  swift run sentence-validator \
  --bundle ../../Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary)
```

Expected output:
```
sentence-validator: 1 cells, 20 sentences
  PASS
```

If any sentence fails: read the violation, edit the offending entry in the JSON, re-run. The four common-failure modes and remedies:
- `undecodableGrapheme` — a grapheme outside L2 ∪ {sh} ∪ sight whitelist crept in. Re-tokenize the word into single letters or pick a different word.
- `targetCountTooLow` — fewer than 4 `sh` graphemes total. Add another `sh`-bearing word (proper noun pool: `Shen, Sharon, Shep, Shari`) or coda word (`fish, dish, wish, mash, cash, dash, gash, hash, bash, gosh, hush, rush, brush, crush`).
- `targetInitialContentWordsTooLow` — fewer than 3 sh-initial content words. Replace a coda-sh word with an onset-sh one.
- `interestWordNotInSentence` — typo in the `interestWords` tag. Compare against the `text` and `words` arrays.

- [ ] **Step 4: Re-run the SentenceLibrary tests now that the cell exists**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter SentenceLibraryTests)
```

Expected: PASS for all three (including `test_cell_returnsTwentySentencesForSampleCell` which previously failed).

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/
git commit -m "engines(content): sample cell sh/vehicles_mid (20 validated sentences)

The single fully-populated B-1 cell. Twenty tongue-twister-style
decodable sentences for sh-week vehicles-interest mid-age-band learners,
each satisfying:
  - graphemes in L2 alphabet ∪ {sh} (sight word whitelist excepted)
  - sh appears word-initial in >=3 content words
  - sh appears >=4 times total
  - >=1 interest-tagged word from the vehicles vocabulary
  - 6 to 10 words in length

Drafted in-conversation by Claude Code per spec sec 6.3 (no API calls,
no Python LLM client). Validator confirms all 20 pass.

Empty .gitkeep files in th/, f/, r/, short_a/ pin the directory layout
for B-2 incremental fill.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 12: CI integration + lint + full build + commit + PR

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read the existing CI workflow to find the right insertion point**

Run:
```sh
grep -n 'swift test' .github/workflows/ci.yml | head -10
```

Expected: a line near `for pkg in MoraCore MoraEngines MoraUI MoraTesting MoraFixtures; do` that runs `(cd Packages/$pkg && swift test)`. The validator step belongs **immediately after** that loop's `done` line, inside the same job.

- [ ] **Step 2: Add the validator step**

Edit `.github/workflows/ci.yml`. Find the SPM test loop:

```yaml
      - name: SPM tests
        run: |
          set -euo pipefail
          for pkg in MoraCore MoraEngines MoraUI MoraTesting MoraFixtures; do
            (cd Packages/$pkg && swift test)
          done
```

(The exact step name and indentation may differ; preserve them.) Add a new step immediately after, at the same indentation level:

```yaml
      - name: Validate decodable sentence library
        run: |
          set -euo pipefail
          (cd dev-tools/sentence-validator && swift test)
          swift run --package-path dev-tools/sentence-validator \
            sentence-validator \
            --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

The two commands run unconditionally on every PR — the validator's own unit/CLI tests AND the live bundle check. Adding a `paths:` filter is deliberately skipped because B-2 will commit JSON-only PRs that need this gate exactly when no Swift code changed.

- [ ] **Step 3: Run swift-format strict lint locally**

Run:
```sh
swift-format lint --strict --recursive \
  Mora Packages/*/Sources Packages/*/Tests \
  dev-tools/sentence-validator/Sources dev-tools/sentence-validator/Tests
```

Expected: clean exit. If any new file has a violation, `swift-format format --in-place` it (with the same path arguments) and re-stage.

- [ ] **Step 4: Run all package tests + the validator end-to-end**

Run:
```sh
(cd Packages/MoraCore && swift test) && \
(cd Packages/MoraEngines && swift test) && \
(cd Packages/MoraUI && swift test) && \
(cd Packages/MoraTesting && swift test) && \
(cd dev-tools/sentence-validator && swift test) && \
swift run --package-path dev-tools/sentence-validator \
  sentence-validator \
  --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: every step exits 0; the validator prints `1 cells, 20 sentences  PASS`.

- [ ] **Step 5: Regenerate Xcode project + run xcodebuild**

`DEVELOPMENT_TEAM` is now committed in `project.yml` (per merged PR #84 and memory `feedback_mora_xcodegen_team_injection`), so no inject-and-revert ritual is needed.

Run:
```sh
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED`. The new `Resources/SentenceLibrary/` directory is picked up automatically by `.process("Resources")` so the regenerated project has nothing manual to wire.

- [ ] **Step 6: Commit the CI step**

```sh
git add .github/workflows/ci.yml
git commit -m "ci: validate decodable sentence library on every PR

Runs the validator's own unit + CLI tests, then exercises the live
bundle (Packages/MoraEngines/.../Resources/SentenceLibrary) so the gate
fires on JSON-only PRs in Track B-2 — the case where no Swift code
changed but content did. No paths: filter for that reason.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

- [ ] **Step 7: Push the branch and open the PR**

Push to a feature branch:

```sh
git checkout -b feat/sentence-library-validator
git push -u origin feat/sentence-library-validator
gh pr create \
  --title "tools+engines+content: decodable sentence library validator + sample cell (Track B-1)" \
  --body "$(cat <<'EOF'
## Summary

Track B-1 of the spec at `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6.

Lands the **schema, validator, in-app loader, and one fully-validated sample cell** so Track B-2 can fill the remaining 89 cells with JSON-only PRs (no further code changes) and Track B-3 can wire the runtime selector.

## Architecture

- New `dev-tools/sentence-validator/` Swift CLI (mirrors `dev-tools/pronunciation-bench/` layout).
  - Validates `Resources/SentenceLibrary/{phoneme}/{interest}_{ageBand}.json` against four rules: decodability, ≥4 target occurrences, ≥3 target word-initial in content words, ≥1 interest-tag word, length ∈ [6, 10].
  - Computes the allowed grapheme set for each cell from `MoraEngines.CurriculumEngine.taughtGraphemes(beforeWeekIndex:) ∪ {target}`.
  - Sight-word whitelist (`the, a, and, is, to, on, at`) lives in the validator and `SentenceLibrary` loader; centralizing it later (e.g., in `MoraCore`) is a natural follow-up.
- New `MoraCore.AgeBand` enum: `early` (4–7), `mid` (8–10), `late` (11+).
- New `MoraEngines.SentenceLibrary` actor: loads `Bundle.module` resources at init; exposes `cell(phoneme:interest:ageBand:)` for tests; selector method body fatalErrors and is filled by Track B-3.
- New `Resources/SentenceLibrary/{sh,th,f,r,short_a}/` directory tree. Only `sh/vehicles_mid.json` is populated (20 sentences); the four other phoneme directories are placeholders pinned with `.gitkeep`.

## Sample-cell content

Twenty tongue-twister-style sentences for `sh × vehicles × mid`. Drafted in-conversation by Claude Code per spec § 6.3 — **no Claude API calls, no Python LLM client, no model download** — and committed only after the validator confirms all 20 pass.

## Deviations from spec (also documented in the plan)

- Validator location is `dev-tools/sentence-validator/` (not `tools/sentence-validator/`) to match the existing Swift CLI convention (`dev-tools/pronunciation-bench/`). `tools/yokai-forge/` is Python.
- `interestWords` is per-sentence author-provided; the validator checks the list is non-empty and every entry surfaces in the sentence, but does not maintain a centralized `(interest, ageBand) → vocabulary` table for v1.
- `SentenceLibrary.sentences(...)` body is `fatalError("...")`. Track B-3 fills it.

## Test plan

- [x] `swift test` for MoraCore / MoraEngines / MoraUI / MoraTesting
- [x] `swift test` for dev-tools/sentence-validator (`ValidatorTests` + `CLITests`)
- [x] `swift run sentence-validator --bundle ...` reports `1 cells, 20 sentences  PASS`
- [x] `swift-format lint --strict` clean
- [x] `xcodegen generate && xcodebuild build` on iOS Simulator
- [ ] On-device: visually confirm the sample cell is included in the app bundle (resource is loaded via `Bundle.module`; unit tests already prove the loader sees it, but a Release-config run on hardware confirms `.process("Resources")` picked up the new subdirectory)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 8: No commit needed for this step**

Verification + PR open is the deliverable.

---

## Self-Review

### Spec coverage

| Spec section            | Plan task                                     |
|-------------------------|-----------------------------------------------|
| § 6.1 matrix design     | Tasks 9 (`AgeBand`), 10 (`SentenceLibrary` keys + 5-phoneme dir tree) |
| § 6.2 sentence rules    | Tasks 4 (decodability), 5 (density), 6 (interest + length) — every rule has a validator branch + test |
| § 6.3 generation flow   | Task 11 — drafted in-conversation, validated, committed |
| § 6.4 validator         | Tasks 1–8 — full Swift CLI with unit + fixture tests |
| § 6.5 JSON schema       | Task 2 (Codable types in validator), Task 10 (Codable types in `SentenceLibrary` loader), Task 11 (sample-cell file matches the schema) |
| § 6.6 runtime types     | Task 9 (`AgeBand`), Task 10 (`SentenceLibrary` actor with `init(bundle:)` + cell lookup; selector signature stubbed) |
| § 6.7 bootstrap         | **Track B-3** (out of scope for this plan; signature pinned in Task 10 so B-3 lands as a body-only change) |
| § 6.10 tests            | `AgeBandTests` (Task 9), `SentenceLibraryTests` (Task 10), `ValidatorTests` (Tasks 4–6), `CLITests` (Task 8); Decodability/Density tests for the bundled cell are subsumed by Task 11 Step 3 (validator is the single source of truth) |
| § 9 PR 2 done state     | Task 12 PR description and acceptance bullets |

### Type consistency

- `Validator.validate(sentence:map:curriculum:sightWords:)` — same signature in tests (Task 4–6) and CLI (Task 7).
- `PhonemeDirectoryMap.lookup(directory:)` — same call site shape in CLI (Task 7) and tests (Task 4).
- `SentenceLibrary.cell(phoneme:interest:ageBand:)` — `phoneme` is the directory-name `String` (e.g., `"sh"`), `interest` is the `InterestCategory.key` `String` (e.g., `"vehicles"`), `ageBand` is `AgeBand`. Both the loader's `CellKey` and the test's call use this triple in this order.
- `AgeBand` raw values (`"early"`, `"mid"`, `"late"`) — match the JSON `"ageBand"` field, the test, and the documented bucket boundaries.
- `Violation` enum cases — every test asserts on a case that's defined in `Validator.swift` (Task 4 + appended in Task 5/6), with associated values in the same order.
- `CellPayload` (validator, Task 2) and `CellPayload` (loader, Task 10) are structurally identical but live in separate modules — both decode the same JSON shape; this is intentional duplication to keep the validator standalone (no MoraEngines-internal types leak into the CLI).

### Placeholder scan

- No "TBD", "TODO", or "implement later" except the deliberate `fatalError("SentenceLibrary.sentences — selector wiring is Track B-3")` in Task 10, which is documented in the deviations note and pinned by the spec § 9 PR 2 boundary.
- No "similar to Task N" — every code block stands alone.
- All shell commands have expected output described.
- The 20-sentence cell is fully inline in Task 11; the executor copies the JSON verbatim.

### Risks the plan handles inline

- **Sample-cell drafting drift** — Task 11 Step 3 re-runs the validator and Step 4 has a four-bullet remediation guide for the four common failure modes.
- **`DecodeSentence` may not exist as a public type** — Task 10 Step 5 verifies via `grep` and surfaces to the user if missing rather than guessing.
- **CI workflow indentation may differ from the assumed shape** — Task 12 Step 1 reads the file first to find the SPM test loop precisely; Step 2 asks the executor to preserve the existing indentation when adding the new step.
- **`swift-format` `{ }` rule** (per memory `feedback_mora_alpha_plan_drift` cousin from yokai plan) — none of the new code blocks contain empty closure literals; no proactive fix needed, but Task 12 Step 3 catches it if it slipped in.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-decodable-sentence-library-validator.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
