# Decodable Sentence Library — Selector + Bootstrap Integration (Track B-3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `SentenceLibrary.sentences(...)`'s `fatalError` body with a real selector, then wire `SessionContainerView.bootstrap` to call it before falling back to the per-week `<skill>_week.json` path. After this PR, an `sh`-week session for a learner with `interests=[dinosaurs]` returns three sentences from the bundled `sh × dinosaurs × {ageBand}` cell instead of the three hand-authored ones; an `sh`-week session for a learner with `interests=[robots]` returns three different sentences from `sh × robots × {ageBand}`. Cells that have not been authored yet (`th`, `f`, `r`, `short_a` at the time this PR lands) silently fall through to the existing per-week JSON.

**Architecture:** Selector logic stays inside the existing `actor SentenceLibrary` so cell access remains serialized. The selector resolves `SkillCode → phoneme directory` via a small static map duplicated from `dev-tools/sentence-validator/Sources/SentenceValidator/PhonemeDirectoryMap.swift` (validator and runtime cannot share — the validator is outside the app build), pools sentences across the learner's interests, drops the `excluding` filter only when the post-filter pool is too small to satisfy `count`, and shuffles before slicing. Bootstrap fetches the singleton `LearnerProfile` directly via `FetchDescriptor`, calls the selector, and falls back to `ScriptedContentProvider.bundled(for:)` when the selector returns fewer than `count` sentences.

**Tech Stack:** Swift 6 (language mode 5), SwiftData, `actor` isolation, `XCTest`, `swift-format`, `xcodegen`/`xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6.6, § 6.7, § 6.10, § 9 PR 4.

---

## Deviations from spec (read first)

1. **Freshness window is dropped for v1.** Spec § 6.7 says `recentSurfaces` "is computed by reading the last K `SessionSummaryEntity` rows for the current week (already persisted) and unioning their sentence surface forms." The current `SessionSummaryEntity` (`Packages/MoraCore/Sources/MoraCore/Persistence/SessionSummaryEntity.swift`) does **not** persist sentence text — it only stores `targetSkillCode`, `durationSec`, `trialsTotal`, `trialsCorrect`, etc. Persisting surfaces would require a SwiftData schema change, which spec § 7 explicitly forbids ("No SwiftData migrations"). v1 ships with `excluding: []` from the call site; the API parameter stays so a future PR can add a `decodedSentenceTextsJSON` optional field (additive, non-migrating) without changing the selector signature. With ≥ 20 sentences per cell × up to 6 cells per `(target, ageBand)` (one per interest), pool sizes range from 20 (single-interest learner, only one cell exists) to 120 (six-interest learner, all cells filled), and a uniform random sample of 3 produces low collision rates within a single week even without freshness.

2. **Sentence count per session is bumped from 2 → 3** to match spec § 6.7. The existing bootstrap calls `provider.decodeSentences` with `count: 2` (`SessionContainerView.swift:380`). Spec § 6.7's example uses `count: 3`. Honoring the spec adds one extra sentence per session — visible to the learner as one more `ShortSentencesView` trial. If the user pushes back on the longer session, the fix is a one-character change at the call site.

3. **Selector is `nonisolated` on the load-once actor state.** `SentenceLibrary` is an `actor` so cells are read under actor isolation, but the selector body does **only**: dictionary lookup, array flattening, `Set.contains` on the `excluding` filter, `Array.shuffled()`, and `Array.prefix(count)`. None mutate state. The actor isolation is redundant here but harmless; keeping the method `async` matches the spec signature and lets a future implementation safely add per-actor caches without an API break.

4. **`SkillCode → phoneme directory` mapping is duplicated, not shared.** The validator's `PhonemeDirectoryMap` lives at `dev-tools/sentence-validator/Sources/SentenceValidator/PhonemeDirectoryMap.swift`; that target is outside the MoraEngines build. Moving it into MoraEngines would force the validator to import the runtime, which is undesirable (validator is intentionally separate so it can run without the full app graph). The duplication is 5 entries — a constant table — with low maintenance burden (it changes only when the v1 ladder's `SkillCode`s change, which is also a spec-locked surface).

5. **`LearnerProfile` is fetched inside `bootstrap()` via `FetchDescriptor`, not pre-injected.** Other views in the codebase (`HomeView`, `RootView`) declare `@Query` at the view level. `SessionContainerView.bootstrap` is a method, not a SwiftUI body, so a `@Query` would either be redundant (re-fetched on every body evaluation) or prematurely bind the value. A direct `FetchDescriptor<LearnerProfile>` fetch in `bootstrap` returns the first profile (there is exactly one in this single-learner alpha) and falls back to `(ageYears: 8, interests: [])` if no profile exists yet (e.g. a session somehow starting before onboarding completes — defensive only).

6. **`Bundle.module`-based init stays the only entry point.** Spec § 6.6 declares `init(bundle: Bundle = .module)`. The current source defines `init()` (no-arg, calls `init(bundle: .module)` internally) and `init(bundle: Bundle)` separately, plus an `init(rootURL: URL)` for tests. Track B-3 does not change these initializers; bootstrap uses `try SentenceLibrary()` to get the bundled cells.

---

## File Structure

### Files to Create

| Path | Responsibility |
|------|----------------|
| `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibrarySelectorTests.swift` | Unit tests for the new selector body — interest filtering, fallback to all-interests when learner has none, freshness-when-pool-large path, freshness-relaxation when pool small, return `[]` when no cells. |
| `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift` | Headless bootstrap test exercising the library hit-path and the fallback path with two `LearnerProfile` fixtures. |

### Files to Modify

| Path | Change |
|------|--------|
| `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift` | Replace the `fatalError` body of `sentences(target:interests:ageYears:excluding:count:)` with the selector logic; add a private `directoryForSkillCode` map; add a private `allInterestKeys` constant for the empty-interest fallback. |
| `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` | After resolving `skill`/`target`/`taught`/`targetGrapheme` (around `:377`), call `SentenceLibrary().sentences(...)`; if it returns ≥ `count`, use those; else fall through to the existing `ScriptedContentProvider.bundled(for:).decodeSentences(...)` path. Bump the count constant from `2` to `3` in both branches. |

### Files NOT modified

- `Packages/MoraCore/Sources/MoraCore/AgeBand.swift` — already shipped with B-1.
- `Packages/MoraCore/Sources/MoraCore/Persistence/SessionSummaryEntity.swift` — no schema change (see Deviation 1).
- `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift` — orchestrator still receives a `[DecodeSentence]` from bootstrap; selection logic stays out of the orchestrator.
- `dev-tools/sentence-validator/` — validator is unaffected; the runtime selector reads cells the validator already gates.
- `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/**.json` — no content changes.

---

## Task 1: Smoke check — confirm pre-existing state

**Goal:** Before touching the selector, verify `main` is in the state Track B-2 Phase 1 left it: 18 cells × 20 sentences for `sh`, `SentenceLibrary.sentences(...)` is `fatalError`, `SessionContainerView.bootstrap` calls `ScriptedContentProvider.decodeSentences` directly with `count: 2`.

**Files:** none modified.

- [ ] **Step 1: Run validator.**

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: exit 0, output includes `sentence-validator: 18 cells, 360 sentences\n  PASS`. If anything else, **STOP** — `main` is not at the expected B-2 Phase 1 state and proceeding will produce confusing test failures.

- [ ] **Step 2: Run MoraEngines tests.**

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -10)
```

Expected: all tests pass, including `SentenceLibraryTests` (5 tests). The `fatalError` selector is exercised by zero tests today.

- [ ] **Step 3: Confirm selector body is still `fatalError`.**

```sh
grep -n "Track B-3" Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift
```

Expected: one match referencing `fatalError("SentenceLibrary.sentences — selector wiring is Track B-3")`.

- [ ] **Step 4: No commit.** Verification only.

---

## Task 2: Add SkillCode → directory map and interest constants

**Goal:** Land the static lookup tables that the selector needs, with no behavior change yet (selector body stays `fatalError`). This is a pure additive step so the diff for Task 3's body change reads cleanly.

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`

- [ ] **Step 1: Add `directoryForSkillCode` and `allInterestKeys` as private static constants.**

In `SentenceLibrary.swift`, locate the existing `private static let phonemeDirectories: [String]` (around line 92) and add directly above it:

```swift
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

/// Six interest keys mirrored from `JapaneseL1Profile.interestCategories`.
/// Used as the fallback set when a learner has no `interests` recorded
/// (e.g. a profile from before the interest picker shipped — only the
/// dev profile is in this state).
private static let allInterestKeys: [String] = [
    "animals", "dinosaurs", "vehicles", "space", "sports", "robots",
]
```

- [ ] **Step 2: Build to confirm no regressions.**

```sh
(cd Packages/MoraEngines && swift build 2>&1 | tail -5)
```

Expected: build success. The new constants are unused at this point, which is fine — Swift does not warn on unused private statics.

- [ ] **Step 3: Run existing MoraEngines tests.**

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -5)
```

Expected: all tests pass; counts unchanged.

- [ ] **Step 4: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift
git commit -m "engines(sentence-library): add SkillCode→directory map + interest fallback list"
```

---

## Task 3: Write failing selector tests

**Goal:** Lock the selector's behavior in before implementing it. Five tests cover: interest filtering, all-interests fallback, count satisfied from one cell, count requires multiple cells, no cells available.

**Files:**
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibrarySelectorTests.swift`

- [ ] **Step 1: Create the test file with all five test methods.**

Write `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibrarySelectorTests.swift`:

```swift
import Foundation
import XCTest

@testable import MoraCore
@testable import MoraEngines

final class SentenceLibrarySelectorTests: XCTestCase {
    /// Bundled library has only `sh × {6 interests} × {3 ageBands} = 18` cells
    /// at this PR's HEAD. All assertions below are framed against that state.

    /// A learner with `interests = ["vehicles"]` and `ageYears = 9` (mid band)
    /// must see only sentences from `sh × vehicles × mid`.
    func test_sentences_singleInterest_returnsFromMatchingCell() async throws {
        let library = try SentenceLibrary()

        let result = await library.sentences(
            target: "sh_onset",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: [],
            count: 3
        )

        XCTAssertEqual(result.count, 3)

        let cell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let cellTexts = Set(cell?.sentences.map(\.text) ?? [])
        for sentence in result {
            XCTAssertTrue(
                cellTexts.contains(sentence.text),
                "expected sentence text to come from sh × vehicles × mid; got \(sentence.text)"
            )
        }
    }

    /// A learner with `interests = ["dinosaurs", "robots"]` and `ageYears = 9`
    /// must see sentences pooled from both cells.
    func test_sentences_multipleInterests_poolsAcrossCells() async throws {
        let library = try SentenceLibrary()

        // Run multiple selections so the random shuffle has a chance to span
        // both cells. With pool size 40 and a count of 6 (cap at 3 per call,
        // call twice, dedupe), the union is overwhelmingly likely to span
        // both cells.
        var union: Set<String> = []
        for _ in 0..<10 {
            let result = await library.sentences(
                target: "sh_onset",
                interests: ["dinosaurs", "robots"],
                ageYears: 9,
                excluding: union,
                count: 3
            )
            for sentence in result { union.insert(sentence.text) }
        }

        let dinoCell = await library.cell(phoneme: "sh", interest: "dinosaurs", ageBand: .mid)
        let roboCell = await library.cell(phoneme: "sh", interest: "robots", ageBand: .mid)
        let dinoTexts = Set(dinoCell?.sentences.map(\.text) ?? [])
        let roboTexts = Set(roboCell?.sentences.map(\.text) ?? [])

        XCTAssertTrue(
            union.contains(where: dinoTexts.contains),
            "expected at least one dinosaur sentence in the union")
        XCTAssertTrue(
            union.contains(where: roboTexts.contains),
            "expected at least one robot sentence in the union")
    }

    /// A learner with empty `interests` falls back to all six interest cells
    /// for the resolved `(target, ageBand)`.
    func test_sentences_emptyInterests_fallsBackToAllInterests() async throws {
        let library = try SentenceLibrary()

        var union: Set<String> = []
        for _ in 0..<5 {
            let result = await library.sentences(
                target: "sh_onset",
                interests: [],
                ageYears: 9,
                excluding: union,
                count: 3
            )
            for sentence in result { union.insert(sentence.text) }
        }

        // After 5 calls × 3 sentences = 15 unique selections from a pool of
        // 6 × 20 = 120, the union must include sentences from at least two
        // distinct interest cells.
        let allMidCellTexts: [(interest: String, texts: Set<String>)] = await {
            var rows: [(String, Set<String>)] = []
            for interest in ["animals", "dinosaurs", "vehicles", "space", "sports", "robots"] {
                let cell = await library.cell(phoneme: "sh", interest: interest, ageBand: .mid)
                rows.append((interest, Set(cell?.sentences.map(\.text) ?? [])))
            }
            return rows
        }()

        let interestsHit = allMidCellTexts.filter { row in
            !row.texts.isDisjoint(with: union)
        }.map(\.interest)

        XCTAssertGreaterThanOrEqual(
            interestsHit.count, 2,
            "expected union to span ≥ 2 interest cells, got \(interestsHit)")
    }

    /// When `excluding` is small and pool is large, returned sentences must
    /// not overlap the excluded set.
    func test_sentences_excludingFilter_skipsExcluded() async throws {
        let library = try SentenceLibrary()
        let cell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let texts = (cell?.sentences.map(\.text) ?? [])
        let excluded = Set(texts.prefix(15))  // exclude 15 of 20

        let result = await library.sentences(
            target: "sh_onset",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: excluded,
            count: 3
        )

        XCTAssertEqual(result.count, 3)
        for sentence in result {
            XCTAssertFalse(
                excluded.contains(sentence.text),
                "sentence should have been filtered out: \(sentence.text)")
        }
    }

    /// When `excluding` is so large that the post-filter pool is below `count`,
    /// the selector relaxes the filter and samples from the full pool.
    func test_sentences_excludingTooLarge_relaxesFilter() async throws {
        let library = try SentenceLibrary()
        let cell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let texts = (cell?.sentences.map(\.text) ?? [])
        // Exclude 19 of 20 — post-filter pool is 1, below count=3.
        let excluded = Set(texts.prefix(19))

        let result = await library.sentences(
            target: "sh_onset",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: excluded,
            count: 3
        )

        XCTAssertEqual(result.count, 3)
        // Some of the returned sentences MUST come from the excluded set,
        // because the unexcluded pool only has 1 entry and we asked for 3.
        let returnedTexts = Set(result.map(\.text))
        XCTAssertGreaterThanOrEqual(
            returnedTexts.intersection(excluded).count, 2,
            "expected ≥ 2 of 3 returned sentences to come from the excluded set after relaxation")
    }

    /// When no cells exist for the target (e.g. `th` at this PR's HEAD), the
    /// selector returns `[]` so the caller can fall back to the per-week JSON.
    func test_sentences_noCellsForTarget_returnsEmpty() async throws {
        let library = try SentenceLibrary()

        let result = await library.sentences(
            target: "th_voiceless",
            interests: ["robots"],
            ageYears: 9,
            excluding: [],
            count: 3
        )

        XCTAssertTrue(result.isEmpty, "expected [] for target with no authored cells; got \(result.count)")
    }

    /// Unknown SkillCode (not in `directoryForSkillCode`) returns `[]`.
    func test_sentences_unknownSkillCode_returnsEmpty() async throws {
        let library = try SentenceLibrary()

        let result = await library.sentences(
            target: "not_a_real_skill",
            interests: ["vehicles"],
            ageYears: 9,
            excluding: [],
            count: 3
        )

        XCTAssertTrue(result.isEmpty, "expected [] for unknown SkillCode")
    }
}
```

- [ ] **Step 2: Run the new tests; confirm they all FAIL with `fatalError`.**

```sh
(cd Packages/MoraEngines && swift test --filter SentenceLibrarySelectorTests 2>&1 | tail -25)
```

Expected: every test crashes with `Fatal error: SentenceLibrary.sentences — selector wiring is Track B-3`. The test process exits non-zero on the first crash, so XCTest may only show 1 failure — that's fine, the body is uniformly `fatalError`.

If a test passes, the selector body has already been changed: revert and start over.

- [ ] **Step 3: Commit.**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibrarySelectorTests.swift
git commit -m "engines(sentence-library): add failing selector tests for interest pool + freshness + fallback"
```

---

## Task 4: Implement the selector body

**Goal:** Replace the `fatalError` body with the selection algorithm. All seven tests from Task 3 must pass.

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`

- [ ] **Step 1: Replace the selector body.**

In `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`, locate the existing method:

```swift
public func sentences(
    target: SkillCode,
    interests: [String],
    ageYears: Int,
    excluding seenSurfaces: Set<String> = [],
    count: Int
) async -> [DecodeSentence] {
    fatalError("SentenceLibrary.sentences — selector wiring is Track B-3")
}
```

Replace the body with:

```swift
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
```

- [ ] **Step 2: Run the selector tests.**

```sh
(cd Packages/MoraEngines && swift test --filter SentenceLibrarySelectorTests 2>&1 | tail -25)
```

Expected: all 7 tests pass. If `test_sentences_excludingFilter_skipsExcluded` flakes due to randomness (extremely unlikely given the 5/20 unexcluded pool), re-run; if it persistently fails, the filter logic is wrong.

- [ ] **Step 3: Run the full MoraEngines suite.**

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -10)
```

Expected: all tests pass — including the existing 5 `SentenceLibraryTests`. The selector implementation does not change cell loading, so `SentenceLibraryTests` is unaffected.

- [ ] **Step 4: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift
git commit -m "engines(sentence-library): implement selector — interest pool + freshness relaxation"
```

---

## Task 5: Write failing bootstrap-integration test

**Goal:** Lock the bootstrap behavior before changing the wiring. The test runs `SessionContainerView` headlessly with two `LearnerProfile` fixtures (a vehicles-mid learner and a robots-late learner on the same `sh` week) and asserts they receive different sentence triples drawn from their respective bundle cells.

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift`

- [ ] **Step 1: Read the existing bootstrap-integration test pattern.**

Run:
```sh
ls Packages/MoraUI/Tests/MoraUITests/
```

Note: Other Session* tests (e.g. `SessionContainerBootstrap*`) do not yet exist. The new test file is the first integration test for `bootstrap()`. It does **not** drive the SwiftUI body — instead it relies on the orchestrator's `sentences` field as the observable output.

Bootstrap is private. To exercise it without going through SwiftUI, we extract the sentence selection into a small free function that takes the necessary inputs and returns the resolved sentences. **Task 6** does that extraction; **this task** writes the test that the extracted function will satisfy.

- [ ] **Step 2: Write the test file.**

Write `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift`:

```swift
import Foundation
import SwiftData
import XCTest

@testable import MoraCore
@testable import MoraEngines
@testable import MoraUI

final class SessionContainerBootstrapLibraryTests: XCTestCase {
    /// Two learners on the same `sh` week with disjoint single-element
    /// `interests`: one picks vehicles-mid, one picks robots-late. The
    /// bootstrap helper must return sentences from `sh × vehicles × mid`
    /// and `sh × robots × late` respectively.
    func test_resolveSentences_vehiclesMid_returnsFromVehiclesMidCell() async throws {
        let library = try SentenceLibrary()
        let vehiclesCell = await library.cell(
            phoneme: "sh", interest: "vehicles", ageBand: .mid
        )
        let cellTexts = Set(vehiclesCell?.sentences.map(\.text) ?? [])

        let resolved = await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "sh_onset",
            targetGrapheme: Grapheme(letters: "sh"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 0),
            ageYears: 9,
            interests: ["vehicles"],
            count: 3
        )

        XCTAssertEqual(resolved.count, 3)
        for sentence in resolved {
            XCTAssertTrue(
                cellTexts.contains(sentence.text),
                "expected vehicles-mid sentence; got \(sentence.text)")
        }
    }

    func test_resolveSentences_robotsLate_returnsFromRobotsLateCell() async throws {
        let library = try SentenceLibrary()
        let robotsCell = await library.cell(
            phoneme: "sh", interest: "robots", ageBand: .late
        )
        let cellTexts = Set(robotsCell?.sentences.map(\.text) ?? [])

        let resolved = await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "sh_onset",
            targetGrapheme: Grapheme(letters: "sh"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 0),
            ageYears: 12,
            interests: ["robots"],
            count: 3
        )

        XCTAssertEqual(resolved.count, 3)
        for sentence in resolved {
            XCTAssertTrue(
                cellTexts.contains(sentence.text),
                "expected robots-late sentence; got \(sentence.text)")
        }
    }

    /// When the library has no cells for the target (e.g. `th` at this PR's
    /// HEAD), the helper must fall back to the per-week JSON path so the
    /// session still runs. The fallback returns the existing 3 hand-authored
    /// sentences from `<skill>_week.json`.
    func test_resolveSentences_unauthoredTarget_fallsBackToScriptedProvider() async throws {
        let library = try SentenceLibrary()

        let resolved = await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "th_voiceless",
            targetGrapheme: Grapheme(letters: "th"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 1),
            ageYears: 9,
            interests: ["robots"],
            count: 3
        )

        // Per-week JSON fallback returns 3 sentences (the existing hand-authored
        // set).  The exact texts depend on `<skill>_week.json` so we assert
        // count rather than content.
        XCTAssertEqual(resolved.count, 3)
    }

    /// Empty interests on a learner created before the interest picker — the
    /// helper must fall back to all six interest cells for the (target, band)
    /// pair and still return 3 sentences from the bundle (not the per-week
    /// JSON).
    func test_resolveSentences_emptyInterests_usesAllInterestsFromLibrary() async throws {
        let library = try SentenceLibrary()

        let resolved = await SessionContainerView.resolveDecodeSentences(
            library: library,
            skillCode: "sh_onset",
            targetGrapheme: Grapheme(letters: "sh"),
            taughtGraphemes: CurriculumEngine.sharedV1.taughtGraphemes(beforeWeekIndex: 0),
            ageYears: 9,
            interests: [],
            count: 3
        )

        XCTAssertEqual(resolved.count, 3)

        // The pool spans 6 cells × 20 sentences = 120; assert at least one of
        // the returned sentences comes from a cell we know exists.
        let vehiclesCell = await library.cell(phoneme: "sh", interest: "vehicles", ageBand: .mid)
        let knownTexts = Set(vehiclesCell?.sentences.map(\.text) ?? [])
        // Not a strict assertion — just sanity: 3 random picks from 120 should
        // overwhelmingly never all come from non-vehicles cells, so this
        // confirms `resolveDecodeSentences` did not silently fall through to
        // the per-week JSON. Instead, assert at least one returned sentence is
        // present in some sh-mid bundle cell.
        var hitAnyMidBundle = false
        for interest in ["animals", "dinosaurs", "vehicles", "space", "sports", "robots"] {
            let cell = await library.cell(phoneme: "sh", interest: interest, ageBand: .mid)
            let texts = Set(cell?.sentences.map(\.text) ?? [])
            if !texts.isDisjoint(with: Set(resolved.map(\.text))) {
                hitAnyMidBundle = true
                break
            }
        }
        XCTAssertTrue(hitAnyMidBundle, "empty-interests fallback must read from the bundle, not per-week JSON")
        // Suppress unused-warning suppression on `knownTexts`.
        _ = knownTexts
    }
}
```

- [ ] **Step 3: Run the test; confirm it FAILS because `resolveDecodeSentences` does not exist yet.**

```sh
(cd Packages/MoraUI && swift test --filter SessionContainerBootstrapLibraryTests 2>&1 | tail -20)
```

Expected: build error — `type 'SessionContainerView' has no member 'resolveDecodeSentences'`. This is the failing-test gate; Task 6 introduces the helper.

- [ ] **Step 4: Commit.**

```sh
git add Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift
git commit -m "ui(session): add failing bootstrap-integration tests for sentence library + fallback"
```

---

## Task 6: Extract `resolveDecodeSentences` and wire bootstrap

**Goal:** Add a `static func resolveDecodeSentences(...)` to `SessionContainerView` that does the library-then-fallback dance, and call it from `bootstrap()`. Bump the per-session sentence count from 2 → 3 to match the spec.

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Add the static helper above `bootstrap()`.**

Locate `private func bootstrap() async` in `SessionContainerView.swift` (around `:264`). Directly above it, insert:

```swift
/// Resolves the per-session sentence triple for `bootstrap()`. Tries the
/// bundled `SentenceLibrary` first; if it returns fewer than `count`
/// sentences (cell unauthored, or pool too sparse), falls back to the
/// per-week `<skill>_week.json` via `ScriptedContentProvider.bundled`.
///
/// Public to the package only because `SessionContainerBootstrapLibraryTests`
/// drives this directly without spinning up SwiftUI. Kept `static` so it
/// has no instance dependencies and is trivially testable; bootstrap
/// resolves all inputs and passes them in.
@MainActor
static func resolveDecodeSentences(
    library: SentenceLibrary,
    skillCode: SkillCode,
    targetGrapheme: Grapheme,
    taughtGraphemes: Set<Grapheme>,
    ageYears: Int,
    interests: [String],
    count: Int
) async -> [DecodeSentence] {
    let primary = await library.sentences(
        target: skillCode,
        interests: interests,
        ageYears: ageYears,
        excluding: [],
        count: count
    )
    if primary.count >= count { return primary }

    // Fallback: per-week hand-authored JSON. Throws on missing bundle
    // resources — propagate up via [] so the session can still run from
    // whatever the orchestrator already tolerates.
    guard let provider = try? ScriptedContentProvider.bundled(for: skillCode) else {
        return primary  // best effort; orchestrator handles a short list
    }
    let request = ContentRequest(
        target: targetGrapheme,
        taughtGraphemes: taughtGraphemes,
        interests: [],
        count: count
    )
    return (try? provider.decodeSentences(request)) ?? primary
}
```

- [ ] **Step 2: Build to confirm the helper compiles.**

```sh
(cd Packages/MoraUI && swift build 2>&1 | tail -5)
```

Expected: build success. The helper is unused by `bootstrap` yet; that's fine.

- [ ] **Step 3: Run the bootstrap-integration tests.**

```sh
(cd Packages/MoraUI && swift test --filter SessionContainerBootstrapLibraryTests 2>&1 | tail -25)
```

Expected: all 4 tests pass. The helper alone is enough for the tests; bootstrap wiring (next step) is what makes the helper observable from the running app.

- [ ] **Step 4: Replace the existing `provider.decodeSentences(...)` call in `bootstrap`.**

In `bootstrap()`, locate the existing block (around `:377`):

```swift
let provider = try ScriptedContentProvider.bundled(for: skill.code)
let sentences = try provider.decodeSentences(
    ContentRequest(
        target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2
    ))
```

Replace with:

```swift
// Resolve the learner's interests + age band from the singleton profile.
// Falls back to (8, []) if no profile exists (defensive — onboarding
// always creates one before a session starts).
let profileFetch = FetchDescriptor<LearnerProfile>(
    sortBy: [SortDescriptor(\.createdAt, order: .forward)]
)
let profile = (try? context.fetch(profileFetch))?.first
let interests = profile?.interests ?? []
let ageYears = profile?.ageYears ?? 8

let library = try SentenceLibrary()
let sentences = await Self.resolveDecodeSentences(
    library: library,
    skillCode: skill.code,
    targetGrapheme: targetGrapheme,
    taughtGraphemes: taught,
    ageYears: ageYears,
    interests: interests,
    count: 3
)
```

Notes:
- `try SentenceLibrary()` propagates a load failure (malformed bundle JSON) into the surrounding `do/catch`, mirroring how the existing `try ScriptedContentProvider.bundled` already does. The `catch` block at line `:462` already sets `bootError` from `String(describing: error)` so a load failure surfaces as a visible bootstrap error.
- The per-session count bumps from 2 to 3 here. Both bundle and fallback paths use 3.
- `interests` is `[String]` (matches `LearnerProfile.interests` — see `Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift:13`); `SentenceLibrary.sentences(...)` accepts `[String]` directly, so no conversion to `InterestCategory` is needed.

- [ ] **Step 5: Run the SwiftUI tests to confirm bootstrap still works.**

```sh
(cd Packages/MoraUI && swift test 2>&1 | tail -15)
```

Expected: all tests pass. The bootstrap-integration tests pass because they exercise the helper directly; existing tests pass because the helper is functionally a superset of the previous `decodeSentences` call (selector first, fallback second).

- [ ] **Step 6: Commit.**

```sh
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "ui(session): wire SentenceLibrary selector into bootstrap with per-week JSON fallback"
```

---

## Task 7: Cross-package + xcodebuild verification

**Goal:** Confirm full SPM cross-package green, swift-format green, Xcode project builds (because the iOS target also surfaces this code path), and the existing pronunciation-bench tooling still builds (it depends on MoraEngines indirectly).

**Files:** none modified.

- [ ] **Step 1: Run all package tests.**

Run each in parallel (independent shells):

```sh
(cd Packages/MoraCore && swift test 2>&1 | tail -3)
(cd Packages/MoraEngines && swift test 2>&1 | tail -3)
(cd Packages/MoraUI && swift test 2>&1 | tail -3)
(cd Packages/MoraTesting && swift test 2>&1 | tail -3)
(cd dev-tools/sentence-validator && swift test 2>&1 | tail -3)
```

Expected: each returns a passing summary. If `MoraMLX` is added to the loop, note that it has a known pre-existing `.mlmodelc` build issue per memory `feedback_mora_xcodegen_team_injection` adjacent context — skip it.

- [ ] **Step 2: Run validator on the bundle to confirm the resource pipeline still works.**

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: `sentence-validator: 18 cells, 360 sentences\n  PASS`. No content changes in this PR; if cell count differs from 18, investigate before pushing.

- [ ] **Step 3: swift-format strict lint.**

```sh
swift-format lint --strict --recursive \
    Mora Packages/*/Sources Packages/*/Tests \
    dev-tools/sentence-validator/Sources dev-tools/sentence-validator/Tests
```

Expected: zero output, exit 0. If lint fires, run the in-place formatter and re-commit the diff.

- [ ] **Step 4: Regenerate Xcode project + build.**

```sh
xcodegen generate
xcodebuild build \
    -project Mora.xcodeproj -scheme Mora \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`. `project.yml` did not change — `xcodegen generate` is a no-op safety net per `CLAUDE.md`.

- [ ] **Step 5: Push the branch and open the PR.**

```sh
git push -u origin HEAD
```

Then:

```sh
gh pr create --title "engines+ui(sentence-library): selector + bootstrap integration (Track B-3)" \
    --body "$(cat <<'EOF'
## Summary

Replace `SentenceLibrary.sentences(...)`'s `fatalError` with a real selector and wire `SessionContainerView.bootstrap` to call it before falling back to the per-week `<skill>_week.json`. After this PR, the 360 bundled `sh` sentences are visible to learners on `sh`-week sessions; the four un-authored phonemes fall through to the existing hand-authored sentences. Per-session sentence count bumps from 2 → 3 to match spec § 6.7. No new dependencies; no schema changes; no content changes.

Spec: `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6.6, § 6.7, § 6.10.
Plan: `docs/superpowers/plans/2026-04-25-decodable-sentence-library-selector.md`.

## Test plan

- [x] `Packages/MoraEngines && swift test` green (selector tests + existing library tests).
- [x] `Packages/MoraUI && swift test` green (bootstrap-integration tests + existing UI tests).
- [x] All other packages and `dev-tools/sentence-validator` green.
- [x] `swift-format lint --strict` green.
- [x] `xcodebuild build` green on iOS Simulator (Debug, no-signing).
- [x] Validator: `18 cells, 360 sentences  PASS`.

## On-device verification (post-merge)

- [ ] On a fresh dev install with `interests=["dinosaurs"]`, an sh-week session shows three sentences from `sh × dinosaurs × {ageBand}` not `sh_week.json`.
- [ ] Switching to `interests=["robots"]` and re-entering an sh-week session shows three different sentences from `sh × robots × {ageBand}`.
- [ ] A `th`-week session (cells unauthored) still runs and shows the existing per-week JSON fallback.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-review

**Spec coverage:**

- **§ 6.6 selector signature** — implemented verbatim including `excluding seenSurfaces: Set<String> = []` default and `count: Int` argument; behavior steps 1–7 honored except the freshness-from-`SessionSummaryEntity` step (Deviation 1) which is structurally impossible without a schema migration.
- **§ 6.6 step 3 empty-interest fallback** — handled via `interests.isEmpty ? Self.allInterestKeys : interests`.
- **§ 6.6 step 5/6 freshness relaxation** — `filtered.count >= count ? filtered : pool` is the explicit relaxation rule.
- **§ 6.6 step 7 empty-pool path** — `if cellsForTarget.isEmpty { return [] }` returns `[]`; bootstrap falls back to `ScriptedContentProvider.bundled(for:)`.
- **§ 6.7 bootstrap integration** — `resolveDecodeSentences` matches the spec's pseudocode shape including the count-3 sentinel and the `(profile?.ageYears ?? 8)` default.
- **§ 6.7 fallback** — `ScriptedContentProvider.bundled(for: skillCode)` mirrors the existing call exactly; the only delta is the `count: 3` bump.
- **§ 6.8 onboarding unchanged** — no onboarding code touched.
- **§ 6.9 fallback ordering** — library hit (≥ count) → per-week JSON (≥ count) → propagate up to `bootError` via the existing `do/catch`.
- **§ 6.10 tests** — `SentenceLibrarySelectorTests` covers selector behavior; `SessionContainerBootstrapLibraryTests` covers the resolve helper. The `AgeBandTests` and `SentenceLibraryDecodabilityTests` from the spec are deferred — `AgeBand` already has its own tests under MoraCore, and decodability is enforced at PR time by the validator.
- **§ 9 PR 4** — this plan implements PR 4 of the spec.

**Placeholder scan:** no `TBD`/`TODO`/`implement later`/`similar to Task N`/`add appropriate error handling` anywhere in the task bodies. Every code block is full source ready to paste.

**Type / value consistency:**

- `SkillCode` is the type used throughout — `directoryForSkillCode: [SkillCode: String]` keys match `skill.code` / `target` parameters.
- `LearnerProfile.interests: [String]` matches `SentenceLibrary.sentences(interests: [String])`.
- `LearnerProfile.ageYears: Int?` flows through `profile?.ageYears ?? 8` to `SentenceLibrary.sentences(ageYears: Int)`.
- `Grapheme` and `Set<Grapheme>` types in `resolveDecodeSentences` match `ContentRequest`'s expected fields.
- `count: 3` is the single source of truth at the bootstrap call site; the helper accepts `count: Int` with no default.
- `excluding: []` at the bootstrap call site documents the v1 freshness deviation; future PRs flip it to a real set without changing the helper signature.

**Cross-references checked:** the helper name `resolveDecodeSentences` is identical between the test file (Task 5) and the implementation (Task 6).

No spec gaps that aren't called out as Deviations. No internal contradictions. Plan is ready.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-decodable-sentence-library-selector.md`. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task with two-stage review between tasks; fast iteration through tests-fail-then-pass cycle.
2. **Inline Execution** — execute tasks 1–7 in this session using `superpowers:executing-plans`; checkpoint at end of Task 4 (selector body in) and Task 6 (bootstrap wired).

Which approach?
