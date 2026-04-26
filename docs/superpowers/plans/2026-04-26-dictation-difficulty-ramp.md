# Dictation (ShortSentences) Difficulty Ramp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The ShortSentences (dictation) phase scales by day-in-week — Day 1 sentences are 4–5 words, Day 5 keeps the original full sentence — without re-authoring the bundled sentence library and with the absolute minimum source-code footprint. Days 2–4 ramp monotonically between them.

**Architecture:** Each sentence in `Resources/SentenceLibrary/{phoneme}/{interest}_{ageBand}.json` gets an optional `byDay` object that holds pre-authored shorter variants for Days 1–4. Each variant is a fully-formed `{ text, words }` pair (not an index subset — subagents author the trimmed text and copy across the matching `words` entries directly, so the engine has zero derivation work). Day 5 reads the existing top-level `text` + `words`. The engine adds one trivial picker helper and threads a `dayInWeek` argument from `SessionContainerView.bootstrap` (computed from `YokaiEncounterEntity.sessionCompletionCount + 1`) into `SentenceLibrary.sentences(...)`. No SwiftData migration, no validator changes (the validator can grow `byDay` rules in a follow-up plan if needed).

The bulk of the work is content authoring. The five phoneme directories (`sh`, `th`, `f`, `r`, `short_a`) are file-disjoint — one Claude Sonnet subagent per directory in parallel, each operating in its own git worktree to avoid file contention and to spread the rate limit.

**Tech Stack:** Swift 6 / SwiftPM (MoraEngines, MoraUI), JSON resources, XCTest.

---

## Day-length policy (single source of truth — referenced by every authoring task)

For each original sentence with `n = words.count` (range 6–10), the variant lengths are:

| Day | Target word count | Selection rule |
| --- | --- | --- |
| 1 | exactly 4 (use 5 only if 4 cannot include both the target phoneme AND a grammatical reading) | Subset of original words |
| 2 | Day-1 count + 1 | Strict superset of Day 1 |
| 3 | Day-2 count + 1 | Strict superset of Day 2 |
| 4 | `min(n - 1, Day-3 count + 1)` (if `n == 6`, may equal Day 3) | Strict superset of Day 3 |
| 5 | `n` (full original) | Stored at top level — no `byDay` entry |

Mandatory invariants for every variant:

1. **Word order preserved** — words in each day's `words` array appear in the same order as in the original.
2. **Word selection is a subset of the original** — every word in a Day-N variant matches an original word entry exactly (same `surface`, `graphemes`, `phonemes`).
3. **Monotone superset** — `Day k words ⊆ Day k+1 words` (every word kept on Day k is also kept on Day k+1).
4. **Grammatical** — the trimmed `text` reads as a valid English sentence to a fluent reader. First word capitalized; single spaces between words; original sentence's terminal punctuation (`.`, `?`, or `!`) carried over. Drop function words (articles, conjunctions, repeated prepositions) before content words; never strand a preposition.
5. **Day 1 must include at least one word whose first grapheme equals the cell's `graphemeLetters`** (the target phoneme). When the cell's `interestWords` is non-empty, Day 1 should also include at least one of them when grammaticality allows; if both cannot fit in 4 words, prefer the target-phoneme word and bump Day 1 to 5 to fit an interest word.
6. **Decodability is automatically preserved** — every kept word was decodable in the original cell, so the subset is decodable.

If `n == 6`: Day 1 = 4, Day 2 = 5, Day 3 = 6 (= full), Day 4 = 6 (= Day 3 = full). The engine still returns the full sentence for Days 3–5 in that case; collapsing is harmless.

---

## File Structure

**New files:**

- `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceDayPicker.swift` — five-line picker helper (selects the day variant or falls through to full).
- `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceDayPickerTests.swift` — three unit tests (Day 5 fall-through, Day 1 returns variant, missing-variant fall-through).

**Modified files (source — minimal):**

- `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift` — add `byDay: [String: SentencePayload]?` to the private `SentencePayload`; carry it through to a new in-memory `Cell.byDayPayloads` array; add a `dayInWeek` parameter on `sentences(...)` that runs each picked sentence through `SentenceDayPicker.pick`.
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — add a `dayInWeek` parameter to `resolveDecodeSentences`; in `bootstrap()` compute `dayInWeek = clamp(resolution.encounter.sessionCompletionCount + 1, 1...5)` and pass it through.
- `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift` — add tests for Day 1 / Day 5 lookup and missing-`byDay` fall-through.
- `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift` — assert Day 1 sentences average shorter than Day 5 sentences against the real bundled library.

**Modified files (content — bulk of the work):**

- All 90 cells under `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{sh,th,f,r,short_a}/*.json` — add a `byDay` object to every sentence (authored by 5 parallel Sonnet subagents, one per phoneme directory).

---

## Task 1: `SentenceDayPicker` helper

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceDayPicker.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceDayPickerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceDayPickerTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class SentenceDayPickerTests: XCTestCase {
    private func word(_ s: String) -> Word {
        Word(surface: s, graphemes: [Grapheme(letters: s)], phonemes: [Phoneme(ipa: s)])
    }

    func testDayFiveReturnsFullSentence() {
        let full = DecodeSentence(
            text: "Adam and Anna had an Apollo and an axis.",
            words: ["Adam","and","Anna","had","an","Apollo","and","an","axis"].map(word)
        )
        let day1 = DecodeSentence(text: "Adam had an Apollo.", words: ["Adam","had","an","Apollo"].map(word))
        let result = SentenceDayPicker.pick(full: full, byDay: ["1": day1], dayInWeek: 5)
        XCTAssertEqual(result.text, full.text)
        XCTAssertEqual(result.words.count, 9)
    }

    func testDayOneReturnsAuthoredVariant() {
        let full = DecodeSentence(
            text: "Adam and Anna had an Apollo and an axis.",
            words: ["Adam","and","Anna","had","an","Apollo","and","an","axis"].map(word)
        )
        let day1 = DecodeSentence(text: "Adam had an Apollo.", words: ["Adam","had","an","Apollo"].map(word))
        let result = SentenceDayPicker.pick(full: full, byDay: ["1": day1], dayInWeek: 1)
        XCTAssertEqual(result.text, "Adam had an Apollo.")
        XCTAssertEqual(result.words.count, 4)
    }

    func testMissingVariantFallsThroughToFull() {
        let full = DecodeSentence(
            text: "Anna sat in an Apollo.",
            words: ["Anna","sat","in","an","Apollo"].map(word)
        )
        let result = SentenceDayPicker.pick(full: full, byDay: nil, dayInWeek: 1)
        XCTAssertEqual(result.text, full.text)

        let result2 = SentenceDayPicker.pick(full: full, byDay: ["2": full], dayInWeek: 1)
        XCTAssertEqual(result2.text, full.text, "Day 1 missing — should fall through to full")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraEngines && swift test --filter SentenceDayPickerTests)`
Expected: FAIL with "cannot find SentenceDayPicker in scope".

- [ ] **Step 3: Write the implementation**

Create `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceDayPicker.swift`:

```swift
import Foundation
import MoraCore

/// Per-day picker over the bundled sentence library. The library JSON authors
/// pre-trimmed Day 1..4 variants in each sentence's `byDay` object; this
/// helper just looks them up by integer day. Day 5 (or any day with no
/// authored variant) returns the full sentence unchanged.
public enum SentenceDayPicker {
    public static func pick(
        full: DecodeSentence,
        byDay: [String: DecodeSentence]?,
        dayInWeek: Int
    ) -> DecodeSentence {
        guard dayInWeek >= 1, dayInWeek <= 4 else { return full }
        return byDay?[String(dayInWeek)] ?? full
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `(cd Packages/MoraEngines && swift test --filter SentenceDayPickerTests)`
Expected: 3 PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Content/SentenceDayPicker.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/SentenceDayPickerTests.swift
git commit -m "engines: add SentenceDayPicker helper for dictation difficulty ramp"
```

---

## Task 2: Parse `byDay` in `SentenceLibrary` and thread `dayInWeek` through `sentences(...)`

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift`:

```swift
func testByDayLookupReturnsTrimmedSentenceForDayOne() async throws {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("svtest-\(UUID().uuidString)")
    let cellDir = tmp.appendingPathComponent("sh", isDirectory: true)
    try FileManager.default.createDirectory(at: cellDir, withIntermediateDirectories: true)
    let json = """
    {
      "phoneme": "sh",
      "phonemeIPA": "ʃ",
      "graphemeLetters": "sh",
      "interest": "vehicles",
      "ageBand": "mid",
      "sentences": [
        {
          "text": "She shoves a sharp ship to shore.",
          "targetCount": 4, "targetInitialContentWords": 4,
          "interestWords": ["ship"],
          "words": [
            {"surface":"She","graphemes":["sh","e"],"phonemes":["ʃ","i"]},
            {"surface":"shoves","graphemes":["sh","o","v","e","s"],"phonemes":["ʃ","ʌ","v","z"]},
            {"surface":"a","graphemes":["a"],"phonemes":["ə"]},
            {"surface":"sharp","graphemes":["sh","a","r","p"],"phonemes":["ʃ","ɑ","r","p"]},
            {"surface":"ship","graphemes":["sh","i","p"],"phonemes":["ʃ","ɪ","p"]},
            {"surface":"to","graphemes":["t","o"],"phonemes":["t","ə"]},
            {"surface":"shore","graphemes":["sh","o","r","e"],"phonemes":["ʃ","ɔ","r"]}
          ],
          "byDay": {
            "1": {
              "text": "She shoves sharp ship.",
              "words": [
                {"surface":"She","graphemes":["sh","e"],"phonemes":["ʃ","i"]},
                {"surface":"shoves","graphemes":["sh","o","v","e","s"],"phonemes":["ʃ","ʌ","v","z"]},
                {"surface":"sharp","graphemes":["sh","a","r","p"],"phonemes":["ʃ","ɑ","r","p"]},
                {"surface":"ship","graphemes":["sh","i","p"],"phonemes":["ʃ","ɪ","p"]}
              ]
            }
          }
        }
      ]
    }
    """
    try Data(json.utf8).write(to: cellDir.appendingPathComponent("vehicles_mid.json"))
    let library = try SentenceLibrary(rootURL: tmp)

    let day1 = await library.sentences(
        target: "sh_onset", interests: ["vehicles"], ageYears: 8,
        dayInWeek: 1, excluding: [], count: 1
    )
    XCTAssertEqual(day1.first?.text, "She shoves sharp ship.")
    XCTAssertEqual(day1.first?.words.count, 4)

    let day5 = await library.sentences(
        target: "sh_onset", interests: ["vehicles"], ageYears: 8,
        dayInWeek: 5, excluding: [], count: 1
    )
    XCTAssertEqual(day5.first?.text, "She shoves a sharp ship to shore.")
    XCTAssertEqual(day5.first?.words.count, 7)
}

func testByDayAbsentFallsThroughToFullSentence() async throws {
    // Default-day overload (existing API) returns full sentences regardless.
    let library = try SentenceLibrary()
    let result = await library.sentences(
        target: "sh_onset", interests: ["vehicles"], ageYears: 8,
        excluding: [], count: 1
    )
    XCTAssertNotNil(result.first)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraEngines && swift test --filter SentenceLibraryTests.testByDayLookupReturnsTrimmedSentenceForDayOne)`
Expected: FAIL — `sentences(...)` has no `dayInWeek` parameter.

- [ ] **Step 3: Modify `SentenceLibrary.swift`**

In `Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift`:

(a) Extend the private `SentencePayload` to decode the optional `byDay`:

```swift
private struct SentencePayload: Decodable {
    let text: String
    let words: [WordPayload]
    let byDay: [String: DayVariantPayload]?
}

private struct DayVariantPayload: Decodable {
    let text: String
    let words: [WordPayload]
}
```

(b) Extend the in-memory `Cell` shape so per-day variants travel with each sentence (one entry per sentence, possibly empty):

```swift
public struct Cell: Sendable {
    public let phoneme: String
    public let phonemeIPA: String
    public let graphemeLetters: String
    public let interest: String
    public let ageBand: AgeBand
    public let sentences: [DecodeSentence]
    public let byDay: [[String: DecodeSentence]]   // count == sentences.count
}
```

(c) In `loadCells(from root:)`, build the parallel `byDay` array (replace the existing `Cell(...)` construction):

```swift
let decoded = payload.sentences
let sentences = decoded.map { p in
    DecodeSentence(
        text: p.text,
        words: p.words.map { wordFromPayload($0) }
    )
}
let byDay: [[String: DecodeSentence]] = decoded.map { p in
    guard let raw = p.byDay else { return [:] }
    var out: [String: DecodeSentence] = [:]
    for (key, variant) in raw {
        out[key] = DecodeSentence(
            text: variant.text,
            words: variant.words.map { wordFromPayload($0) }
        )
    }
    return out
}
out[key] = Cell(
    phoneme: payload.phoneme,
    phonemeIPA: payload.phonemeIPA,
    graphemeLetters: payload.graphemeLetters,
    interest: payload.interest,
    ageBand: band,
    sentences: sentences,
    byDay: byDay
)
```

(Hoist `wordFromPayload` out of the existing closure if it isn't already a function — extract once and reuse for both arrays.)

(d) Add a new `sentences(...)` overload that accepts `dayInWeek` and keep the existing one as a thin wrapper that defaults to Day 5:

```swift
public func sentences(
    target: SkillCode,
    interests: [String],
    ageYears: Int,
    excluding seenSurfaces: Set<String> = [],
    count: Int
) async -> [DecodeSentence] {
    await sentences(
        target: target, interests: interests, ageYears: ageYears,
        dayInWeek: 5, excluding: seenSurfaces, count: count
    )
}

public func sentences(
    target: SkillCode,
    interests: [String],
    ageYears: Int,
    dayInWeek: Int,
    excluding seenSurfaces: Set<String> = [],
    count: Int
) async -> [DecodeSentence] {
    guard let directory = Self.directoryForSkillCode[target] else { return [] }
    let band = AgeBand.from(years: ageYears)
    let interestKeys = interests.isEmpty ? Self.allInterestKeys : interests

    struct Entry { let sentence: DecodeSentence; let byDay: [String: DecodeSentence] }
    let entries: [Entry] = interestKeys.flatMap { interest -> [Entry] in
        guard let cell = cells[CellKey(phoneme: directory, interest: interest, ageBand: band)] else {
            return []
        }
        return zip(cell.sentences, cell.byDay).map { Entry(sentence: $0.0, byDay: $0.1) }
    }
    if entries.isEmpty { return [] }

    let filtered = entries.filter { !seenSurfaces.contains($0.sentence.text) }
    let candidates = filtered.count >= count ? filtered : entries

    return Array(candidates.shuffled().prefix(count)).map { entry in
        SentenceDayPicker.pick(full: entry.sentence, byDay: entry.byDay, dayInWeek: dayInWeek)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `(cd Packages/MoraEngines && swift test --filter SentenceLibraryTests)`
Expected: all SentenceLibraryTests PASS, including the two new cases.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Content/SentenceLibrary.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/SentenceLibraryTests.swift
git commit -m "engines: thread dayInWeek through SentenceLibrary, parse byDay variants"
```

---

## Task 3: Wire `dayInWeek` from `SessionContainerView.bootstrap`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift:215-243` and `:449-458`
- Modify: `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift` (if the file does not exist, locate the bootstrap-related test file with `git grep -l "resolveDecodeSentences" Packages/MoraUI/Tests` and append there):

```swift
func testResolveDecodeSentencesUsesDayInWeekForTrimming() async throws {
    let library = try SentenceLibrary()
    let day1 = try await SessionContainerView.resolveDecodeSentences(
        library: library,
        skillCode: "sh_onset",
        targetGrapheme: Grapheme(letters: "sh"),
        taughtGraphemes: [],
        ageYears: 8,
        interests: ["vehicles"],
        dayInWeek: 1,
        count: 3
    )
    let day5 = try await SessionContainerView.resolveDecodeSentences(
        library: library,
        skillCode: "sh_onset",
        targetGrapheme: Grapheme(letters: "sh"),
        taughtGraphemes: [],
        ageYears: 8,
        interests: ["vehicles"],
        dayInWeek: 5,
        count: 3
    )
    let day1Avg = Double(day1.map(\.words.count).reduce(0, +)) / Double(max(1, day1.count))
    let day5Avg = Double(day5.map(\.words.count).reduce(0, +)) / Double(max(1, day5.count))
    XCTAssertLessThan(day1Avg, day5Avg, "Day 1 should average shorter than Day 5")
    XCTAssertLessThanOrEqual(day1Avg, 5.5, "Day 1 should average ≤ 5 words")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraUI && swift test --filter SessionContainerBootstrapLibraryTests.testResolveDecodeSentencesUsesDayInWeekForTrimming)`
Expected: FAIL — `resolveDecodeSentences` has no `dayInWeek` parameter.

- [ ] **Step 3: Modify `SessionContainerView.swift`**

(a) Update the `resolveDecodeSentences` signature (around line 215):

```swift
static func resolveDecodeSentences(
    library: SentenceLibrary,
    skillCode: SkillCode,
    targetGrapheme: Grapheme,
    taughtGraphemes: Set<Grapheme>,
    ageYears: Int,
    interests: [String],
    dayInWeek: Int,
    count: Int
) async throws -> [DecodeSentence] {
    let primary = await library.sentences(
        target: skillCode,
        interests: interests,
        ageYears: ageYears,
        dayInWeek: dayInWeek,
        excluding: [],
        count: count
    )
    if primary.count >= count { return primary }

    // Fallback: per-week hand-authored JSON has no per-day variants — every
    // day reads as the full sentence, matching pre-Track-B behavior.
    let provider = try ScriptedContentProvider.bundled(for: skillCode)
    let request = ContentRequest(
        target: targetGrapheme,
        taughtGraphemes: taughtGraphemes,
        interests: [],
        count: count
    )
    return try provider.decodeSentences(request)
}
```

(b) Update the call site inside `bootstrap()` (around line 450):

```swift
let dayInWeek = max(1, min(5, resolution.encounter.sessionCompletionCount + 1))
let library = try SentenceLibrary()
let sentences = try await Self.resolveDecodeSentences(
    library: library,
    skillCode: skill.code,
    targetGrapheme: targetGrapheme,
    taughtGraphemes: taught,
    ageYears: ageYears,
    interests: interests,
    dayInWeek: dayInWeek,
    count: 3
)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `(cd Packages/MoraUI && swift test --filter SessionContainerBootstrapLibraryTests)`
Expected: PASS.

(Note: the new assertion `day1Avg < day5Avg` will only hold once Task 4 has authored `byDay` for the `sh × vehicles × mid` cell. If you are running tasks strictly in order before Task 4 finishes, the test will fail with `day1Avg == day5Avg`. That is expected — the test wedges Task 4 forward and confirms its effect end-to-end. Either author `byDay` for `sh/vehicles_mid.json` first to unblock this test, or accept the failure until Task 4 lands and re-run.)

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift \
        Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapLibraryTests.swift
git commit -m "ui: pass active encounter's day-in-week into SentenceLibrary lookup"
```

---

## Task 4: Author `byDay` variants for the bundled library — 5 parallel Sonnet subagents

This is the bulk-content task. The five phoneme directories under `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{sh,th,f,r,short_a}/` are file-disjoint — dispatch one Sonnet subagent per directory, each in its own git worktree, all five in parallel in a single Agent-tool message (matches `feedback_parallel_subagents_isolation.md`).

**Files (per subagent):**
- Modify: every `*.json` under `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/<phoneme>/` — 18 cells × ~20 sentences = ~360 sentences

- [ ] **Step 1: Verify all five directories exist and count cells**

Run: `for p in sh th f r short_a; do echo -n "$p: "; ls Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/$p/*.json 2>/dev/null | wc -l; done`
Expected: each phoneme reports `18`.

- [ ] **Step 2: Dispatch the five subagents in parallel**

In a **single** assistant message, send five concurrent `Agent` tool calls, all with `subagent_type: "general-purpose"`, `model: "sonnet"`, `isolation: "worktree"`, `run_in_background: true`. Use this prompt template, substituting `<PHONEME>` for `sh`, `th`, `f`, `r`, `short_a` respectively:

> **Task:** Add a `byDay` field to every sentence in every JSON cell file under `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/<PHONEME>/`. There are 18 files, each with ~20 sentences. **You only reduce existing sentences — do not invent new vocabulary, do not generate net-new sentences, do not edit any source code.**
>
> **JSON shape — for each existing sentence object, add a sibling `byDay` field:**
> ```json
> {
>   "text": "<original full sentence>",
>   "targetCount": ..., "targetInitialContentWords": ...,
>   "interestWords": [...],
>   "words": [ ...original words... ],
>   "byDay": {
>     "1": { "text": "<4 or 5 word trimmed sentence>", "words": [ ...subset of original words, in order... ] },
>     "2": { "text": "...", "words": [ ... ] },
>     "3": { "text": "...", "words": [ ... ] },
>     "4": { "text": "...", "words": [ ... ] }
>   }
> }
> ```
>
> Each variant's `words` entries MUST be exact copies of entries from the parent sentence's `words` array (same `surface`, `graphemes`, `phonemes`) — copy them verbatim, do not invent new words.
>
> **Policy (must hold for every sentence with `n = words.count`):**
> 1. **Day 1 length = 4** (use 5 only if 4 cannot include any word whose first grapheme equals the cell's `graphemeLetters` while remaining grammatical).
> 2. **Day 2 length = Day 1 length + 1.**
> 3. **Day 3 length = Day 2 length + 1.**
> 4. **Day 4 length = `min(n - 1, Day 3 length + 1)`.** If `n == 6`, Day 4 may equal Day 3.
> 5. **Word order preserved** — kept words appear in the same order as in the original `words` array.
> 6. **Monotone superset** — every word kept in Day k is also kept in Day k+1.
> 7. **Day 1 includes at least one word whose first grapheme equals the cell's `graphemeLetters`** (the target phoneme).
> 8. **Grammatical:** the variant `text` reads as a valid English sentence to a fluent reader. Capitalize the first kept word; join with single spaces; carry over the original sentence's terminal punctuation (`.`, `?`, or `!`). Drop function words (articles, conjunctions, repeated prepositions) before content words; never strand a preposition.
> 9. **interestWords:** when the cell's `interestWords` is non-empty, prefer including at least one in Day 1; if it doesn't fit in 4 words, use Day 1 length 5 instead.
>
> **Authoring algorithm — apply per sentence:**
> 1. Read `words[].surface` in order.
> 2. Identify content words (non-articles, non-conjunctions, non-prepositions) that include the target phoneme; pick one as the Day 1 anchor.
> 3. Add 3 more grammatically-essential words to make a 4-word sentence (subject + verb + object + the anchor, in original order).
> 4. Day 2: add the next most pedagogically-useful word (often a determiner or interest word).
> 5. Day 3: add one more.
> 6. Day 4: add one more, capped per the policy above.
> 7. Construct each `text` by concatenating the kept `surface` values with single spaces, capitalizing the first letter of the first kept word (preserving any inherent capitalization of proper nouns), and appending the original sentence's terminal punctuation.
>
> **Edit mechanics:** Use the `Edit` tool with `replace_all: false`. For each sentence, find the trailing `]` of its `words` array and insert `,\n          "byDay": { ... }` before the closing `}` of the sentence object. Preserve the existing 2-space JSON indentation style — match the file you opened. Do **not** reflow the existing fields. Do **not** modify `text`, `targetCount`, `targetInitialContentWords`, `interestWords`, or the original `words` array.
>
> **Verification (run inside the worktree before reporting done):**
> 1. `python3 -c 'import json,glob;[json.load(open(f)) for f in glob.glob("Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/<PHONEME>/*.json")]'` — confirms each file is still valid JSON.
> 2. `(cd Packages/MoraEngines && swift test --filter SentenceLibraryTests)` — confirms the loader still parses all cells.
> 3. Spot-check 3 random sentences by printing their `byDay["1"].text` values and confirming each reads naturally.
>
> **Report back:** number of sentences modified, number of files modified, full path to the worktree, and three before/after examples (original sentence + each day's text).
>
> **Do not** modify any file outside `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/<PHONEME>/`. Do **not** modify any `.swift` file.

- [ ] **Step 3: Wait for all five subagents to complete (background notifications)**

Do not poll. The runtime delivers a notification per agent on completion. Read each report; verify:

- JSON files still parse.
- `SentenceLibraryTests` still pass per phoneme.
- File-modification counts roughly match `18 files × ~20 sentences = ~360 edits` per phoneme.
- The sample before/after sentences read naturally.

If a subagent's output reveals a systemic mistake (broken JSON, fabricated words not in the original, violated monotonicity, ungrammatical Day-1 trims), do **not** merge that worktree. Re-dispatch a corrective subagent for just that phoneme with a tightened prompt.

- [ ] **Step 4: Merge each worktree's changes back into the main worktree**

For each phoneme worktree path returned by the agent reports, run from this worktree:

```bash
git fetch <worktree-path-or-branch>
git merge --no-ff <branch>
```

(File paths are disjoint, so merges should not conflict. A conflict means a subagent touched files outside its phoneme directory — investigate before resolving.)

- [ ] **Step 5: Commit (only if subagents did not commit themselves)**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
git commit -m "content(sentence-library): add byDay variants to all 90 cells for dictation difficulty ramp"
```

---

## Task 5: End-to-end smoke

**Files:**
- Verify: `Mora.xcodeproj` regenerated; build clean; all tests pass; lint clean.

- [ ] **Step 1: Regenerate the Xcode project**

Run: `xcodegen generate`
Expected: no errors.

- [ ] **Step 2: Build the app target**

Run: `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run all package tests**

Run in parallel:
```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```
Expected: all green. The Day 1 vs Day 5 averaging assertion in `SessionContainerBootstrapLibraryTests` should now hold for every phoneme.

- [ ] **Step 4: Lint**

Run: `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests`
Expected: no diagnostics.

- [ ] **Step 5: Commit anything caught by lint**

If `swift-format format --in-place` produced changes, stage them and commit:

```bash
git add -u
git commit -m "chore: swift-format pass after dictation difficulty ramp"
```

(If no diff, skip.)

---

## Self-Review Checklist (run before handoff)

- [ ] Spec coverage — Day 1 ≤ 5 words ✅ (Task 4 policy); Day 5 = full ✅ (Task 1 fall-through); intermediate ramp ✅ (Task 4 policy); 5 parallel Sonnet subagents ✅ (Task 4 dispatch).
- [ ] Subagents only reduce — they author `byDay` whose `words` entries are verbatim copies from the parent sentence's `words` array. No source-code edits. No new vocabulary.
- [ ] Source-code footprint — exactly **3 source files modified** (`SentenceDayPicker.swift` new, `SentenceLibrary.swift`, `SessionContainerView.swift`) plus 3 test files.
- [ ] Schema name match — `byDay: [String: DayVariantPayload]?` in `SentenceLibrary.SentencePayload`; subagent prompt uses the same `byDay` key shape.
- [ ] `SessionContainerView.bootstrap` uses `resolution.encounter.sessionCompletionCount + 1` (Day index, 1-based) clamped to `1...5`.
- [ ] `resolveDecodeSentences` falls through cleanly when the per-week scripted-content fallback is taken (returns full sentences regardless of day — documented inline).
- [ ] `SentenceLibrary.sentences(...)` shuffle order is the same regardless of `dayInWeek` (the variant pick happens after shuffle, so Day 1 and Day 5 select the same sentence identities at any given seed).

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-26-dictation-difficulty-ramp.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Fresh subagent per task, review between tasks, fast iteration. Task 4 is itself a parallel-subagent fan-out, so this mode composes naturally.

**2. Inline Execution** — Execute tasks 1–3 + 5 inline; Task 4 still fans out via the parallel-subagents pattern.

Which approach?
