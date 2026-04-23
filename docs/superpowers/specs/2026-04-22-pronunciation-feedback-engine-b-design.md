# mora — Pronunciation Feedback Engine B (Shadow Mode) Design Spec

- **Date:** 2026-04-22
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Release target:** v1.5 (alongside MoraMLX activation)
- **Refines:** `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md` §6.3 (Engine B), §12 (Phase 3), §13.1 (`PronunciationTrialLog`).
- **Relates to:** `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-a.md` (Engine A, Phase 1 + 2 — landed, defines the `PronunciationEvaluator` protocol that Engine B slots into).
- **Coordinates with:** `dev-tools/pronunciation-bench/` (separate session). This spec does not design, create, or modify anything under `dev-tools/pronunciation-bench/`. The correlation / calibration work that feeds back GOP sigmoid parameters happens there.

---

## 1. Overview

The parent pronunciation-feedback spec (§6.3) describes Engine B at the design level: a wav2vec2-phoneme CoreML model performs forced alignment against the expected word and produces GOP scores; the orchestrator runs Engine A and Engine B in parallel; Engine A drives the UI, Engine B feeds a `PronunciationTrialLog` SwiftData entity for later correlation analysis. Engine B ships alongside Engine A in v1.5 "in shadow" — logged but not shown to the learner.

This spec is the implementation-detail contract for that Phase 3 work. It:

- Fixes the internal boundary between `MoraMLX` (model hosting) and `MoraEngines` (alignment, GOP, composition, logging) so Engine B can be unit-tested without the 150 MB model file loaded.
- Defines `ShadowLoggingPronunciationEvaluator`, the composite `PronunciationEvaluator` that runs Engine A and Engine B together, forwards A to the UI, and writes the log row via a `PronunciationTrialLogger`.
- Defines `PronunciationTrialLog` and its FIFO retention policy at the code level, along with the `MoraModelContainer` schema change.
- Settles the model-distribution path: `dev-tools/model-conversion/` (Python + coremltools, checked in) produces the `.mlmodelc`; the `.mlmodelc` is tracked by Git LFS and bundled as a `MoraMLX` package resource.
- Splits the implementation into two PRs (Part 1 = evaluator code + SwiftData + composite; Part 2 = real model bundling + CoreML provider + CI wiring).

Every on-device invariant from the parent pronunciation spec holds: no raw audio, transcript, or per-trial detail leaves the device in any shipped build. Engine B's model lives in the app bundle; its outputs are persisted only in local SwiftData.

## 2. Motivation

Engine A (now landed) covers eight curated L1-Japanese↔English phoneme confusion pairs (plus one drift target for /ʃ/) using hand-picked acoustic features. That is enough for the v1.5 learner's highest-value confusions, but three things are out of reach for a rule-based evaluator:

1. **Coverage beyond the curated pairs.** Engine A returns `supports = false` for any phoneme not in its table. That drops into transcript-only assessment — no category, no score, no coaching.
2. **Forced alignment.** Engine A localizes a phoneme using positional heuristics on the word's ASR timing (first 150 ms ≈ onset, last 150 ms ≈ coda, medial = `isReliable = false`). Forced alignment against the actual phoneme sequence is how Engine B justifies showing a score on medial phonemes.
3. **Ground truth for threshold tuning.** Engine A's boundaries are literature-derived defaults. Without a reference evaluator scoring the same audio, we have no correlation signal to know whether the defaults are pulling in the right direction for the learner's actual voice.

Shipping Engine B in shadow from v1.5 day one gives the app a parallel scoring signal accumulating in `PronunciationTrialLog`, which (combined with `dev-tools/pronunciation-bench/`'s SpeechAce correlation work in a separate session) feeds the promotion decision in a later release. The parent spec (§6.3 "Promotion gate") spells out that decision; this spec does not implement it.

## 3. Goals and Non-Goals

### Goals

- Engine B evaluator (`PhonemeModelPronunciationEvaluator`) that accepts a `PhonemePosteriorProvider`, a `ForcedAligner`, and a `GOPScorer` and returns `PhonemeTrialAssessment` via the existing `PronunciationEvaluator` protocol.
- Clean test seam: every Engine B component tested with a `FakePhonemePosteriorProvider` so CI does not require the 150 MB model to exercise the evaluation logic.
- `ShadowLoggingPronunciationEvaluator` composite that runs Engine A and Engine B in parallel on every trial, forwards Engine A's result to the UI path, and persists both through a `PronunciationTrialLogger`.
- `PronunciationTrialLog` SwiftData entity in `MoraCore` with a FIFO 1000-row retention policy triggered at app launch.
- `dev-tools/model-conversion/` (Python) that produces a reproducible `.mlmodelc` from a pinned Hugging Face revision, plus a sidecar `phoneme-labels.json` describing the column order of the posterior matrix.
- Git LFS wiring for the `.mlmodelc` resource, with CI fetching LFS objects during checkout.
- App-level injection (`MoraApp`) that wraps Engine A in the composite when the model loads successfully and silently falls back to bare Engine A when it does not.
- Engine B smoke test in `MoraMLX` that loads the real `.mlmodelc` in CI and asserts posterior-shape sanity on a short synthetic clip.

### Non-Goals

- UI surface for Engine B's output. Shadow mode is invisible to the learner.
- A primary-evaluator toggle (`SettingsStore.preferredEvaluator`). The parent spec (§6.3) defers this to a post-v1.5 promotion PR. This spec does not introduce the setting.
- Per-speaker threshold adaptation. Deferred per parent spec §14 Q2.
- `dev-tools/pronunciation-bench/`. Separate session; this spec does not design it, does not depend on it, and does not block on it.
- GOP sigmoid calibration. Defaults ship here; calibration loops back from `pronunciation-bench/` in a follow-up PR.
- Parent-mode export of shadow logs. Parent Mode spec is a separate future track.
- Engine B coverage outside the curated English phoneme inventory MVP defined in §5.3. Phoneme coverage expansion is a post-v1.5 follow-up.

## 4. Design Decisions

### 4.1 MoraMLX hosts the model; MoraEngines hosts the evaluator logic

The parent spec (§6.3) places `PhonemeModelPronunciationEvaluator` inside `MoraMLX`. In this refinement, only the **CoreML-bound `PhonemePosteriorProvider`** and the model-loading machinery live in `MoraMLX`. Alignment, GOP, composition, and the `PronunciationEvaluator` wrapper itself live in `MoraEngines`. The boundary is a single protocol:

```swift
public protocol PhonemePosteriorProvider: Sendable {
    func posterior(for audio: AudioClip) async throws -> PhonemePosterior
}
```

This separation has three consequences:

- Engine B's evaluation logic can be unit-tested in `MoraEngines/Tests` with a `FakePhonemePosteriorProvider` returning scripted posteriors. No CoreML model load. CI is fast.
- The parent spec's `MoraMLX` placement comment (`// Placeholder for v1.5. This package intentionally has no dependencies and no public API in v1`) is lifted: MoraMLX now exports two public symbols, `CoreMLPhonemePosteriorProvider` and `MoraMLXModelCatalog`, and takes on dependencies `MoraCore` and `MoraEngines`. `MoraUI` does not gain a dependency on `MoraMLX` — app startup does the wiring.
- The same split is reusable for v1.5's Qwen / Gemma LLM work: `MoraMLX` hosts models; domain packages (`MoraEngines`) host business logic, consuming MLX via narrow protocols.

### 4.2 Composite decorator, always-fire Engine B

Fan-out policy is locked in brainstorming as Option C (always fire B, regardless of Engine A's support status):

- Engine B's supported-phoneme inventory is a superset of Engine A's.
- Shadow mode exists to gather correlation data. Skipping trials where A fell back to transcript-only would systematically under-sample exactly the phonemes where B is interesting.
- The composite owns the logging policy, so "always log when B returned a result, never log when B threw" is a single rule in one file.

Trade-off (accepted): the composite has two support sources instead of one. Acceptable because the composite is the only place in the shipped app that needs this decision; orchestrator and UI see a plain `PronunciationEvaluator`.

### 4.3 Always-detached shadow call; timeout is non-negotiable

The parent spec sets a 1000 ms budget (§6.3) and says B is discarded on timeout. Implementation:

- `ShadowLoggingPronunciationEvaluator.evaluate` returns Engine A's result as soon as A finishes.
- Engine B's call happens inside `Task.detached(priority: .background)` with a `withTimeout(.milliseconds(1000))` wrapper. The detached task writes the log row; it never blocks the caller.
- A's result must be captured into the detached closure by value (it is `Sendable`). This keeps the task self-contained and prevents orchestrator-state leaks.

The UI path is therefore never slowed by Engine B regardless of model latency, model-load cost, or Neural Engine contention.

### 4.4 GOP sigmoid defaults are honest pre-calibration values, not performative

Parent spec §6.3 mentions a sigmoid "trained on a held-out set from `dev-tools/pronunciation-bench/`". `pronunciation-bench/` is being built in a separate session and the training set does not exist yet. This spec therefore:

- Ships `GOPScorer` with `k = 5.0`, `gopZero = -1.5` as v1.5 defaults. These are monotonic and roughly-centered on typical wav2vec2 GOP ranges reported in the pronunciation-assessment literature (Hu et al. 2015, 2022) but are **not** validated against the learner's voice.
- Labels the values in code as "pre-calibration defaults" in the docstring.
- Exposes `k` and `gopZero` as `var` members of `GOPScorer` (not `let`) so a follow-up PR fed by `pronunciation-bench/` correlation can override them without touching consumers.
- Does not gate shadow logging behind calibration; the whole point of shadow logging is to feed calibration.

### 4.5 Model distribution: `dev-tools/model-conversion/` + Git LFS + MoraMLX resource

Parent spec §4.1 requires the model to live in the shipped bundle (no first-launch download for v1.5). The pragmatic path is:

- `dev-tools/model-conversion/convert.py` performs the Hugging Face → CoreML conversion deterministically, pinned to a specific HF revision.
- The `.mlmodelc` output lands at `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/`.
- `.gitattributes` tracks that directory tree as Git LFS (`filter=lfs diff=lfs merge=lfs -text`).
- CI's `actions/checkout` step gains `lfs: true` so the smoke test and device build have the bytes.
- The sidecar `phoneme-labels.json` (a few KB) is plain git — not LFS.

Rationale for Git LFS over direct git: a 150 MB binary commits into repo history forever; every `git clone` pulls it even for developers not touching MoraMLX. LFS keeps the pointer in history and materializes the object only on demand. Overhead (setup: one-time `git lfs install`) is small compared to repo-wide checkout time amortized across future model updates.

### 4.6 `dev-tools/` boundary

The author is running `dev-tools/pronunciation-bench/` in a parallel worktree / session. To avoid collisions:

- This spec's implementation creates `dev-tools/model-conversion/` only.
- The top-level `dev-tools/` directory itself is created by whichever session lands first. Both specs treat it as existing. Neither session adds a top-level `README.md` at `dev-tools/` to avoid merge conflicts; per-tool READMEs live inside each tool's subdirectory.
- `dev-tools/model-conversion/` has no dependency on `dev-tools/pronunciation-bench/` and vice versa. Both can land in either order.

### 4.7 Engine B inventory MVP

wav2vec2-xlsr-53-espeak-cv-ft outputs ~80 espeak IPA phoneme classes. v1.5 does not need that full coverage — the L1-Japanese curriculum's phoneme targets span a small subset. The MVP inventory Engine B declares as "supported" is:

- All 12 phonemes referenced by Engine A's curated pairs: `ʃ s r l f h v b θ t æ ʌ`.
- Common English phonemes near the curriculum's near-term expansion: `i ɪ e ɛ ə ʊ u ɑ ɔ p k d g m n ŋ j w z ʒ dʒ tʃ`.

Total MVP: approximately 36 phonemes. The `PhonemeInventory` type exposes this as `Set<String>`; phonemes outside it return `supports = false` and Engine B is silent on that trial (the log row still records Engine A's result plus an `engineBLabel = "unsupported"` sentinel). Expansion to full inventory is a data-only change (add to the set) and out of scope here.

### 4.8 Fallback behavior when the model does not load

If `MoraMLXModelCatalog.loadPhonemeEvaluator()` throws (model file missing, corrupted, or the OS fails to materialize the `.mlmodelc`), `MoraApp` silently installs bare Engine A. No shadow logging occurs until the next successful app launch. An `os_log` line at `.error` records the failure for debugging. The app is fully functional with just Engine A.

This is a safety-net, not a supported shipping configuration. Part 2's CI smoke test prevents a model-missing Release build from shipping.

## 5. Architecture

### 5.1 File layout

```
Packages/MoraEngines/Sources/MoraEngines/Pronunciation/
  PhonemePosterior.swift                         [NEW]
  PhonemePosteriorProvider.swift                 [NEW]
  PhonemeInventory.swift                         [NEW]
  ForcedAligner.swift                            [NEW]
  GOPScorer.swift                                [NEW]
  PhonemeModelPronunciationEvaluator.swift       [NEW]
  ShadowLoggingPronunciationEvaluator.swift      [NEW]
  PronunciationTrialLogger.swift                 [NEW]
  SwiftDataPronunciationTrialLogger.swift        [NEW]
  CoachingKeyResolver.swift                      [NEW — extracted from Engine A]
  Concurrency.swift                              [NEW — withTimeout helper]

Packages/MoraEngines/Tests/MoraEnginesTests/
  PhonemePosteriorTests.swift                    [NEW]
  ForcedAlignerTests.swift                       [NEW]
  GOPScorerTests.swift                           [NEW]
  PhonemeModelPronunciationEvaluatorTests.swift  [NEW]
  ShadowLoggingPronunciationEvaluatorTests.swift [NEW]
  PronunciationTrialLoggerTests.swift            [NEW]
  SessionOrchestratorShadowLoggingTests.swift    [NEW]
  ConcurrencyTests.swift                         [NEW]

Packages/MoraMLX/Sources/MoraMLX/
  MoraMLXPlaceholder.swift                       [DELETE]
  MoraMLXModelCatalog.swift                      [NEW]
  CoreMLPhonemePosteriorProvider.swift           [NEW]
  Resources/
    wav2vec2-phoneme.mlmodelc/                   [NEW — Git LFS]
    phoneme-labels.json                          [NEW — plain git]

Packages/MoraMLX/Tests/MoraMLXTests/
  CoreMLPhonemePosteriorProviderSmokeTests.swift [NEW]
  Fixtures/
    short-ʃ-clip.wav                             [NEW — small, committed]

Packages/MoraCore/Sources/MoraCore/Persistence/
  PronunciationTrialLog.swift                    [NEW]
  PronunciationTrialRetentionPolicy.swift        [NEW]

Packages/MoraCore/Tests/MoraCoreTests/
  PronunciationTrialLogTests.swift               [NEW]
  PronunciationTrialRetentionPolicyTests.swift   [NEW]

Packages/MoraTesting/Sources/MoraTesting/
  FakePhonemePosteriorProvider.swift             [NEW]
  InMemoryPronunciationTrialLogger.swift         [NEW]

dev-tools/model-conversion/
  README.md                                      [NEW]
  convert.py                                     [NEW]
  requirements.txt                               [NEW]
  .env.example                                   [NEW]
  .gitignore                                     [NEW]

.gitattributes                                   [NEW]
```

### 5.2 Modified files

| File | Change |
|---|---|
| `Packages/MoraMLX/Package.swift` | Add `.package(path: "../MoraCore")` + `.package(path: "../MoraEngines")` dependencies. Declare the `Resources/` directory as `.process(...)`. Add a `MoraMLXTests` test target. |
| `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift` | Append `PronunciationTrialLog.self` to `schema`. |
| `Packages/MoraCore/Sources/MoraCore/MoraCore.swift` | Unchanged (version bump optional, not required by functionality). |
| `Mora/MoraApp.swift` | Instantiate `ShadowLoggingPronunciationEvaluator` when `MoraMLXModelCatalog.loadPhonemeEvaluator()` succeeds; fall back to bare `FeatureBasedPronunciationEvaluator` on failure. Pass the SwiftData `ModelContainer` into `SwiftDataPronunciationTrialLogger`. Call `PronunciationTrialRetentionPolicy.cleanup` once at startup. |
| `.github/workflows/ci.yml` | `actions/checkout` → `with: lfs: true`. The CI's existing `Binary gate — no cloud symbols` step excludes the new `Resources/` model bytes via path filter. |
| `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md` | Add `- **Implementation plan (Phase 3):** docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` to the header metadata. |

### 5.3 Dependency graph change

Before:

```
MoraCore ← MoraEngines ← MoraUI
                         MoraTesting → MoraCore, MoraEngines
                         MoraMLX     (isolated)
```

After:

```
MoraCore ← MoraEngines ← MoraUI
                      ↖ MoraMLX
                         MoraTesting → MoraCore, MoraEngines
```

`MoraMLX` now depends on `MoraCore` (for `Phoneme`, `Word`) and `MoraEngines` (for `AudioClip`, `PhonemePosteriorProvider`). No other edges change. `MoraUI` still does not depend on `MoraMLX`; the app target wires them together. The dependency direction remains one-way (no cycles).

## 6. Components

### 6.1 `PhonemePosterior` — posterior matrix value type

```swift
public struct PhonemePosterior: Sendable, Hashable, Codable {
    public let framesPerSecond: Double          // typically 50 (20 ms frame, 50 Hz stride)
    public let phonemeLabels: [String]          // column index → espeak IPA label
    public let logProbabilities: [[Float]]      // [frameCount][phonemeLabels.count]

    public var frameCount: Int { logProbabilities.count }
    public var phonemeCount: Int { phonemeLabels.count }
    public func frameIndex(forSecond second: Double) -> Int
    public func second(forFrame index: Int) -> Double
}
```

- Log-probabilities, not raw probabilities: Viterbi and GOP both sum in log-space.
- Row-major storage for cache-friendly iteration over frames in Viterbi.
- `Hashable`/`Codable` for scripted test fixtures; serialization of real posteriors to disk is not required in v1.5.

### 6.2 `PhonemePosteriorProvider` protocol

```swift
public protocol PhonemePosteriorProvider: Sendable {
    func posterior(for audio: AudioClip) async throws -> PhonemePosterior
}
```

Contract:

- Input audio is mono 16 kHz Float32 (already the ring-buffer output of `AppleSpeechEngine` — enforced by `AudioClip`'s existing shape).
- Returns a posterior whose `framesPerSecond` and `phonemeLabels` are stable within one process lifetime for a given provider.
- Throws on model-load failure, audio-preprocessing failure, or CoreML runtime error.

`FakePhonemePosteriorProvider` (MoraTesting) accepts a scripted `PhonemePosterior` and returns it verbatim. An overload throws a scripted error.

### 6.3 `PhonemeInventory` — espeak ↔ MoraCore.Phoneme mapping

```swift
public struct PhonemeInventory: Sendable, Hashable {
    public let espeakLabels: [String]                      // canonical column order
    public let supportedPhonemeIPA: Set<String>            // the v1.5 MVP subset
    public let ipaToColumn: [String: Int]                  // Phoneme.ipa → posterior column

    public init(espeakLabels: [String], supportedPhonemeIPA: Set<String>) {
        self.espeakLabels = espeakLabels
        self.supportedPhonemeIPA = supportedPhonemeIPA
        var map: [String: Int] = [:]
        for (index, label) in espeakLabels.enumerated() {
            map[label] = index
        }
        self.ipaToColumn = map
    }

    /// The v1.5 MVP phoneme set. The value is metadata only — the full
    /// `PhonemeInventory` is constructed by `MoraMLX` at load time by
    /// pairing this set with espeak labels read from `phoneme-labels.json`.
    public static let v15SupportedPhonemeIPA: Set<String> = [
        "ʃ", "s", "r", "l", "f", "h", "v", "b", "θ", "t", "æ", "ʌ",
        "i", "ɪ", "e", "ɛ", "ə", "ʊ", "u", "ɑ", "ɔ",
        "p", "k", "d", "g", "m", "n", "ŋ", "j", "w",
        "z", "ʒ", "dʒ", "tʃ",
    ]
}
```

`phoneme-labels.json` is emitted by `dev-tools/model-conversion/convert.py` alongside the `.mlmodelc`. It lists the espeak IPA labels in the exact column order of the model's final classification head. `MoraMLX` at process start decodes that JSON and constructs a full `PhonemeInventory(espeakLabels: loadedLabels, supportedPhonemeIPA: .v15SupportedPhonemeIPA)`. `MoraEngines` depends only on the static set and on the value type — it does not read the JSON. Tests in MoraEngines build ad-hoc inventories with hand-written label lists.

### 6.4 `ForcedAligner`

```swift
public struct PhonemeAlignment: Sendable, Hashable {
    public let phoneme: Phoneme
    public let startFrame: Int
    public let endFrame: Int                    // half-open: [startFrame, endFrame)
    public let averageLogProb: Float            // mean log-prob of the target phoneme over the range
}

public struct ForcedAligner: Sendable {
    public let inventory: PhonemeInventory

    public func align(
        posterior: PhonemePosterior,
        phonemes: [Phoneme]
    ) -> [PhonemeAlignment]
}
```

Algorithm: left-to-right HMM with one state per expected phoneme in order, no skip transitions, self-loops with a small insertion penalty. Viterbi over `frameCount × phonemes.count` log-posterior matrix (the relevant column for each state is looked up via `inventory.ipaToColumn`). Backtrack yields contiguous frame ranges per phoneme.

Edge cases:

- Phoneme not in inventory → its column index is `nil`; the aligner treats that state as uniform-prior (returns `averageLogProb = −log(inventory.phonemeCount)` and a positional fallback range `[position × frameCount / phonemes.count, (position+1) × frameCount / phonemes.count)`).
- `frameCount < phonemes.count` → collapse: each phoneme gets at least one frame; remainder distributed positionally; `averageLogProb` set to `-.infinity` (treated as unreliable downstream).
- `phonemes` empty → return `[]`.

### 6.5 `GOPScorer`

```swift
public struct GOPScorer: Sendable {
    public var k: Double = 5.0                  // pre-calibration sigmoid slope
    public var gopZero: Double = -1.5           // pre-calibration sigmoid midpoint
    public var reliabilityThreshold: Double = -2.5  // min averageLogProb for score emission

    public func gop(
        posterior: PhonemePosterior,
        range: Range<Int>,
        targetColumn: Int
    ) -> Double

    public func score0to100(gop: Double) -> Int
}
```

- GOP formula per parent spec §6.3: `(1 / |range|) * Σ_{t ∈ range} [log p(target | t) − max_q log p(q | t)]`. Upper-bounded by 0.
- Sigmoid: `sigmoid(x) = 1 / (1 + exp(-k*(x − gopZero)))`, then `round(100 * sigmoid(gop))`, clamped to `[0, 100]`. Monotone-increasing in `gop` (closer to 0 → higher score).
- `reliabilityThreshold` is consumed by `PhonemeModelPronunciationEvaluator`, not by `GOPScorer` directly; placed here so calibration can adjust it alongside sigmoid parameters.

Pre-calibration values are flagged in the source docstring with the text "pre-calibration; updated from dev-tools/pronunciation-bench/ correlation output in a follow-up PR".

### 6.6 `PhonemeModelPronunciationEvaluator`

```swift
public struct PhonemeModelPronunciationEvaluator: PronunciationEvaluator {
    public let provider: any PhonemePosteriorProvider
    public let aligner: ForcedAligner
    public let scorer: GOPScorer
    public let inventory: PhonemeInventory
    public let l1Profile: any L1Profile                   // for substitution resolution
    public let timeout: Duration                          // default .milliseconds(1000)

    public func supports(target: Phoneme, in word: Word) -> Bool {
        inventory.supportedPhonemeIPA.contains(target.ipa)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment
}
```

`evaluate` flow:

1. Call `provider.posterior(for: audio)` under `withTimeout(timeout)`. On timeout, throw, or empty posterior → return `.unclear` with `isReliable = false` and `features = ["reason": "<code>"]`.
2. Compute `alignments = aligner.align(posterior:, expected.phonemes)`.
3. Locate the alignment for `targetPhoneme` (match by `Phoneme.ipa`; if multiple occurrences, pick the one whose index in `expected.phonemes` equals `expected.targetPhonemeIndex` when set, else the first match).
4. If the alignment's `averageLogProb < scorer.reliabilityThreshold` → return `.unclear` with `isReliable = false` (label `.unclear`, score nil).
5. Look up `targetColumn = inventory.ipaToColumn[targetPhoneme.ipa]`. If nil (inventory drift — the supported set knows the phoneme but the loaded espeak labels do not), return `.unclear` with `isReliable = false`. Otherwise compute `gop = scorer.gop(posterior:, range: alignment.startFrame..<alignment.endFrame, targetColumn: targetColumn)`.
6. Compute `score = scorer.score0to100(gop: gop)`.
7. Classify by argmax over the alignment range:
   - argmax column's IPA == `targetPhoneme.ipa` → `label = .matched`.
   - argmax IPA matches a known L1 interference pair (`l1Profile.interferencePairs` with `from = targetPhoneme`) → `label = .substitutedBy(Phoneme(ipa: argmaxIPA))`.
   - otherwise → `label = .unclear`.
8. `coachingKey` resolved via the same helper used by Engine A (extracted in Part 1; shared between evaluators). Defined in `MoraEngines/Pronunciation/CoachingKeyResolver.swift` as part of Engine B work, refactored out of Engine A's file.
9. `features` dictionary carries `["gop": gop, "avgLogProb": Double(alignment.averageLogProb), "frameCount": Double(alignment.endFrame - alignment.startFrame), "argmaxIPA": <hashed-int placeholder>]`. IPAs are short; we store them by interning them into `Int` columns in the log only, not in this dict.
10. `isReliable = true` iff steps 3–5 did not bail. Score emitted only when `isReliable`.

### 6.7 `PronunciationTrialLogger` protocol and concrete implementations

```swift
public protocol PronunciationTrialLogger: Sendable {
    func record(_ entry: PronunciationTrialLogEntry) async
}

public struct PronunciationTrialLogEntry: Sendable {
    public let timestamp: Date
    public let word: Word
    public let targetPhoneme: Phoneme
    public let engineA: PhonemeTrialAssessment?      // nil when A didn't run (supports=false)
    public let engineB: EngineBLogResult              // includes latency + timeout flag
}

public enum EngineBLogResult: Sendable {
    case completed(PhonemeTrialAssessment, latencyMs: Int)
    case timedOut(latencyMs: Int)
    case failed(reason: String, latencyMs: Int)
    case unsupported
}
```

Concrete implementations:

- `SwiftDataPronunciationTrialLogger` (MoraEngines) — wraps a `ModelContainer`, builds a `PronunciationTrialLog` row per entry, inserts on a `@ModelActor` background actor. Never awaited by the caller's UI path because the composite calls it from a detached task.
- `InMemoryPronunciationTrialLogger` (MoraTesting) — appends to an array exposed as `entries`. Used by `ShadowLoggingPronunciationEvaluatorTests` and orchestrator integration tests.

`SwiftDataPronunciationTrialLogger` is in `MoraEngines`, not `MoraCore`, because it consumes `PhonemeTrialAssessment` (a `MoraEngines` type). The `@Model` entity lives in `MoraCore` because SwiftData schema registration happens at that layer.

### 6.8 `ShadowLoggingPronunciationEvaluator` — composite decorator

```swift
public struct ShadowLoggingPronunciationEvaluator: PronunciationEvaluator {
    public let primary: any PronunciationEvaluator       // Engine A
    public let shadow: any PronunciationEvaluator        // Engine B
    public let logger: any PronunciationTrialLogger
    public let clock: any Clock<Duration>                // injectable for tests
    public let timeout: Duration                         // default .milliseconds(1000)

    public func supports(target: Phoneme, in word: Word) -> Bool {
        primary.supports(target: target, in: word) ||
            shadow.supports(target: target, in: word)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment
}
```

Flow:

1. Decide `primarySupport = primary.supports(target:, in:)`.
2. If `primarySupport`: `let a = await primary.evaluate(audio:, expected:, targetPhoneme:, asr:)`; else `a = nil`.
3. Enqueue a detached task:
   - `start = clock.now`
   - `let b = await withTimeout(timeout) { try? await shadow.evaluate(audio:, expected:, targetPhoneme:, asr:) }`
   - `elapsed = start.duration(to: clock.now)`
   - Build `EngineBLogResult`:
     - `b != nil && !shadow.supports(...)` — never happens because `supports` gates. Drop.
     - `b != nil` → `.completed(b!, latencyMs: Int(elapsed.ms))`
     - `b == nil && shadow.supports(...)` → `.timedOut(latencyMs: Int(elapsed.ms))` (timeout path)
     - `!shadow.supports(...)` → `.unsupported`
   - If `shadow.evaluate` threw (captured via `Result` in the `withTimeout` wrapper) → `.failed(reason: String(describing: error), latencyMs: Int(elapsed.ms))`.
   - Call `await logger.record(PronunciationTrialLogEntry(timestamp: Date(), word: expected, targetPhoneme: targetPhoneme, engineA: a, engineB: bResult))`.
4. Return `a` if non-nil, else a synthesized `.unclear` placeholder for `targetPhoneme` so `AssessmentEngine`'s existing null-safety code path is unaffected.

Unit-test coverage for §6.8 in `ShadowLoggingPronunciationEvaluatorTests`:

- Primary-supports + shadow-supports: logger sees both; UI sees A.
- Primary-unsupports + shadow-supports: logger sees B only; UI sees `.unclear` placeholder.
- Primary-supports + shadow times out: logger sees A + `.timedOut`.
- Primary-supports + shadow throws: logger sees A + `.failed`.
- Neither supports: logger not called (no row).

### 6.10 `withTimeout` helper

Both `PhonemeModelPronunciationEvaluator` (§6.6) and `ShadowLoggingPronunciationEvaluator` (§6.8) need to bound an async call to a deadline. Swift's stdlib does not provide a ready-made helper; the spec adds one in `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/Concurrency.swift`:

```swift
/// Runs `operation` under a timeout. Returns the operation's result if it
/// completes in time, or nil if the timeout elapses first. The operation's
/// task is cancelled on timeout.
public func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @Sendable @escaping () async throws -> T
) async -> T? {
    await withTaskGroup(of: Optional<T>.self) { group in
        group.addTask { try? await operation() }
        group.addTask {
            try? await Task.sleep(for: duration)
            return nil
        }
        defer { group.cancelAll() }
        return await group.next() ?? nil
    }
}
```

Tests in `ConcurrencyTests` verify: fast operation returns its value; slow operation returns nil; a throwing operation returns nil; cancellation propagates to the operation's task. The helper is `internal` to `MoraEngines` (not exported via `public`) because it is an implementation detail of the evaluators.

### 6.9 `PronunciationTrialLog` SwiftData entity and retention

```swift
@Model
public final class PronunciationTrialLog {
    public var timestamp: Date
    public var wordSurface: String
    public var targetPhonemeIPA: String

    public var engineALabel: String                     // JSON-encoded PhonemeAssessmentLabel
    public var engineAScore: Int?
    public var engineAFeaturesJSON: String              // JSON-encoded [String: Double]

    public var engineBState: String                     // "completed" | "timedOut" | "failed" | "unsupported"
    public var engineBLabel: String?                    // nil unless state = "completed"
    public var engineBScore: Int?
    public var engineBLatencyMs: Int?
    public var engineBFailureReason: String?

    public init(...)
}
```

Retention (`PronunciationTrialRetentionPolicy`):

```swift
public enum PronunciationTrialRetentionPolicy {
    public static let maxRows = 1_000

    @MainActor
    public static func cleanup(_ ctx: ModelContext) throws
}
```

`cleanup` fetches the count (`FetchDescriptor<PronunciationTrialLog>` with `fetchLimit = nil`, sort by `timestamp` ascending), and if `count > maxRows` deletes the oldest `count − maxRows` rows. Called once at app startup (`MoraApp.init`). O(1) when under the cap; O(excess) when over it, which is small.

Logger-side: `SwiftDataPronunciationTrialLogger.record` does not enforce the cap itself to avoid per-trial database traffic. The cap is a startup-sweep only. Worst case: within a single session a learner produces >1000 trials (very unlikely — a session is tens of trials). If that ever becomes relevant, move cleanup into the logger.

## 7. Data Flow — Single Trial in Shadow Mode

```
1. UI (DecodeActivityView / ShortSentencesView) starts tap-to-listen.
2. AppleSpeechEngine emits .final(TrialRecording) as before.
3. SessionOrchestrator.handle(.answerHeard(recording)) calls:
     await assessmentEngine.assess(expected: word, recording: recording, leniency: ...)
4. AssessmentEngine.assess(recording:):
     let phoneme = await evaluator.evaluate(
         audio: recording.audio,
         expected: word,
         targetPhoneme: word.targetPhoneme ?? word.phonemes.first!,
         asr: recording.asr
     )
     // evaluator here is ShadowLoggingPronunciationEvaluator
     return TrialAssessment(..., phoneme: phoneme)
5. Inside ShadowLoggingPronunciationEvaluator.evaluate:
   Foreground:
     - await primary.evaluate(...)   → returns Engine A's result (or .unclear placeholder)
     - return it (UI path resumes)
   Detached (priority: .background):
     - Start clock.
     - await withTimeout(1000ms) { try? await shadow.evaluate(...) }
     - Compose PronunciationTrialLogEntry with both results.
     - await logger.record(entry)
6. SwiftDataPronunciationTrialLogger on its ModelActor:
     - Build PronunciationTrialLog row.
     - Insert into ModelContext, save.
7. Next app launch:
     - PronunciationTrialRetentionPolicy.cleanup trims FIFO to 1000.
```

UI rendering is identical to Engine-A-only mode. The learner sees nothing different.

## 8. API Changes

### 8.1 `PronunciationEvaluator` — unchanged

The protocol defined in the Engine A plan stays as-is. `ShadowLoggingPronunciationEvaluator` and `PhonemeModelPronunciationEvaluator` conform to it. No change to `evaluate` signatures, `supports`, or the `PhonemeTrialAssessment` type.

### 8.2 `AssessmentEngine` — unchanged

`AssessmentEngine` already holds `let evaluator: any PronunciationEvaluator`. In shadow mode, `MoraApp` hands it a `ShadowLoggingPronunciationEvaluator`. The engine itself does not know which shape of evaluator it holds.

### 8.3 `MoraMLX` — new public API

```swift
public enum MoraMLXModelCatalog {
    public static func loadPhonemeEvaluator(
        timeout: Duration = .milliseconds(1000)
    ) throws -> PhonemeModelPronunciationEvaluator
}

public struct CoreMLPhonemePosteriorProvider: PhonemePosteriorProvider {
    public init(model: MLModel, inventory: PhonemeInventory)
    public func posterior(for audio: AudioClip) async throws -> PhonemePosterior
}
```

`loadPhonemeEvaluator` loads `wav2vec2-phoneme.mlmodelc` from `Bundle.module`, loads `phoneme-labels.json`, constructs the inventory, and returns a fully wired `PhonemeModelPronunciationEvaluator`. Cached across calls within a single process lifetime.

Deletes the placeholder `MoraMLX.version` string; replace with a `MoraMLXVersion` enum if any caller depends on it (currently none in the codebase — a grep confirms).

### 8.4 `MoraCore` — SwiftData schema

```swift
// MoraModelContainer.swift
public static let schema = Schema([
    LearnerEntity.self,
    SkillEntity.self,
    SessionSummaryEntity.self,
    PerformanceEntity.self,
    LearnerProfile.self,
    DailyStreak.self,
    PronunciationTrialLog.self,             // NEW
])
```

This is an additive schema change. SwiftData handles "new entity" with lightweight migration automatically. No manual migration code required.

### 8.5 `MoraApp` — injection

```swift
// Mora/MoraApp.swift
@main
struct MoraApp: App {
    private let modelContainer: ModelContainer
    private let evaluator: any PronunciationEvaluator
    // ...

    init() {
        self.modelContainer = (try? MoraModelContainer.onDisk())
            ?? (try! MoraModelContainer.inMemory())

        let engineA = FeatureBasedPronunciationEvaluator()
        if let engineB = try? MoraMLXModelCatalog.loadPhonemeEvaluator() {
            let logger = SwiftDataPronunciationTrialLogger(container: modelContainer)
            self.evaluator = ShadowLoggingPronunciationEvaluator(
                primary: engineA,
                shadow: engineB,
                logger: logger,
                clock: ContinuousClock(),
                timeout: .milliseconds(1000)
            )
        } else {
            os_log("MLX phoneme evaluator failed to load; running Engine A only", type: .error)
            self.evaluator = engineA
        }

        Task { @MainActor in
            try? PronunciationTrialRetentionPolicy.cleanup(modelContainer.mainContext)
        }
    }
    // ...
}
```

## 9. Error Handling

| Condition | Behavior |
|---|---|
| MLX model file missing from bundle at launch | `MoraMLXModelCatalog.loadPhonemeEvaluator()` throws; `MoraApp` installs bare Engine A; `os_log` records the failure; no shadow rows. |
| MLX model load succeeds but first inference throws | Provider's async call throws; `ShadowLoggingPronunciationEvaluator` logs `.failed(reason:)`. Subsequent trials continue to invoke the provider (the model is loaded). |
| Provider call times out (>1000 ms) | `withTimeout` returns nil; entry logged as `.timedOut(latencyMs: 1000)`. |
| Alignment `averageLogProb < reliabilityThreshold` | `evaluate` returns `.unclear` with `isReliable = false` and `score = nil`. Still logged. |
| Target phoneme not in `PhonemeInventory.supportedPhonemeIPA` | Evaluator returns without calling the provider: `supports` was false. Composite logs entry with `engineBState = "unsupported"`. |
| SwiftData save in logger throws | Caught in logger; `os_log` records; entry dropped. Next startup cleanup is unaffected. |
| Retention cleanup throws | Caught in `MoraApp.init`; `os_log` records. App still launches. |

## 10. Privacy and Cloud Isolation

This spec preserves every invariant from the parent spec §10:

- No raw audio, transcript, or per-trial detail leaves the device. `PronunciationTrialLog` rows are SwiftData-local, not CloudKit-synced, and not exported.
- No cloud pronunciation SDK enters the shipped binary. The source gate and binary gate landed in the Engine A plan continue to run against all of `Mora` + `Packages`.
- `dev-tools/model-conversion/` does not ship with the app. Its Python dependencies (Hugging Face `transformers`, `coremltools`) are not listed in any `Package.swift`. The binary gate excludes `dev-tools/` by construction (it matches `-- Mora Packages`, which does not include `dev-tools/`).
- `phoneme-labels.json` carries only the espeak IPA label list — no PII.

The model file itself is derived from `facebook/wav2vec2-xlsr-53-espeak-cv-ft`, which is MIT-licensed and redistribution-compatible with PolyForm Noncommercial 1.0.0. The HF model card URL and SHA are recorded in `dev-tools/model-conversion/README.md`.

## 11. Testing Strategy

### 11.1 Unit — value types

- `PhonemePosteriorTests`: Codable round-trip; `frameIndex(forSecond:)` boundaries; empty posterior.

### 11.2 Unit — alignment

`ForcedAlignerTests`: synthetic posteriors with known phoneme-column masses.

- Single phoneme, uniform column distribution → whole-range alignment.
- Two phonemes, posterior spikes at frames [0, 5] for p1 and [5, 10] for p2 → Viterbi recovers the correct boundary.
- Phoneme not in inventory → positional fallback returned; `averageLogProb = −log(N)` ± epsilon.
- `frameCount < phonemes.count` → each phoneme gets ≥1 frame; `averageLogProb = −.infinity`.

### 11.3 Unit — GOP

`GOPScorerTests`: 

- GOP = 0 exactly when target column dominates entire range → `score0to100 ≥ 99`.
- GOP = −3.0 (far below `gopZero = -1.5`) → `score0to100 ≤ 10`.
- Sigmoid monotonicity: GOP −2.0 → −1.5 → −1.0 produces strictly increasing scores.
- `gop(...)` on an empty range returns `-.infinity` (guarded by caller).

### 11.4 Unit — evaluator

`PhonemeModelPronunciationEvaluatorTests` with `FakePhonemePosteriorProvider`:

- Matched path: posterior spikes on target column → `.matched`, `score ≥ 80`.
- Substitution path: posterior spikes on a known substitute (`/s/` when target is `/ʃ/`) → `.substitutedBy(/s/)`, `score ≤ 30`, `coachingKey == "coaching.sh_sub_s"`.
- Unclear path: uniform posterior → `.unclear`, `score == nil`, `isReliable == false`.
- Timeout path: fake provider blocks; evaluator called with `timeout: .milliseconds(10)` returns `.unclear` promptly.
- Unsupported phoneme: `supports(target:)` returns false; `evaluate` not called by the engine in practice, but a defensive test asserts `evaluate` on an unsupported target still returns `.unclear`.

### 11.5 Unit — composite

`ShadowLoggingPronunciationEvaluatorTests` with fake A + fake B + `InMemoryPronunciationTrialLogger`:

- Both supported: logger sees one entry with both fields populated; UI sees A.
- A unsupported, B supported: logger sees entry with `engineA == nil`, `engineB = .completed(...)`; composite returns `.unclear` placeholder.
- B times out (fake B awaits indefinitely): logger entry has `engineBState = "timedOut"`, `engineBLatencyMs ≈ timeout`.
- B throws: logger entry has `engineBState = "failed"`, reason captured.
- Neither supports: logger not called.
- Clock injection: tests use a `ControlledClock` to assert deterministic latencies without wall-clock flakiness.

### 11.6 Unit — SwiftData entity + retention

- `PronunciationTrialLogTests`: insert one row; fetch; assert all fields round-trip including optional ones. JSON-encoded fields decoded back into their Codable types match.
- `PronunciationTrialRetentionPolicyTests`: insert 1001 rows; call `cleanup`; assert exactly 1000 remain, oldest removed by `timestamp` ordering. Re-run on 1000 rows; assert no change.

### 11.7 Integration — orchestrator end-to-end

`SessionOrchestratorShadowLoggingTests` (MainActor):

- Orchestrator configured with `AssessmentEngine` that holds `ShadowLoggingPronunciationEvaluator`.
- Feed a scripted `TrialRecording`; assert `TrialAssessment.phoneme` matches A's scripted result, and assert `InMemoryPronunciationTrialLogger.entries.count == 1` with both fields populated.

### 11.8 Smoke — real CoreML model (Part 2 only)

`CoreMLPhonemePosteriorProviderSmokeTests` (MoraMLX):

- Load `wav2vec2-phoneme.mlmodelc` from `Bundle.module`.
- Call `posterior(for:)` on a committed ~1-second synthetic 16 kHz `AudioClip` fixture (`Fixtures/short-ʃ-clip.wav`, <20 KB).
- Assert `frameCount > 0`, `phonemeCount > 30`, `logProbabilities[0].max() > -5.0` (sanity: the model produced non-degenerate output).
- Does not assert a specific phoneme label; this is a shape sanity check, not an accuracy test.

Skipped gracefully (test passes with a warning) when the `.mlmodelc` is absent, so developers who have not fetched LFS can still run `swift test` locally. CI always fetches LFS, so CI always runs this.

### 11.9 Device-only latency benchmark (not in CI)

`Mora/Benchmarks/Phase3LatencyBenchmark.swift` (iOS-only, manual):

- 10-second warmup + 20 inference passes on a 2-second fixture clip.
- Reports p50 / p95 latency in milliseconds to console.
- Not run in CI; invoked manually by Yutaka on iPad Air M2 to confirm the <1000 ms budget.

### 11.10 Lint and format

`swift-format lint --strict` passes on all new files. No exceptions.

## 12. Phasing

### Part 1 — Evaluator logic, SwiftData, composite, all fake-driven (~19 tasks)

Goal: Engine B's evaluator code, the composite, the SwiftData entity, and the logger all compile, pass tests, and are exercised through fakes. Shipped app behavior is unchanged because `MoraMLXModelCatalog.loadPhonemeEvaluator` is a stub that always throws and `MoraApp` falls back to bare Engine A.

Work items:

1. `PhonemePosterior` value type + tests.
2. `PhonemePosteriorProvider` protocol + `FakePhonemePosteriorProvider` in MoraTesting.
3. `PhonemeInventory` struct with `v15SupportedPhonemeIPA` static set. Tests construct inventories ad-hoc with hand-written espeak label lists. The JSON-driven construction at MoraMLX boot is deferred to Part 2 (no JSON is bundled in Part 1).
4. `ForcedAligner` + tests.
5. `GOPScorer` + tests.
6. Refactor Engine A's inline coaching-key lookup into `CoachingKeyResolver`; update Engine A tests.
7. `withTimeout` helper in `Concurrency.swift` + `ConcurrencyTests`.
8. `PhonemeModelPronunciationEvaluator` + tests (fake provider).
9. `PronunciationTrialLog` SwiftData entity, schema registration, round-trip test.
10. `PronunciationTrialRetentionPolicy` + tests.
11. `PronunciationTrialLogger` protocol + `PronunciationTrialLogEntry` value types.
12. `SwiftDataPronunciationTrialLogger` in MoraEngines.
13. `InMemoryPronunciationTrialLogger` in MoraTesting.
14. `ShadowLoggingPronunciationEvaluator` + tests.
15. `SessionOrchestratorShadowLoggingTests` integration.
16. `MoraMLXModelCatalog.loadPhonemeEvaluator` stub added in MoraMLX — the function signature and throwing behavior are final, but the body always throws `MoraMLXError.modelNotBundled`. `MoraMLXPlaceholder.swift` stays in place until Part 2 deletes it. `Package.swift` gains the MoraCore + MoraEngines dependencies required for the stub's signature. No CoreML dependency, no Resources directory, no model bytes in Part 1.
17. `MoraApp` wiring: attempts to load Engine B via the stub, catches the throw, falls back to bare Engine A. Also calls `PronunciationTrialRetentionPolicy.cleanup` once at startup. The call-site pattern is final; only the stub's body changes in Part 2.
18. Swift-format + all package test suites green.
19. Docs: Part 1 PR description enumerates landed files and references this spec.

At the end of Part 1, no user-visible change. All 189+ tests still green; ~40 new tests added.

### Part 2 — Real model, MoraMLX wiring, CI LFS, smoke test (~10 tasks)

Goal: Engine B goes live on device. Shadow rows accumulate.

Work items:

1. `dev-tools/model-conversion/` — `convert.py`, `requirements.txt`, `README.md`, `.env.example`, `.gitignore`. Run locally; commit artifacts via LFS.
2. `.gitattributes` — LFS patterns for `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/**` and `wav2vec2-phoneme.mlpackage/**`.
3. Commit `phoneme-labels.json` (plain git) and `wav2vec2-phoneme.mlmodelc/` (LFS).
4. `Packages/MoraMLX/Package.swift` — add MoraCore + MoraEngines dependencies, add `.process("Resources")`, add test target.
5. Delete `MoraMLXPlaceholder.swift`. Introduce `MoraMLXModelCatalog.swift`.
6. `CoreMLPhonemePosteriorProvider.swift` — real provider. 16 kHz Float32 input → `MLMultiArray` → `prediction` → posterior decoding.
7. `MoraMLXModelCatalog` reads `phoneme-labels.json` at load time and constructs `PhonemeInventory(espeakLabels: loaded, supportedPhonemeIPA: .v15SupportedPhonemeIPA)` (derived `ipaToColumn` fills in automatically).
8. Update `MoraApp` so `MoraMLXModelCatalog.loadPhonemeEvaluator()` actually returns a working evaluator (no longer throws by default).
9. `CoreMLPhonemePosteriorProviderSmokeTests` + fixture clip.
10. CI: `actions/checkout` `with: lfs: true`; verify source gate still passes; verify binary gate path filters exclude `Resources/`.
11. Docs: Part 2 PR description; cross-link spec ↔ plan line in the parent spec.

At the end of Part 2, the `.mlmodelc` ships in the bundle, shadow mode is live on device, `PronunciationTrialLog` rows accumulate in SwiftData, Engine A still drives the UI unchanged.

## 13. Data Model

### 13.1 `PronunciationTrialLog` (SwiftData)

Defined in §6.9. Schema: 11 fields. All optional fields are explicitly nullable in SwiftData.

### 13.2 `Word` — unchanged

Engine A already added `Word.targetPhoneme`. No further change.

### 13.3 Codable JSON strings in the log

Three fields store JSON strings because SwiftData is best at simple scalars:

- `engineALabel`: `PhonemeAssessmentLabel` (enum with an associated `Phoneme`) via `JSONEncoder`.
- `engineBLabel`: same type, optional.
- `engineAFeaturesJSON`: `[String: Double]` via `JSONEncoder`.

Decoding is on-demand. `PronunciationTrialLog` exposes computed properties (`decodedEngineALabel: PhonemeAssessmentLabel?`, etc.) that eagerly decode + cache. No migration is required when the underlying type evolves as long as the JSON is backwards-decodable.

## 14. Open Questions

1. **CoreML model size on M-series iPads vs A-series.** INT8 quantization yields ~150 MB; the conversion may ship larger or smaller depending on coremltools version and `mlprogram` vs `neuralnetwork` target. Validated at convert-time and recorded in the PR description. If the final size exceeds ~200 MB, revisit on-demand resource strategy per parent spec §14 Q5.
2. **Inventory coverage.** The v1.5 MVP inventory is ~36 phonemes. Post-v1.5, expansion is a data-only change; the split between "in MVP" and "outside MVP" is reviewed after the first month of shadow-log data shows which phonemes the curriculum actually exercises.
3. **Clock and timeout test determinism.** `ContinuousClock` is injected into `ShadowLoggingPronunciationEvaluator`. A `ControlledClock` is added to `MoraTesting` for tests. Verify that `withTimeout(_:operation:)` accepts the injected clock; if not, use `Task.sleep(for:)` patterns that honor it.
4. **GOP sigmoid review cadence.** Defaults ship; calibration happens in `pronunciation-bench/`'s separate session. Parent spec §6.3's promotion gate (Spearman ρ ≥ 0.80 vs SpeechAce, Cohen's κ ≥ 0.70 vs Engine A) is the promotion trigger, not the sigmoid-tuning trigger. Sigmoid tuning happens any time between them.
5. **Shadow log privacy walk-back.** If at any point in v1.5's lifetime Yutaka decides per-trial detail is too sensitive to persist even locally, the entity is removed in a single migration and the composite becomes a pass-through of A. Keep the logger implementation small enough that this remains a tractable one-PR change.
6. **`ForcedAligner` without frame-level timing from wav2vec2.** The model emits 50 Hz posteriors; Apple Speech's word-level timing is not used by Engine B (spec §6.3 says forced alignment replaces it). If a future correlation study shows alignment errors dominate GOP noise, reintroducing Apple Speech's coarse word timing as a Viterbi prior is a post-v1.5 tuning step.
7. **`.env.example` vs secret management.** `dev-tools/model-conversion/.env.example` lists `HF_TOKEN=`. The real `.env` is `.gitignore`d. Pre-commit hook or local guard not added in this spec; flagged as a future improvement.

---

## Appendix A — Why not download the model on first launch

Parent spec §14 Q5 raises on-demand resource download as a possible alternative for the ~150 MB model. The downsides for v1.5:

- First-launch experience becomes "tap Start → wait for 150 MB over Wi-Fi" for the target learner, who is 8 years old and has limited patience for progress bars.
- The app's offline-first posture is broken at first launch (cellular, airplane mode, school Wi-Fi with a captive portal all block download).
- An additional failure mode (download interrupted, corrupted, invalid) adds states to the `MoraApp` state machine.

Bundling the model is worse on App Store size but better on first-launch experience. v1.5 chooses bundling.

v2's LLM weights (Qwen ~2.3 GB) can't be bundled, so on-demand download is unavoidable there. That work (separate, future) sets up the `ModelCatalog` pattern that v1.5's Engine B does not need.

## Appendix B — Why Part 1 touches MoraMLX only with a stub

Part 1 lands `ShadowLoggingPronunciationEvaluator` and related code along with a **stub** `MoraMLXModelCatalog.loadPhonemeEvaluator` that always throws `MoraMLXError.modelNotBundled`. `MoraApp` catches the throw and falls back to bare Engine A; the shipped behavior is unchanged.

The stub is thin on purpose: its signature is final, and Part 2 only has to replace the body. This lets the `MoraApp` call-site pattern (`if let engineB = try? catalog.load() { … composite … } else { … engineA … }`) be exercised by tests in Part 1 even before the real model lands.

Part 2 cannot start until the `.mlmodelc` file exists (generated by `dev-tools/model-conversion/convert.py`). That generation is independent of the parallel `dev-tools/pronunciation-bench/` session's timeline, but it is still a separate step from Part 1's code work. Keeping Part 1 free of the Resources directory, CoreML dependency, and model bytes means Part 1 can merge any time after all tests pass, independent of when the model is generated.

## Appendix C — Why `SwiftDataPronunciationTrialLogger` is in MoraEngines, not MoraCore

The logger consumes `PhonemeTrialAssessment` (a MoraEngines type) and `Word` (a MoraCore type). Putting the logger in MoraCore would force MoraCore to depend on MoraEngines, inverting the dependency graph. Putting the entity (`PronunciationTrialLog`) in MoraCore keeps the schema-registration layer in the right place. The two are connected by JSON serialization at the logger boundary: MoraEngines types are encoded to strings in the logger, and the entity stores strings. This is an acceptable dataflow cost for preserving the layering.
