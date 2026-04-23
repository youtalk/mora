# mora — Pronunciation Bench & Child-Speaker Calibration Design Spec

- **Date:** 2026-04-22
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Release target:** v1.5 precursor; lands before Phase 3 (Engine B) so Engine A can be calibrated against the learner's actual voice and against SpeechAce as an oracle
- **Extends:** `2026-04-22-pronunciation-feedback-design.md` §4.1 (dev-tools carve-out), §10.2 (`dev-tools/pronunciation-bench/` structure), §11.2 (recorded fixtures), §11.7 (dev benchmark), §14.6 (child-speaker acoustic shift)
- **Relates to:** `2026-04-22-pronunciation-feedback-engine-a.md` (Part 1 plan — Engine A infrastructure + primary evaluator). This spec is **Part 2** of the pronunciation-feedback roadmap and intentionally stays orthogonal to Phase 3 (Engine B, wav2vec2-phoneme CoreML shadow mode), which starts in parallel on a separate worktree.

---

## 1. Overview

Part 1 shipped Engine A as the v1.5 primary evaluator: `FeatureBasedPronunciationEvaluator` with literature-derived thresholds in `PhonemeThresholds`, wired end to end from `AppleSpeechEngine` through the orchestrator to a `PronunciationFeedbackOverlay` in the UI. What it does not yet have is empirical validation. The thresholds are taken from adult-speaker acoustic phonetics (Kent & Read, Ladefoged, Fujimura) and the only regression coverage against those thresholds comes from synthetic PCM. For several pairs — `/r/` vs `/l/`, `/v/` vs `/b/`, `/æ/` vs `/ʌ/` — Part 1 explicitly skipped the behavioral tests with a `// TODO(post-alpha): needs recorded fixture` marker because synthetic audio cannot express the joint-formant and temporal-feature structure those pairs rely on.

Part 2 closes that gap by standing up the calibration loop the parent spec already sketches:

1. A **DEBUG-build-only in-app fixture recorder** that lets Yutaka capture labeled WAV + sidecar JSON from an iPad, export them via Files.app, and feed them into the bench.
2. A new repo-root Swift Package **`dev-tools/pronunciation-bench/`** that links Engine A by `path:` reference, calls the SpeechAce HTTP API for each fixture, and produces a CSV of (fixture, Engine A output, SpeechAce score) for manual review.
3. **Recorded WAV fixtures** (Yutaka, adult proxy) checked into `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/`, replacing the three TODO'd synthetic test stubs with real-audio behavioral tests.
4. A **child-speaker calibration pass** that runs the son's recordings through the bench, quantifies the roughly-10 % formant shift predicted in the parent spec §14.6, and updates `PhonemeThresholds.swift` numerically once.

The shipped application binary gains nothing at runtime beyond an updated numeric table in `PhonemeThresholds`. The debug recorder lives entirely behind `#if DEBUG` and the bench is isolated at the repo root. The on-device invariant from `2026-04-21-mora-dyslexia-esl-design.md` §3 is preserved on every shipped build (Debug and Release).

## 2. Motivation

Engine A promises honest per-phoneme scoring based on measured acoustic features, not on fabricated output. That promise only holds if the thresholds it compares against are appropriate for the learner in front of us. The parent spec already flags two concrete risks:

- **Child speech sits higher in frequency.** Shorter vocal tract raises F1, F2, F3 by roughly 10 %. Running adult-literature numbers against an 8-year-old's voice will systematically misjudge formant-driven pairs (`r/l`, `æ/ʌ`, `/ʃ/` drift).
- **Synthetic audio cannot cover every pair.** Temporal features (voicing-onset time for `v/b`) and joint formants (`æ` vs `ʌ` F1+F2) need real speech to be stress-tested.

The bench exists to answer one question per phoneme pair: does Engine A's label (and score, when `isReliable`) agree with SpeechAce and with what Yutaka's ear tells him? When answers diverge, Yutaka either records more fixtures, adjusts a threshold, or files a bug against a feature extractor. The CSV is the artifact that drives those decisions.

## 3. Goals and Non-Goals

### Goals

- Capture labeled fixture audio on an iPad with one SwiftUI screen, using only the iPad's microphone — no laptop handoff during capture.
- Ship a repo-root bench harness that Yutaka runs locally with `swift run bench <fixtures-dir>` and that produces a per-fixture CSV containing Engine A's output and a SpeechAce reference score.
- Replace the three TODO'd synthetic tests in `FeatureBasedEvaluatorTests` with fixture-based behavioral tests covering `r/l`, `v/b`, `æ/ʌ`.
- Perform one calibration pass: record the son's voice for the supported phoneme set, run the bench, update `PhonemeThresholds` numerically if and only if the data warrants it.
- Preserve the on-device invariant. No cloud symbols in the shipped binary, no cloud calls from any shipped package.
- Do not touch any file Phase 3 (Engine B) is known to modify. Part 2 and Phase 3 merge cleanly in either order.

### Non-Goals

- Session-capture mode (automatically saving every trial during normal A-day play). Deferred: if Phase 3's `PronunciationTrialLog` gains an audio-blob field later, it will cover this path more cleanly than Part 2 could.
- Automated threshold suggestions, Swift-source patches, or anything that mutates shipped code without a human reviewer. The bench emits data only.
- Per-speaker adaptive thresholds (the parent spec §14.2 follow-up). Part 2 performs a single calibration pass that updates the single shared `PhonemeThresholds` table; per-speaker profiles remain a post-v1.5 topic.
- A new `PhonemeAcousticTarget` type replacing the `from == to` drift sentinel (parent spec §14.3). Still deferred to Engine B design work.
- Continuous-integration coverage for `dev-tools/`. The bench's own test target runs on Yutaka's laptop only.
- `PronunciationTrialLog` SwiftData entity or any MoraMLX activation. Both belong to Phase 3.

## 4. Design Decisions

### 4.1 DEBUG-only in-app recorder, exported via Files.app

The parent spec §10.2 says capture can happen either through "a debug-only recording UI (to be spec'd separately) or… QuickTime/Xcode during TestFlight sessions." Part 2 picks the first path because:

- The iPad already has the microphone permission the learner session uses. No reconfiguration overhead.
- Labeling happens at capture time (target phoneme + expected label + word), which prevents the common failure mode of accumulating unlabeled WAVs whose context is forgotten a week later.
- Release builds cannot reach the recorder because the entire feature is wrapped in `#if DEBUG`. The CI binary gate already rejects cloud symbols; the recorder adds none.

Export uses the system Files.app. The recorder writes to `FileManager.default.urls(for: .documentDirectory)[0]`, which surfaces to Files.app under "On My iPad → Mora". Yutaka selects files and AirDrops them to his Mac.

### 4.2 Repo-root Swift Package, not an SPM subdirectory

`dev-tools/pronunciation-bench/` has its own `Package.swift` at the repo root. It is not listed in `project.yml`, not declared as a dependency of any shipped `Package.swift`, and not built by any CI job. It `path:`-references `Packages/MoraEngines` and `Packages/MoraCore` to re-use Engine A's feature extraction without forking.

This structural choice is inherited from the parent spec §4.1 and §10.2 and is what lets the bench hold a SpeechAce client without violating the on-device invariant. The existing CI source gate (`git grep -nIE 'speechace|…' -- Mora Packages`) scopes the grep to shipped paths; `dev-tools/` is outside that scope by construction.

### 4.3 CSV-only output, manual threshold updates

Part 2 does not generate suggested threshold values, Swift patches, or config files that mutate shipped code. The bench writes one CSV row per fixture; Yutaka reads the CSV and decides. The rationale is small and deliberate:

- Engine A's thresholds ship as literature values with a documented ±15 % drift budget. Moving a number outside that budget should involve human judgement, not an averaging script.
- The data set is small (tens of fixtures per pair). Heuristics that fit a small set are easy to over-index on.
- Shipped changes flow through a normal PR review, which gives the threshold change an audit trail and a human sanity check.

Automation can be added later once the first calibration pass has revealed whether the bottleneck is "Yutaka doesn't have enough time to eyeball rows" or "Yutaka doesn't have enough data."

### 4.4 Part 2 stays out of Phase 3's file set

Phase 3 lives in its own worktree and will modify `AssessmentEngine.swift`, `SessionOrchestrator.swift`, `AppleSpeechEngine.swift`, `SpeechEvent.swift`, `PronunciationEvaluator.swift` (the protocol), the `Packages/MoraMLX/` tree, and `Packages/MoraCore/Sources/MoraCore/Persistence/`. Part 2 treats those as read-only. The only overlap surface that cannot be avoided:

- `Packages/MoraEngines/Package.swift` — Part 2 adds `resources: [.copy("Fixtures")]` to the `MoraEnginesTests` target. Phase 3 changes (if any) would target MoraMLX or the main MoraEngines library target, not MoraEnginesTests.
- `.gitignore` — both branches add a `dev-tools/<subdir>/` line (Phase 3 for `model-conversion/`, Part 2 for `pronunciation-bench/.env`). Trivially resolvable in a 3-way merge.

No other shared files. Merge order between Part 2 and Phase 3 is irrelevant.

### 4.5 Session-capture is out of scope

The learner's son will generate useful calibration data during normal A-day sessions, and it is tempting to auto-save every trial's audio. Part 2 explicitly does not do this because implementing it would require touching `AppleSpeechEngine` (to expose the captured PCM to a sink) or `SessionOrchestrator` (to intercept `SpeechEvent.final`). Both files are Phase 3 territory. Capturing the son's voice happens by having Yutaka sit next to him and drive the DEBUG recorder manually between utterances. The throughput cost is acceptable for one learner; the structural cost of touching Phase 3's files is not.

A cleaner design becomes possible once Phase 3's `PronunciationTrialLog` exists: that entity can grow an optional `audioBytes: Data?` field under a DEBUG-only code path, eliminating the need for a parallel capture pipeline. That is a post-Phase-3 discussion, not a Part 2 concern.

### 4.6 Adult proxy fixtures ship; child fixtures stay local

Initial WAV fixtures checked into `Packages/MoraEngines/Tests/.../Fixtures/` are recorded by Yutaka (adult, known pronunciations). These are small (<100 KB each, short, mono, 16 kHz) and their purpose is behavioral regression — making sure Engine A labels `/r/` as `/r/` when it is `/r/` and as `/l/` when it is `/l/`. The son's recordings used for threshold calibration stay on Yutaka's laptop and are not committed. This preserves the privacy posture of the project while letting the repo carry enough fixtures to catch Engine A regressions in CI.

## 5. Architecture

```
Packages/MoraUI/Sources/MoraUI/Debug/                  [NEW — #if DEBUG]
  ├── DebugEntryPoint.swift                            ViewModifier: 5-tap gesture on HomeView header
  └── PronunciationRecorderView.swift                  SwiftUI fixture-capture screen

Packages/MoraEngines/Sources/MoraEngines/Debug/        [NEW — #if DEBUG]
  ├── FixtureMetadata.swift                            Codable metadata struct
  ├── FixtureRecorder.swift                            AVAudioEngine tap + 16 kHz downsample
  └── FixtureWriter.swift                              WAV (16-bit PCM) + sidecar JSON writer

Packages/MoraEngines/Tests/MoraEnginesTests/
  ├── Fixtures/                                        [NEW — real WAVs, <100KB each]
  │     rl/   right-correct.wav, right-as-light.wav, light-correct.wav, light-as-right.wav
  │     vb/   very-correct.wav, very-as-berry.wav, berry-correct.wav, berry-as-very.wav
  │     aeuh/ cat-correct.wav, cat-as-cut.wav, cut-correct.wav, cut-as-cat.wav
  ├── Debug/FixtureWriterTests.swift                   [NEW — #if DEBUG]
  └── FeatureBasedEvaluatorFixtureTests.swift          [NEW — replaces TODO'd synthetic stubs]

Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeThresholds.swift
                                                       [MODIFIED once, at end of Phase D]

Packages/MoraEngines/Package.swift
                                                       [MODIFIED — resources: [.copy("Fixtures")]]

dev-tools/pronunciation-bench/                         [NEW — repo-root Swift Package]
  ├── Package.swift                                    path: MoraEngines + MoraCore,
  │                                                    apple/swift-argument-parser
  ├── .env.example                                     SPEECHACE_API_KEY=
  ├── .gitignore                                       .env, .build/
  ├── README.md                                        Usage: swift run bench <dir>
  ├── Sources/Bench/
  │     main.swift                                     BenchCLI with ArgumentParser
  │     FixtureLoader.swift                            Enumerate *.wav + *.json pairs
  │     EngineARunner.swift                            Wrap FeatureBasedPronunciationEvaluator
  │     SpeechAceClient.swift                          URLSession multipart POST
  │     CSVWriter.swift                                RFC 4180 escaping, 13 fixed columns
  └── Tests/BenchTests/                                Local-only, not in CI

.gitignore                                             [MODIFIED — +/dev-tools/pronunciation-bench/.env]
```

**Dependency direction** (preserved): `Core ← Engines ← UI`, with `dev-tools/pronunciation-bench/` depending on Engines + Core but not depended on in return.

## 6. Components

### 6.1 `FixtureMetadata`

New file: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift`. Gated on `#if DEBUG`.

```swift
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel     // matched | substitutedBy | driftedWithin
    public let substitutePhonemeIPA: String?    // non-nil only when expectedLabel == substitutedBy
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag           // adult | child
}

public enum ExpectedLabel: String, Codable, Sendable { case matched, substitutedBy, driftedWithin }
public enum SpeakerTag: String, Codable, Sendable { case adult, child }
```

The expected-label vocabulary deliberately mirrors `PhonemeAssessmentLabel` but is its own type: the fixture author labels what they *intended to produce*, not what Engine A *said*. The bench writes both into the CSV so discrepancies are visible.

### 6.2 `FixtureRecorder`

New file: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift`. Gated on `#if DEBUG`.

- Owns an `AVAudioEngine`. Installs a tap on the input node at the hardware-native format.
- Uses `AVAudioConverter` to downmix (if stereo) and resample to 16 kHz mono Float32 before accumulation.
- Exposes `start()`, `stop()`, `drain() -> (samples: [Float], sampleRate: Double)`.
- Does not share an engine or tap with `AppleSpeechEngine`; the two never run simultaneously because the Debug recorder is not reachable from the main session flow.

### 6.3 `FixtureWriter`

New file: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureWriter.swift`. Gated on `#if DEBUG`.

- Synchronously serializes a Float32 `[Float]` + `FixtureMetadata` to a 16-bit PCM WAV file plus a JSON sidecar (same basename, `.json` extension).
- Filename pattern: `YYYYMMDD-HHMMSS-<phonemeSlug>-<labelSlug>[-<substituteSlug>].wav` where slugs are IPA mapped through a small table (`ʃ` → `sh`, `θ` → `th`, etc.) to keep filenames ASCII-friendly.
- Target directory is the app Documents directory, reachable from Files.app.
- WAV writer is pure-Swift (no `AVAssetWriter`) so it is fully unit-testable.

### 6.4 `PronunciationRecorderView` and `DebugEntryPoint`

New files: `Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift`, `Packages/MoraUI/Sources/MoraUI/Debug/DebugEntryPoint.swift`. Both gated on `#if DEBUG`.

- `PronunciationRecorderView` is a SwiftUI form: target-phoneme picker (enumerating the Engine A supported set), expected-label picker with conditional substitute-phoneme picker, word `TextField`, speaker toggle (adult/child), `Record`/`Stop`/`Save` buttons, most-recent-capture row with delete.
- `DebugEntryPoint` is a `ViewModifier` attached to `HomeView`'s top header anchor (`Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`) with a 5-tap `TapGesture`. Five taps within 3 seconds flip a `@State` flag that reveals a `NavigationLink` to `PronunciationRecorderView`. The recorder lives in `MoraUI` rather than the `Mora/` app target so the hook attaches inside `HomeView` (which lives in MoraUI) without touching `Mora/MoraApp.swift`, which is reserved for Phase 3.
- No strings go through `MoraStrings`; all copy is hard-coded English in the Debug file. This avoids contaminating the shipped localization catalog with debug-only keys.

### 6.5 dev-tools/pronunciation-bench

New Swift Package at `dev-tools/pronunciation-bench/`.

```swift
// Package.swift
let package = Package(
    name: "pronunciation-bench",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "bench", targets: ["Bench"]),
    ],
    dependencies: [
        .package(path: "../../Packages/MoraEngines"),
        .package(path: "../../Packages/MoraCore"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "Bench",
            dependencies: [
                .product(name: "MoraEngines", package: "MoraEngines"),
                .product(name: "MoraCore", package: "MoraCore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "BenchTests", dependencies: ["Bench"]),
    ]
)
```

Subcomponents:

- **`BenchCLI`** (`main.swift`) — ArgumentParser-based entry point. Usage: `swift run bench <fixtures-dir> [--output <csv>] [--no-speechace]`. Fail-fast on missing `SPEECHACE_API_KEY` when SpeechAce is enabled.
- **`FixtureLoader`** — enumerates the fixtures directory, pairs `*.wav` with same-basename `*.json`, emits `LoadedFixture { audioURL, metadata, samples, sampleRate }`. Decodes WAV via `AudioToolbox`/`AVAudioFile` and resamples to 16 kHz mono if needed.
- **`EngineARunner`** — constructs an `AudioClip` and synthesizes a `Word` whose `targetPhoneme` matches the metadata. Calls `FeatureBasedPronunciationEvaluator().evaluate(audio:expected:targetPhoneme:asr:)` with an empty `ASRResult` (bench-time confidence is already in the metadata).
- **`SpeechAceClient`** — `URLSession` multipart POST to the SpeechAce scoring endpoint. Parses the JSON response for `overall_score`. On network / HTTP / decoding error: returns `nil`, surfaces a warning, does not retry.
- **`CSVWriter`** — writes a 13-column row per fixture (see §7). RFC-4180 quoting for cells that contain commas, quotes, or newlines.

### 6.6 Recorded WAV fixture set (initial, adult proxy)

Checked into `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/`:

| Subdir | Fixtures | Purpose |
|---|---|---|
| `rl/` | `right-correct.wav`, `right-as-light.wav`, `light-correct.wav`, `light-as-right.wav` | /r/ vs /l/ (F3-driven) |
| `vb/` | `very-correct.wav`, `very-as-berry.wav`, `berry-correct.wav`, `berry-as-very.wav` | /v/ vs /b/ (voicing-onset time) |
| `aeuh/` | `cat-correct.wav`, `cat-as-cut.wav`, `cut-correct.wav`, `cut-as-cat.wav` | /æ/ vs /ʌ/ (F1+F2 joint) |

Each fixture is mono, 16 kHz, 16-bit PCM, under 100 KB. Sidecar JSON files are **not** checked in; fixtures use a hard-coded mapping from filename to expected label inside `FeatureBasedEvaluatorFixtureTests.swift`, and the bench re-derives metadata from sidecar JSON only for fixtures Yutaka records locally.

## 7. Data Flow

### 7.1 Fixture capture (iPad, DEBUG build)

```
1. Yutaka opens Mora on an iPad to HomeView.
2. Taps the HomeView header anchor five times within 3 s → the
   `DebugEntryPoint` modifier reveals a "Fixture Recorder" NavigationLink
   underneath it.
3. Selects target phoneme (e.g. /r/), expected label (e.g. .substitutedBy(/l/)),
   word ("right"), speaker (adult/child).
4. Taps Record → FixtureRecorder starts the AVAudioEngine, tap callback
   accumulates 16 kHz mono Float32 samples.
5. Taps Stop → recorder removes the tap, freezes the buffer.
6. Taps Save → FixtureWriter writes <timestamp>-r-substitutedBy-l.wav and
   <timestamp>-r-substitutedBy-l.json into app Documents.
7. Files.app → "On My iPad → Mora" → AirDrop (or iCloud Drive) to Mac.
```

### 7.2 Bench run (Mac)

```
1. cd dev-tools/pronunciation-bench && swift run bench ~/fixtures/ out.csv
2. CLI reads SPEECHACE_API_KEY from `ProcessInfo.processInfo.environment`
   (unless --no-speechace). A shell-sourced / exported `.env` is the
   intended delivery mechanism — the CLI does not parse `.env` files
   itself. The `.env.example` template ships alongside the package; users
   copy it to `.env` and `source .env` (or export the variable in their
   shell profile) before `swift run bench`.
3. FixtureLoader enumerates (*.wav, *.json) pairs.
4. For each pair, sequentially (the v1 CLI processes one fixture at a
   time; ordering is deterministic, SpeechAce rate-limit pressure stays
   trivial, and the bench never outruns the user reviewing the CSV):
   a. Load WAV → [Float] @ 16 kHz mono
   b. Build AudioClip, synthesize Word { surface, targetPhoneme } from metadata
   c. If SpeechAce enabled: SpeechAceClient.score(audio, text: wordSurface) → Double?
   d. EngineARunner.evaluate(audio, word, targetPhoneme) → PhonemeTrialAssessment
5. CSVWriter appends one row per fixture to out.csv.
6. Yutaka opens out.csv in Numbers/pandas, reviews, updates PhonemeThresholds.swift
   in a separate PR if the data warrants it.
```

### 7.3 CSV schema

| Column | Source |
|---|---|
| `fixture` | WAV filename relative to fixtures dir |
| `captured_at` | `FixtureMetadata.capturedAt` (ISO 8601) |
| `target_phoneme` | `FixtureMetadata.targetPhonemeIPA` |
| `expected_label` | `FixtureMetadata.expectedLabel.rawValue` |
| `substitute_phoneme` | `FixtureMetadata.substitutePhonemeIPA` or empty |
| `word` | `FixtureMetadata.wordSurface` |
| `speaker_tag` | `FixtureMetadata.speakerTag.rawValue` |
| `engine_a_label` | JSON-encoded `PhonemeAssessmentLabel` |
| `engine_a_score` | Integer 0–100 or empty when `isReliable == false` |
| `engine_a_is_reliable` | `true` / `false` |
| `engine_a_features_json` | JSON-encoded `[String: Double]` from `PhonemeTrialAssessment.features` |
| `speechace_score` | SpeechAce `overall_score` or empty |
| `speechace_raw_json` | Full SpeechAce response body (pretty-printed JSON string) or empty |

CSV files are git-ignored at the `dev-tools/pronunciation-bench/` level. Results are never checked into the repo.

## 8. Error Handling

| Condition | Behavior |
|---|---|
| DEBUG recorder: microphone permission denied | Simple SwiftUI alert. Record button remains disabled until permission is granted from Settings. Does not reuse the main-session `PermissionCoordinator`. |
| Hardware format ≠ 16 kHz mono | `AVAudioConverter` downmixes/resamples. Converter-init failure → alert, recording canceled. |
| WAV write failure (disk full, sandbox) | Alert, delete any partial file, return UI to idle. |
| Sidecar JSON missing or malformed (bench side) | FixtureLoader logs a warning and skips the pair. |
| SpeechAce HTTP 4xx / 5xx / decode failure | CSV row's SpeechAce columns are empty; a warning is logged. Bench does not retry or crash. |
| `SPEECHACE_API_KEY` missing from env and `--no-speechace` not passed | Bench exits with code 2 and a clear message. |
| `--no-speechace` passed | SpeechAce columns are empty for all rows; no network call made. |
| Engine A returns `.unclear` | Row is still written. The fact that Engine A could not classify is itself signal. |
| Fixture WAV was recorded at an unusual sample rate | Bench resamples at load. If resampling fails, the row is skipped with a warning. |
| Calibration data agrees with literature thresholds | No action. `PhonemeThresholds.swift` is left unchanged; the Phase D PR simply records that agreement. |

## 9. Privacy and Invariants

### 9.1 Release-build invariants preserved

- `#if DEBUG` wrapping on every new type in `Packages/MoraUI/Sources/MoraUI/Debug/` and `Packages/MoraEngines/Sources/MoraEngines/Debug/`. Release builds do not compile these files.
- CI binary gate (landed in Part 1) continues to assert that the built `Mora.app` contains no SpeechAce or other cloud-assessment symbols. Part 2 adds none.
- CI source gate (landed in Part 1) already scopes its grep to `-- Mora Packages`, so `dev-tools/pronunciation-bench/` is outside its reach by construction.

### 9.2 Audio handling

- Fixture WAV files are written to the app sandbox Documents directory only when Yutaka explicitly taps Save in the DEBUG recorder. The app never uploads them.
- Export is user-initiated: AirDrop, iCloud Drive, or Files.app → Mac.
- SpeechAce traffic happens exclusively from Yutaka's Mac, from the `dev-tools/pronunciation-bench/` binary. No app build has a network path to SpeechAce.

### 9.3 Fixture repo policy

- Adult-proxy fixtures (Yutaka's voice) are checked into `Packages/MoraEngines/Tests/.../Fixtures/` as short WAVs (<100 KB each) that regression-test Engine A behavior.
- Child fixtures (the son's voice) are **not** checked in. They live on Yutaka's Mac for calibration work and are referenced in the calibration PR's commit message as "recorded locally, not committed, N fixtures per pair."
- This asymmetric policy keeps the repo's voice-data footprint minimal while still giving CI the regression coverage it needs.

## 10. Testing

### 10.1 Debug recorder plumbing

New file: `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureWriterTests.swift`, gated `#if DEBUG`.

- WAV round-trip: write a known Float32 buffer, read back with `AVAudioFile`, assert samples and sample-rate round-trip within PCM 16-bit quantization tolerance.
- Sidecar JSON schema: `FixtureMetadata` encodes/decodes symmetrically, including the `substitutePhonemeIPA == nil` case for non-substitution labels.
- Filename slug: verify IPA-to-ASCII mapping (`ʃ` → `sh`, `θ` → `th`, `æ` → `ae`).

`FixtureRecorder` is not unit-tested beyond a construction smoke test because it wraps `AVAudioEngine` + `AVAudioConverter`, both of which are Apple-provided and ill-suited to stub. Manual verification on iPad during Phase A covers it.

### 10.2 Debug recorder UI

Not unit-tested. Manual verification on iPad.

### 10.3 dev-tools/pronunciation-bench

New tests under `dev-tools/pronunciation-bench/Tests/BenchTests/`, run on Yutaka's laptop only.

- `SpeechAceClientTests` — feed a recorded SpeechAce response JSON to the client's decoder; assert `overall_score` extraction. URLSession is abstracted behind a small protocol so the test never hits the network.
- `CSVWriterTests` — RFC-4180 escaping for commas, quotes, newlines, empty cells.
- `FixtureLoaderTests` — directory enumeration, orphan handling (`*.wav` without `*.json` skipped with a warning; `*.json` without `*.wav` skipped).

### 10.4 Engine A fixture-based behavioral tests

New file: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift`.

- Loads WAVs from `Fixtures/rl/`, `Fixtures/vb/`, `Fixtures/aeuh/` via a small helper that mirrors the `EngineARunner` loader but runs in-process.
- Assertion style matches the parent spec §11.2 table:

| Fixture | Expected label | Expected score range |
|---|---|---|
| `right-correct.wav` | `.matched` for /r/ | ≥ 70 |
| `right-as-light.wav` | `.substitutedBy(/l/)` for /r/ | ≤ 40 |
| `light-correct.wav` | `.matched` for /l/ | ≥ 70 |
| `light-as-right.wav` | `.substitutedBy(/r/)` for /l/ | ≤ 40 |
| `very-correct.wav` | `.matched` for /v/ | ≥ 70 |
| `very-as-berry.wav` | `.substitutedBy(/b/)` for /v/ | ≤ 40 |
| `berry-correct.wav` | `.matched` for /b/ | ≥ 70 |
| `berry-as-very.wav` | `.substitutedBy(/v/)` for /b/ | ≤ 40 |
| `cat-correct.wav` | `.matched` for /æ/ | ≥ 70 |
| `cat-as-cut.wav` | `.substitutedBy(/ʌ/)` for /æ/ | ≤ 40 |
| `cut-correct.wav` | `.matched` for /ʌ/ | ≥ 70 |
| `cut-as-cat.wav` | `.substitutedBy(/æ/)` for /ʌ/ | ≤ 40 |

- Tolerance bounds may be widened (to 65 / 45) during Phase D if the adult-proxy thresholds are nudged to favor child-speaker performance. Any widening must be documented in the PR body that adjusts `PhonemeThresholds`.

The existing `// TODO(post-alpha): needs recorded fixture` comments in `FeatureBasedEvaluatorTests.swift` are deleted in the same commit that adds this new file.

### 10.5 CI impact

- `Packages/MoraEngines/Package.swift` gains `resources: [.copy("Fixtures")]` on the test target. No other test-target or main-target change.
- CI already runs `swift test` per package; the new fixture tests run automatically.
- `dev-tools/` remains outside CI. Phase 3's CI additions (if any) are orthogonal.

## 11. Phasing

- **Phase A — DEBUG recorder (iPad side).** FixtureMetadata → FixtureWriter → FixtureRecorder → PronunciationRecorderView → DebugEntryPoint. Verified by unit tests for the plumbing and by manual iPad recording for the UI.
- **Phase B — dev-tools bench (Mac side).** Package skeleton → FixtureLoader → EngineARunner → SpeechAceClient → CSVWriter → BenchCLI. Verified by local unit tests and one smoke run with two fixtures.
- **Phase C — Fixture collection and test adoption.** Record adult-proxy WAVs for the three pairs, check them in, replace the TODO'd stubs with `FeatureBasedEvaluatorFixtureTests`, ensure CI stays green.
- **Phase D — Child-speaker calibration pass.** Record the son's fixtures locally (not committed), run the bench, eyeball CSV, update `PhonemeThresholds.swift` numerically if data warrants, re-tune fixture test tolerances if the adult-proxy tests begin to fail post-update.

Phases are sequential: B requires no file from A, but C needs both (the recorder to produce fixtures, the bench to sanity-check them before committing). D requires C so the child fixtures do not interfere with the adult-proxy regression suite.

## 12. Open Questions

1. `Fixtures/` as a test resource bundle — Swift Package Manager `.copy` vs `.process` behavior with WAVs. Default is to use `.copy` to avoid resource processing; Phase C confirms during first run.
2. Microphone Info.plist usage description is already present for the main session recorder. Debug recorder reuses the same key; no `project.yml` change expected.
3. If the Debug entry point's 5-tap gesture collides with an existing SwiftUI gesture on the HomeView header anchor, fall back to a long-press on the same anchor.
4. If Phase 3 changes the public signature of `FeatureBasedPronunciationEvaluator.evaluate(…)` while Part 2 is in flight, `EngineARunner` needs a one-line update. The parent spec §6.1 treats the `PronunciationEvaluator` protocol surface as stable; this is unlikely but worth calling out.
5. Calibration output format revisit: if a second calibration pass becomes necessary within v1.5, Part 2 deliberately left room to add a `PhonemeThresholds` JSON loader without changing the Swift API. That is a follow-up PR, not a Part 2 task.

---

## Appendix A — Why not auto-capture during sessions

Session-capture was proposed and rejected during brainstorming. The decisive argument is structural: the code paths that would feed audio to an automatic sink (`AppleSpeechEngine`, `SessionOrchestrator`, `SpeechEvent`) are exactly the files Phase 3 needs to modify for shadow-mode logging. Two branches editing those files in parallel guarantees merge pain. Manual capture through the Debug recorder is slower per fixture but structurally cheap. Once Phase 3 lands its `PronunciationTrialLog` entity, a DEBUG-only extension that attaches audio bytes to the log row will satisfy the auto-capture goal without duplicating machinery.

## Appendix B — Why SpeechAce specifically

The parent spec §4.1 names SpeechAce as the correlation oracle of record. Part 2 uses the same API for consistency with any future Engine B promotion study. Azure Pronunciation Assessment, Google Speech, and GPT-4o audio were considered and rejected on the same grounds the parent spec rejected them: unit-economics, rate limits, and the fact that a personal project does not need two oracles.
