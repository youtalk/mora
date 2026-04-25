# Yokai Voice Wiring + Decodable Sentence Library — Design Spec

- **Date:** 2026-04-25
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Project:** `mora`
- **Relates to:**
  - `docs/superpowers/specs/2026-04-21-mora-design.md` (original on-device LLM track — superseded for v1; pre-generation supplants the MLX/Qwen path)
  - `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md` (canonical product spec — §6 template engine, §9 multi-L1)
  - `docs/superpowers/specs/2026-04-24-a-day-five-weeks-yokai-live-design.md` (5-week curriculum + yokai live wiring — assumed merged)
  - `docs/superpowers/specs/2026-04-22-native-language-and-age-selection-design.md` (`LearnerProfile.ageYears` + `interests` already onboarded)
- **Scope:**
  - Wire all 8 bundled yokai voice clips per yokai into session-internal trigger points
  - Pre-generate ~1,800 tongue-twister-style decodable sentences indexed by `(target phoneme, interest, age band)`; ship as bundled JSON; select per session at runtime; fall back to existing per-week sentences on miss

---

## 1. Overview

Two independent work tracks address the two largest engagement gaps observed after PRs #74–#79:

**Track A — Yokai Voice Wiring Expansion.** Forty bundled yokai voice clips shipped (PR #66, audited #76). Eight clip slots per yokai exist (`phoneme`, `example_1`, `example_2`, `example_3`, `greet`, `encourage`, `gentle_retry`, `friday_acknowledge`). Of these, only `greet` (Monday cutscene), `friday_acknowledge` (Friday cutscene), and `encourage` (SRS cameo path) ever play at runtime. The other five — `phoneme`, `example_1/2/3`, `gentle_retry`, plus the **session-internal** firing of `encourage` — are dead weight inside the bundle. Track A wires every clip into a session-internal trigger so the active week's yokai is audibly present moment-to-moment, not only at week boundaries. No new content, no new dependencies.

**Track B — Decodable Sentence Library.** The current `shortSentences` phase reads three hand-authored sentences from `<skill>_week.json`. Every learner sees the same three sentences for a given week, regardless of interest or age. Track B replaces the per-week sentence list with per-session selection from a pre-generated library of ~1,800 tongue-twister-style decodable sentences indexed by `(target phoneme, interest category, age band)`. Sentences are generated dev-time **by Claude Code in conversation**, validated by a new Swift CLI tool, and committed as bundled JSON. Onboarding's existing `interests` and `ageYears` fields drive runtime selection. Decodability is preserved as a CI-gated invariant.

The two tracks are intentionally orthogonal: Track A ships first (visible value Day 1, pure wiring), Track B follows (content overhaul). Either can revert without affecting the other.

## 2. Motivation & Context

The current alpha has two compounding boredom risks for the target learner (8-year-old, Japanese L1):

1. **Yokai presence is binary.** The yokai appears at Monday intro and Friday befriend cutscenes; in the four sessions in between, the yokai is a corner portrait with no voice. The forge investment in Fish Speech voice cloning (`tools/yokai-forge/`) produced character-distinct voices that the learner hears for ~12 seconds per week. The 5/8 unused clips per yokai are exactly the moments where character presence would be most valuable: when the new sound is introduced (`phoneme`), when the first decodable word appears (`example_1`), on a missed trial (`gentle_retry`), and as positive reinforcement on a streak (`encourage`).

2. **Sentence content is fixed and impersonal.** "The ship can hop." plays for every learner on every sh-week session. There is no signal of interest tagging, no novelty across sessions, and no tongue-twister density that would make the target sound feel like the protagonist of the sentence. The canonical spec (§6 template engine) anticipates interest-aware sentence selection but the v1 alpha shipped without it because hand-authoring 1,800 interest-tagged decodable tongue-twisters is impractical for one human author.

The two together cause cumulative attentional drift: same words, same voiceless yokai, same three sentences. Engine A/B work was originally going to absorb attention, but adult/child fixture recordings stalled (memory: `project_mora_pronunciation_bench_status`), so Engine A/B is blocked on input data the developer can't synthesize. Tracks A and B are explicitly chosen because they unblock visible value without depending on those recordings.

The original on-device LLM track (`mora-design.md` §5.3, Qwen 3.5 4B Instruct on MLX Swift) is **deferred** — not killed. mora-design.md's `LLMEngine` protocol shape and `ModelCatalog` download flow remain valid future work; pre-generation lets us ship interest-tagged content this month without iOS 18+ gating, model download, or a 6-week MLX integration. If user feedback on the bundled library is positive, an on-device LLM can later either (a) generate fresh sentences nightly into the same library schema, or (b) supplant the library entirely. Spec section 11 enumerates the forward hooks.

## 3. Goals & Non-Goals

### Goals

- **G1 (Track A)**: Every one of the 8 yokai voice clips per yokai fires at a deterministic session-internal trigger; a single full session of any week audibly plays at least 6 distinct clips (≥3 unique on a typical session).
- **G2 (Track B)**: Bundled sentence library covers `5 phonemes × 6 interests × 3 age bands × 20 sentences = 1,800 sentences`. Every sentence:
  - is strictly decodable (`Word.isDecodable(taughtGraphemes:target:)` returns `true` for every word against the appropriate week's mastered set ∪ {target}),
  - contains the target phoneme word-initial in ≥3 content words AND ≥4 occurrences total,
  - contains ≥1 word from the cell's interest vocabulary.
- **G3**: A learner with `interests=[dinosaurs]` and `ageYears=8` sees /sh/-week sentences containing dinosaur vocabulary at age-appropriate length. A different learner with `interests=[robots]` and `ageYears=11` sees /sh/-week sentences containing robot vocabulary at a longer/denser cadence. Same week, different content.
- **G4**: CI gate prevents any sentence violating the decodability invariant from landing.
- **G5**: Existing 5-week curriculum, yokai cutscenes, and Engine A/B paths are unaffected.
- **G6**: No new runtime dependencies. iOS 17+ deployment target preserved. No on-device LLM. No model download. No network at runtime.

### Non-Goals

- On-device LLM (`mora-design.md` §5.3 Qwen MLX track): deferred until pre-generation has been validated by user feedback.
- New phonemes / yokai beyond v1 cast.
- Decode-word library (only sentences in this scope; the per-week 10-decode-word list stays in `<skill>_week.json`).
- Mini-stories (yokai's letter), warmup intro lines, live yokai banter (deferred — see §11).
- New interest categories beyond the existing six (`animals, dinosaurs, vehicles, space, sports, robots`). User stated: expand only if alpha feedback warrants.
- Settings UI for re-editing interests or age (deferred to a future Settings plan).
- Generation pipeline running on remote GPU (the user offered `youtalk-desktop.local` with RTX 5090; not adopted in this scope because Claude Code in-conversation produced acceptable samples and avoids new infrastructure).
- New SwiftData entities or migrations.
- Changes to onboarding screens (`InterestPickView`, age picker) — they already capture the data we need.

### Success Criteria

- **C1 (Track A clip coverage)**: An on-device dev-mode script that runs a full session for each of the five v1 yokai records every audio playback event and asserts every one of the 8 clip keys was played at least once across the five sessions. (Single session asserts ≥6 distinct clips.)
- **C2 (Track A no overlap)**: At no point does a yokai clip play simultaneously with an Apple TTS utterance from `SpeechController`. The router serializes the two paths.
- **C3 (Track B library completeness)**: `swift run sentence-validator --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary` exits 0; reports exactly 90 cells × 20 sentences = 1,800 entries; every entry passes decodability + density rules.
- **C4 (Track B selection)**: With `LearnerProfile(ageYears: 8, interests: ["dinosaurs", "vehicles"])`, three consecutive sessions on sh-week return three different sentence triples drawn from `sh × dinosaurs × mid` and `sh × vehicles × mid` cells with no within-week repetition.
- **C5 (Track B fallback)**: When the library has zero entries for the active `(target, interest, ageBand)` cell, `SessionContainerView.bootstrap` falls back to the existing `<skill>_week.json` sentences and the session runs normally.
- **C6 (no regression)**: Full `swift test` across all packages passes; existing yokai cutscene flow on Mon/Fri unchanged; existing Engine A/B integration paths untouched.

## 4. Approach

Three structural choices were considered:

- **A1 — Single bundled PR**: ship Tracks A + B together as one big PR. Rejected: too large to review (~1500 LOC + 360KB JSON), and Track A's quick win is held hostage to Track B's longer tail (1,800-sentence generation + selector + tests).
- **A2 — Two parallel PRs (A + B as separate worktrees)**: faster wall time but loses the feedback loop where on-device observation of Track A informs Track B's clip-trigger interactions (e.g., does `gentle_retry` overlap badly with the next sentence's TTS?). Rejected.
- **A3 — Sequential, A then B, with B internally split into 3 PRs (validator → library → selector)**: chosen. Track A is a clean ~400-LOC refactor that ships in 1 week. Track B's risk is concentrated in B-1 (the validator and JSON schema), so B-1 lands a small sample bundle first; B-2 is the bulk content commit (mostly JSON, minimal code); B-3 is the runtime selector. Each PR leaves the app in a strictly-better state than its predecessor.

This phasing also matches the memory record `feedback_mora_bundled_pr_when_clear`: Track A is mechanical (matches "machine-like" criterion), Track B is implementation-heavy (matches "engine-implementation-style" criterion that warrants splits).

## 5. Track A — Yokai Voice Wiring

### 5.1 Clip Inventory and Trigger Map

Per active yokai (currentEncounter.yokaiID), this is the proposed trigger map. The five rows in **bold** are new wiring; the other three are unchanged.

| Clip key            | Today's trigger        | New trigger (Track A)                                                                                       | Frequency per session |
|---------------------|------------------------|-------------------------------------------------------------------------------------------------------------|-----------------------|
| `greet`             | Monday cutscene        | unchanged                                                                                                   | 1× on Monday only     |
| **`phoneme`**       | (never)                | **WarmupView appear** — replaces the current Apple-TTS `.phoneme(p, .slow)` rendering of the target sound   | 1× per session        |
| **`example_1`**     | BestiaryDetailView only| **DecodeBoardView**, on first decode word reveal (before learner taps)                                      | 1× per session        |
| **`example_2`**     | BestiaryDetailView only| **DecodeBoardView**, on the 4th decode word reveal (≈ midway)                                               | 1× per session        |
| **`example_3`**     | BestiaryDetailView only| **DecodeBoardView**, on the 8th decode word reveal (late)                                                   | 1× per session        |
| **`encourage`**     | SRS cameo only         | **ShortSentencesView**, after every 3rd consecutive correct trial (streak ≥3, resets on miss or new streak)| 0–2× per session typically (one per 3-correct streak; multiple streaks possible in a long session) |
| **`gentle_retry`**  | (never)                | **ShortSentencesView**, on a wrong answer; throttled to ≤1 fire per 5 trials                                | 0–1× per session      |
| `friday_acknowledge`| Friday cutscene        | unchanged                                                                                                   | 1× on Friday only     |

Single-session expected coverage on Tuesday–Thursday (no cutscene): `phoneme` + `example_1` + `example_2` + `example_3` + (sometimes `encourage`) + (sometimes `gentle_retry`) = **4–6 distinct clips**, satisfying C1.

### 5.2 New Component: `YokaiClipRouter`

A new `@MainActor` class in `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift`. Responsible for:

1. Owning the active yokai ID for the current session.
2. Resolving a `YokaiClipKey` to a bundled m4a `URL` via `BundledYokaiStore.voiceClipURL(for:clip:)`.
3. Silencing any in-flight Apple TTS utterance before clip playback so the two paths never overlap. Done via an injected `silencer: () async -> Void` closure rather than a direct `SpeechController` reference — `SpeechController` lives in `MoraUI` and the router lives in `MoraEngines`, so a closure preserves the one-way `Core ← Engines ← UI` dependency direction.
4. Exposing a single `play(_ clip: YokaiClipKey) async` method to all view layers.
5. Throttling: maintains a per-clip last-played counter; refuses replays within a clip-specific minimum interval (e.g., `gentle_retry: 5 trials`).

```swift
@MainActor
public final class YokaiClipRouter {
    public init(
        yokaiID: String,
        store: YokaiStore,
        silencer: @escaping () async -> Void
    )
    public func play(_ clip: YokaiClipKey) async
    public func stop()
    /// Streak helper for `encourage` — view layer calls this on each correct trial.
    public func recordCorrect()
    /// Resets streak (called on incorrect trial or phase boundary).
    public func resetStreak()
}
```

`SessionContainerView.bootstrap` constructs the router with `silencer: { [speech] in await speech?.stop() }`, which captures the `MoraUI` `SpeechController` without leaking the type into `MoraEngines`. The router lives in `MoraEngines` (not `MoraUI`) so view code is purely declarative; the router decides whether a given trigger event should produce audio. View code calls `router.play(.phoneme)` unconditionally; the router applies throttling and overlap rules.

### 5.3 Wiring Locations

- **`Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`** — `bootstrap()` constructs the router after resolving the active encounter:

  ```swift
  let yokaiClipRouter = YokaiClipRouter(
      yokaiID: encounter.yokaiID,
      store: try BundledYokaiStore(),
      speech: speech
  )
  ```

  Stored in a new `@State private var clipRouter: YokaiClipRouter?` and injected into the per-phase views via a new SwiftUI `EnvironmentKey` (so non-direct children — e.g., `DecodeBoardView` deep inside the phase switch — pick it up without prop drilling).

- **`WarmupView.swift`** — `playTargetPhoneme()` becomes:
  ```swift
  speech.play([.text(Self.promptPrefix, .normal)])  // narrator says "Which one says"
  await clipRouter?.play(.phoneme)                  // yokai voices the target sound
  ```
  Falls back to the current `.phoneme(p, .slow)` Apple TTS path if `clipRouter == nil` or the clip URL is missing.

- **`DecodeBoardView.swift`** — at the moment a decode word is revealed (existing `currentTileBoardEngine` transition), the view calls `clipRouter?.play(.example_1)` for index 0, `.example_2` for index 3, `.example_3` for index 7.

- **`ShortSentencesView.swift`** — on `feedback == .correct`, the view calls `clipRouter?.recordCorrect()`. The router internally tracks the streak and triggers `.encourage` on the 3rd consecutive correct. On `feedback == .wrong`, the view calls `clipRouter?.play(.gentle_retry)` (router applies throttle).

- **`SessionOrchestrator.swift`** — no changes. The orchestrator already exposes `trials`, `phase`, and feedback signals; the view layer reads these and dispatches to the router. Keeping the orchestrator pure (no audio dependency) preserves testability.

### 5.4 Overlap Avoidance

The existing `SpeechController` queues utterances; `YokaiClipRouter` plays AVAudioPlayer m4a directly. The two paths must not overlap. Before each `router.play(...)`:

```swift
await speech?.stop()  // drain any in-flight utterance
player = try? AVAudioPlayer(contentsOf: url)
player?.play()
```

This mirrors the pattern already used by `YokaiCutsceneOverlay.play(clip:yokai:)`.

The reverse direction (Apple TTS starts while a clip is playing) is prevented by the router's `stop()` being called from each phase's `onChange(of:)` for the previous phase — the same hook that already cancels TTS at phase boundaries (`SessionContainerView` line ~80).

### 5.5 Tests

- `YokaiClipRouterTests` (MoraEngines): per (clip key, fake clock) → expected play / suppressed-by-throttle. Covers streak math (3 correct → fire, 2-correct-then-wrong → reset). Uses a `FakeClipPlayer` injected via init.
- `WarmupViewSnapshotTests` (MoraUI): assert appearance and a one-shot router invocation; uses a fake router to avoid real audio.
- `ShortSentencesViewIntegrationTests` (MoraUI, headless): drive feedback transitions, assert router invocations.
- Existing `YokaiCutsceneOverlay` flow remains; no regression test changes needed.

### 5.6 LOC Estimate

- New: `YokaiClipRouter` (~120 LOC), `YokaiClipRouterEnvironmentKey` (~20), tests (~150).
- Modified: `WarmupView` (~10 LOC delta), `DecodeBoardView` (~20), `ShortSentencesView` (~25), `SessionContainerView` (~30).
- Total: ~400 LOC.

## 6. Track B — Decodable Sentence Library

### 6.1 Matrix Design

Axes:

| Axis      | Cardinality | Values                                                                                                                            |
|-----------|-------------|-----------------------------------------------------------------------------------------------------------------------------------|
| phoneme   | 5           | `sh_onset` (/ʃ/), `th_voiceless` (/θ/), `f_onset` (/f/), `r_onset` (/r/), `short_a` (/æ/) — 1:1 with v1 ladder                     |
| interest  | 6           | `animals`, `dinosaurs`, `vehicles`, `space`, `sports`, `robots` (per `JapaneseL1Profile.interestCategories`)                       |
| age band  | 3           | `early` (4–7), `mid` (8–10), `late` (11+) — bucketed from `LearnerProfile.ageYears`                                                |

Per cell: 20 sentences. Total: **5 × 6 × 3 × 20 = 1,800 sentences**.

Choice of 20 per cell: at three sentences per session, twenty entries gives ≥6 distinct triples per cell — enough to span a single five-session week without immediate repetition while still being hand-reviewable in PR. Larger pools (e.g., 50) push token cost and review load past the value floor for v1.

### 6.2 Sentence Format and Constraints

For every sentence in every cell:

1. **Decodable** — every grapheme of every word ∈ `taughtGraphemes(beforeWeekIndex: N) ∪ {target}` where N is the index of the cell's phoneme in `defaultV1Ladder()`. Concretely:
   - `sh` cell: L2 alphabet ∪ {`sh`}
   - `th` cell: L2 alphabet ∪ {`sh`, `th`}
   - `f` cell: L2 alphabet ∪ {`sh`, `th`, `f`}
   - `r` cell: L2 alphabet ∪ {`sh`, `th`, `f`, `r`}
   - `short_a` cell: L2 alphabet ∪ {`sh`, `th`, `f`, `r`} ∪ short-a as the target phoneme rendered via `a`
2. **Tongue-twister density** —
   - Target phoneme appears word-initial in **≥3 content words** (content = noun, verb, adjective, proper noun; excludes articles and conjunctions).
   - Target phoneme appears **≥4 times total** across the sentence (initial, medial, or coda).
3. **Interest tagging** — at least one content word is drawn from the cell's interest vocabulary (e.g., `vehicles` cell has ≥1 word from {`van`, `cab`, `ship`, `truck`, `tram`, …}).
4. **Length** — 6–10 words. Keeps oral reading under ~12 seconds at child cadence.
5. **Sight-word allowance** — `the`, `a`, `and`, `is`, `to`, `on`, `at` may appear even when their grapheme decomposition strays from the strict L2 set (these are already present in the bundled `<skill>_week.json` sentences with the `t-h-e` fudge for "the"). The validator whitelists this set.
6. **Proper noun policy** — proper nouns are allowed if all letters are in the cell's allowed graphemes. Recommended pool per phoneme:
   - `sh`: `Shen`, `Sharon`, `Shep`
   - `th`: `Thad`, `Theo`, `Beth`, `Seth`
   - `f`: `Finn`, `Fred`, `Frank`
   - `r`: `Rex`, `Ron`, `Rip`, `Rob`
   - `short_a`: `Sam`, `Jan`, `Pat`, `Cam`

### 6.3 Generation Flow (Claude Code In-Conversation)

The user's existing `tools/yokai-forge/` is a Python+model pipeline; this scope deliberately avoids a parallel Python pipeline because (a) Claude Code samples already meet the quality bar, (b) building a generic LLM-call orchestration in Python adds work without yielding value beyond what Claude Code in-conversation produces, and (c) the validator (§6.4) catches generation errors regardless of which tool produced them.

Per-cell generation procedure (executed during Track B-2 in dedicated working sessions):

1. The user opens a Claude Code session and invokes a content-generation slash command or simply pastes the cell's prompt.
2. Claude Code receives:
   - Target phoneme + IPA + grapheme letters.
   - Allowed graphemes for the cell (computed from `taughtGraphemes(beforeWeekIndex:)`).
   - Interest vocabulary list (10–20 starter words per (interest, ageBand) pair).
   - Age-band reading-level guidance (sentence length, abstraction).
   - Sample 2–3 hand-validated sentences from the same cell or a sibling cell.
   - Output JSON schema (see §6.5).
3. Claude Code emits 20 candidate sentences as a single JSON object.
4. The user runs the validator (§6.4) on the freshly emitted file.
5. Failures are reported per-sentence with the offending grapheme. Claude Code regenerates only the failing entries; passing entries are preserved.
6. Loop until all 20 pass.
7. Cell file is committed to `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{phoneme}/{interest}_{ageBand}.json`.

Total of 90 cells. At ~10 cells per Claude Code session this is ~9 sessions; at higher density (20+ cells/session for compatible cells, e.g., several `vehicles × *` cells in one go) it can fold to ~5 sessions. Either way, generation is not on the critical path for a single PR — Track B-2 may extend across multiple commits as the library fills in.

**Forward escape hatch**: if Claude Code throughput limits or quality drift become an issue mid-generation, the same JSON schema accepts output from any LLM, including a local Qwen-on-RTX-5090 pipeline run via `ssh -A youtalk@youtalk-desktop.local`. The schema and validator are the contract; the generator is interchangeable.

### 6.4 Decodability Validator (Swift CLI)

New executable Swift Package at `tools/sentence-validator/` (parallel to `tools/yokai-forge/`):

```
tools/sentence-validator/
├── Package.swift
└── Sources/
    └── SentenceValidator/
        ├── main.swift
        └── Validator.swift
```

- Depends on `MoraCore` (`Word`, `Grapheme`, `Phoneme`, `JapaneseL1Profile`) and `MoraEngines` (`CurriculumEngine.defaultV1Ladder`, `taughtGraphemes(beforeWeekIndex:)`).
- Accepts `--bundle <path>` pointing at the `SentenceLibrary` resource directory.
- Walks all `*.json` files; for each cell:
  - Parses `phoneme`, `interest`, `ageBand` from filename and front-matter.
  - Resolves the cell's `taughtGraphemes` ∪ `{target}` once.
  - For each sentence:
    - Counts target-phoneme occurrences (total ≥4; word-initial in content words ≥3).
    - Walks each word; if any grapheme ∉ `(taught ∪ target ∪ sight-word whitelist)`, records a violation.
    - Confirms ≥1 content word is in the cell's interest vocabulary.
    - Confirms word count ∈ [6, 10].
- Emits a structured report (TSV or JSON) and exits non-zero on any violation.
- Hooked into CI as `swift run --package-path tools/sentence-validator sentence-validator --bundle Packages/MoraEngines/.../SentenceLibrary` after the package build step.

### 6.5 Bundled JSON Schema

Per-cell file. Filename: `{interest}_{ageBand}.json` under `Resources/SentenceLibrary/{phoneme}/`.

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
      "targetInitialContentWords": 4,
      "interestWords": ["ship"],
      "words": [
        { "surface": "Shen",   "graphemes": ["sh","e","n"],     "phonemes": ["ʃ","ɛ","n"] },
        { "surface": "and",    "graphemes": ["a","n","d"],      "phonemes": ["æ","n","d"] },
        { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
        { "surface": "shop",   "graphemes": ["sh","o","p"],     "phonemes": ["ʃ","ɒ","p"] },
        { "surface": "for",    "graphemes": ["f","o","r"],      "phonemes": ["f","ɔ","r"] },
        { "surface": "a",      "graphemes": ["a"],              "phonemes": ["ə"] },
        { "surface": "ship",   "graphemes": ["sh","i","p"],     "phonemes": ["ʃ","ɪ","p"] },
        { "surface": "at",     "graphemes": ["a","t"],          "phonemes": ["æ","t"] },
        { "surface": "the",    "graphemes": ["t","h","e"],      "phonemes": ["ð","ə"] },
        { "surface": "shed",   "graphemes": ["sh","e","d"],     "phonemes": ["ʃ","ɛ","d"] }
      ]
    }
  ]
}
```

Schema reuses the existing `<skill>_week.json` word shape so `WordPayload` decoding can be shared between `ScriptedContentProvider` and the new `SentenceLibrary` loader.

Estimated total bundle size: 1,800 sentences × ~360 bytes per JSON entry (with structured words) ≈ **650 KB**. Well within iPad app bundle budget.

### 6.6 Runtime: `SentenceLibrary` and `AgeBand`

New types in `MoraCore` and `MoraEngines`:

```swift
// MoraCore/AgeBand.swift  (pure)

public enum AgeBand: String, Sendable, CaseIterable {
    case early   // 4–7
    case mid     // 8–10
    case late    // 11+

    public static func from(years: Int) -> AgeBand {
        switch years {
        case ..<8: .early
        case 8...10: .mid
        default: .late
        }
    }
}
```

```swift
// MoraEngines/Content/SentenceLibrary.swift  (new)

public actor SentenceLibrary {
    public init(bundle: Bundle = .module) throws

    public func sentences(
        target: SkillCode,
        interests: [String],
        ageYears: Int,
        excluding seenSurfaces: Set<String> = [],
        count: Int
    ) async -> [DecodeSentence]
}
```

Selector logic:

1. `let band = AgeBand.from(years: ageYears)`.
2. Resolve `(target, band)` → list of cells per interest in `interests`. Skip any interest with no cell.
3. If `interests.isEmpty` (legacy install) → fall through to all interests for that `(target, band)` pair (act as if the learner picked all six).
4. Pool sentences from selected cells; subtract `seenSurfaces` (per-week freshness window driven by `SessionSummaryEntity`-tracked surfaces).
5. If pool size ≥ `count`: return random sample.
6. Else: relax freshness (drop the `excluding` filter), sample again.
7. Else: return `[]` — caller falls back to per-week JSON.

The actor isolation ensures concurrent reads (e.g., a future C-day path or a parent-mode preview) see consistent state.

### 6.7 Bootstrap Integration

`SessionContainerView.bootstrap()` is the single integration point.

```swift
let library = try? await SentenceLibrary(bundle: .module)
let primary = await library?.sentences(
    target: skill.code,
    interests: profile.interests,        // already [String]; selector keys on InterestCategory.key
    ageYears: profile.ageYears ?? 8,
    excluding: recentSurfaces,
    count: 3
) ?? []

let sentences: [DecodeSentence]
if primary.count >= 3 {
    sentences = primary
} else {
    let provider = try ScriptedContentProvider.bundled(for: skill.code)
    let request = ContentRequest(
        target: targetGrapheme,
        taughtGraphemes: taught,
        interests: [],
        count: 3
    )
    sentences = (try? provider.decodeSentences(request)) ?? []
}
```

The selector takes `interests` as `[String]` (the `InterestCategory.key` form persisted in `LearnerProfile`); no in-flight conversion to `InterestCategory` is needed. The fallback `ContentRequest` passes `interests: []` because the per-week JSON does not key on interests — it returns the same three sentences regardless.

`recentSurfaces` is computed by reading the last K `SessionSummaryEntity` rows for the current week (already persisted) and unioning their sentence surface forms. This is pure read — no schema migration.

### 6.8 Onboarding — No Changes

Both `LearnerProfile.interests: [String]` and `LearnerProfile.ageYears: Int?` exist and are populated by the current onboarding flow. Track B reads them; it does not mutate them.

Legacy installs with `ageYears == nil` (only the developer's own pre-PR-#23 dev profile, per `2026-04-22-native-language-and-age-selection-design.md` §4 migration row) bucket to `.mid` per the `?? 8` default in §6.7. This mirrors the existing fallback behavior.

### 6.9 Fallback Behavior

Fallback paths, in order:

1. **Library returns ≥ 3 sentences for active cell** → use library.
2. **Library returns < 3** (cell sparse or freshness exhausts pool) → existing `<skill>_week.json` 3 hand-authored sentences via `ScriptedContentProvider.bundled(for:).decodeSentences(request)`.
3. **Both fail** → `bootError` — same existing path as today.

The session never stalls; the worst case is the learner sees the existing v1 hand-authored sentences (i.e., today's behavior).

### 6.10 Tests

- `SentenceLibraryTests` (MoraEngines) — load the bundled library; assert 90 cells × 20 = 1,800 entries; every cell has ≥20 entries; `(target, interest, ageBand)` triple uniquely identifies a cell.
- `SentenceLibraryDecodabilityTests` (MoraEngines) — for every entry in every cell, run `Word.isDecodable` against the cell's allowed graphemes; expect all pass. (This is also CI-gated by the validator at the bundle step, but the test ensures the runtime loader's decoded shape matches what the validator saw.)
- `SentenceLibraryDensityTests` (MoraEngines) — every entry has ≥4 target-phoneme occurrences, ≥3 word-initial in content words. Prevents drift if a future generation pass forgets the rule.
- `SentenceLibrarySelectorTests` (MoraEngines) — cover round-robin across multi-interest learners, freshness-window filter, sparse-cell fallback, empty-interests legacy fallback.
- `AgeBandTests` (MoraCore) — boundaries (3 → `.early`, 7 → `.early`, 8 → `.mid`, 10 → `.mid`, 11 → `.late`, 13 → `.late`).
- `SessionContainerBootstrapLibraryTests` (MoraUI) — in-memory model container with two LearnerProfile fixtures (`(8, [dinosaurs])` and `(11, [robots])`); assert different sentence triples returned for the same week.
- CI validator integration test (`tools/sentence-validator/`) — known-bad JSON fixture must exit non-zero; known-good fixture exits 0.

## 7. Data Model Changes

- **New file**: `Packages/MoraCore/Sources/MoraCore/AgeBand.swift` (pure `enum AgeBand`).
- **No SwiftData migrations.** All persisted entities (`LearnerProfile`, `YokaiEncounterEntity`, `SessionSummaryEntity`, etc.) are unchanged.
- **No protocol changes** to `L1Profile`, `ContentProvider`, `SpeechEngine`, `AssessmentEngine`, or any other established surface.
- **New types** (additive): `YokaiClipRouter`, `SentenceLibrary`. Both are new, neither replaces or shadows an existing type.

## 8. Risks & Dependencies

| Risk                                                                         | Trigger                                                | Mitigation                                                                                                                                                |
|------------------------------------------------------------------------------|--------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Claude Code generates non-decodable sentences                                | Mistakes in grapheme tokenization or sight-word leak   | Swift CLI validator gates CI; offending entries regenerated until clean.                                                                                  |
| Tongue-twister density unattainable for some `(interest, ageBand)` cells     | E.g., `th × sports × early` has very limited vocabulary| Allow density floor of 3 occurrences (instead of 4) for cells flagged as constrained; documented per-cell exception in the cell's JSON metadata.          |
| Yokai clip overlaps Apple TTS                                                | Concurrent dispatch from view layer                    | `YokaiClipRouter.play` always awaits `speech.stop()` first; existing `YokaiCutsceneOverlay` pattern.                                                      |
| Engine B miscall fires `gentle_retry` storm                                  | Engine B substitution false-positive on every trial    | Throttle `gentle_retry` to ≤1 fire per 5 trials inside the router; storm becomes a single fire.                                                           |
| Bundle size growth                                                           | Sentence library + future expansion                    | 650 KB / 1.8K sentences is well under iPad limits. If decode-words library or mini-stories ship later, total is still <5 MB even at 10× current scope.    |
| Legacy installs missing `ageYears`                                           | Devs's own dev profile created pre-#23                 | `?? 8` default → `.mid` bucket. Already enforced elsewhere.                                                                                               |
| Legacy installs with `interests = []`                                        | Theoretical only — alpha mandates 3 picks              | Selector treats empty interests as "all six selected".                                                                                                    |
| Round-robin across multiple interests gives uneven distribution within week  | E.g., always picks dinosaurs first                     | Random shuffle of interests per session, then round-robin.                                                                                                |
| Validator passes but runtime `Word.isDecodable` disagrees                    | Validator and runtime use different `taughtGraphemes`  | Both use `CurriculumEngine.sharedV1`. Lock by adding a runtime parity test that asserts `validator-computed allowed set == runtime-computed allowed set`. |
| `MoraMLX` bundling collides with future on-device LLM                        | Forward path                                           | This scope adds nothing to `MoraMLX`; the package stays a single-purpose CoreML host as today.                                                            |

## 9. Phasing & PR Plan

### PR 1 — Track A: Yokai Voice Wiring (~400 LOC, ~1 week)

- Add `YokaiClipRouter` in `MoraEngines/Yokai/`.
- Wire into `WarmupView`, `DecodeBoardView`, `ShortSentencesView`, `SessionContainerView.bootstrap`.
- Unit tests for router; integration tests for trigger points.
- No content changes; no JSON changes.

**Done state**: a single session on any week audibly fires ≥6 distinct yokai clips; existing cutscene flow unchanged.

### PR 2 — Track B-1: Validator + Sample Bundle (~500 LOC code + 1 cell JSON, ~1 week)

- New executable Swift Package `tools/sentence-validator/`.
- New `AgeBand` enum in `MoraCore`.
- New `SentenceLibrary` actor in `MoraEngines` (load + lookup; selector logic stubbed).
- New `Resources/SentenceLibrary/` directory with the **schema**, the per-phoneme subdirectories (5), and **one fully-populated sample cell**: `sh/vehicles_mid.json` with 20 sentences hand-validated against the rules.
- CI step running the validator; CI test fixture for valid + invalid JSON.

**Done state**: schema is locked, validator is the source of truth, one cell is shippable.

### PR 3 — Track B-2: Full Library (~minimal LOC, ~650 KB JSON, ~2–3 weeks of intermittent generation work)

- All remaining 89 cells generated in Claude Code sessions.
- Each cell committed individually or in small per-phoneme batches (a per-phoneme batch = 18 cells = one commit), so review can be incremental and bisectable.
- Each commit's cells must pass the validator before merge.
- No code changes; pure content.

**Done state**: `swift run sentence-validator` reports 1,800 entries across 90 cells.

### PR 4 — Track B-3: Selector + Bootstrap Integration (~500 LOC, ~1 week)

- Wire `SentenceLibrary` selector logic.
- Integrate into `SessionContainerView.bootstrap`.
- Freshness-window read from `SessionSummaryEntity`.
- Tests per §6.10.

**Done state**: live A-day session pulls per-learner sentences; Track B fully visible to the learner.

**Total**: 4 PRs, ~5–6 weeks of calendar time including content-generation work that runs in parallel with code-only PRs.

## 10. Forward Hooks (Future Work, Out of This Scope)

Designed-in seams so later expansions don't churn this scope's surfaces:

1. **On-device LLM (resurrected `mora-design.md` track)** — `SentenceLibrary` becomes pluggable; an `OnDeviceLLMProvider` could mint sentences into the same JSON shape and merge with the bundled library. The validator's contract continues to hold.
2. **Decode-word library** — same matrix shape, same validator. The selector grows to expose `decodeWords(target:interests:ageYears:count:)`.
3. **Mini-stories ("yokai's letter")** — same matrix shape with one additional axis (story arc index, 1–5 for Mon–Fri). Validator extends to multi-sentence units.
4. **New interest categories** — adding a 7th category requires generating 5 phonemes × 3 ageBands × 20 = 300 new sentences and committing one PR. The selector requires no code change.
5. **New phonemes (week 6+)** — adding a 6th phoneme requires 6 × 3 × 20 = 360 new sentences. The selector and validator are phoneme-agnostic.
6. **C-day reading adventure** — the same library can feed the C-day story slot (per canonical spec §6 StoryLibrary) once that work picks up.

## 11. Open Questions

1. **Multi-interest weighting** — when a learner picks 3 interests in onboarding, should sentence selection treat them equally, or weight by selection order? Current proposal: equal weight via shuffled round-robin. Reassess if alpha shows dominance.
2. **Apple TTS narrator vs full-yokai warmup** — §5.3 proposes `narrator says "Which one says" + yokai phoneme clip`. Alternative: yokai speaks the entire prompt via `greet`-style longer recording. Decision: keep narrator framing for v1 because the existing `greet` recordings don't cover "Which one says X?" framing.
3. **Sample-cell choice for B-1** — `sh × vehicles × mid` is the natural pick (most common phoneme + universal interest + alpha target age). Confirmed.
4. **Validator tooling location** — `tools/sentence-validator/` parallels `tools/yokai-forge/`. Alternative: bundle as a Swift Package executable target inside `MoraEngines`. Decision: external `tools/` is cleaner because it stays out of the app build.
5. **Generator language choice for future scale** — if Claude Code throughput becomes the bottleneck, the GPU-PC path (`ssh -A youtalk@youtalk-desktop.local`, RTX 5090) is wired through the same JSON contract. No spec change needed; only an additional generation client.

## 12. Acceptance Checklist

For PR 1 (Track A):
- [ ] All 8 clip keys play in a manually-driven full session for at least one week.
- [ ] No clip overlaps with Apple TTS audibly.
- [ ] `gentle_retry` throttle holds at ≤1 per 5 trials.
- [ ] Existing cutscene flows unchanged; existing tests green.

For PRs 2–4 (Track B):
- [ ] Validator exits 0 on bundle.
- [ ] 1,800 sentences across 90 cells, 20 each.
- [ ] Two test learners (`(8, dinosaurs)` and `(11, robots)`) see materially different sentences for the same week.
- [ ] Fallback to per-week JSON exercised by an integration test.
- [ ] Full `swift test` green.
- [ ] `xcodegen generate && xcodebuild build` green for the regenerated project.
