# mora — Recorder In-App Engine A Evaluation Design Spec

- **Date:** 2026-04-24
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Release target:** Not shipped. The recorder is a personal dev tool; this
  change keeps the recorder personal-dev-only.
- **Relates to:** `2026-04-23-fixture-recorder-app-design.md` (base recorder
  design), `2026-04-22-pronunciation-feedback-engine-a.md` (evaluator), PR #64
  review comment (the re-record guidance this spec automates on-device).
- **Does not affect:** `2026-04-22-pronunciation-feedback-engine-b-design.md`,
  `2026-04-23-engine-b-followup-real-model-bundling.md`. Engine B stays
  unvalidated and is explicitly out of scope for the recorder.

---

## 1. Overview

The Fixture Recorder app (`recorder/MoraFixtureRecorder/`) currently captures
takes but defers evaluation to the Mac-side bench tool
(`dev-tools/pronunciation-bench/`). The current loop is:

```
iPad: record take → Save → AirDrop to Mac → bench prints matched/substitutedBy
→ decision: keep or re-record → iPad: record again → …
```

PR #64's review comment lists per-fixture re-record guidance ("light-correct
needs F3 ≥ 2300 Hz", "very-correct needs VOT = -100 sentinel", etc.). The
diagnostic data driving every row of that table is produced by Engine A
(`FeatureBasedPronunciationEvaluator`) — a pure-Swift, fast, deterministic
evaluator that already runs happily on the device used for recording.

This spec wires Engine A into the Recorder so each take is classified in place
after Stop, before Save. Yutaka sees the matched / substitutedBy verdict (plus
full feature detail, score, and reliability flag) immediately on the iPad, and
decides whether to save the take or re-record without round-tripping to the
Mac. The decision loop becomes:

```
iPad: record → evaluate → verdict shown inline → decide: Save or re-record
```

Engine B is out of scope. The CoreML wav2vec2 evaluator
(`PhonemeModelPronunciationEvaluator`) has not been bench-tested against real
fixture audio yet; introducing it alongside Engine A would raise a new
"which engine do I trust?" question without adding signal. A later spec can
add Engine B once its precision against ground-truth is known.

The sidecar JSON schema (`FixtureMetadata`) is unchanged. Verdicts are
in-memory state inside the Recorder process, not persisted. The Mac bench
re-evaluates from raw audio anyway.

## 2. Motivation

The recorder currently offers no feedback on whether a take will pass the
bench's ground-truth check. Yutaka records, exports, runs bench, reads the
CSV, decides, and re-records if needed — a loop that crosses a device
boundary and takes several minutes per iteration. When a fixture fails, the
cost to diagnose and re-take is disproportionate to the edit.

Engine A is fast (tens of milliseconds per 1–2 s clip), deterministic
(pure-Swift FFT + fixed thresholds), and already the source of truth for
bench's pass/fail labeling. Putting it behind the Stop button on the iPad
collapses the loop to seconds and moves the decision point to where the
microphone is.

Two follow-on benefits:

- **iPad verdict == Mac bench verdict** by construction. Both call the same
  evaluator with the same input primitives; whatever the iPad says about a
  take is what bench will say.
- The re-record guidance table in PR #64's review comment becomes a live
  on-device assistant, not a separate document. The acoustic targets (F1,
  F3, VOT) Yutaka is already reading from bench output are displayed next
  to the Capture button as soon as the recording stops.

## 3. Goals and Non-Goals

### Goals

- Add Engine A evaluation to the Recorder. Run it after Stop on the captured
  in-memory samples and display the verdict inline before Save.
- Display the full `PhonemeTrialAssessment` output: label, score, features,
  isReliable, coachingKey. Collapsed by default to a 2–3 line summary; tap
  to expand to full detail.
- Cache verdicts in memory for the current Recorder process. Saved takes
  viewed in the takes list show the cached verdict; takes from a previous
  app launch get lazy-evaluated on first view.
- Share the evaluator invocation path between the Recorder and bench so both
  produce identical verdicts for the same audio.
- Keep `FixtureMetadata` / sidecar JSON schema unchanged. No persistent
  verdict storage.

### Non-Goals

- **Engine B integration.** Out of scope; revisit when Engine B has a
  validated precision/recall against ground-truth fixtures.
- **Persistent verdict storage.** No sidecar schema change, no SwiftData
  addition, no per-verdict history. The Mac bench is the system of record
  for durable verdicts; the iPad's verdict is ephemeral UX.
- **Automated re-record suggestions or Save blocking.** The recorder shows
  the verdict; Yutaka decides. Save is never disabled or gated by verdict.
- **Changes to Engine A itself.** `FeatureBasedPronunciationEvaluator`,
  `FeatureExtractor`, `PhonemeRegionLocalizer`, `PhonemeThresholds` all stay
  as they are on PR #64's HEAD. This spec is pure wiring.
- **Re-running evaluation on demand via a button.** There is no "re-evaluate"
  button. Evaluation is deterministic; re-running would produce the same
  answer. Lazy evaluation on view appearance covers the "I want to see the
  verdict for an older take" use case.
- **Expanding the fixture catalog or adding new patterns.** Orthogonal to
  this work.

### Invariants

- **iPad verdict matches Mac bench verdict** for the same audio / pattern
  inputs. Guaranteed by both sides calling the same `FeatureBasedPronunciationEvaluator`
  through a shared `PronunciationEvaluationRunner` type, with identical
  `Word` construction (phoneme sequence + target index) and identical
  sample rate (16 kHz mono Float32).
- **Recorder stays a dev tool.** No CI binary gate extensions, no privacy
  policy, no cloud dependencies. The extra code path runs on device and
  makes no network calls.
- **`MoraFixtures` remains a leaf SPM package.** No new dependency from
  `MoraFixtures` to `MoraEngines` / `MoraCore`. The shared evaluator helper
  lives in `MoraEngines` and takes primitive inputs the Recorder extracts
  from `FixturePattern` on its own.
- **Swift 6 tools-version + `.swiftLanguageMode(.v5)`** continues for every
  modified package per the repo-wide pin.
- **`#if DEBUG` is not introduced.** The recorder is non-shipping; all code
  paths are unconditional within the recorder target.

## 4. Design Decisions

### 4.1 Engine A only, Engine B deferred

Engine B is bundled in main Mora (via `MoraMLX` + wav2vec2 mlmodelc from
GitHub Releases per PR #62) but has not been run against a real fixture set.
The bench sweep table in PR #64 — and every piece of re-record guidance
derived from it — is 100% Engine A. Introducing Engine B into the recorder
would expand the "interpret this verdict" mental model (A says matched,
B says substitutedBy — now what?) without adding any data Yutaka currently
trusts. A later spec can add Engine B once its ground-truth precision is
known; that work is independent of this one.

### 4.2 Pre-Save evaluation + in-memory session cache

Evaluation fires after Stop and before Save. The user sees the verdict on
the captured (still-in-memory) clip; if the verdict disagrees with the
catalog's expected label, they can discard and re-record without ever
committing a bad file to disk. This matches the stated goal ("avoid
re-re-recording") at the earliest possible decision point.

After Save, the verdict is kept in a per-Recorder-process `[URL:
PhonemeTrialAssessment]` dictionary keyed by the saved WAV URL. The takes
list renders a compact badge for each cached entry. Takes without a cached
verdict (e.g. from a previous app launch) trigger a lazy evaluation on the
`TakeRow.onAppear`; Engine A is cheap enough to run on-demand and the
result is cached for the rest of the session.

**Alternatives considered and rejected:**

- *Ephemeral pre-Save only:* every take row in the list would be blank for
  verdicts; Yutaka would have to re-record (destructively) to see a verdict.
  Worse UX than lazy-eval-on-appear and not simpler in implementation.
- *Persist verdict in `FixtureMetadata` sidecar:* adds schema migration,
  backwards-compat decoders, and a new field tested in `FixtureMetadataTests`
  — all for a value the Mac bench would just re-compute. The iPad verdict
  is information only for the iPad session.

### 4.3 Full-detail display, collapsed by default

Yutaka actively tunes Engine A. When the verdict is "matched" he usually
doesn't need feature values; when the verdict is "substitutedBy" he very
much wants to know which feature drove it (F3 = 1656 Hz vs the 2300 Hz
boundary, VOT = +24 ms vs the -5 ms boundary) so he can decide whether a
re-record will cross the threshold or whether the issue is extractor-limited
(per the PR #64 follow-ups table). Collapsing to a 2–3 line summary and
expanding on tap gives both modes.

The displayed items are straight from `PhonemeTrialAssessment`:

- label (matched / substitutedBy(phoneme) / driftedWithin / unclear)
- score (0–100, nil when label is .matched reliable or .unclear)
- features (typically 1 entry; the feature that triggered the decision)
- isReliable
- coachingKey (shown when non-nil)

### 4.4 `PronunciationEvaluationRunner` in `MoraEngines`

Both the Recorder and the bench need the same logic: "given samples +
word + target + phoneme sequence + target index, run the evaluator and
return the assessment". A new struct `PronunciationEvaluationRunner` in
`MoraEngines` centralizes this logic. The bench's existing `EngineARunner`
becomes a thin adapter that translates `LoadedFixture` (bench) → primitives
→ runner. The Recorder calls the runner directly with primitives extracted
from `FixturePattern`.

This keeps `MoraFixtures` a leaf (no upward dependency into `MoraEngines`)
while sharing the production-grade evaluation path between the two
consumers. Any future change to `Word` construction (e.g. richer
`graphemes`) lives in one place.

### 4.5 New Recorder deps: `MoraEngines` + `MoraCore`

The Recorder currently depends only on `MoraFixtures`. Engine A evaluation
requires `MoraEngines` (for the evaluator and runner) and `MoraCore` (for
`Word`, `Phoneme`, `Grapheme`, `AudioClip`, `ASRResult`). `MoraEngines`
transitively pulls `MoraCore`, so the recorder `project.yml` declares
`MoraEngines` and `MoraCore` both explicitly for clarity.

Tree-shaking at link time means unused `MoraEngines` symbols
(SessionOrchestrator, AssessmentEngine, etc.) do not land in the recorder's
final binary — only the evaluator subtree and its dependencies.

### 4.6 Separate `pendingVerdict` observable, not nested in `RecordingState`

The existing `RecordingState` enum describes the audio-capture pipeline
state (idle → recording → captured → saving → saveFailed). Evaluation is a
separate concern that runs *after* capture lands in `.captured`. Mixing
verdict state into the capture enum would either couple two axes (adding
`PhonemeTrialAssessment?` to every `.captured(...)` value and propagating
equality changes through SwiftUI observation) or force `.captured` to
sometimes mean "captured and evaluating" and sometimes "captured and ready".

The cleaner factoring is two observable properties:

- `recordingState` (existing) for audio capture.
- `pendingVerdict` (new, 3 cases: `.idle` / `.evaluating` / `.ready(a)`) for
  evaluation of the captured take.

### 4.7 `toggleRecording` gains a `pattern:` parameter

The Recorder needs to know which pattern was active when Stop fires so it
can invoke the evaluator with the right primitives. Rather than introduce
a separate `store.evaluate(pattern:)` call that `PatternDetailView` would
have to remember to invoke after Stop, the evaluation kick-off is folded
into `toggleRecording(pattern:)`. The pattern is always available at the
call site (it is owned by `PatternDetailView`), and the Recorder never
evaluates in a state where the pattern is unknown.

## 5. Architecture

```
recorder/MoraFixtureRecorder/
├── MoraFixtures                                   (leaf, unchanged)
├── MoraEngines (NEW dep)                          ┐
│   └── PronunciationEvaluationRunner (NEW)        │ verdict source
│       └── FeatureBasedPronunciationEvaluator     │ (existing)
└── MoraCore    (NEW dep, explicit)                ┘

dev-tools/pronunciation-bench/
├── MoraEngines
│   └── PronunciationEvaluationRunner (shared)    ← bench and recorder
├── MoraCore
└── MoraFixtures
    └── EngineARunner (reduced to delegation)
```

Dependency direction stays `MoraCore ← MoraEngines`. `MoraFixtures` remains
a leaf with no `MoraEngines` edge. The Recorder and the bench both depend
on `MoraEngines`, so any future change to `PronunciationEvaluationRunner`
is picked up by both without further wiring.

## 6. Components

### 6.1 `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationEvaluationRunner.swift` (NEW)

```swift
import Foundation
import MoraCore

public protocol PronunciationRunning: Sendable {
    func evaluate(
        samples: [Float],
        sampleRate: Double,
        wordSurface: String,
        targetPhonemeIPA: String,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?
    ) async -> PhonemeTrialAssessment
}

public struct PronunciationEvaluationRunner: PronunciationRunning {
    public let evaluator: FeatureBasedPronunciationEvaluator

    public init(evaluator: FeatureBasedPronunciationEvaluator = .init()) {
        self.evaluator = evaluator
    }

    public func evaluate(
        samples: [Float],
        sampleRate: Double,
        wordSurface: String,
        targetPhonemeIPA: String,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?
    ) async -> PhonemeTrialAssessment {
        let target = Phoneme(ipa: targetPhonemeIPA)
        let phonemes: [Phoneme]
        let targetIndex: Int
        if let seq = phonemeSequenceIPA,
            let idx = targetPhonemeIndex,
            seq.indices.contains(idx)
        {
            phonemes = seq.map { Phoneme(ipa: $0) }
            targetIndex = idx
        } else {
            phonemes = [target]
            targetIndex = 0
        }
        let word = Word(
            surface: wordSurface,
            graphemes: [Grapheme(letters: wordSurface)],
            phonemes: phonemes,
            targetPhoneme: phonemes[targetIndex]
        )
        let audio = AudioClip(samples: samples, sampleRate: sampleRate)
        return await evaluator.evaluate(
            audio: audio, expected: word,
            targetPhoneme: phonemes[targetIndex],
            asr: ASRResult(transcript: wordSurface, confidence: 1.0)
        )
    }
}
```

Logic equivalent to the current bench `EngineARunner.evaluate(_:)` body,
minus the `FixtureMetadata`-shaped interface. The fallback branch
(sequence or index absent) preserves the pre-B1 onset-only behavior for
legacy sidecars.

### 6.2 `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift` (REDUCED)

```swift
import Foundation
import MoraEngines
import MoraFixtures

public struct EngineARunner {
    private let runner: any PronunciationRunning

    public init(runner: any PronunciationRunning = PronunciationEvaluationRunner()) {
        self.runner = runner
    }

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        await runner.evaluate(
            samples: loaded.samples,
            sampleRate: loaded.sampleRate,
            wordSurface: loaded.metadata.wordSurface,
            targetPhonemeIPA: loaded.metadata.targetPhonemeIPA,
            phonemeSequenceIPA: loaded.metadata.phonemeSequenceIPA,
            targetPhonemeIndex: loaded.metadata.targetPhonemeIndex
        )
    }
}
```

`BenchCLI.swift` is unchanged — it still instantiates `EngineARunner()` and
calls `evaluate(loaded:)`. The imports `import MoraCore` from the old
`EngineARunner` are no longer required at the bench call site (only
`EngineARunner` itself imports `MoraEngines`).

### 6.3 `recorder/project.yml` (MODIFIED)

```yaml
packages:
  MoraFixtures:
    path: ../Packages/MoraFixtures
  MoraCore:
    path: ../Packages/MoraCore
  MoraEngines:
    path: ../Packages/MoraEngines
targets:
  MoraFixtureRecorder:
    dependencies:
      - package: MoraFixtures
      - package: MoraCore
      - package: MoraEngines
```

Both `MoraCore` and `MoraEngines` are explicitly listed so the target file
documents the full API surface used, even though `MoraEngines` would
transitively pull `MoraCore`.

### 6.4 `recorder/MoraFixtureRecorder/RecorderStore.swift` (MODIFIED)

Additions (existing fields preserved):

```swift
public enum PendingVerdict: Sendable, Equatable {
    case idle
    case evaluating
    case ready(PhonemeTrialAssessment)
}

@Observable @MainActor
public final class RecorderStore {
    // ... existing state ...

    public var pendingVerdict: PendingVerdict = .idle
    public private(set) var savedVerdicts: [URL: PhonemeTrialAssessment] = [:]

    private var evaluationTask: Task<Void, Never>?
    private let runner: any PronunciationRunning

    public init(
        documentsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        recorder: FixtureRecorder? = nil,
        runner: any PronunciationRunning = PronunciationEvaluationRunner()
    ) { ... }

    public func toggleRecording(pattern: FixturePattern) { ... }
    public func save(pattern: FixturePattern) { ... }           // existing signature
    public func deleteTake(url: URL) { ... }                    // existing signature
    public func evaluateSavedTake(url: URL, pattern: FixturePattern) async { ... }

    private func evaluateCaptured(pattern: FixturePattern) { ... }
}
```

**Behavior changes on existing methods:**

- `toggleRecording(pattern:)`:
  - On **idle / saveFailed / captured → recording**: cancel any running
    `evaluationTask`, set `pendingVerdict = .idle`, then existing `recorder.start()` + state transition.
  - On **recording → captured**: existing `recorder.stop()` + samples drain
    + `recordingState = .captured(snapshot)`, then call `evaluateCaptured(pattern:)`.
  - On **saving**: unchanged (ignore).
- `save(pattern:)`:
  - Capture `FixtureWriter.writeTake(...)`'s returned `Output.wav` URL
    (currently discarded via `_ = try …`). If `case .ready(let a) = pendingVerdict`,
    insert `savedVerdicts[output.wav] = a`.
  - Set `pendingVerdict = .idle` (whether or not a verdict was cached).
  - Existing `recordingState = .idle` + `takesRevision &+= 1`.
- `deleteTake(url:)`:
  - Existing removal, plus `savedVerdicts[url] = nil`.

**New method bodies:**

```swift
private func evaluateCaptured(pattern: FixturePattern) {
    guard case let .captured(snapshot) = recordingState else { return }
    pendingVerdict = .evaluating
    let runner = self.runner
    let sampleRate = recorder.targetSampleRate
    evaluationTask = Task.detached { [weak self] in
        let assessment = await runner.evaluate(
            samples: snapshot.samples,
            sampleRate: sampleRate,
            wordSurface: pattern.wordSurface,
            targetPhonemeIPA: pattern.targetPhonemeIPA,
            phonemeSequenceIPA: pattern.phonemeSequenceIPA,
            targetPhonemeIndex: pattern.targetPhonemeIndex
        )
        if Task.isCancelled { return }
        await MainActor.run {
            guard let self else { return }
            if case .evaluating = self.pendingVerdict {
                self.pendingVerdict = .ready(assessment)
            }
        }
    }
}

public func evaluateSavedTake(url: URL, pattern: FixturePattern) async {
    if savedVerdicts[url] != nil { return }
    let sampleRate = recorder.targetSampleRate
    let runner = self.runner
    let assessment = await Task.detached { () -> PhonemeTrialAssessment? in
        guard let samples = try? FixtureRecorder.decode(from: url) else { return nil }
        return await runner.evaluate(
            samples: samples,
            sampleRate: sampleRate,
            wordSurface: pattern.wordSurface,
            targetPhonemeIPA: pattern.targetPhonemeIPA,
            phonemeSequenceIPA: pattern.phonemeSequenceIPA,
            targetPhonemeIndex: pattern.targetPhonemeIndex
        )
    }.value
    if let assessment { savedVerdicts[url] = assessment }
}
```

The double-guard in `evaluateCaptured` (`Task.isCancelled` + `if case .evaluating`)
protects against stale detached results landing on a new capture.

### 6.5 `recorder/MoraFixtureRecorder/FixtureRecorder.swift` (MODIFIED)

Add a `nonisolated static` decode helper that reads a WAV at `url` and
returns 16 kHz mono Float32 samples — the same format the recorder
captures. `FixtureRecorder` is `@MainActor`-isolated, so the static
function is explicitly marked `nonisolated` to let AVAudioFile's
synchronous IO run on any thread rather than serializing through the
main actor:

```swift
nonisolated public static func decode(from url: URL) throws -> [Float] {
    let file = try AVAudioFile(forReading: url)
    let hardwareFormat = file.processingFormat
    guard let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000, channels: 1, interleaved: false
    ) else { throw FixtureRecorderError.converterInitFailed }
    guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)
    else { throw FixtureRecorderError.converterInitFailed }
    // Read into an `AVAudioPCMBuffer` at hardwareFormat, then convert
    // to targetFormat, then extract channel[0] as `[Float]`. Mirrors
    // `FixtureLoader.readMono16kFloat(from:)` in bench.
    return samples
}
```

Callers wrap the synchronous call in a `Task.detached` when they need it
off the main thread (as `evaluateSavedTake` does).

### 6.6 `recorder/MoraFixtureRecorder/PatternDetailView.swift` (MODIFIED)

```swift
struct PatternDetailView: View {
    @Bindable var store: RecorderStore
    let pattern: FixturePattern

    var body: some View {
        Form {
            Section("Pattern") { /* unchanged */ }

            Section("Capture") {
                Button(store.isRecording ? "Stop" : "Record") {
                    store.toggleRecording(pattern: pattern)
                }
                Button("Save") { store.save(pattern: pattern) }
                    .disabled(!store.hasCapturedSamples)

                VerdictPanel(pattern: pattern, pending: store.pendingVerdict)
            }

            Section("Takes") {
                ForEach(store.takesOnDisk(for: pattern), id: \.self) { take in
                    TakeRow(url: take, store: store, pattern: pattern)
                }
            }

            if let error = store.errorMessage {
                Section("Error") { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle(pattern.filenameStem)
    }
}
```

The only non-cosmetic changes: `store.toggleRecording(pattern: pattern)`
(was no-arg) and the new `VerdictPanel`.

### 6.7 `recorder/MoraFixtureRecorder/VerdictPanel.swift` (NEW)

```swift
struct VerdictPanel: View {
    let pattern: FixturePattern
    let pending: PendingVerdict

    var body: some View {
        switch pending {
        case .idle:
            EmptyView()
        case .evaluating:
            HStack {
                ProgressView().controlSize(.small)
                Text("evaluating…").foregroundStyle(.secondary)
            }
        case .ready(let a):
            VerdictSummary(pattern: pattern, assessment: a)
        }
    }
}

struct VerdictSummary: View {
    let pattern: FixturePattern
    let assessment: PhonemeTrialAssessment
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            // features, isReliable, coachingKey
            VStack(alignment: .leading, spacing: 4) {
                ForEach(assessment.features.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                    LabeledContent(k) { Text(String(format: "%.1f", v)).monospacedDigit() }
                }
                LabeledContent("reliable", value: "\(assessment.isReliable)")
                if let key = assessment.coachingKey {
                    LabeledContent("coaching", value: key)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        } label: {
            VerdictHeadlineView(
                headline: PronunciationVerdictHeadline.make(pattern: pattern, assessment: assessment)
            )
        }
    }
}
```

### 6.8 `recorder/MoraFixtureRecorder/PronunciationVerdictHeadline.swift` (NEW)

Pure function + small value type that captures the 7-case display
logic from §5.1. Isolated from SwiftUI so it can be unit-tested directly.

```swift
struct PronunciationVerdictHeadlineContent: Equatable {
    enum Tone { case pass, fail, warn }
    let tone: Tone
    let title: String
    let subtitle: String?
}

enum PronunciationVerdictHeadline {
    static func make(
        pattern: FixturePattern,
        assessment: PhonemeTrialAssessment
    ) -> PronunciationVerdictHeadlineContent {
        // §5.1 truth table: (observed label, isReliable, expected from pattern)
        // → tone + title + subtitle
    }
}
```

The 7 cases enumerated in §5.1 of this spec map 1:1 to test cases in
`PronunciationVerdictHeadlineTests` (§10.2).

### 6.9 `recorder/MoraFixtureRecorder/TakeRow.swift` (MODIFIED)

Add a compact verdict badge on the right, lazy-evaluated on appear:

```swift
struct TakeRow: View {
    let url: URL
    @Bindable var store: RecorderStore
    let pattern: FixturePattern

    var body: some View {
        HStack {
            // ... existing take number + duration ...

            VerdictBadge(cached: store.savedVerdicts[url], pattern: pattern)
                .task(id: url) {
                    await store.evaluateSavedTake(url: url, pattern: pattern)
                }

            ShareLink(items: store.takeArtifacts(for: url)) { Image(systemName: "square.and.arrow.up") }
            Button(role: .destructive) { store.deleteTake(url: url) } label: {
                Image(systemName: "trash")
            }
        }
    }
}

struct VerdictBadge: View {
    let cached: PhonemeTrialAssessment?
    let pattern: FixturePattern

    var body: some View {
        if let a = cached {
            // compact tone icon + short title
        } else {
            ProgressView().controlSize(.mini)
        }
    }
}
```

`task(id: url)` restarts lazy evaluation if the row's `url` changes (should
be rare; takes list is stable).

## 7. Data Flow

### 7.1 Happy path — record, evaluate, save

```
PatternDetailView appears for pattern aeuh-cat-correct.
User taps Record:
  store.toggleRecording(pattern: aeuh-cat-correct)
    evaluationTask?.cancel()
    pendingVerdict = .idle
    recorder.start(); recordingState = .recording

User speaks "cat" for ~1.5s. Taps Stop:
  store.toggleRecording(pattern: aeuh-cat-correct)
    recorder.stop(); samples = recorder.drain()
    recordingState = .captured(snapshot)
    evaluateCaptured(pattern: aeuh-cat-correct)
      pendingVerdict = .evaluating
      [Task.detached]
        assessment = await runner.evaluate(
          samples, 16_000, "cat", "æ", ["k","æ","t"], 1
        )
        // assessment.label = .matched, features = ["F1": 720], score = 100
        [MainActor.run]
          pendingVerdict = .ready(assessment)

UI: VerdictPanel re-renders → VerdictSummary with "✓ matched", F1 = 720.0,
score 100/100, reliable.

User taps Save:
  store.save(pattern: aeuh-cat-correct)
    FixtureWriter.writeTake(...) → wavURL = .../adult/aeuh/cat-correct-take1.wav
    savedVerdicts[wavURL] = assessment
    pendingVerdict = .idle
    recordingState = .idle

UI: Takes section appends new row. TakeRow.VerdictBadge reads
savedVerdicts[wavURL] directly — no lazy eval needed (already cached).
```

### 7.2 Mismatch — verdict disagrees, user re-records

```
Pattern: rl-light-correct (expected matched /l/)
User speaks "light" → Stop.
assessment.label = .substitutedBy(Phoneme(ipa: "r"))
assessment.features = ["F3": 1656.0], score = 40, isReliable = true.
pendingVerdict = .ready(assessment)

UI VerdictPanel:
  ✗ heard /r/ (expected matched /l/)
  [expand] F3 = 1656.0, reliable = true, coaching = rl.subR

User taps Record without Saving:
  store.toggleRecording(pattern: rl-light-correct)
    evaluationTask?.cancel()      // .ready is final, cancel is a no-op
    pendingVerdict = .idle
    recorder.start(); recordingState = .recording

The captured snapshot is discarded. No WAV is written.
```

### 7.3 Lazy evaluation of an older take

```
User opens PatternDetailView for rl-right-correct. Two existing takes from
a previous app launch are listed: take1, take2.

Each TakeRow's .task(id: url) fires on appear:
  store.evaluateSavedTake(url: .../rl/right-correct-take1.wav, pattern:)
    savedVerdicts[url] is nil
    samples = await FixtureRecorder.decode(from: url)
    assessment = await runner.evaluate(samples, ...)
    savedVerdicts[url] = assessment

UI: VerdictBadge re-renders with the cached verdict (progress spinner →
tone icon + title). Happens in parallel for both rows.
```

## 8. Impact on Other Components

| Component | Change |
|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationEvaluationRunner.swift` | NEW file (§6.1). |
| `Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationEvaluationRunnerTests.swift` | NEW file (§10.1). |
| `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift` | Reduced to delegation (§6.2). Public API preserved. |
| `dev-tools/pronunciation-bench/Tests/BenchTests/EngineARunnerDelegationTests.swift` | NEW file (§10.3) — golden test proving iPad / bench verdict equivalence. |
| `recorder/project.yml` | Declares `MoraEngines` + `MoraCore` dependencies (§6.3). |
| `recorder/MoraFixtureRecorder/RecorderStore.swift` | Adds pendingVerdict / savedVerdicts / runner / evaluateCaptured / evaluateSavedTake (§6.4). |
| `recorder/MoraFixtureRecorder/FixtureRecorder.swift` | Adds `static decode(from:)` (§6.5). |
| `recorder/MoraFixtureRecorder/PatternDetailView.swift` | Uses `toggleRecording(pattern:)`; embeds `VerdictPanel` (§6.6). |
| `recorder/MoraFixtureRecorder/VerdictPanel.swift` | NEW file (§6.7). |
| `recorder/MoraFixtureRecorder/PronunciationVerdictHeadline.swift` | NEW file (§6.8). |
| `recorder/MoraFixtureRecorder/TakeRow.swift` | Adds `VerdictBadge`; `.task(id: url)` lazy eval kick (§6.9). |
| `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift` | Expanded (§10.2). |
| `recorder/MoraFixtureRecorderTests/PronunciationVerdictHeadlineTests.swift` | NEW file (§10.2). |
| `recorder/README.md` | New "Evaluation" section describing Stop → verdict → Save flow. |
| `FixtureMetadata` / sidecar JSON schema | **No change.** |
| Main Mora app (`Mora/`, `Packages/MoraUI/`, etc.) | **No change.** |
| CI gates / workflows | **No change.** Recorder stays outside CI scope; no new binary-gate entries required because no new symbols are added to the main app. |

## 9. Error Handling

| Condition | Behavior |
|---|---|
| Evaluator returns `.unclear` label | `pendingVerdict = .ready(a)` with `a.label == .unclear`. UI shows ⚠︎ headline "audio unclear — re-record longer/louder". |
| `assessment.isReliable == false` | ⚠︎ tone with the actual label still shown (e.g. "(unreliable) heard /r/"). Features / score still displayed for diagnosis. |
| `evaluateSavedTake` can't read WAV (file missing, corrupted) | `savedVerdicts[url]` stays nil. `VerdictBadge` falls back to a "—" glyph. The row remains usable (share, delete still work). A tap on the row re-triggers `.task(id: url)` and retries decode. |
| User taps Record mid-evaluation (race) | `evaluationTask.cancel()` + `pendingVerdict = .idle` fire before `recorder.start()`. The detached task's `if Task.isCancelled { return }` guard prevents a stale verdict from landing. Even if the MainActor hop races past the cancellation check, the `if case .evaluating` guard on `pendingVerdict` rejects the assignment because the new Record already moved it to `.idle`. |
| Save before evaluation completes | `save(pattern:)` runs normally. `pendingVerdict` is not `.ready`, so no entry is added to `savedVerdicts`. The take lands on disk; `TakeRow.task(id: url)` triggers lazy evaluation next render. |
| Save fails | Existing behavior: `recordingState = .saveFailed(msg)`. `pendingVerdict` is deliberately preserved so Retry-Save still caches the verdict on success. |
| Delete removes a cached verdict | `deleteTake(url:)` clears both files and `savedVerdicts[url]`. |
| Evaluator throws (it currently cannot — `evaluate` is non-throwing) | Not a path. If the protocol changes later, wrap in a local `do-try` and map to an `.unclear` verdict. |

## 10. Testing

### 10.1 `MoraEnginesTests/PronunciationEvaluationRunnerTests.swift` (NEW)

- `evaluate(...)` with a synthetic `voicedStop` + `phonemeSequenceIPA=["b","ɛ","r","i"]`, `targetPhonemeIndex=0`, `targetPhonemeIPA="b"` produces a `PhonemeTrialAssessment` whose `targetPhoneme.ipa == "b"` and whose localization matches what `FeatureBasedPronunciationEvaluator.evaluate(audio:expected:targetPhoneme:asr:)` returns for the same constructed `Word`.
- Fallback: when `phonemeSequenceIPA` is nil, runner constructs `Word.phonemes = [Phoneme(ipa: targetPhonemeIPA)]`, matching pre-B1 onset-only evaluation.
- Fallback: when `targetPhonemeIndex` is out of range, same fallback path.
- `Word.wordSurface`, `Word.graphemes` construction matches bench's current implementation.

### 10.2 `MoraFixtureRecorderTests/RecorderStoreTests.swift` (EXPANDED) + `PronunciationVerdictHeadlineTests.swift` (NEW)

`RecorderStoreTests` additions:

- `toggleRecording(pattern:)` on Stop populates `pendingVerdict = .evaluating` synchronously, then advances to `.ready(a)` once the injected `FakeRunner` resolves.
- Stop → immediate Record cancels the evaluation task, returns `pendingVerdict` to `.idle`, and a late-arriving `FakeRunner` resolution does not flip `.idle` back to `.ready(…)`.
- Save with `pendingVerdict == .ready(a)` inserts into `savedVerdicts[wavURL]` and resets to `.idle`.
- Save with `pendingVerdict == .evaluating` does not populate `savedVerdicts` and keeps `pendingVerdict` intact.
- `deleteTake(url:)` removes both the disk artifacts and `savedVerdicts[url]`.
- `evaluateSavedTake(url:pattern:)` is idempotent — calling twice invokes `FakeRunner.evaluate` exactly once.

`PronunciationVerdictHeadlineTests` covers the 7 truth-table cases from §5.1 as named tests:
- `matched_expectedMatched_pass`
- `matched_expectedSub_fail` (produced too cleanly)
- `subY_expectedMatched_fail`
- `subY_expectedSubY_pass` (intended substitution confirmed)
- `subY_expectedSubX_fail` (wrong substitute)
- `drifted_expectedMatched_fail`
- `unclear_anyExpected_warn`
- Plus `unreliable_prefix` for `isReliable == false`.

### 10.3 `dev-tools/pronunciation-bench/Tests/BenchTests/EngineARunnerDelegationTests.swift` (NEW)

- Given a synthetic `LoadedFixture`, `EngineARunner().evaluate(loaded)` returns the same `PhonemeTrialAssessment` as a direct
  `PronunciationEvaluationRunner().evaluate(samples:sampleRate:wordSurface:targetPhonemeIPA:phonemeSequenceIPA:targetPhonemeIndex:)`
  called with the same primitives.
- The bench's existing CSV-writing golden test (`BenchTests` run at
  `(cd dev-tools/pronunciation-bench && swift test)`) continues to pass
  unchanged, proving the refactor is observationally invariant.

### 10.4 `FakeRunner` test double

```swift
actor FakeRunner: PronunciationRunning {
    var nextResult: PhonemeTrialAssessment = .unclear...
    var calls: Int = 0
    func evaluate(...) -> PhonemeTrialAssessment {
        calls += 1
        return nextResult
    }
}
```

Lives in `MoraFixtureRecorderTests` (recorder-specific test helper). Not
promoted to `MoraTesting` because the protocol `PronunciationRunning` is
defined in `MoraEngines`, not shared production API beyond the bench +
recorder use cases.

### 10.5 iPad smoke (manual)

Before merging, run on a physical iPad:

1. Record `rl-right-correct` → observe `✓ matched` verdict.
2. Record `rl-light-correct` poorly (short /l/) → observe `✗ heard /r/` verdict with F3 feature value.
3. Save both → return to list → observe verdict badges on each take row.
4. Kill and relaunch the app → open the same pattern → observe badges reappear via lazy evaluation on `TakeRow.task`.
5. Record, then immediately tap Record again before the verdict fires → observe no stale verdict leaks into the new capture cycle.

## 11. Phasing

**One PR.** The changes are mechanical and tightly coupled (runner move,
bench delegation, recorder wiring, UI shells) and leaving intermediate
states (e.g. runner in MoraEngines but bench still using its own copy)
would create pointless review surface. Internal commit order:

1. Add `PronunciationRunning` + `PronunciationEvaluationRunner` in `MoraEngines` with tests.
2. Reduce bench `EngineARunner` to delegation; add `EngineARunnerDelegationTests`. Bench swift test green.
3. Wire `MoraCore` + `MoraEngines` deps into `recorder/project.yml`. Regenerate via `xcodegen generate` (with the `DEVELOPMENT_TEAM` inject/revert dance per the existing memory).
4. Extend `RecorderStore` with verdict state + evaluation hooks. Add `FixtureRecorder.decode(from:)`. Change `toggleRecording` signature to `toggleRecording(pattern:)`.
5. Expand `RecorderStoreTests`; add `PronunciationVerdictHeadlineTests`.
6. Add `VerdictPanel`, `VerdictBadge`, `PronunciationVerdictHeadline`. Update `PatternDetailView` + `TakeRow`.
7. Update `recorder/README.md` with the new Stop → verdict → Save flow. iPad smoke (§10.5).

## 12. Open Questions

1. **Should `evaluateSavedTake` run on `TakeRow.task(id:)` or `onAppear`?**
   `task(id:)` is closer to Swift-native lifecycle and handles view reuse
   more cleanly, but reruns on any `url` identity shift. For the stable
   takes list this is fine. If reruns become noisy, switch to a manual
   `.task { … }` without id binding.
2. **What does the `VerdictBadge` show in the "—" (decode failed) case?**
   Default to a small `xmark.octagon` glyph with `.secondary` color, no
   subtitle. Users rarely hit this; tapping the row re-triggers decode.
3. **Score formatting — 0/100 vs 0–100 normalized vs percentage.** The
   evaluator returns `Int` already in 0–100. Display as `score NN/100`.
   Match bench CSV convention.
4. **Does the `PronunciationRunning` protocol belong in `MoraEngines` or in
   a shared "Testing" package?** It's a production protocol with a single
   production impl; the test double is ad-hoc in the recorder's test
   target. Keeping it in `MoraEngines` avoids creating new packages.
5. **Performance floor.** Engine A on a 1.5 s clip is ~30–80 ms per the
   PR #64 bench times. The detached task off the MainActor avoids UI
   stutter. If later measurement shows >150 ms p95 on iPad hardware,
   consider pre-computing feature extraction during the capture tap
   callback rather than post-Stop.

---

## Appendix A — Why not persist verdicts to sidecar

The sidecar JSON currently has `FixtureMetadata` fields describing the
*intent* of the recording (expected label, word, phoneme sequence). The
verdict is the *result* of evaluating a particular recording against that
intent; it is bound to the audio, not to the intent. Putting the verdict
in the sidecar would duplicate state the Mac bench re-derives anyway, add
a schema migration to support backwards-compat decoding of older sidecars,
and introduce drift risk: what if the recorder writes a verdict under an
earlier evaluator version than the bench later re-computes with? Keeping
verdicts in-memory-only sidesteps all of that.

The UX goal is served by the cache: a full set of just-recorded and
lazily-decoded older takes all show their verdict in the current Recorder
session. Cross-session verdicts would require persistence, but the user's
natural cross-session loop goes through AirDrop + bench anyway, which
re-evaluates definitionally.

## Appendix B — Why not expose an Engine B toggle behind a "debug" setting

Tempting but rejected. The recorder is already a dev tool; there is no
user-facing "prod vs dev" axis to gate on. Making Engine B available
through a toggle would just move the "which engine do I trust?" decision
into a settings screen, not solve it. When Engine B has a bench-validated
precision, a later spec will decide whether it replaces Engine A as the
iPad verdict source, runs alongside it for cross-check, or stays Mac-only.
Toggling is not the interesting design question.
