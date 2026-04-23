# mora — Tile-Board Decoding Design Spec

- **Date:** 2026-04-22
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Release target:** v1 (reshapes the already-shipped A-day Decoding phase)
- **Extends:** `2026-04-21-mora-dyslexia-esl-design.md` §7.1 (A-day Decoding phase) and §5 (OG multisensory principle). Replaces the current `DecodeActivityView` treatment of Decoding; the phase, its duration, and its position in the A-day flow are unchanged.
- **Relates to:** `2026-04-22-pronunciation-feedback-design.md` — the Say step of each turn feeds the same `AssessmentEngine` and, in v1.5, the acoustic `PronunciationEvaluator` path. This spec does not alter that contract.

---

## 1. Overview

The A-day Decoding phase is currently a six-minute list-read: the child sees fifteen isolated words containing the week's target grapheme, reads each aloud, and the ASR path assesses the utterance. The phase is pedagogically thin compared to the rest of the app — the child only *reads*, never *constructs*. Orton-Gillingham / Barton practice places a tactile sound-to-letter mapping step between explicit rule introduction and fluent reading, and without it Decoding lands flat for a dyslexic learner.

This design replaces `DecodeActivityView` with a tile-manipulation board that keeps the six-minute budget and the phase's position in A-day, but reshapes the trial loop around Barton-style tile boards. Each trial is one word; the child **hears** the word from TTS, **builds** it from draggable grapheme tiles, and **says** it into the mic for the existing ASR assessment path. Across the six minutes the child moves through three four-word mini-chains (warmup → target-intro → mixed application) where the first word of each chain is built from empty slots and the subsequent words each require swapping exactly one tile to form the next word.

The mechanic is inspired by LearnUp's Digital Phonics Boards, but the design — tile shapes, palette, chain shape, animation language, scaffold ladder — is wholly original and bound to the Orton-Gillingham / Barton tradition those products also draw from. No LearnUp assets, strings, or layouts are reused.

The phase stays fully on-device. Tile pools, chains, and mistake telemetry are produced from the existing `TemplateEngine` + authored content library and persisted in the existing SwiftData store; no network I/O, no LLM, no new third-party dependency.

## 2. Motivation

Three forces converge on this change:

1. **Pedagogy.** Barton's core activity is tile substitution: the child stares at `cat`, the tutor says "change /æ/ to /ʌ/", and the child physically slides the `a` tile out and the `u` tile in. That gesture is what internalizes phoneme–grapheme mapping for a dyslexic reader. A list of pre-rendered words cannot produce it.
2. **Device fit.** The project is iPad-first and the current A-day screens under-use the device: everything is a tap target. A touch-first manipulation surface with careful physics is the one type of UI mora is uniquely positioned to deliver, and the alpha user (8-year-old) responds strongly to animated direct manipulation.
3. **Reuse of existing investments.** The ASR / assessment pipeline, the TTS pacing work, the OpenDyslexic typography, and the pronunciation-feedback overlay all ship already. A tile board sits on top of that stack without duplicating any of it — the Build step is new, the Say step is the existing trial loop.

## 3. Goals and Non-Goals

### Goals

- Replace the Decoding phase's per-trial experience with a tile-manipulation board that keeps the six-minute budget and the phase's position in A-day.
- Deliver both Build (assemble a word from empty slots) and Change (swap exactly one tile to form the next word) as first-class modes within a single shared engine and UI.
- Each six-minute phase runs three mini-chains of four words each: warmup (no target), target introduction, and mixed application. Exactly one tile changes between consecutive words in a chain.
- Keep OG's "I hear, I build, I say" ordering as the default turn shape; the word is spoken by TTS before any visual of the word is shown.
- Provide a four-step scaffold ladder for mis-drops so that no dyslexic learner stalls on a trial, without giving away the answer on the first mistake.
- Persist tile-drop attempts and scaffold levels per trial so Parent Mode (future) can see not only pronunciation outcomes but also construction fluency.
- All animations and tile physics are SwiftUI-native. No SpriteKit, no third-party animation libraries.
- Honor the decodability invariant: each word is composable from the learner's mastered grapheme set plus the week's target.

### Non-Goals

- No free-play or review mode outside the daily quest. The board lives inside the A-day flow only in v1.
- No parent-configurable chain difficulty, chain length, or tile palette in v1.
- No confusion-pair sorting (Sort-by-sound) mechanic in v1. L1 interference pairs continue to surface through the existing pronunciation assessment path, not through the tile board.
- No multisyllable words. The L4 preview words (`sunset`, `picnic`, …) stay in `ShortSentences`; the tile board handles L2/L3 only.
- No C-day port. The Reading Adventure phase remains unchanged and unimplemented in v1; any future tile use there is a separate spec.
- No Elkonin-box (segmentation-into-counters) mode. Grapheme tiles only.
- No user-visible toggle between turn-loop variants. α is the shipped loop; β appears automatically as a one-time scaffold (see §7), γ is not used.

## 4. Approach

The design emerges from four decisions taken during brainstorming:

| Axis | Decision | Rationale |
|---|---|---|
| Core interaction | Build **and** Change, on one board | Both fall out of the same tile UI and reinforce each other pedagogically. Change is impossible without Build establishing the starting state. |
| Placement | Replace A-day Decoding | Keeps daily session length at ~16–17 min. Fits the pedagogical arc (NewRule introduces the grapheme; Decoding now *uses* it tactilely). |
| Turn loop | α — Hear → Build → Say | Standard OG multisensory sequence. Forces phoneme-to-grapheme mapping rather than visual copying. |
| Chain shape | Y — three mini-chains of four words | Preserves the Barton substitution ladder while breaking it into digestible arcs for an 8-year-old dyslexic learner. Creates three natural scene changes during a single phase. |

See the brainstorming session notes in `.superpowers/brainstorm/` for the alternatives considered (single 10-word chain; no-chain build list; Elkonin counters; Sort-by-sound; insertion of the board as an extra phase alongside Decoding). Each was rejected for a specific reason captured there.

## 5. Turn Shape — One Word

A single trial produces one `TrialRecording` via the existing assessment path. It is driven by `TileBoardEngine.state`, a seven-value state machine:

| # | State | What the learner experiences | Exit condition |
|---|---|---|---|
| 1 | `.preparing` | Slots rise into the layout; tiles arrive into the pool with a 50 ms stagger. | 300 ms animation complete. |
| 2 | `.listening` | TTS speaks the word once. For Change turns, TTS speaks a short instruction: "change [old phoneme] to [new phoneme], [new word]". No visual of the word is shown. | `TTSEngine` reports `didFinish`. |
| 3 | `.building` | For Build turns, all slots are empty and all tiles are in the pool. For Change turns, all-but-one slot is pre-filled and locked; the active slot pulses; the pool contains only candidate replacements for the active slot plus distractors. The learner drags tiles. | All slots contain the correct tile. |
| 4 | `.completed` | Slots cascade-glow warm yellow with 50 ms stagger; the word text lifts 1.15× with a soft shadow; the mic icon spring-pops in from the bottom. | 600 ms animation complete. |
| 5 | `.speaking` | Mic is armed. The learner taps-to-record, reads the word, and taps again to stop. Assessment goes through the existing `AssessmentEngine`. In v1.5, `PronunciationEvaluator` runs in parallel as spec'd in `2026-04-22-pronunciation-feedback-design.md`. | `ASRResult` received. |
| 6 | `.feedback` | Existing `PronunciationFeedbackOverlay` presents the result. | Tap-to-dismiss. |
| 7 | `.transitioning` | For a Change successor, the board keeps the locked tiles in place and runs a "swap-back" animation that returns the previous word's differing tile to the pool before the next `.preparing`. For a chain boundary (word 4 → chain N+1 word 1), a full scene transition runs: tiles fly up with stagger, the background gradient shifts to the next chain's palette, the `ChainProgressRibbon` lights the just-completed chain's trophy, and the next board `.preparing`s in. | Next word's `.preparing` begins. |

**β variant — first word of the phase only.** On the very first Build of a session, the target word briefly appears in-place before the slots "unlock" and the tiles scatter into the pool. This is the β "see-and-rebuild" scaffold, used once per day as an orientation gesture. From word 2 onward the phase is pure α. The variant is not user-configurable.

## 6. Chain Shape — One Six-Minute Phase

The phase runs three mini-chains in sequence. Each chain has one Build (head) and three Changes (successors). Let *w* denote the week's target grapheme.

| Chain | Role | Target coverage | Typical length | Example (target = `sh`) |
|---|---|---|---|---|
| 1 | Warmup | 0 of 4 words contain *w* | 4 words | `cat → cut → hut → hat` |
| 2 | Target introduction | 4 of 4 words contain *w* | 4 words | `ship → shop → shut → shot` |
| 3 | Mixed application | 2 or 3 of 4 words contain *w* | 4 words | `fish → dish → wish → miss` |

Aggregate over the phase: twelve trials; between six and seven of the twelve contain *w* (≥ 50 %).

Each chain's first word is a **Build** (α, or β on the first chain of the day). Each successor is a **Change** where the predecessor and successor differ by exactly one tile position, and the two tiles at that position differ by exactly one grapheme. A multi-letter grapheme (`sh`, `ch`, `th`, `ck`, `st`, `bl`, …) occupies a single tile and a single slot, so `ship → chip` is a legal one-tile Change even though the spelling changes two letters.

Word families (shared rime, e.g., `-ip`, `-at`) are the default shape of a chain. Onset-only swap chains (same rime, swap initial consonant or blend) are equally valid. Medial-vowel swap chains (`cat → cut → cot → cat`) are equally valid. A chain does not have to stay within one family across its four words — the Change invariant is local to each adjacent pair.

If the authored library does not contain four words that satisfy all invariants for this week's target, `WordChainProvider` falls back to template generation constrained by the same invariants. If neither source can produce four valid successors, the chain truncates to the longest valid prefix and the missing trials are filled by independent Builds from the same family. This is a safety valve for undersized content; it is not the normal path.

## 7. Scaffold Ladder

Dropping a tile on a slot that does not accept it increments `slotMissCount` for that slot. The ladder triggers on *consecutive* mis-drops on the same slot within the same trial:

| Misses | Intervention | Recorded as |
|---|---|---|
| 1 | Tile bounces back to pool with 0.25 s shake (amplitude 8 pt). Soft haptic. Slot flashes hint color for 180 ms. | `slotMissCount++` |
| 2 | TTS repeats the target phoneme in isolation (e.g., "/ʃ/ — find /ʃ/"). Correct tile in pool pulses at 1 Hz. | `ttsHintIssued = true` |
| 3 | Pool reduces to the correct tile plus one distractor. Other tiles fade out over 300 ms and are not reachable. | `poolReducedTo2 = true` |
| 4 | Slot auto-fills with the correct tile. Tile animates into place from the pool. Auto-fill tiles are visually distinguishable (dashed outline) so the child can see which tiles they did not place themselves. | `autoFilled = true`, trial `scaffoldLevel = 4` |

`scaffoldLevel` is the maximum of the per-slot intervention levels reached during the trial, where each ladder step maps 1→1. `scaffoldLevel = 0` means the trial was first-try perfect.

The ladder resets at each new slot; a child who makes three mistakes on slot 1 then hits slot 2 cleanly resets slot 2's `slotMissCount` to 0 and does not inherit the earlier interventions.

The Say step (state `.speaking`) is *not* part of the ladder. Pronunciation feedback follows the rules established in `2026-04-22-pronunciation-feedback-design.md`; the build ladder governs only tile construction.

## 8. Content Invariants — `WordChainProvider`

A four-word chain must satisfy, atomically:

1. **Decodability.** Every word decomposes into graphemes drawn exclusively from (mastered set) ∪ {*w*} where *w* is the week's target.
2. **Change-by-one.** For adjacent words *wᵢ*, *wᵢ₊₁* in the chain there is exactly one position *k* such that the tiles at position *k* differ. All other positions' tiles are identical.
3. **Single-grapheme delta.** The differing tiles at position *k* are each valid single-tile graphemes in the learner's inventory. (Digraphs swap with digraphs, single letters with single letters; `sh ↔ ch` counts as a single-grapheme delta, `sh ↔ s` does not.)
4. **Target coverage.** The chain's role (warmup / intro / mixed) dictates the minimum and maximum count of target-containing words; see §6.

A full phase (three chains) must additionally satisfy:

5. **Chain roles.** Chain 1 is warmup, Chain 2 is target intro, Chain 3 is mixed application.
6. **Aggregate target coverage.** At least 6 of 12 words contain the target.
7. **No word repetition across chains.** A word may not appear as both a head and a successor, nor in two different chains, within one phase.

The provider searches the authored library first. On miss, it requests candidate words from `TemplateEngine` and validates them against invariants 1–3 locally. If the truncation path is taken it is recorded on the `SessionSummaryEntity` for diagnostics.

## 9. Architecture

The change respects the one-way dependency direction `Core ← Engines ← UI`, with `Testing` depending on Core+Engines.

### 9.1 MoraCore

New value types (all `Sendable`, all in `Sources/MoraCore/`):

- `TileKind` — enum: `consonant`, `vowel`, `digraph`, `blend`, `trigraph`. Derived from `Grapheme` attributes, not declared on the tile.
- `Tile` — a `Grapheme` plus display metadata (`kind`, rendered string). Identity is the grapheme.
- `BuildTarget` — `{ word: Word, slots: [Grapheme] }`. The canonical spelling of a Build head.
- `ChangeTarget` — `{ predecessor: Word, successor: Word, changedIndex: Int }`. Invariant: exactly one position differs.
- `WordChain` — `{ role: ChainRole, head: BuildTarget, successors: [ChangeTarget] }` with a validator that rejects chains failing §8 invariants 1–3.
- `ChainRole` — enum: `warmup`, `targetIntro`, `mixedApplication`.
- `BuildAttemptRecord` — `{ slotIndex: Int, tileDropped: Grapheme, wasCorrect: Bool, timestampOffset: TimeInterval }`. Carried on the in-memory `TrialRecording` value type (alongside `asr`, `audio`) so the build story travels with the same object downstream consumers already handle.

Existing types (`Grapheme`, `Phoneme`, `Word`, `Target`, `Skill`) are unchanged. `TrialRecording` in MoraEngines gains `buildAttempts: [BuildAttemptRecord]` and `scaffoldLevel: Int`; `ASRResult` and `AudioBuffer` are unchanged.

### 9.2 MoraCore persistence

SwiftData schema changes land as one lightweight migration. `PerformanceEntity` (the per-trial row) gains:

- `buildAttemptsJSON: Data?` — codable serialization of `[BuildAttemptRecord]`, `nil` for trials that predate this feature and for non-tile-board trials (today there are none, but the field stays nullable for forward compatibility).
- `scaffoldLevel: Int` — 0 for first-try-perfect; up to 4 for auto-filled.
- `ttsHintIssued: Bool`, `poolReducedToTwo: Bool`, `autoFilled: Bool` — three booleans recording which ladder rungs fired. Redundant with `scaffoldLevel` but cheap to store and useful for Parent Mode filtering.

`SessionSummaryEntity` gains `tileBoardMetricsJSON: Data?` — codable serialization of `TileBoardMetrics { chainCount: Int, truncatedChainCount: Int, totalDropMisses: Int, autoFillCount: Int }`.

All new fields are nullable / default-initialized so the migration is additive. `MoraModelContainer.onDisk()` falls back to `.inMemory()` if the migration fails, matching the existing safety-net contract.

### 9.3 MoraEngines

New components, all in `Sources/MoraEngines/TileBoard/` except where noted:

- `TileBoardEngine` (`@Observable @MainActor`, class) — owns the seven-state machine of §5. Consumes `TileBoardEvent`s (`.tileLifted`, `.tileDroppedOn(slotIndex)`, `.micTapped`, `.feedbackDismissed`) and emits transitions. Delegates TTS to the injected `TTSEngine` and ASR to the injected `SpeechEngine` + `AssessmentEngine`.
- `WordChainProvider` (protocol + `LibraryFirstWordChainProvider` default impl) — generates the three-chain phase for a given `(target, masteredSet)`. Depends on the existing `ContentProvider` / `ScriptedContentProvider` library and `TemplateEngine`.
- `ChainScaffoldLadder` (pure struct with static functions) — given `slotMissCount` and current `poolPolicy`, returns the next intervention (`.bounceBack`, `.ttsHint`, `.reducePool`, `.autoFill`). Easy to unit-test; no dependencies.
- `TilePoolPolicy` — enum with associated values describing how the pool is constructed for a trial (`.buildFromWord(withDistractors: Int)`, `.vowelsOnly`, `.reducedToTwo(correct: Grapheme, distractor: Grapheme)`, etc.).

Existing orchestration changes:

- `SessionOrchestrator` routes the `.decoding` phase to `TileBoardEngine` instead of the current per-word controller.  The orchestrator does not learn about chains directly — it feeds the engine one chain at a time and consumes a `.chainFinished` event to advance.
- `ADayPhase.decoding` retains its enum case; only the underlying driver changes.
- `OrchestratorEvent` gains `.tileBoardTrialCompleted(TrialRecording)` which fires once per word (same shape as today's `.answerHeard`, so downstream summary code keeps working).

Deletions (removed outright; no backwards-compatibility shim per CLAUDE.md):

- Any per-word list-read UI owned by `DecodeActivityView`. If helper types in `MoraEngines` exist only to service that UI, they go too.

### 9.4 MoraUI

New views under `Sources/MoraUI/Session/TileBoard/`:

- `DecodeBoardView` — the top-level `.decoding` container. Replaces `DecodeActivityView`.
- `TileView` — one tile. Owns the pickup/shake/settle gestures and animation states. Uses `.matchedGeometryEffect` for pool ↔ slot flight.
- `SlotView` — one slot. Knows its own `state: .empty / .active / .filled(Tile) / .locked(Tile) / .autoFilled(Tile)`.
- `TilePoolView` — flow layout for the current pool. Handles pool reduction animations.
- `ChainProgressRibbon` — twelve-pip indicator at the top of the board, grouped into three of four with small dividers, showing which word the learner is on and which chains are complete.
- `ChainTransitionOverlay` — scene transition between chains (background gradient crossfade, tile fly-out, trophy illumination).

Removed: `DecodeActivityView` and its subcomponents.

Reused unchanged: `PronunciationFeedbackOverlay`, `SpeechController`, `MoraStrings` keys for "tap to speak", "great", etc.

### 9.5 MoraTesting

- `FakeTileBoardEngine` — records `events` and lets tests drive state transitions without Apple `Speech` / `AVFoundation`.
- `FixtureWordChains` — hand-written valid chains for a handful of targets (`sh`, `ch`, `th`, `ck`) to pin animation tests and snapshot tests.

## 10. Visual and Motion Design

The board lives inside the existing `RootView → SessionContainerView` scaffolding and inherits the established palette, OpenDyslexic typography, and alpha hero-CTA motion language.

### 10.1 Tile palette

- **Consonants** — blue fill (`#dbeafe`), blue border (`#93c5fd`), dark-blue text (`#1e3a8a`).
- **Vowels** — warm-orange fill (`#fed7aa`), orange border (`#fb923c`), dark-orange text (`#9a3412`).
- **Digraphs / blends / trigraphs** — green fill (`#d9f99d`), green border (`#a3e635`), dark-green text (`#3f6212`).

The three-color system matches the Barton tradition (one color per class) while being visually distinct from LearnUp's palette. Colors are defined centrally in `MoraUI/Design/TileColors.swift` and driven from `TileKind`, not hard-coded in views.

### 10.2 Tile dimensions and hit targets

64 × 64 pt base tile, 16 pt spacing in the pool, 12 pt spacing in the slot row. On iPad in landscape the board comfortably fits six pool tiles in one row. In portrait the pool wraps to two rows. Text is 32 pt OpenDyslexic.

### 10.3 Tile motion

All motion is SwiftUI-native (`withAnimation`, `.matchedGeometryEffect`, `.spring(response:dampingFraction:)`). No SpriteKit or third-party animation library.

| Event | Animation | Haptic |
|---|---|---|
| Pickup (tile lifts on long-press / drag start) | scale 1.12, shadow bloom, micro-rotation ±3°, 150 ms ease-out | `.soft` (intensity 0.4) |
| Hover over valid slot | slot scales 1.04 and brightens fill by 8% | none |
| Correct drop | matched-geometry flight to slot, spring (response 0.35, damping 0.7) | `.medium` |
| Slot settle | slot flashes warm-yellow for 300 ms post-lock | none |
| Wrong drop | 0.25 s horizontal shake (amplitude 8 pt), then bounce back to pool via spring | `.soft` |
| Word complete | slots cascade-glow with 50 ms stagger, word text lifts 1.15× with soft shadow, mic icon spring-pops | `.medium` (single) |
| Chain transition | tiles fly up with 120 ms stagger, background gradient crossfade 600 ms, next chain materializes with reverse stagger | none |

### 10.4 Background language for chains

Each chain owns a gradient that signals its role without text:

- Chain 1 — cool dawn (pale blue → lavender).
- Chain 2 — warm midday (pale yellow → soft peach).
- Chain 3 — warm dusk (soft peach → muted coral).

Transitions between chains are 600 ms crossfades with subtle 2% scale breath. The palette stays within a narrow luminance band so the tiles' contrast does not change — accessibility targets remain met across all three.

### 10.5 Accessibility

- **OpenDyslexic** typography across all tile text, slot text, and prompt text.
- **Dynamic Type** respected on the prompt row and progress ribbon labels. Tile glyphs stay fixed at 32 pt to preserve layout.
- **Reduce Motion**: springs replaced by 120 ms linear moves; shake replaced by a 2-pulse color flash; chain transitions become instant crossfades without scale breath.
- **VoiceOver**: each tile announces `"/ʃ/, as in ship"` (drawn from `MoraStrings`); each slot announces `"position 1 of 3, empty"` / `"… contains sh"`; the mic button announces `"tap to say the word"`.
- **Switch Control**: tiles and slots are individually focusable. Drag-and-drop is available via the standard focus-lift-drop AX gestures.
- **Sound toggle**: a setting exposed in the existing Settings surface mutes non-TTS tile sounds. Default is on but kept quiet (tile drop = 15 dB below TTS reference).

## 11. Data Flow for One Phase

1. `SessionOrchestrator` transitions to `.decoding`.
2. Orchestrator calls `WordChainProvider.generatePhase(target:masteredSet:)`. Provider returns three `WordChain`s or a truncated set (logged on `SessionSummaryEntity`).
3. For each chain:
   1. Orchestrator sends the chain to `TileBoardEngine.present(chain:)`.
   2. Engine drives §5's seven states for the head (Build).
   3. For each of the three successors, engine reuses the locked tiles from the previous trial's slot array, keeps them in place (state transition `.transitioning → .preparing`), and runs §5 again in Change mode.
   4. When the fourth trial reaches `.feedback → .feedbackDismissed`, engine emits `.chainFinished(ChainMetrics)` and plays `ChainTransitionOverlay`.
4. After the third chain's `.chainFinished`, engine emits `.phaseFinished(PhaseMetrics)`. Orchestrator advances `ADayPhase` to `.shortSentences`.

Every `.speaking → .feedback` transition produces one `TrialRecording` via the existing assessment path. `BuildAttemptRecord`s are appended as they happen.

## 12. Testing

The layering makes three test tiers natural.

- **Unit (MoraCore, MoraEngines).**
  - `WordChain` validator rejects chains that violate §8.1–§8.3. Includes cases where `sh → ch` passes and `sh → s` fails.
  - `WordChainProvider` generation: given a synthetic library and target, asserts §8.4–§8.7. Includes the truncation fallback path.
  - `ChainScaffoldLadder` returns the expected intervention for each `(slotMissCount, currentPoolPolicy)` pair. Exhaustive because the state space is tiny.
  - `TileBoardEngine` state-machine transitions: given a scripted sequence of events, assert the state trajectory and emitted `OrchestratorEvent`s. Uses `FakeSpeechEngine` / `FakeTTSEngine` from MoraTesting.
- **Integration (MoraEngines + MoraTesting).**
  - Full phase run with a fixture of three `WordChain`s. Assert: exactly twelve trials produced; chain boundaries emit `.chainFinished`; `.phaseFinished` fires exactly once.
  - Scaffold ladder integration: a trial where all four ladder steps fire in sequence produces `scaffoldLevel = 4` and `autoFilled = true` on the `TrialRecording`.
- **UI (MoraUI).**
  - SwiftUI preview snapshots for each of the seven states of one trial, in both Build and Change mode, in both light and dark, and at Reduce-Motion on/off.
  - VoiceOver label snapshot: assertions that each tile, slot, and control exposes the expected label string.

CI runs the non-UI tiers via `swift test` on each package (per existing CI). UI snapshots are generated on-demand with Xcode Previews; no snapshot-testing dependency is added.

## 13. Rollout and Scope Boundaries

The work lands as one phase of A-day's implementation (the existing Decoding slot). There is no feature flag, no hybrid coexistence with `DecodeActivityView`, and no runtime A/B. When this feature merges, the list-read Decoding UI is deleted in the same PR.

Strictly out of scope for v1:

- Any free-play / review mode outside A-day.
- Parent-configurable difficulty.
- Non-JP L1 confusion-pair boards (covered by Sort-by-sound, explicitly deferred).
- C-day Reading Adventure (itself deferred).
- Multisyllable words (L4+).
- Spaced-retrieval across days; within-session retention only.

Deferred but considered:

- v1.5 will cross-reference `PronunciationEvaluator` phoneme diagnoses against the tile placements during the Say step, to coach the child on which graphemes corresponded to which mispronounced phonemes. This integration is a separate spec; the data needed to enable it is persisted from day one of the tile board via `BuildAttemptRecord`.

## 14. Open Questions

1. **Chain-family authoring budget.** The authored library must cover every v1 target (L2 consonants + short vowels, L3 digraphs/blends) with at least three valid four-word chains per target per role. This is a content task outside the engineering implementation; the plan should budget a separate content pass or rely on `TemplateEngine` to cover gaps with a documented fallback rate.
2. **Chain celebration audio.** Current plan keeps celebrations silent-but-haptic (see §10.5 sound toggle). If playtesting shows the 8-year-old wants audible cheers, add them in a later pass — the engine already emits `.chainFinished`, so adding sound is UI-local.
3. **Change-mode pool policy when the new grapheme is novel-for-this-week.** Example: week introduces `sh`; Chain 2 starts `ship → chip`. `chip` uses `ch`, which may or may not be mastered. Current policy: if `ch` is in the mastered set it appears in the pool; if not, Chain 2 stays within `sh` and `ship → chip` is moved to a later week. Provider enforces this, but it constrains content authoring and should be verified with the first two weeks' material.
