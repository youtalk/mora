# mora — Fixture Recorder App Design Spec

- **Date:** 2026-04-23
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Release target:** Not shipped. The recorder is a personal dev tool used only by Yutaka to produce fixture audio for Engine A calibration and regression tests.
- **Supersedes (for the recorder portion):** `2026-04-22-pronunciation-bench-and-calibration-design.md` §4.1, §4.4, §6.1–§6.4, §7.1, §9.1. Bench-side sections of that spec (§4.2, §5, §6.5, §6.6, §7.2–§7.3, §8–§12) stay in force.
- **Relates to:** `2026-04-23-pronunciation-bench-followups.md` (rewritten in Step E of this spec to drop the in-main-app DEBUG recorder steps and adopt the new recorder app's workflow).
- **Does not affect:** `2026-04-22-pronunciation-feedback-design.md`, `2026-04-22-pronunciation-feedback-engine-a.md`, `2026-04-22-pronunciation-feedback-engine-b-design.md`, `2026-04-22-pronunciation-feedback-engine-b.md`, `2026-04-23-engine-b-followup-real-model-bundling.md`. Engine A and Engine B are independent of how fixture audio is captured.

---

## 1. Overview

The pronunciation-bench spec landed with fixture capture living inside the main Mora app as a `#if DEBUG`-gated SwiftUI screen reached by a five-tap gesture on the `HomeView` wordmark. In practice that setup carries two durable costs:

1. **Mistakes at the metadata step.** The recorder shows four hand-driven pickers (Target Phoneme / Expected Label / Substitute Phoneme / Word) plus a free-form speaker toggle. Every recording requires re-configuring them correctly — the UI does nothing to stop Yutaka from saving a /r/-labelled clip of the word "cat". Follow-up plan Task B1 makes this worse by proposing two more hand-driven fields (phoneme sequence, target index) to fix medial-vowel localization.
2. **Export path never worked.** The bench-and-calibration spec called for `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` to be injected into the main `project.yml` so the app's Documents directory would surface in Files.app; that `project.yml` change was never merged to `main`. The recorder on `main` today writes files into a sandbox directory that nothing can reach. Even on a local worktree that re-added the Debug configs / postBuildScripts, Files.app either did not show the folder reliably or made multi-file AirDrop awkward.

This spec carves the recorder out of the main Mora app into its own iPad project, replaces the hand-driven pickers with a pre-defined catalog of 12 patterns that the user picks from a list, and makes in-app iOS Share Sheet the primary export path. Side effects: the `#if DEBUG` gating scaffolding across `MoraEngines` and `MoraUI` disappears (the recorder now lives outside the main app entirely), follow-up plan Task B1's schema extension is absorbed into the initial catalog definition, and the abandoned idea of surfacing main Mora's Documents directory via a `postBuildScript` is closed out (the main `project.yml` stays as it is on `main` today — unchanged — and the recorder app owns Files.app exposure instead).

The recorder app is explicitly **not** a shipped product. It is Yutaka's personal dev tool. App Store / TestFlight distribution is not planned. Privacy invariants that apply to the main Mora app (no cloud SDK, no network calls, CI source / binary gates) are not extended to the recorder — they are not needed for a tool that never reaches anyone else's device.

## 2. Motivation

Engine A's regression suite has twelve fixture tests (`FeatureBasedEvaluatorFixtureTests`, landed in PR #42) that currently `XCTSkip` because the adult-proxy WAVs have not been recorded yet. The recording is blocked not on engineering but on Yutaka's time; any friction in the recorder translates directly into fewer recordings and a longer skip list.

The twelve patterns are known in advance (`2026-04-23-pronunciation-bench-followups.md` Task A1 Step 2):

- r / l — right-correct, right-as-light, light-correct, light-as-right
- v / b — very-correct, very-as-berry, berry-correct, berry-as-very
- æ / ʌ — cat-correct, cat-as-cut, cut-correct, cut-as-cat

The insight is that if the list is fixed, every piece of metadata for every take is also fixed (target phoneme, expected label, substitute phoneme, word surface, phoneme sequence, target index, output filename stem). The user's only legitimate choices during a recording session are (a) which pattern to record, (b) when to hit Record and Stop, and (c) whether this is an adult or child voice. Everything else is either pre-baked into the catalog or derived (`capturedAt`, `durationSeconds`, `sampleRate`, take number).

The same insight lets the recorder emit sidecar JSON metadata that already carries Task B1's `phonemeSequenceIPA` + `targetPhonemeIndex` from the moment it ships. The follow-up plan's Task B1 (which would have modified `FixtureMetadata.swift` and `PronunciationRecorderView.swift` after the fact) is rendered into a small `EngineARunner` adjustment instead.

## 3. Goals and Non-Goals

### Goals

- A second iPad-only project at `recorder/MoraFixtureRecorder/` with its own bundle id (`tech.reenable.MoraFixtureRecorder`) and own XcodeGen input, structurally parallel to `bench/MoraBench`.
- A canonical catalog of 12 `FixturePattern`s covering Task A1's r/l, v/b, æ/ʌ rows, each carrying full phoneme sequence + target index.
- Two-screen SwiftUI flow: list of patterns (with per-pattern take-count badges and a speaker toggle) → detail screen (Record / Stop / Save + per-take share + delete).
- Multiple takes per pattern, auto-incrementing `-takeN` suffix, filename stem fixed by the catalog. Adult uses typically one take per pattern; child uses three or more.
- Global SpeakerTag toggle at the list screen header (persisted in UserDefaults across launches).
- In-app iOS Share Sheet as the primary export path: per-take share (wav + sidecar JSON), bulk share of all takes under the current speaker as a single zip.
- A new `Packages/MoraFixtures/` SPM package holding the types both the recorder app and `dev-tools/pronunciation-bench/` need (`FixtureMetadata`, `ExpectedLabel`, `SpeakerTag`, `FixturePattern`, `FixtureCatalog`, `FixtureWriter`, `FilenameSlug`). No dependency from main Mora into `MoraFixtures`.
- Removal of `Packages/MoraEngines/Sources/MoraEngines/Debug/`, `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/`, `Packages/MoraUI/Sources/MoraUI/Debug/`, and the `#if DEBUG` hook in `HomeView.swift`. Main `project.yml` stays as it is on `main` (it never had the Debug `configs` / `postBuildScripts` blocks that the bench-and-calibration spec proposed).
- `dev-tools/pronunciation-bench/` adopts `MoraFixtures` (instead of the MoraEngines `Debug/` types) for sidecar decoding, and acquires the `phonemeSequenceIPA` code path so the medial-vowel fixtures localize correctly.

### Non-Goals

- Session-capture (automatically saving trials produced during a normal A-day session). Still deferred per `2026-04-22-pronunciation-bench-and-calibration-design.md` §4.5 / Appendix A.
- Expanding the catalog beyond 12 patterns. θ/t (follow-up plan Task B3) is out of scope here; it depends on an Engine A coaching-map change that is its own decision.
- Mac Catalyst support. `bench/MoraBench` targets Mac Catalyst for LLM smoke testing; the recorder stays iPad-only because its purpose is capturing a real child speaker's microphone on the device Yutaka actually uses.
- A user-visible Settings toggle for "release mode vs dev mode" in the recorder. The recorder has only one mode; it is always a dev tool.
- Making the recorder a shipped product, distributing via TestFlight, or drafting a privacy policy for it. The recorder stays on Yutaka's personal device.
- Any code change to Engine A (`FeatureBasedPronunciationEvaluator`), Engine B (`PhonemeModelPronunciationEvaluator`), the orchestrator, or the main Mora session flow. Those ship independently of this work.
- Editing, trimming, or normalizing recorded audio in the app. The `sox` trim step in the follow-up plan stays on the Mac side.

### Invariants

- **Main Mora app's existing invariants stay in force.** The CI source gate (`git grep -- Mora Packages`) still runs with the same scope. The CI binary gate still asserts cloud pronunciation symbols are absent in `Mora.app`. This spec adds one assertion to the binary gate: also reject `FixtureRecorder|FixtureWriter|FixtureMetadata|PronunciationRecorderView|DebugFixtureRecorderEntryModifier` symbols in the main app, so the removal cannot silently regress.
- **Recorder app is a dev tool.** No privacy policy, no on-device-only CI gates, no cloud SDK ban are applied to it. It happens to make no network calls because it has no reason to, not because the spec forbids them.
- **No `#if DEBUG` gating anywhere in the new code paths.** `MoraFixtures` types are always compiled; the recorder app is always on inside its own target; the recorder target is not linked by the main Mora app.
- **Swift 6 `.v5` language mode pin** applies to `Packages/MoraFixtures/Package.swift` and to `recorder/project.yml`, matching the repo-wide convention captured in the existing packages' `Package.swift` files.
- **XcodeGen team injection workflow** (`DEVELOPMENT_TEAM: 2AFT9XT8R2` added before `xcodegen generate`, reverted after) applies to `recorder/project.yml` the same way it applies to the main `project.yml`.

## 4. Design Decisions

### 4.1 Separate iPad app, not an in-main-app `#if DEBUG` screen

The original pronunciation-bench spec picked the in-main-app Debug path on the grounds that the microphone permission was already granted for the main session recorder. That economy does not offset the two costs called out in §1 (metadata mistakes, fragile Files.app export), and it leaks `#if DEBUG` scaffolding across three packages. A second iPad project owned by `recorder/` mirrors the pattern `bench/MoraBench` already established: structurally isolated from main Mora, its own bundle id, its own `xcodegen` pipeline, its own README and entitlements. The main Mora build becomes cleaner; the recorder grows its own concerns independently.

### 4.2 Catalog-driven list UI, not a picker form

Yutaka produces one recording at a time from a fixed list of twelve. A `List` of twelve rows with take-count badges is a better UX than a picker form because it makes the session's progress visible at a glance ("I still need to do berry-correct and cut-as-cat") and because it removes every chance to misconfigure metadata. The catalog entry that backs a row is the sole source of truth for target phoneme, expected label, substitute phoneme, word surface, phoneme sequence, and target index; the user cannot override any of them.

The catalog also pre-bakes the phoneme sequence + target index that follow-up plan Task B1 was going to add through a schema migration. A medial-vowel row like `aeuh-cat-correct` knows `phonemeSequenceIPA = ["k", "æ", "t"]` and `targetPhonemeIndex = 1` at authoring time; the sidecar JSON carries those values on every take.

### 4.3 Multiple takes per pattern, auto-incrementing `-takeN`

The follow-up plan's Task A2 calls for three or more child-speaker takes per pattern. The recorder supports that directly: each Save writes a new file with the next available `-takeN` suffix for the current (speaker, pattern) combination, computed by scanning the pattern's subdirectory for existing files. The take row on the detail screen lists all takes for the pattern; each row has Play, Share, and Delete. Adult users who want a single canonical file per pattern simply record once; the take number is always `-take1` on a fresh pattern.

Renaming `-take1.wav` to `-take.wav` for the committed adult-proxy fixture set is done manually on the Mac side by the user during the trim step (`sox`), matching the naming convention `FeatureBasedEvaluatorFixtureTests` already expects. The recorder does not try to second-guess this — the file on disk is always `-takeN`, and the trim/rename step is a Mac-side shell command.

### 4.4 Global speaker toggle at the session root

Recording sessions alternate: Yutaka records his own voice for the adult-proxy set over one session, then switches to recording the child for the child-speaker set in a later session. A global toggle in the `CatalogListView` header is therefore natural: pick adult, do all twelve; pick child, do the same twelve again with multiple takes per row. Take-count badges on the list are filtered by the current speaker; files under the other speaker's subdirectory stay on disk but are not displayed. UserDefaults persists the toggle across launches so Yutaka does not re-pick speaker on every run.

A per-pattern speaker picker (flippable mid-row) was considered and rejected — it reintroduces the "misclick on every save" failure mode the whole redesign is built to eliminate.

### 4.5 `MoraFixtures` as a shared leaf SPM package

Three places need `FixtureMetadata` (or a byte-compatible equivalent): the recorder (writes it into the sidecar JSON), the bench (decodes it from the sidecar JSON), and Engine A's in-repo fixture regression tests (read filename convention, do not decode sidecar JSON directly but benefit from the same filename-slug helper). A new leaf SPM package at `Packages/MoraFixtures/` is the cleanest place — it sits outside the `Core ← Engines ← UI` dependency chain, declares no dependencies other than Foundation / AVFoundation (standard frameworks), and is consumed only by the recorder app and by `dev-tools/pronunciation-bench/`. The main Mora app has no link edge into `MoraFixtures`.

The alternative (keep types in `MoraEngines/Debug/` after stripping `#if DEBUG`) was rejected because it leaves `MoraEngines` with a mixed mandate — production engine logic plus dev-tool type library — and causes the recorder types to get linked into the main Mora release binary regardless.

### 4.6 iOS Share Sheet as primary export, Files.app as backup

The original bench-and-calibration spec planned to expose the main app's Documents directory to Files.app via `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`, with AirDrop from Files.app as the export route. That `project.yml` change never landed on `main`, so today's Debug build of Mora records fixtures into an unreachable sandbox. On a local experiment that re-added the configs + postBuildScripts, Files.app still did not show the folder reliably and multi-file AirDrop was awkward. The recorder app does not chase that path — it uses `ShareLink` directly:

- **Per-take share** — a small share icon in each take row on the detail screen, passing `[wavURL, sidecarURL]` to `ShareLink`. Tapping it presents the standard iOS Share Sheet; AirDrop to Mac delivers both files in one drop.
- **Bulk share** — a toolbar button on the list screen: `Share <speaker> takes (N)`. It triggers a build of a zip archive containing `<Documents>/<speaker>/` (preserving the `rl/`, `vb/`, `aeuh/` subdirectory structure), performed with `NSFileCoordinator.coordinate(readingItemAt:options:.forUploading)` and copied out of the coordinator scope to a stable URL under `NSTemporaryDirectory`. The zip is then passed to `ShareLink`. AirDrop delivers a single `<speaker>-<timestamp>.zip` to the Mac, which unzips into `~/mora-fixtures-<speaker>/`.

`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are set directly in the recorder's Info.plist (via XcodeGen's `info.properties:` block, which does not need a `postBuildScript` because the recorder's Info.plist is written explicitly rather than auto-generated) so Files.app sees the recorder's own Documents directory as a fallback export path. The recorder app's primary export guidance still points at the Share Sheet; Files.app is the safety net. Main Mora's `project.yml` stays unchanged — it never had these keys on `main` and still should not.

### 4.7 Recorder app is a dev tool, relaxed privacy stance

Because the recorder app is never distributed, the on-device invariants that apply to main Mora do not apply here. Specifically:

- No App Store / TestFlight submission is planned, so no privacy policy is required for the recorder.
- The CI binary gate (`nm Mora.app/Mora | grep -iE 'speechace|...'`) scopes only the main Mora binary. The recorder binary is not built in CI and is not scanned.
- The CI source gate (`git grep -- Mora Packages`) likewise scopes only main-app source trees. `Packages/MoraFixtures/` is under `Packages/` but carries no cloud dependency and is not imported by main Mora, so the gate is unaffected; `recorder/` is outside the gate's scope by path.
- The recorder has no reason to make network calls and does not. This is a natural outcome, not a policy the spec enforces.

The reverse direction is asserted: the main Mora binary must not contain recorder symbols. A new `nm`-style grep is added to the existing CI binary gate to reject `FixtureRecorder|FixtureWriter|FixtureMetadata|PronunciationRecorderView|DebugFixtureRecorderEntryModifier` symbols in `Mora.app/Mora`. This guards against regressions during refactoring.

## 5. Architecture

```
Main Mora app                          Fixture Recorder app              Pronunciation Bench (Mac CLI)
(tech.reenable.Mora)                   (tech.reenable.MoraFixtureRecorder)  (dev-tools/pronunciation-bench/)
└── MoraUI                             └── recorder/MoraFixtureRecorder/   └── swift-argument-parser
    └── MoraEngines                        │  MoraFixtureRecorderApp            + MoraEngines (EngineARunner)
        └── MoraCore                       │  CatalogListView                   + MoraCore (Word, Phoneme)
        └── MoraTesting                    │  PatternDetailView                 + MoraFixtures (metadata,
        └── MoraMLX                        │  RecorderStore                         catalog, FixtureWriter)
                                           │  FixtureRecorder (AVFoundation)
                                           └── MoraFixtures  (NEW leaf SPM)

                                           Packages/MoraFixtures/
                                             Sources/MoraFixtures/
                                               FixtureMetadata.swift
                                               ExpectedLabel.swift
                                               SpeakerTag.swift
                                               FixturePattern.swift
                                               FixtureCatalog.swift
                                               FixtureWriter.swift
                                               FilenameSlug.swift
                                             Tests/MoraFixturesTests/
                                               FixtureMetadataTests.swift
                                               FixtureCatalogTests.swift
                                               FixtureWriterTests.swift
                                               FilenameSlugTests.swift
```

Dependency direction: `MoraCore ← MoraEngines ← MoraUI`, with `MoraTesting` and `MoraMLX` branching off `MoraEngines`. `MoraFixtures` is a separate leaf with no dependency into any other mora package and no mora package depending into it except the recorder app target and `dev-tools/pronunciation-bench/`'s `Package.swift`. Main Mora never imports `MoraFixtures`.

## 6. Components

### 6.1 `Packages/MoraFixtures/Package.swift`

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MoraFixtures",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraFixtures", targets: ["MoraFixtures"]),
    ],
    targets: [
        .target(
            name: "MoraFixtures",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraFixturesTests",
            dependencies: ["MoraFixtures"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

`.macOS(.v14)` so `dev-tools/pronunciation-bench/` (Mac CLI) can link. No third-party dependencies.

### 6.2 `ExpectedLabel` and `SpeakerTag`

Moved from `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift`, `#if DEBUG` wrapper dropped. Shape unchanged:

```swift
public enum ExpectedLabel: String, Codable, Sendable, Hashable {
    case matched
    case substitutedBy
    case driftedWithin
}

public enum SpeakerTag: String, Codable, Sendable, Hashable {
    case adult
    case child
}
```

### 6.3 `FixtureMetadata`

Absorbs follow-up plan Task B1's deferred fields (`phonemeSequenceIPA`, `targetPhonemeIndex`) plus a new `patternID` field pointing back at the catalog entry that produced the take:

```swift
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?      // nil unless expectedLabel == .substitutedBy
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag
    public let phonemeSequenceIPA: [String]?      // nil only on legacy sidecars
    public let targetPhonemeIndex: Int?           // nil only on legacy sidecars
    public let patternID: String?                 // nil on legacy / ad-hoc recordings

    public init(...) { ... }
}
```

`Codable` decoding uses `decodeIfPresent` for the three optional fields so pre-2026-04-23 sidecars (without those keys) still decode to `nil` for each. Tests in `FixtureMetadataTests` cover both round-trip and legacy-payload decoding.

### 6.4 `FixturePattern`

Value type describing one catalog entry. It owns every field the recorder would otherwise have asked the user for:

```swift
public struct FixturePattern: Sendable, Hashable, Identifiable {
    public let id: String                          // stable catalog tag
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let phonemeSequenceIPA: [String]
    public let targetPhonemeIndex: Int
    public let outputSubdirectory: String          // e.g. "rl"
    public let filenameStem: String                // e.g. "right-correct"

    public var displayLabel: String { ... }

    public func metadata(
        capturedAt: Date,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag
    ) -> FixtureMetadata
}
```

`metadata(capturedAt:sampleRate:durationSeconds:speakerTag:)` builds a `FixtureMetadata` whose pattern-derived fields (target, expected, substitute, word, sequence, index, patternID) are taken from the pattern and whose runtime fields (captured timestamp, sample rate, duration, speaker) are supplied by the recorder. This is the only constructor the recorder calls; there is no way to build a partially-correct metadata.

`displayLabel` returns the text the list row shows — for example `"right — /r/ matched"` or `"right — /r/ substituted by /l/"` or `"cat — /æ/ matched"`.

### 6.5 `FixtureCatalog`

```swift
public enum FixtureCatalog {
    public static let v1Patterns: [FixturePattern] = [
        // r / l — onset consonant, target index 0
        FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        ),
        FixturePattern(
            id: "rl-right-as-light",
            targetPhonemeIPA: "r",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l",
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-as-light"
        ),
        FixturePattern(
            id: "rl-light-correct",
            targetPhonemeIPA: "l",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "light",
            phonemeSequenceIPA: ["l", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "light-correct"
        ),
        FixturePattern(
            id: "rl-light-as-right",
            targetPhonemeIPA: "l",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "r",
            wordSurface: "light",
            phonemeSequenceIPA: ["l", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "light-as-right"
        ),

        // v / b — onset consonant, target index 0
        FixturePattern(
            id: "vb-very-correct",
            targetPhonemeIPA: "v",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "very",
            phonemeSequenceIPA: ["v", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "very-correct"
        ),
        FixturePattern(
            id: "vb-very-as-berry",
            targetPhonemeIPA: "v",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "b",
            wordSurface: "very",
            phonemeSequenceIPA: ["v", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "very-as-berry"
        ),
        FixturePattern(
            id: "vb-berry-correct",
            targetPhonemeIPA: "b",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "berry",
            phonemeSequenceIPA: ["b", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "berry-correct"
        ),
        FixturePattern(
            id: "vb-berry-as-very",
            targetPhonemeIPA: "b",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "v",
            wordSurface: "berry",
            phonemeSequenceIPA: ["b", "ɛ", "r", "i"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "vb",
            filenameStem: "berry-as-very"
        ),

        // æ / ʌ — medial vowel, target index 1
        FixturePattern(
            id: "aeuh-cat-correct",
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cat-correct"
        ),
        FixturePattern(
            id: "aeuh-cat-as-cut",
            targetPhonemeIPA: "æ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "ʌ",
            wordSurface: "cat",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cat-as-cut"
        ),
        FixturePattern(
            id: "aeuh-cut-correct",
            targetPhonemeIPA: "ʌ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cut",
            phonemeSequenceIPA: ["k", "ʌ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cut-correct"
        ),
        FixturePattern(
            id: "aeuh-cut-as-cat",
            targetPhonemeIPA: "ʌ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "æ",
            wordSurface: "cut",
            phonemeSequenceIPA: ["k", "ʌ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cut-as-cat"
        ),
    ]
}
```

`FixtureCatalogTests` asserts:

- `v1Patterns.count == 12`.
- Every `id` and every `filenameStem` is unique.
- `expectedLabel == .substitutedBy` iff `substitutePhonemeIPA != nil`.
- `targetPhonemeIndex` is a valid index into `phonemeSequenceIPA`.
- `phonemeSequenceIPA[targetPhonemeIndex] == targetPhonemeIPA`.

Any authoring mistake in the catalog therefore fails CI.

### 6.6 `FixtureWriter` and `FilenameSlug`

Moved from `Packages/MoraEngines/.../Debug/FixtureWriter.swift`. `#if DEBUG` removed. Two public entry points:

```swift
public enum FixtureWriter {
    public struct Output: Equatable, Sendable {
        public let wav: URL
        public let sidecar: URL
    }

    /// Catalog-driven take. Filename: <pattern.filenameStem>-take<N>.wav/.json
    /// inside `directory`. `directory` is typically
    /// <Documents>/<speakerTag.rawValue>/<pattern.outputSubdirectory>/.
    /// Creates `directory` if missing.
    public static func writeTake(
        samples: [Float],
        metadata: FixtureMetadata,
        pattern: FixturePattern,
        takeNumber: Int,
        into directory: URL
    ) throws -> Output

    /// Ad-hoc take. Filename: <ISO-slug>-<targetSlug>-<labelSlug>[-<subSlug>].wav
    /// matching the current in-app recorder's convention. Not used by the
    /// new recorder app; kept so legacy code paths and CLI utilities can still
    /// produce sidecars.
    public static func writeAdHoc(
        samples: [Float],
        metadata: FixtureMetadata,
        into directory: URL
    ) throws -> Output
}

public enum FilenameSlug {
    /// Maps IPA characters to ASCII filename components:
    /// ʃ→sh, θ→th, æ→ae, ʌ→uh, ɪ→ih, ɛ→eh, ɔ→aw, ɑ→ah, ɜ→er, ɚ→er, ŋ→ng, ʒ→zh.
    /// Unmapped characters pass through unchanged.
    public static func ascii(ipa: String) -> String
}
```

WAV encoding (16-bit PCM little-endian mono) is unchanged from the current `FixtureWriter.encodeWAV` implementation.

### 6.7 `recorder/project.yml`

```yaml
name: Mora Fixture Recorder
options:
  bundleIdPrefix: tech.reenable
  deploymentTarget:
    iOS: "17.0"
  developmentLanguage: en
settings:
  base:
    SWIFT_VERSION: "5.9"
packages:
  MoraFixtures:
    path: ../Packages/MoraFixtures
targets:
  MoraFixtureRecorder:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: MoraFixtureRecorder
    resources:
      - path: MoraFixtureRecorder/Assets.xcassets
    dependencies:
      - package: MoraFixtures
    info:
      path: MoraFixtureRecorder/Info.plist
      properties:
        UIFileSharingEnabled: true
        LSSupportsOpeningDocumentsInPlace: true
        NSMicrophoneUsageDescription: "Records fixture audio for Engine A calibration."
        UILaunchScreen: {}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: tech.reenable.MoraFixtureRecorder
        CURRENT_PROJECT_VERSION: "1"
        MARKETING_VERSION: "1.0"
        TARGETED_DEVICE_FAMILY: "2"
        CODE_SIGN_STYLE: Automatic
  MoraFixtureRecorderTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: MoraFixtureRecorderTests
    dependencies:
      - target: MoraFixtureRecorder
schemes:
  MoraFixtureRecorder:
    build:
      targets:
        MoraFixtureRecorder: all
        MoraFixtureRecorderTests: [test]
    test:
      targets:
        - MoraFixtureRecorderTests
```

- `GENERATE_INFOPLIST_FILE` is omitted; an explicit Info.plist is written so `UIFileSharingEnabled` lands without a `postBuildScript`.
- `TARGETED_DEVICE_FAMILY: "2"` keeps the app iPad-only.

### 6.8 `MoraFixtureRecorderApp`

```swift
import MoraFixtures
import SwiftUI

@main
struct MoraFixtureRecorderApp: App {
    @State private var store = RecorderStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CatalogListView(store: store)
            }
        }
    }
}
```

### 6.9 `CatalogListView`

```swift
struct CatalogListView: View {
    @Bindable var store: RecorderStore

    var body: some View {
        List {
            Section {
                Picker("Speaker", selection: $store.speakerTag) {
                    Text("Adult").tag(SpeakerTag.adult)
                    Text("Child").tag(SpeakerTag.child)
                }
                .pickerStyle(.segmented)
            }

            Section("Patterns") {
                ForEach(FixtureCatalog.v1Patterns) { pattern in
                    NavigationLink {
                        PatternDetailView(store: store, pattern: pattern)
                    } label: {
                        HStack {
                            Text(pattern.displayLabel)
                            Spacer()
                            Text("\(store.takeCount(for: pattern)) takes")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BulkShareButton(store: store)
            }
        }
        .navigationTitle("Fixture Recorder")
    }
}
```

`BulkShareButton` either shows a plain `ShareLink(item: zipURL)` when the archive is ready, or a `Button` that builds the archive on tap and then presents the Share Sheet via a `.sheet` modifier; it is disabled when `store.totalTakesInCurrentSpeaker == 0`.

### 6.10 `PatternDetailView`

```swift
struct PatternDetailView: View {
    @Bindable var store: RecorderStore
    let pattern: FixturePattern

    var body: some View {
        Form {
            Section("Pattern") {
                LabeledContent("Word", value: pattern.wordSurface)
                LabeledContent("Target", value: "/\(pattern.targetPhonemeIPA)/")
                LabeledContent("Expected", value: pattern.expectedLabel.rawValue)
                if let sub = pattern.substitutePhonemeIPA {
                    LabeledContent("Substitute", value: "/\(sub)/")
                }
                LabeledContent("Sequence", value: pattern.phonemeSequenceIPA.joined(separator: " "))
                LabeledContent("Target index", value: "\(pattern.targetPhonemeIndex)")
            }

            Section("Capture") {
                Button(store.isRecording ? "Stop" : "Record") {
                    store.toggleRecording()
                }
                Button("Save") {
                    store.save(pattern: pattern)
                }
                .disabled(!store.hasCapturedSamples)
            }

            Section("Takes") {
                ForEach(store.takesOnDisk(for: pattern), id: \.self) { take in
                    TakeRow(url: take, store: store, pattern: pattern)
                }
            }

            if let error = store.errorMessage {
                Section("Error") {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(pattern.filenameStem)
    }
}
```

`TakeRow` shows the take number, duration, a `ShareLink(items: [wav, json])` icon, and a delete button.

### 6.11 `RecorderStore`

```swift
@Observable @MainActor
final class RecorderStore {
    var speakerTag: SpeakerTag  // persisted to UserDefaults
    var recordingState: RecordingState = .idle

    var isRecording: Bool { if case .recording = recordingState { true } else { false } }
    var hasCapturedSamples: Bool { ... }
    var errorMessage: String? { ... }
    var totalTakesInCurrentSpeaker: Int { ... }

    init(fileManager: FileManager = .default, userDefaults: UserDefaults = .standard)

    func toggleRecording()
    func save(pattern: FixturePattern)
    func deleteTake(url: URL)
    func takesOnDisk(for pattern: FixturePattern) -> [URL]
    func takeCount(for pattern: FixturePattern) -> Int
    func takeArtifacts(for wavURL: URL) -> [URL]   // [wav, sidecar json]
    func prepareSpeakerArchive() throws -> URL      // returns temp zip URL
}

enum RecordingState: Equatable {
    case idle
    case recording
    case captured(samples: [Float], durationSeconds: Double)
    case saving
    case saveFailed(String)
}
```

- `takesOnDisk(for:)` enumerates `<Documents>/<speakerTag>/<pattern.outputSubdirectory>/` for files matching `<pattern.filenameStem>-take<N>.wav`, sorted by N.
- `save(pattern:)` computes `takeNumber = (max existing N) + 1`, constructs `FixtureMetadata` via `pattern.metadata(...)`, calls `FixtureWriter.writeTake`, then resets `recordingState` to `.idle`.
- `deleteTake(url:)` removes both `.wav` and sidecar `.json`.
- `prepareSpeakerArchive()` wraps `NSFileCoordinator.coordinate(readingItemAt:options:.forUploading)`, copies the coordinator's temp zip out to `NSTemporaryDirectory()/<UUID>-<speaker>-<ISO>.zip`, and returns that URL. Throws `FixtureExportError.emptyDirectory` if the speaker folder has no takes.

### 6.12 `FixtureRecorder` (moved from MoraEngines)

The current `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift` is moved verbatim to `recorder/MoraFixtureRecorder/FixtureRecorder.swift`. The only changes:

- Drop the `#if DEBUG` wrapper.
- Remove `import MoraEngines` (there isn't one today; confirm none is added by mistake during the move).
- Keep the `sessionGeneration` late-callback guard that PR #41 introduced (commit `9129301`).

## 7. Data Flow

### 7.1 Recording one take

```
1. App launches → CatalogListView appears.
2. User checks or flips speaker toggle (e.g. .adult).
3. User taps a pattern row, e.g. "cat — /æ/ matched" → PatternDetailView.
4. User taps Record → store.toggleRecording():
     → recordingState = .recording
     → FixtureRecorder.start() starts AVAudioEngine
5. User speaks "cat" into the iPad microphone for ~1-2 seconds.
6. User taps Stop → store.toggleRecording():
     → FixtureRecorder.stop() removes the tap
     → samples = FixtureRecorder.drain()
     → recordingState = .captured(samples, duration)
7. User taps Save → store.save(pattern:):
     → recordingState = .saving
     → takeN = max(existing takes) + 1
     → metadata = pattern.metadata(
           capturedAt: .now,
           sampleRate: 16_000,
           durationSeconds: duration,
           speakerTag: .adult
       )
       → phonemeSequenceIPA = ["k", "æ", "t"]
       → targetPhonemeIndex = 1
       → patternID = "aeuh-cat-correct"
     → FixtureWriter.writeTake(
           samples, metadata, pattern,
           takeNumber: takeN,
           into: <Documents>/adult/aeuh/
       )
       → writes aeuh/cat-correct-takeN.wav + aeuh/cat-correct-takeN.json
     → recordingState = .idle
8. Takes list on the detail screen gains a new row; take-count badge on
   the list screen ticks up.
```

### 7.2 Exporting — per-take

```
User taps the ShareLink icon on a take row:
  → ShareLink(items: [take.wav, take.json]) presents the iOS Share Sheet
  → User picks AirDrop → Mac
  → Mac receives both files in ~/Downloads/
```

### 7.3 Exporting — bulk

```
User taps "Share adult takes (24)" in the toolbar:
  → store.prepareSpeakerArchive()
    → NSFileCoordinator.coordinate(
          readingItemAt: <Documents>/adult/,
          options: .forUploading,
          error: &err
      ) { tempZipURL in
          FileManager.copy tempZipURL → <tmp>/adult-<timestamp>.zip
      }
    → returns <tmp>/adult-<timestamp>.zip
  → ShareLink(item: zipURL) presents the iOS Share Sheet
  → User picks AirDrop → Mac
  → Mac receives adult-<timestamp>.zip in ~/Downloads/
  → On the Mac: cd ~/Downloads && unzip -q adult-*.zip -d ~/mora-fixtures-adult/
```

### 7.4 On-disk directory layout

```
<Documents>/
├── adult/
│   ├── rl/
│   │   ├── right-correct-take1.wav
│   │   ├── right-correct-take1.json
│   │   ├── right-as-light-take1.wav
│   │   ├── right-as-light-take1.json
│   │   └── …
│   ├── vb/…
│   └── aeuh/…
└── child/
    ├── rl/
    │   ├── right-correct-take1.wav
    │   ├── right-correct-take1.json
    │   ├── right-correct-take2.wav
    │   ├── right-correct-take2.json
    │   ├── right-correct-take3.wav
    │   └── …
    └── …
```

Adult fixtures used as regression input for `FeatureBasedEvaluatorFixtureTests` are committed without the `-takeN` suffix; the rename (`right-correct-take1.wav` → `right-correct.wav`) happens on the Mac during the `sox` trim step documented in `2026-04-23-pronunciation-bench-followups.md` Task A1 Step 5.

## 8. Impact on the Main Mora App

### 8.1 Files deleted

```
Packages/MoraEngines/Sources/MoraEngines/Debug/   (directory)
  ├── FixtureMetadata.swift
  ├── FixtureRecorder.swift
  └── FixtureWriter.swift

Packages/MoraEngines/Tests/MoraEnginesTests/Debug/  (directory)
  ├── FixtureMetadataTests.swift
  └── FixtureWriterTests.swift

Packages/MoraUI/Sources/MoraUI/Debug/   (directory)
  ├── DebugEntryPoint.swift
  └── PronunciationRecorderView.swift
```

### 8.2 Files modified

- `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` (lines 66–75)
  The `wordmark` computed property is reduced to:
  ```swift
  private var wordmark: some View {
      Text("Mora")
          .font(MoraType.heading())
          .foregroundStyle(MoraTheme.Accent.orange)
  }
  ```
  The `#if DEBUG` block and the `debugFixtureRecorderEntry()` call are removed.

- `project.yml` (main Mora) — **no change on `main`**. HEAD's `project.yml` has no Debug `configs` block and no `postBuildScripts`; the bench-and-calibration spec's `UIFileSharingEnabled` injection was never merged. If the current worktree carries an unstaged re-addition of those blocks (seen as a `M project.yml` diff on the `worktree-silly-wiggling-naur` branch as of 2026-04-23), discard the diff with `git restore project.yml` before starting the PR — this spec supersedes that attempt.

- `dev-tools/pronunciation-bench/Package.swift`
  Add `.package(path: "../../Packages/MoraFixtures")` to the dependencies list and `.product(name: "MoraFixtures", package: "MoraFixtures")` to the `Bench` target's dependencies.

- `dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift`
  Add `import MoraFixtures`. The symbols `FixtureMetadata`, `ExpectedLabel`, `SpeakerTag` now resolve through `MoraFixtures` instead of `MoraEngines`.

- `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift`
  Add `import MoraFixtures`. Implement the phoneme-sequence-aware `Word` construction that follow-up plan Task B1 called for: if `metadata.phonemeSequenceIPA != nil` and `metadata.targetPhonemeIndex != nil`, build the `Word` with the full sequence and use the indexed phoneme as `targetPhoneme`; otherwise fall back to `[target]`.

- `dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift`
  Add `import MoraFixtures`.

### 8.3 CI adjustments

The existing source / binary gates stay in force with no scope change. One assertion is added to the binary gate:

```yaml
- name: Binary gate — no recorder symbols in shipped Mora
  run: |
    if nm build/Debug-iphonesimulator/Mora.app/Mora 2>/dev/null | \
       grep -iE 'FixtureRecorder|FixtureWriter|FixtureMetadata|PronunciationRecorderView|DebugFixtureRecorderEntryModifier'; then
      echo "Recorder symbols detected in shipped Mora binary"
      exit 1
    fi
```

This catches accidental re-adds of the recorder types in `MoraEngines` / `MoraUI` during future refactors.

No CI job is added for the recorder app or for `Packages/MoraFixtures/`. `swift test` picks up `MoraFixtures` automatically because CI iterates packages; `recorder/` is outside CI by convention (matching `bench/` and `dev-tools/pronunciation-bench/`).

## 9. Error Handling

| Condition | Behavior |
|---|---|
| Microphone permission denied | `store.recordingState = .saveFailed("…")`; Record button disabled; error banner tells the user to enable mic in Settings. The recorder does not retry the permission prompt on its own. |
| `AVAudioEngine.start()` throws | Same path — `recordingState = .saveFailed(String(describing: error))`. User can retry. |
| `AVAudioConverter` init fails (hardware format incompatibility) | Same; recording never begins. |
| WAV write fails (disk full, sandbox, permission) | `store.save(pattern:)` catches the throw, sets `recordingState = .saveFailed(...)`, leaves the captured samples in the state so the user can retry. No partial file remains. |
| Save attempt when the same take number file already exists (races, clock skew) | `FixtureWriter.writeTake` throws; `store.save` catches and surfaces. In practice the take-number algorithm in `store` is deterministic against a single observer of the directory, so this path is a belt-and-suspenders guard. |
| Bulk share from empty speaker directory | `prepareSpeakerArchive()` throws `FixtureExportError.emptyDirectory`; the `Share adult takes (0)` button is disabled before the user can reach this, so the throw is a defensive check, not a typical path. |
| `NSFileCoordinator` zip fails (file lock, disk pressure) | Same; share flow shows an alert. The user can retry immediately. |
| Sidecar JSON decoding fails when another app reads it (bench side) | Out of scope for the recorder; `FixtureLoader` already handles this by skipping the orphan pair with a warning. |

## 10. Testing

### 10.1 `MoraFixturesTests`

- **`FixtureMetadataTests.swift`** — `Codable` round-trip over all fields, including the three new optional fields. Legacy-payload test: a pre-2026-04-23 sidecar JSON (without `phonemeSequenceIPA`, `targetPhonemeIndex`, `patternID`) must decode cleanly with those fields nil.
- **`FixtureCatalogTests.swift`** — the five invariants enumerated in §6.5.
- **`FixtureWriterTests.swift`** — `writeTake` generates the right filename (`rl/right-correct-take1.wav` and `.json`), the WAV round-trips through `AVAudioFile`, the sidecar JSON decodes back to an equal `FixtureMetadata`, and `writeTake` auto-creates missing subdirectories.
- **`FilenameSlugTests.swift`** — the full IPA-to-ASCII map enumerated in §6.6 plus unmapped-pass-through.

### 10.2 `MoraFixtureRecorderTests`

- **`RecorderStoreTests.swift`** — `takesOnDisk(for:)` enumeration over a test temp directory; `save(pattern:)` next-take-number algorithm (given existing `-take1`, `-take2`, `-take4`, next is `-take5`, not `-take3`); `deleteTake(url:)` removes both wav and json; `speakerTag` persists through a store relaunch (mocking UserDefaults).
- **`SpeakerArchiveTests.swift`** — `prepareSpeakerArchive()` produces a zip under `NSTemporaryDirectory()` whose name contains the speaker tag and a timestamp; unzipping it yields the same subdirectory structure as the source (`rl/`, `vb/`, `aeuh/`); empty-directory throws.
- **`FixtureDirectoryLayoutTests.swift`** — `patternDirectory(for:)` joins speaker + subdirectory correctly; missing subdirectory is created on first save; files for the other speaker are ignored by `takesOnDisk(for:)`.

`FixtureRecorder` itself is not unit-tested (it wraps `AVAudioEngine`, same as the current code); iPad simulator smoke is sufficient.

### 10.3 Existing test suites

- `FeatureBasedEvaluatorFixtureTests` — unchanged. The adult-proxy WAVs that land it committed use the `-take`-less convention (renamed from `-take1` during the Mac trim step), so filename expectations (`rl/right-correct.wav` etc.) still hold.
- `BenchTests` — still pass after the import swap. The legacy-sidecar decoding coverage in `FixtureLoaderTests` remains valid.
- `MoraEnginesTests/Debug/*` — deleted (the tests' subjects moved to `MoraFixturesTests`).
- All other packages (`MoraCore`, `MoraEngines` beyond `Debug/`, `MoraUI`, `MoraTesting`, `MoraMLX`) — unchanged tests, all still green.

## 11. Phasing

The work lands in **one PR**. The implementation is split into five internal steps for ordering and commit structure, but they ship together because the changes are mechanical (new package, file moves, UI shell, doc updates) and leaving the repo in a partial state between PRs (for example, `MoraFixtures` exists but the bench still imports from `MoraEngines/Debug/`) would invite merge-conflict surface during the window. Order the commits inside the PR as A → B → C → D → E so reviewers can read them in logical flow.

- **Step A — `Packages/MoraFixtures/` skeleton and types.** Package.swift, type moves (`ExpectedLabel`, `SpeakerTag`, `FixtureMetadata` with the three new fields, `FixtureWriter`, `FilenameSlug`), `FixturePattern`, `FixtureCatalog.v1Patterns`, full test suite. `swift test` on the new package green.
- **Step B — `dev-tools/pronunciation-bench/` adopts `MoraFixtures`.** Package.swift dependency add, `FixtureLoader` / `EngineARunner` / `FixtureLoaderTests` import swap, `EngineARunner` phoneme-sequence-aware `Word` construction. `(cd dev-tools/pronunciation-bench && swift test)` green.
- **Step C — remove recorder from main Mora.** Delete `Packages/MoraEngines/Sources/MoraEngines/Debug/`, `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/`, `Packages/MoraUI/Sources/MoraUI/Debug/`. Modify `HomeView.swift` (drop the wordmark hook). `project.yml` on `main` already matches the target state — no edit needed; if the worktree has an unstaged re-addition of Debug `configs` / `postBuildScripts`, discard that working-tree diff (`git restore project.yml`) before committing. `xcodegen generate && xcodebuild build` green. All package suites green. Add the recorder-symbol assertion to the CI binary gate.
- **Step D — `recorder/MoraFixtureRecorder/` app.** New `recorder/project.yml` and source tree: `MoraFixtureRecorderApp`, `RecorderStore` (with UserDefaults persistence), `CatalogListView`, `PatternDetailView`, `BulkShareButton`, `TakeRow`, `FixtureRecorder` (moved from MoraEngines), microphone permission handling. Test target with `RecorderStoreTests`, `SpeakerArchiveTests`, `FixtureDirectoryLayoutTests`. `xcodebuild` of the recorder project green locally. iPad physical-device smoke: record two patterns, verify saved files, share each take, bulk-share once.
- **Step E — update dependent specs and plans.** Add the superseding note to `2026-04-22-pronunciation-bench-and-calibration-design.md` and `2026-04-22-pronunciation-bench-and-calibration.md`. Rewrite Task A1 / Task A2 steps in `2026-04-23-pronunciation-bench-followups.md` to use the new recorder app + Share Sheet. Reduce Task B1 to just the `FeatureBasedEvaluatorFixtureTests` helper extension (the schema extension and `EngineARunner` call-site updates are absorbed into Step A / Step B of this spec); note that Task B1's residual change is best landed in the same commit as Task A1's fixture check-in. Task B2 and Task B3 unchanged.

Within the PR, each step is its own commit so `git log` reads cleanly; step ordering is enforced by the dependency graph (B requires A; D requires A; C is independent but lands after B so the bench stays functional between intermediate commits; E documents what the prior commits shipped).

## 12. Impact on Existing Specs and Plans

| Document | Change |
|---|---|
| `docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md` | Add a superseding note at the top covering §4.1, §4.4, §6.1–§6.4, §7.1, §9.1. Bench-side sections (§4.2, §5, §6.5, §6.6, §7.2–§7.3, §8–§12) remain authoritative. |
| `docs/superpowers/plans/2026-04-22-pronunciation-bench-and-calibration.md` | Add a superseding note. Tasks 1–5 are already merged (no-op update). The "Modified files" table's `HomeView.swift #if DEBUG add` entry is called out as reversed by this spec. |
| `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` | Rewrite Task A1 Steps 1–6 to walk through launching the recorder app, toggling the speaker, recording each pattern, using bulk Share Sheet → AirDrop, unzipping on the Mac, renaming `-take1` → `-take`, committing. Rewrite Task A2 to the same flow in child mode (plus per-take share for quick mid-session AirDrops). Reduce Task B1 to just the `FeatureBasedEvaluatorFixtureTests` helper extension (the schema extension and the `EngineARunner` call-site update are absorbed into Step A / Step B of this spec); recommend Task B1's residual change land in the same commit as Task A1's fixture check-in so medial-vowel tests unskip cleanly. Task B2 unchanged. Task B3 unchanged. |
| `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md` | No change. |
| `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-a.md` | No change. |
| `docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md` | No change. |
| `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` | No change. |
| `docs/superpowers/plans/2026-04-23-engine-b-followup-real-model-bundling.md` | No change. |

## 13. Open Questions

1. **Take numbering after delete** — the algorithm in §6.11 uses `max(existing) + 1`, so deleting `take3` and recording again produces `take4`, not `take3`. This is deliberate (it preserves on-disk ordering) but might confuse the user. If that proves annoying in practice, a follow-up PR can switch to `min unused take number` without changing any on-disk sidecar.
2. **Bulk share when both speakers have takes** — the current design shares only the current speaker. A "Share everything" option could dump both `adult/` and `child/` together, but mixing speakers in one AirDrop drop on the Mac side invites mistakes during the follow-up plan's trim step. Default stance is per-speaker-only; revisit if Yutaka wants a single combined export.
3. **Audio playback** — the detail screen's take row shows a Play button that uses `AVPlayer` with the take's WAV URL. This is trivial to implement but not strictly required for the record-and-export loop. If simulator-side audio playback regresses on some iPad-OS combination, the Play button is the first thing to drop.
4. **Visual feedback during recording** — the spec does not require a VU meter. A simple animated waveform or a recording-time counter would be nice; implementation is deferred to Step D of the PR and can land or not depending on how long Step D ends up being.
5. **Replacing the recorder's own `FixtureRecorder` with `AVAudioRecorder`** — `AVAudioEngine` + `AVAudioConverter` is the tested path we're moving. `AVAudioRecorder` would be simpler code but writes WAV at the hardware native rate, requiring a separate resampling pass to 16 kHz. Stay with the current tap-based approach to avoid a rewrite during a move.
6. **θ/t extension (follow-up plan Task B3)** — out of scope here, but the `FixtureCatalog` is the natural extension point. When Task B3 lands (Option A, symmetric four-fixture pattern), four new `FixturePattern` rows go into `v1Patterns` and no other code changes.

---

## Appendix A — Why not a single shared `Mora/Debug` target in the main project

Keeping the recorder inside the main Mora project as a second executable target was briefly considered — it would avoid standing up a fresh `recorder/project.yml`. Two reasons it lost:

- **Bundle identity.** `bench/MoraBench` and the proposed recorder both want their own bundle id so they install as separate icons on the iPad, each with its own Documents directory. That requires a second `project.yml` anyway.
- **Language policy and CLAUDE.md cleanliness.** The main Mora project has locale-aware rules around string catalogs (`MoraStrings`), test resource layouts (`Fixtures/`), CI gates, and a dependency chain that the recorder does not want to inherit. A separate project keeps the recorder's constraints minimal.

## Appendix B — Why not pay to make the recorder airdrop-free

An earlier option was to have the recorder upload fixtures to a private S3 bucket / iCloud Drive folder / Git LFS directly from the iPad. Every variant required network code, credential handling, or a cross-device storage contract. Since the recorder is already in Yutaka's hands on both sides of the transfer, iOS Share Sheet → AirDrop is the cheapest and least error-prone path. If AirDrop becomes unreliable in a specific network environment later, `ShareLink` is the iOS-standard primitive for swapping in Mail / iCloud Drive / Messages without code changes.
