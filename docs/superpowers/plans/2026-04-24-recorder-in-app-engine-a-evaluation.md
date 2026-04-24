# Recorder In-App Engine A Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `FeatureBasedPronunciationEvaluator` (Engine A) into `recorder/MoraFixtureRecorder/` so each captured take is classified matched / substitutedBy / driftedWithin / unclear on device immediately after Stop, letting Yutaka decide Save vs re-record without round-tripping audio to the Mac bench.

**Architecture:** A new `PronunciationEvaluationRunner` in `MoraEngines` centralizes the "primitives → `PhonemeTrialAssessment`" path shared by the Recorder (post-Stop pre-Save inline verdict + `TakeRow` lazy badge) and bench (`EngineARunner` delegation). The Recorder gets an in-memory `pendingVerdict` state plus a `savedVerdicts: [URL: PhonemeTrialAssessment]` cache that live for the process; the sidecar JSON schema is unchanged. Engine B is out of scope — it remains unvalidated against real fixtures.

**Tech Stack:** Swift 6 (v5 language mode), SwiftUI, AVFoundation, XCTest. Apple Silicon iPad + Xcode 15+. XcodeGen regenerates `recorder/*.xcodeproj` from `recorder/project.yml`.

**Reference spec:** `docs/superpowers/specs/2026-04-24-recorder-in-app-engine-a-evaluation-design.md`.

---

## Conventions for every task

- Work from `/Users/yutaka.kondo/src/mora/.claude/worktrees/snug-moseying-spindle/` (the current worktree). **Do not `cd` back to the main repo root.**
- **Commit messages** follow repo style (lowercase prefix, imperative). Include `Co-Authored-By: Claude <noreply@anthropic.com>` per `project_mora_coauthor_allowed` memory.
- **English-only** in all source, tests, markdown, and commit messages per repo CLAUDE.md.
- **Do NOT skip hooks or `--no-verify`** under any circumstances.
- **Lint** with `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` after any edit that touches `Packages/` source. This matches CI.
- After any edit to `project.yml` files under `recorder/` or the repo root, regenerate the Xcode project per the **team-injection dance** below.

### Team-injection dance for XcodeGen

The `DEVELOPMENT_TEAM: 7BT28X9TQ9` must not be committed to `project.yml`. Before generating, inject; generate; revert. For the recorder:

```sh
cd /Users/yutaka.kondo/src/mora/.claude/worktrees/snug-moseying-spindle/recorder
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 7BT28X9TQ9', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
cd ..
```

### Build commands to remember

```sh
# MoraEngines package unit tests
(cd Packages/MoraEngines && swift test)

# MoraFixtures package unit tests
(cd Packages/MoraFixtures && swift test)

# Bench CLI tests
(cd dev-tools/pronunciation-bench && swift test)

# Main Mora app build (CI-equivalent; regression guard)
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO

# Recorder project build + tests (run on a simulator)
(cd recorder && xcodebuild build -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO)

(cd recorder && xcodebuild test -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO)
```

If the `iPad Pro 13-inch (M4)` simulator is not available, substitute with `xcrun simctl list devicetypes | grep iPad` to find an installed iPad.

---

## File Structure

```
Packages/MoraEngines/
  Sources/MoraEngines/Pronunciation/
    PronunciationEvaluationRunner.swift         [NEW]  Protocol + default runner
  Tests/MoraEnginesTests/
    PronunciationEvaluationRunnerTests.swift    [NEW]

dev-tools/pronunciation-bench/
  Sources/Bench/EngineARunner.swift             [MOD]  Reduced to delegation
  Tests/BenchTests/
    EngineARunnerDelegationTests.swift          [NEW]  Verdict-parity guarantee

recorder/
  project.yml                                   [MOD]  Add MoraCore + MoraEngines deps
  MoraFixtureRecorder/
    RecorderStore.swift                         [MOD]  Verdict state + hooks
    FixtureRecorder.swift                       [MOD]  Add nonisolated decode helper
    PatternDetailView.swift                     [MOD]  Pass pattern to toggleRecording, embed VerdictPanel
    TakeRow.swift                               [MOD]  Add VerdictBadge with lazy eval
    VerdictPanel.swift                          [NEW]  Capture-section inline verdict
    VerdictBadge.swift                          [NEW]  Take-row badge
    PronunciationVerdictHeadline.swift          [NEW]  Pure view-model (7-case truth table)
  MoraFixtureRecorderTests/
    RecorderStoreTests.swift                    [MOD]  New test cases for verdict flow
    PronunciationVerdictHeadlineTests.swift     [NEW]
    FakeRunner.swift                            [NEW]  Test helper
  README.md                                     [MOD]  Document the new Stop → verdict → Save flow
```

Dep graph after changes:
- `MoraFixtures` stays leaf (no dep on MoraEngines / MoraCore).
- Recorder gains `MoraEngines` + `MoraCore` package deps (explicit, not transitive-only).
- Bench already depends on MoraEngines + MoraFixtures + MoraCore; no dep change.

---

## Task 1: Add `PronunciationRunning` + `PronunciationEvaluationRunner` to `MoraEngines`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationEvaluationRunner.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationEvaluationRunnerTests.swift`

- [ ] **Step 1: Write the failing happy-path test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationEvaluationRunnerTests.swift`:

```swift
import MoraCore
import MoraEngines
import XCTest

@MainActor
final class PronunciationEvaluationRunnerTests: XCTestCase {

    // When the full phoneme sequence + valid index is provided, the runner
    // constructs a medial-vowel Word and produces an assessment whose
    // target matches `targetPhonemeIPA`. Uses the existing synthetic audio
    // helper to generate a spectrally-clean /æ/ vowel region; F1 around
    // 700 Hz should land on the /æ/ side of the 590 Hz boundary.
    func testEvaluatesMedialVowelWithSequence() async {
        let runner = PronunciationEvaluationRunner()
        let samples = SyntheticAudio.sineMix(
            frequencies: [700, 1400], gains: [0.5, 0.3],
            durationMs: 600
        ).samples

        let assessment = await runner.evaluate(
            samples: samples,
            sampleRate: 16_000,
            wordSurface: "cat",
            targetPhonemeIPA: "æ",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1
        )

        XCTAssertEqual(assessment.targetPhoneme.ipa, "æ")
        XCTAssertEqual(assessment.label, .matched)
    }

    // Legacy-sidecar fallback: sequence absent, runner builds Word with
    // phonemes == [target] and evaluates onset-only. Output target phoneme
    // must still match the requested IPA.
    func testFallbackOnsetOnlyWhenSequenceAbsent() async {
        let runner = PronunciationEvaluationRunner()
        let samples = SyntheticAudio.sineMix(
            frequencies: [700, 1400], gains: [0.5, 0.3],
            durationMs: 300
        ).samples

        let assessment = await runner.evaluate(
            samples: samples,
            sampleRate: 16_000,
            wordSurface: "cat",
            targetPhonemeIPA: "æ",
            phonemeSequenceIPA: nil,
            targetPhonemeIndex: nil
        )

        XCTAssertEqual(assessment.targetPhoneme.ipa, "æ")
    }

    // Malformed index: sequence present but index out of range falls back
    // to onset-only, identical to the fully-absent case. Never crashes.
    func testFallbackOnOutOfRangeTargetIndex() async {
        let runner = PronunciationEvaluationRunner()
        let samples = SyntheticAudio.sineMix(
            frequencies: [700, 1400], gains: [0.5, 0.3],
            durationMs: 300
        ).samples

        let assessment = await runner.evaluate(
            samples: samples,
            sampleRate: 16_000,
            wordSurface: "cat",
            targetPhonemeIPA: "æ",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 7
        )

        XCTAssertEqual(assessment.targetPhoneme.ipa, "æ")
    }
}
```

- [ ] **Step 2: Run tests — expected to fail**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter PronunciationEvaluationRunnerTests)
```
Expected: compile error `cannot find 'PronunciationEvaluationRunner' in scope`.

- [ ] **Step 3: Create `PronunciationEvaluationRunner.swift`**

Create `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationEvaluationRunner.swift`:

```swift
import Foundation
import MoraCore

/// Shared entry point for Engine A evaluation. Both the Fixture Recorder
/// (in-app pre-Save verdict) and the Mac bench CLI (`EngineARunner`) route
/// through this runner so iPad and Mac produce identical assessments for
/// the same audio + pattern primitives.
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

- [ ] **Step 4: Run tests — expected to pass**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter PronunciationEvaluationRunnerTests)
```
Expected: all three tests pass.

- [ ] **Step 5: Run full MoraEngines test suite — no regressions**

Run:
```sh
(cd Packages/MoraEngines && swift test)
```
Expected: full suite green (previous 223 tests + 3 new = 226 tests).

- [ ] **Step 6: Lint**

Run:
```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```
Expected: silent (lint passes).

If lint complains, apply `swift-format format --in-place` against the specific file and re-run lint.

- [ ] **Step 7: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationEvaluationRunner.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationEvaluationRunnerTests.swift

git commit -m "$(cat <<'EOF'
engines: add PronunciationEvaluationRunner shared across recorder + bench

Extract the primitives-to-PhonemeTrialAssessment path from bench's
EngineARunner into a reusable runner in MoraEngines. The runner takes
raw audio samples + word + target + phoneme sequence + target index,
constructs the expected Word, and calls FeatureBasedPronunciationEvaluator.
Fallback to onset-only Word when sequence or index is absent or invalid,
matching pre-B1 legacy-sidecar behavior.

PronunciationRunning protocol exposes this path for test injection;
PronunciationEvaluationRunner is the production implementation.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Reduce bench `EngineARunner` to delegation + parity test

**Files:**
- Modify: `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift`
- Create: `dev-tools/pronunciation-bench/Tests/BenchTests/EngineARunnerDelegationTests.swift`

- [ ] **Step 1: Write the failing parity test**

Create `dev-tools/pronunciation-bench/Tests/BenchTests/EngineARunnerDelegationTests.swift`:

```swift
import Bench
import Foundation
import MoraCore
import MoraEngines
import MoraFixtures
import XCTest

final class EngineARunnerDelegationTests: XCTestCase {

    // The bench's EngineARunner must produce a PhonemeTrialAssessment
    // byte-for-byte identical to what PronunciationEvaluationRunner
    // produces when fed the same primitives. This guarantees the iPad
    // recorder (which calls the runner directly) and the Mac bench
    // (which goes through EngineARunner) never disagree on the same
    // audio.
    func testBenchDelegatesToPronunciationEvaluationRunner() async throws {
        // Synthetic /æ/-ish tone — stable and cheap to generate here
        // without pulling MoraTesting helpers into the bench target.
        let durationMs = 600
        let sampleRate: Double = 16_000
        let n = Int(Double(durationMs) / 1000.0 * sampleRate)
        var samples = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let s = 0.5 * sin(2 * .pi * 700 * t) + 0.3 * sin(2 * .pi * 1400 * t)
            samples[i] = Float(s)
        }

        let metadata = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            sampleRate: sampleRate,
            durationSeconds: Double(durationMs) / 1000.0,
            speakerTag: .adult,
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            patternID: "aeuh-cat-correct"
        )
        let loaded = LoadedFixture(
            pair: FixturePair(
                basename: "cat-correct-take1",
                wavURL: URL(fileURLWithPath: "/dev/null"),
                sidecarURL: URL(fileURLWithPath: "/dev/null")
            ),
            metadata: metadata,
            samples: samples,
            sampleRate: sampleRate
        )

        let direct = await PronunciationEvaluationRunner().evaluate(
            samples: samples,
            sampleRate: sampleRate,
            wordSurface: metadata.wordSurface,
            targetPhonemeIPA: metadata.targetPhonemeIPA,
            phonemeSequenceIPA: metadata.phonemeSequenceIPA,
            targetPhonemeIndex: metadata.targetPhonemeIndex
        )
        let viaBench = await EngineARunner().evaluate(loaded)

        XCTAssertEqual(direct.label, viaBench.label)
        XCTAssertEqual(direct.targetPhoneme.ipa, viaBench.targetPhoneme.ipa)
        XCTAssertEqual(direct.score, viaBench.score)
        XCTAssertEqual(direct.isReliable, viaBench.isReliable)
        XCTAssertEqual(direct.features, viaBench.features)
        XCTAssertEqual(direct.coachingKey, viaBench.coachingKey)
    }
}
```

- [ ] **Step 2: Run the test — expected to fail**

Run:
```sh
(cd dev-tools/pronunciation-bench && swift test --filter EngineARunnerDelegationTests)
```
Expected: either test fails because `EngineARunner` and direct runner produce minor differences (should not, but the failure might also be "type changes needed for injection") OR it passes because the current `EngineARunner` already reproduces the same logic. Either way, the test itself must compile.

*Note:* the current `EngineARunner` already has logic equivalent to the runner, so this test may pass out of the box. That is acceptable — the failure mode we care about is *regression* during Step 3. The test still earns its keep as a guard.

- [ ] **Step 3: Reduce bench `EngineARunner` to delegation**

Overwrite `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift`:

```swift
import Foundation
import MoraEngines
import MoraFixtures

/// Adapter that pulls FixtureMetadata-shaped input out of `LoadedFixture`
/// and hands the primitives to `PronunciationEvaluationRunner`. Exists so
/// `BenchCLI` keeps its current method-on-fixture call shape; new code
/// paths prefer `PronunciationEvaluationRunner` directly.
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

- [ ] **Step 4: Run the bench test suite — expected to pass**

Run:
```sh
(cd dev-tools/pronunciation-bench && swift test)
```
Expected: all BenchTests (FixtureLoader, SpeechAceClient, CSVWriter, new delegation test) pass.

- [ ] **Step 5: Commit**

```sh
git add dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift \
        dev-tools/pronunciation-bench/Tests/BenchTests/EngineARunnerDelegationTests.swift

git commit -m "$(cat <<'EOF'
bench: delegate EngineARunner to PronunciationEvaluationRunner

EngineARunner becomes a FixtureMetadata adapter around the shared
MoraEngines runner. Public API and BenchCLI are unchanged. Added
EngineARunnerDelegationTests to guarantee the bench output matches
what the recorder will produce for the same audio.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Wire `MoraCore` + `MoraEngines` deps into recorder project

**Files:**
- Modify: `recorder/project.yml`

- [ ] **Step 1: Inspect current `recorder/project.yml` structure**

Run:
```sh
cat recorder/project.yml
```
Confirm `packages:` block has only `MoraFixtures` today; `targets.MoraFixtureRecorder.dependencies:` lists only `- package: MoraFixtures`.

- [ ] **Step 2: Edit `recorder/project.yml`**

Replace the `packages:` and `targets.MoraFixtureRecorder.dependencies:` blocks. After the edit, the file should contain:

```yaml
packages:
  MoraFixtures:
    path: ../Packages/MoraFixtures
  MoraCore:
    path: ../Packages/MoraCore
  MoraEngines:
    path: ../Packages/MoraEngines
```

and

```yaml
    dependencies:
      - package: MoraFixtures
      - package: MoraCore
      - package: MoraEngines
```

- [ ] **Step 3: Regenerate Xcode project with team-injection dance**

Run (from worktree root):

```sh
cd recorder
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 7BT28X9TQ9', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
cd ..
```

Expected: `xcodegen generate` reports `Created project at /Users/.../recorder/Mora Fixture Recorder.xcodeproj`. `git status` shows `recorder/project.yml` clean (the team-id injection has been reverted) and the xcodeproj untracked (per `.gitignore`).

- [ ] **Step 4: Verify recorder project builds with the new deps**

Pick an installed iPad simulator:
```sh
xcrun simctl list devicetypes | grep iPad | head -5
```

Use the first iPad name in the build command (example uses `iPad Pro 13-inch (M4)`):

```sh
(cd recorder && xcodebuild build \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```

Expected: `BUILD SUCCEEDED`. If the build fails because `MoraEngines` / `MoraCore` aren't resolvable, double-check the `packages:` paths are relative to `recorder/`.

- [ ] **Step 5: Commit**

```sh
git add recorder/project.yml
git commit -m "$(cat <<'EOF'
recorder: depend on MoraEngines + MoraCore for Engine A evaluation

Adds the two packages as explicit dependencies so RecorderStore can
invoke PronunciationEvaluationRunner on captured audio. MoraEngines
transitively pulls MoraCore, but MoraCore is listed explicitly to
document the public-API surface used.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add `FixtureRecorder.decode(from:)` nonisolated static helper

**Files:**
- Modify: `recorder/MoraFixtureRecorder/FixtureRecorder.swift`
- Modify: `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift` (+ optional new test file — inlined here for brevity)

- [ ] **Step 1: Write the failing decode test**

Append to `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift` (top-level — add imports at file top if missing). Add this method inside the existing `RecorderStoreTests` class:

```swift
    func testFixtureRecorderDecodeReturnsMono16kSamples() throws {
        // Write a synthetic mono 16 kHz WAV to tempDir, decode it, and
        // verify sample count matches the expected frame count.
        let url = tempDir.appendingPathComponent("synth.wav")
        let durationSeconds = 0.25
        let sampleRate = 16_000.0
        let expectedFrames = Int(durationSeconds * sampleRate)

        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return XCTFail("AVAudioFormat init failed") }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: fmt, frameCapacity: AVAudioFrameCount(expectedFrames)
        ) else { return XCTFail("AVAudioPCMBuffer alloc failed") }
        buffer.frameLength = AVAudioFrameCount(expectedFrames)
        for i in 0..<expectedFrames {
            buffer.floatChannelData![0][i] = Float(sin(
                2 * .pi * 440 * Double(i) / sampleRate
            ))
        }
        try file.write(from: buffer)

        let samples = try FixtureRecorder.decode(from: url)
        XCTAssertEqual(samples.count, expectedFrames)
        XCTAssertFalse(samples.allSatisfy { $0 == 0 })
    }
```

Add `import AVFoundation` at the top of the file if not already present.

- [ ] **Step 2: Run test — expected to fail**

Pick a simulator (as in Task 3) and run:
```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testFixtureRecorderDecodeReturnsMono16kSamples \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: compile error `type 'FixtureRecorder' has no member 'decode'`.

- [ ] **Step 3: Implement `decode(from:)` in `FixtureRecorder.swift`**

Append this helper to `recorder/MoraFixtureRecorder/FixtureRecorder.swift` (inside the class, below `append(convert:with:to:)`):

```swift
    /// Reads `url` as a WAV and returns 16 kHz mono Float32 samples — the
    /// same format the recorder captures. `nonisolated` so synchronous
    /// AVAudioFile IO runs on the caller's executor rather than the main
    /// actor; callers in `RecorderStore` wrap this in `Task.detached`.
    nonisolated public static func decode(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let hardwareFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000, channels: 1, interleaved: false
        ) else { throw FixtureRecorderError.converterInitFailed }
        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat)
        else { throw FixtureRecorderError.converterInitFailed }
        guard let inBuffer = AVAudioPCMBuffer(
            pcmFormat: hardwareFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else { throw FixtureRecorderError.converterInitFailed }
        try file.read(into: inBuffer)

        let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: outCapacity
        ) else { throw FixtureRecorderError.converterInitFailed }

        var done = false
        let input: AVAudioConverterInputBlock = { _, outStatus in
            if done { outStatus.pointee = .noDataNow; return nil }
            done = true; outStatus.pointee = .haveData; return inBuffer
        }
        var error: NSError?
        _ = converter.convert(to: outBuffer, error: &error, withInputFrom: input)
        if let error { throw error }
        guard let channel = outBuffer.floatChannelData else {
            throw FixtureRecorderError.converterInitFailed
        }
        return Array(
            UnsafeBufferPointer(start: channel[0], count: Int(outBuffer.frameLength))
        )
    }
```

- [ ] **Step 4: Run the test — expected to pass**

Rerun the same `xcodebuild test -only-testing:…` command. Expected: test passes.

- [ ] **Step 5: Commit**

```sh
git add recorder/MoraFixtureRecorder/FixtureRecorder.swift \
        recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift
git commit -m "$(cat <<'EOF'
recorder: add FixtureRecorder.decode(from:) for lazy take evaluation

Nonisolated static helper that mirrors the recorder's own capture-time
AVAudioConverter setup (16 kHz mono Float32) in reverse. Used by
RecorderStore.evaluateSavedTake to lazily evaluate takes from previous
sessions when their TakeRow first appears.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Add `PendingVerdict`, `FakeRunner`, and `RecorderStore` state fields

**Files:**
- Modify: `recorder/MoraFixtureRecorder/RecorderStore.swift`
- Create: `recorder/MoraFixtureRecorderTests/FakeRunner.swift`

- [ ] **Step 1: Create `FakeRunner.swift` test helper**

Create `recorder/MoraFixtureRecorderTests/FakeRunner.swift`:

```swift
import Foundation
import MoraCore
import MoraEngines

/// Deterministic PronunciationRunning double for recorder tests. Calls
/// are recorded and resolved against `nextResult`. Isolated to an actor
/// so stored state is thread-safe when tests await across MainActor hops.
actor FakeRunner: PronunciationRunning {
    var nextResult: PhonemeTrialAssessment = PhonemeTrialAssessment(
        targetPhoneme: Phoneme(ipa: "a"),
        label: .matched,
        score: 100,
        coachingKey: nil,
        features: [:],
        isReliable: true
    )
    private(set) var callCount: Int = 0
    private(set) var lastSamples: [Float] = []

    /// Continuation used by tests to block evaluator resolution until
    /// they explicitly call `resume()`, modelling the "evaluation still
    /// running when Record is tapped again" race.
    private var pendingCompletion: CheckedContinuation<Void, Never>?

    func setNextResult(_ r: PhonemeTrialAssessment) {
        nextResult = r
    }

    func waitForNextEvaluateAndSuspend() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            pendingCompletion = c
        }
    }

    func resume() {
        pendingCompletion?.resume()
        pendingCompletion = nil
    }

    func evaluate(
        samples: [Float],
        sampleRate: Double,
        wordSurface: String,
        targetPhonemeIPA: String,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?
    ) async -> PhonemeTrialAssessment {
        callCount += 1
        lastSamples = samples
        if pendingCompletion != nil {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                pendingCompletion = c
            }
        }
        return nextResult
    }
}
```

- [ ] **Step 2: Add `PendingVerdict` enum + fields to `RecorderStore`**

At the top of `recorder/MoraFixtureRecorder/RecorderStore.swift`, add the import:

```swift
import MoraCore
import MoraEngines
```

Below the existing `RecordingState` enum (around line 30), add:

```swift
public enum PendingVerdict: Sendable, Equatable {
    case idle
    case evaluating
    case ready(PhonemeTrialAssessment)
}
```

Inside the `RecorderStore` class, add these new stored properties (place near `takesRevision`):

```swift
    public var pendingVerdict: PendingVerdict = .idle
    public private(set) var savedVerdicts: [URL: PhonemeTrialAssessment] = [:]

    private var evaluationTask: Task<Void, Never>?
    private let runner: any PronunciationRunning
```

Modify the `init` signature:

```swift
    public init(
        documentsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        recorder: FixtureRecorder? = nil,
        runner: any PronunciationRunning = PronunciationEvaluationRunner()
    ) {
        // ... existing body ...
        self.runner = runner
        // continue existing assignments
    }
```

(Place `self.runner = runner` right after `self.recorder = recorder ?? FixtureRecorder()`. The rest of the init body is unchanged.)

- [ ] **Step 3: Verify the recorder project still builds**

```sh
(cd recorder && xcodebuild build \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10)
```
Expected: `BUILD SUCCEEDED`. The new fields compile but are not yet exercised.

- [ ] **Step 4: Commit**

```sh
git add recorder/MoraFixtureRecorder/RecorderStore.swift \
        recorder/MoraFixtureRecorderTests/FakeRunner.swift
git commit -m "$(cat <<'EOF'
recorder: add PendingVerdict enum + RecorderStore eval state + FakeRunner

Introduces the state machine for per-capture evaluation. No callsite yet
invokes the runner; that wiring lands in the next commit where
toggleRecording gains the (pattern:) parameter and kicks off evaluateCaptured.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Change `toggleRecording` to `toggleRecording(pattern:)` + implement `evaluateCaptured`

**Files:**
- Modify: `recorder/MoraFixtureRecorder/RecorderStore.swift`
- Modify: `recorder/MoraFixtureRecorder/PatternDetailView.swift`
- Modify: `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift`

- [ ] **Step 1: Write failing tests for the verdict state machine**

Append the following test methods inside the existing `RecorderStoreTests` class. They use `FakeRunner` (injected via the new `RecorderStore.init(runner:)` param):

```swift
    func testToggleRecordingKeepsPendingIdleInitially() async throws {
        let fake = FakeRunner()
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            runner: fake
        )
        XCTAssertEqual(store.pendingVerdict, .idle)
    }

    func testStopRunsEvaluatorAndPublishesReady() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "æ"),
            label: .matched, score: 100,
            coachingKey: nil, features: ["F1": 720.0],
            isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let fixtureRecorder = StubRecorder()
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: fixtureRecorder, runner: fake
        )

        // Start "recording" (StubRecorder no-op) then stop. StubRecorder
        // returns 24000 deterministic float samples when drained.
        store.toggleRecording(pattern: pattern)  // → .recording
        store.toggleRecording(pattern: pattern)  // → .captured + .evaluating

        XCTAssertEqual(store.pendingVerdict, .evaluating)

        // Wait for evaluation task to resolve.
        await store.waitForPendingVerdict(.ready(expected), timeout: 1.0)
        XCTAssertEqual(store.pendingVerdict, .ready(expected))
        let callCount = await fake.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testRecordAgainCancelsStaleEvaluation() async throws {
        let fake = FakeRunner()
        await fake.waitForNextEvaluateAndSuspend()  // arm suspension

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let fixtureRecorder = StubRecorder()
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: fixtureRecorder, runner: fake
        )

        store.toggleRecording(pattern: pattern)  // → .recording
        store.toggleRecording(pattern: pattern)  // → .captured + kicks evaluate (suspended)
        XCTAssertEqual(store.pendingVerdict, .evaluating)

        // User taps Record again while evaluation is suspended.
        store.toggleRecording(pattern: pattern)  // cancels, → .recording
        XCTAssertEqual(store.pendingVerdict, .idle)

        // Release the suspended evaluator; its late-arriving result must
        // not flip pendingVerdict back to .ready(…).
        await fake.resume()
        try await Task.sleep(nanoseconds: 50_000_000)  // 50 ms MainActor drain
        XCTAssertEqual(store.pendingVerdict, .idle)
    }
```

Two helper types are required (add above the class body, at file scope in the test file):

```swift
/// Test stub for `FixtureRecorder` that avoids AVAudioEngine. `drain()`
/// returns a deterministic 24_000-sample Float32 buffer so the
/// captured state has non-empty audio for the evaluator.
@MainActor
final class StubRecorder: FixtureRecorder {
    override func start() throws { /* no-op */ }
    override func stop() { /* no-op */ }
    override var isRunning: Bool { true }
}
```

Wait — `FixtureRecorder` is marked `public final` in the current file (§6.5). We need it non-final so tests can subclass, or switch `RecorderStore.recorder` from a concrete `FixtureRecorder` to a protocol.

For the purposes of this plan, relax `FixtureRecorder` from `final` to non-final. The change is:

```swift
// was: public final class FixtureRecorder
public class FixtureRecorder
```

Add this to Step 3 of this task (alongside the signature change). If the user prefers protocol-based injection, convert later; for v1 subclassing is the simpler path.

Also add a helper on `RecorderStore` for the tests (inside the class, public):

```swift
    /// Test helper: spin on MainActor until `pendingVerdict` reaches
    /// `target` or `timeout` seconds elapse. Non-production.
    public func waitForPendingVerdict(
        _ target: PendingVerdict,
        timeout: TimeInterval
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while pendingVerdict != target && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)  // 5 ms
        }
    }
```

- [ ] **Step 2: Run the new tests — expected to fail**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testToggleRecordingKeepsPendingIdleInitially \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testStopRunsEvaluatorAndPublishesReady \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testRecordAgainCancelsStaleEvaluation \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30)
```
Expected: compile error `argument 'pattern:' missing in call`, or `cannot override final class`.

- [ ] **Step 3: Change `FixtureRecorder` to non-final + patch its `drain()` for the stub**

In `recorder/MoraFixtureRecorder/FixtureRecorder.swift`:
- Remove `final` from `public final class FixtureRecorder`.
- Mark the following methods `open` so the stub can override them: `start()`, `stop()`, `drain()`, `isRunning`. The easiest form:
  ```swift
  open func start() throws { ... }
  open func stop() { ... }
  open func drain() -> [Float] { ... }
  open var isRunning: Bool { isRecording }
  ```

Also extend `StubRecorder` in the test file with:
```swift
    override func drain() -> [Float] {
        // 1.5 s of silence is enough audio for the evaluator to localize
        // and run; `FakeRunner` doesn't inspect samples in production
        // tests. `lastSamples` on the fake still records what was sent.
        Array(repeating: 0, count: 24_000)
    }
```

- [ ] **Step 4: Change `toggleRecording` signature + implement `evaluateCaptured`**

In `RecorderStore.swift`, replace:

```swift
    public func toggleRecording() {
        switch recordingState {
        case .idle, .saveFailed, .captured:
            do {
                try recorder.start()
                recordingState = .recording
            } catch {
                recordingState = .saveFailed(String(describing: error))
            }
        case .recording:
            recorder.stop()
            let samples = recorder.drain()
            let duration = Double(samples.count) / recorder.targetSampleRate
            recordingState = .captured(
                CaptureSnapshot(samples: samples, durationSeconds: duration))
        case .saving:
            break
        }
    }
```

with:

```swift
    public func toggleRecording(pattern: FixturePattern) {
        switch recordingState {
        case .idle, .saveFailed, .captured:
            evaluationTask?.cancel()
            pendingVerdict = .idle
            do {
                try recorder.start()
                recordingState = .recording
            } catch {
                recordingState = .saveFailed(String(describing: error))
            }
        case .recording:
            recorder.stop()
            let samples = recorder.drain()
            let duration = Double(samples.count) / recorder.targetSampleRate
            recordingState = .captured(
                CaptureSnapshot(samples: samples, durationSeconds: duration))
            evaluateCaptured(pattern: pattern)
        case .saving:
            break
        }
    }

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
```

- [ ] **Step 5: Update `PatternDetailView` callsite**

In `recorder/MoraFixtureRecorder/PatternDetailView.swift`, change:

```swift
Button(store.isRecording ? "Stop" : "Record") {
    store.toggleRecording()
}
```

to:

```swift
Button(store.isRecording ? "Stop" : "Record") {
    store.toggleRecording(pattern: pattern)
}
```

- [ ] **Step 6: Run the three new tests — expected to pass**

Same command as Step 2. Expected: all three new tests pass.

- [ ] **Step 7: Run the full recorder test suite — no regressions**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: all pre-existing tests plus the 3 new tests pass.

- [ ] **Step 8: Commit**

```sh
git add recorder/MoraFixtureRecorder/RecorderStore.swift \
        recorder/MoraFixtureRecorder/FixtureRecorder.swift \
        recorder/MoraFixtureRecorder/PatternDetailView.swift \
        recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift
git commit -m "$(cat <<'EOF'
recorder: kick Engine A evaluation after Stop

toggleRecording gains a (pattern:) argument. On Stop, the store
captures the take and fires evaluateCaptured, which runs the injected
PronunciationRunning on a detached task and posts the result back
to pendingVerdict. A new Record press cancels any running evaluation
and double-guards the MainActor write so stale results never leak.

FixtureRecorder loses `final` and gains `open` methods so tests can
subclass it for audio stubbing.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Cache verdicts into `savedVerdicts` on Save / clear on Delete

**Files:**
- Modify: `recorder/MoraFixtureRecorder/RecorderStore.swift`
- Modify: `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift`

- [ ] **Step 1: Write failing tests for save / delete verdict caching**

Append to `RecorderStoreTests`:

```swift
    func testSaveCachesReadyVerdictInSavedVerdicts() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "æ"), label: .matched,
            score: 100, coachingKey: nil,
            features: ["F1": 720.0], isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: StubRecorder(), runner: fake
        )

        store.toggleRecording(pattern: pattern)
        store.toggleRecording(pattern: pattern)
        await store.waitForPendingVerdict(.ready(expected), timeout: 1.0)

        store.save(pattern: pattern)

        let writtenWav = store.takesOnDisk(for: pattern).first!
        XCTAssertEqual(store.savedVerdicts[writtenWav], expected)
        XCTAssertEqual(store.pendingVerdict, .idle)
    }

    func testSaveBeforeReadyDoesNotCacheAndKeepsEvaluating() async throws {
        let fake = FakeRunner()
        await fake.waitForNextEvaluateAndSuspend()

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: StubRecorder(), runner: fake
        )

        store.toggleRecording(pattern: pattern)
        store.toggleRecording(pattern: pattern)  // → .evaluating, suspended
        XCTAssertEqual(store.pendingVerdict, .evaluating)

        store.save(pattern: pattern)
        let writtenWav = store.takesOnDisk(for: pattern).first!
        XCTAssertNil(store.savedVerdicts[writtenWav])
        // Save resets recordingState to .idle but leaves pendingVerdict
        // untouched so the still-running evaluator can post its result.
        XCTAssertEqual(store.pendingVerdict, .evaluating)

        await fake.resume()
    }

    func testDeleteTakeClearsSavedVerdictEntry() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "æ"), label: .matched,
            score: 100, coachingKey: nil, features: [:], isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            recorder: StubRecorder(), runner: fake
        )

        store.toggleRecording(pattern: pattern)
        store.toggleRecording(pattern: pattern)
        await store.waitForPendingVerdict(.ready(expected), timeout: 1.0)
        store.save(pattern: pattern)
        let wav = store.takesOnDisk(for: pattern).first!
        XCTAssertNotNil(store.savedVerdicts[wav])

        store.deleteTake(url: wav)
        XCTAssertNil(store.savedVerdicts[wav])
    }
```

- [ ] **Step 2: Run — expected to fail**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testSaveCachesReadyVerdictInSavedVerdicts \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testSaveBeforeReadyDoesNotCacheAndKeepsEvaluating \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testDeleteTakeClearsSavedVerdictEntry \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: 3 failures — `savedVerdicts[writtenWav]` is nil, `deleteTake` doesn't clear it, `save` doesn't set it.

- [ ] **Step 3: Modify `save` and `deleteTake` in `RecorderStore.swift`**

Replace the existing `save(pattern:)` with:

```swift
    public func save(pattern: FixturePattern) {
        guard case let .captured(snapshot) = recordingState else { return }
        recordingState = .saving
        do {
            let n = nextTakeNumber(for: pattern)
            let dir = patternDirectory(for: pattern)
            let meta = pattern.metadata(
                capturedAt: Date(),
                sampleRate: recorder.targetSampleRate,
                durationSeconds: snapshot.durationSeconds,
                speakerTag: speakerTag
            )
            let output = try FixtureWriter.writeTake(
                samples: snapshot.samples, metadata: meta,
                pattern: pattern, takeNumber: n, into: dir
            )
            if case let .ready(assessment) = pendingVerdict {
                savedVerdicts[output.wav] = assessment
                pendingVerdict = .idle
            }
            // If pendingVerdict is .evaluating, leave it as-is — the late
            // assessment will land on the still-visible captured snapshot
            // path and a later lazy TakeRow.onAppear will fill savedVerdicts.
            recordingState = .idle
            takesRevision &+= 1
        } catch {
            recordingState = .saveFailed(String(describing: error))
        }
    }
```

Replace `deleteTake(url:)` with:

```swift
    public func deleteTake(url: URL) {
        try? fileManager.removeItem(at: url)
        let sidecar = url.deletingPathExtension().appendingPathExtension("json")
        try? fileManager.removeItem(at: sidecar)
        savedVerdicts[url] = nil
        takesRevision &+= 1
    }
```

- [ ] **Step 4: Run — expected to pass**

Same command as Step 2. Expected: all 3 tests green.

- [ ] **Step 5: Run the full recorder test suite**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: all previous tests + the 3 new ones pass. `testDeleteTakeBumpsTakesRevision` must still pass (deletion path wasn't structurally changed).

- [ ] **Step 6: Commit**

```sh
git add recorder/MoraFixtureRecorder/RecorderStore.swift \
        recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift
git commit -m "$(cat <<'EOF'
recorder: cache verdicts on Save; purge on Delete

When pendingVerdict == .ready(assessment) at Save time, the assessment
lands in savedVerdicts keyed by the written WAV URL and pendingVerdict
is cleared to .idle. If the evaluator is still running, pendingVerdict
is left untouched so the late result isn't discarded — lazy TakeRow
evaluation will fill the cache on next view. deleteTake clears the
cache entry alongside the disk artifacts.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Implement `evaluateSavedTake` lazy-eval path

**Files:**
- Modify: `recorder/MoraFixtureRecorder/RecorderStore.swift`
- Modify: `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift`

- [ ] **Step 1: Write failing tests for lazy eval**

Append to `RecorderStoreTests`:

```swift
    func testEvaluateSavedTakeCachesFirstCallOnly() async throws {
        let fake = FakeRunner()
        let expected = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "r"), label: .matched,
            score: 100, coachingKey: nil, features: [:], isReliable: true
        )
        await fake.setNextResult(expected)

        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!
        let wav = try writeSyntheticWav(
            for: pattern,
            takeNumber: 1,
            speaker: .adult,
            durationSeconds: 0.5
        )
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            runner: fake
        )
        store.speakerTag = .adult

        await store.evaluateSavedTake(url: wav, pattern: pattern)
        XCTAssertEqual(store.savedVerdicts[wav], expected)
        let firstCallCount = await fake.callCount
        XCTAssertEqual(firstCallCount, 1)

        await store.evaluateSavedTake(url: wav, pattern: pattern)
        let secondCallCount = await fake.callCount
        XCTAssertEqual(secondCallCount, 1, "idempotent: cache hit skips evaluator")
    }

    func testEvaluateSavedTakeNoopOnDecodeFailure() async throws {
        let fake = FakeRunner()
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!
        let bogus = tempDir.appendingPathComponent("does-not-exist.wav")
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults,
            runner: fake
        )

        await store.evaluateSavedTake(url: bogus, pattern: pattern)
        XCTAssertNil(store.savedVerdicts[bogus])
        let calls = await fake.callCount
        XCTAssertEqual(calls, 0)
    }
```

Add this instance method on `RecorderStoreTests` (captures `tempDir` from the test case rather than passing it in):

```swift
    func writeSyntheticWav(
        for pattern: FixturePattern,
        takeNumber: Int,
        speaker: SpeakerTag,
        durationSeconds: Double
    ) throws -> URL {
        let sampleRate = 16_000.0
        let frames = Int(durationSeconds * sampleRate)
        let dir = tempDir
            .appendingPathComponent(speaker.rawValue)
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(
            "\(pattern.filenameStem)-take\(takeNumber).wav"
        )
        guard let fmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate, channels: 1, interleaved: false
        ) else { throw NSError(domain: "writeSyntheticWav", code: 1) }
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: fmt, frameCapacity: AVAudioFrameCount(frames)
        ) else { throw NSError(domain: "writeSyntheticWav", code: 2) }
        buffer.frameLength = AVAudioFrameCount(frames)
        for i in 0..<frames {
            buffer.floatChannelData![0][i] = Float(
                0.4 * sin(2 * .pi * 440 * Double(i) / sampleRate)
            )
        }
        try file.write(from: buffer)
        return url
    }
```

- [ ] **Step 2: Run — expected to fail**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testEvaluateSavedTakeCachesFirstCallOnly \
  -only-testing:MoraFixtureRecorderTests/RecorderStoreTests/testEvaluateSavedTakeNoopOnDecodeFailure \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: compile error `value of type 'RecorderStore' has no member 'evaluateSavedTake'`.

- [ ] **Step 3: Add `evaluateSavedTake` in `RecorderStore.swift`**

Add inside the class, near `evaluateCaptured`:

```swift
    public func evaluateSavedTake(url: URL, pattern: FixturePattern) async {
        if savedVerdicts[url] != nil { return }
        let sampleRate = recorder.targetSampleRate
        let runner = self.runner
        let assessment = await Task.detached {
            () -> PhonemeTrialAssessment? in
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

- [ ] **Step 4: Run — expected to pass**

Same command as Step 2. Expected: both tests pass.

- [ ] **Step 5: Full recorder test suite**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: all tests green.

- [ ] **Step 6: Commit**

```sh
git add recorder/MoraFixtureRecorder/RecorderStore.swift \
        recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift
git commit -m "$(cat <<'EOF'
recorder: lazy-evaluate saved takes on demand

evaluateSavedTake reads a WAV from disk, routes through the injected
runner, and caches the verdict in savedVerdicts. Idempotent: a second
call for the same URL skips decode and evaluate. Decode failures
leave the cache untouched so TakeRow falls back to a "—" badge and
retry is a simple re-tap.

The decode + evaluate runs inside a single Task.detached so the main
actor never blocks on AVAudioFile IO.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add `PronunciationVerdictHeadline` (pure view-model) + tests

**Files:**
- Create: `recorder/MoraFixtureRecorder/PronunciationVerdictHeadline.swift`
- Create: `recorder/MoraFixtureRecorderTests/PronunciationVerdictHeadlineTests.swift`

- [ ] **Step 1: Write the failing 8-case truth-table tests**

Create `recorder/MoraFixtureRecorderTests/PronunciationVerdictHeadlineTests.swift`:

```swift
import MoraCore
import MoraEngines
import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

final class PronunciationVerdictHeadlineTests: XCTestCase {

    private func pattern(
        id: String,
        target: String,
        expected: ExpectedLabel,
        sub: String? = nil
    ) -> FixturePattern {
        FixturePattern(
            id: id,
            targetPhonemeIPA: target,
            expectedLabel: expected,
            substitutePhonemeIPA: sub,
            wordSurface: "w",
            phonemeSequenceIPA: [target],
            targetPhonemeIndex: 0,
            outputSubdirectory: "x",
            filenameStem: "stem"
        )
    }

    private func assessment(
        target: String,
        label: PhonemeAssessmentLabel,
        reliable: Bool = true
    ) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: target),
            label: label,
            score: label == .matched ? 100 : 50,
            coachingKey: nil,
            features: [:],
            isReliable: reliable
        )
    }

    func testMatched_expectedMatched_pass() {
        let p = pattern(id: "a", target: "æ", expected: .matched)
        let a = assessment(target: "æ", label: .matched)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .pass)
        XCTAssertEqual(h.title, "matched")
    }

    func testMatched_expectedSub_fail_tooClean() {
        let p = pattern(id: "b", target: "v", expected: .substitutedBy, sub: "b")
        let a = assessment(target: "v", label: .matched)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertTrue(h.title.contains("matched"))
        XCTAssertEqual(h.subtitle, "expected substitution /b/ — re-record with clearer /b/")
    }

    func testSub_expectedMatched_fail() {
        let p = pattern(id: "c", target: "l", expected: .matched)
        let a = assessment(target: "l", label: .substitutedBy(Phoneme(ipa: "r")))
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertEqual(h.title, "heard /r/")
        XCTAssertEqual(h.subtitle, "expected matched /l/")
    }

    func testSub_expectedSameSub_pass() {
        let p = pattern(id: "d", target: "l", expected: .substitutedBy, sub: "r")
        let a = assessment(target: "l", label: .substitutedBy(Phoneme(ipa: "r")))
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .pass)
        XCTAssertEqual(h.title, "heard /r/")
        XCTAssertEqual(h.subtitle, "matches expected substitution")
    }

    func testSub_expectedDifferentSub_fail() {
        let p = pattern(id: "e", target: "r", expected: .substitutedBy, sub: "l")
        let a = assessment(target: "r", label: .substitutedBy(Phoneme(ipa: "w")))
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertEqual(h.title, "heard /w/")
        XCTAssertEqual(h.subtitle, "expected substitution /l/")
    }

    func testDrifted_expectedMatched_fail() {
        let p = pattern(id: "f", target: "ʃ", expected: .matched)
        let a = assessment(target: "ʃ", label: .driftedWithin)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .fail)
        XCTAssertEqual(h.title, "drifted")
    }

    func testUnclear_warn() {
        let p = pattern(id: "g", target: "æ", expected: .matched)
        let a = assessment(target: "æ", label: .unclear)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .warn)
        XCTAssertEqual(h.title, "audio unclear")
        XCTAssertEqual(h.subtitle, "re-record longer/louder")
    }

    func testUnreliableAnnotatesHeadline() {
        let p = pattern(id: "h", target: "æ", expected: .matched)
        let a = assessment(target: "æ", label: .matched, reliable: false)
        let h = PronunciationVerdictHeadline.make(pattern: p, assessment: a)
        XCTAssertEqual(h.tone, .warn)
        XCTAssertTrue(h.title.contains("unreliable"))
    }
}
```

- [ ] **Step 2: Run — expected to fail**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -only-testing:MoraFixtureRecorderTests/PronunciationVerdictHeadlineTests \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10)
```
Expected: compile error `cannot find 'PronunciationVerdictHeadline' in scope`.

- [ ] **Step 3: Implement `PronunciationVerdictHeadline`**

Create `recorder/MoraFixtureRecorder/PronunciationVerdictHeadline.swift`:

```swift
import MoraCore
import MoraEngines
import MoraFixtures

public struct PronunciationVerdictHeadlineContent: Equatable, Sendable {
    public enum Tone: Sendable { case pass, fail, warn }
    public let tone: Tone
    public let title: String
    public let subtitle: String?
}

public enum PronunciationVerdictHeadline {

    /// Maps (pattern expectedLabel + substitute) × (assessment label +
    /// isReliable) into the 7-case display headline from the spec
    /// §5.1, plus the isReliable prefix.
    public static func make(
        pattern: FixturePattern,
        assessment: PhonemeTrialAssessment
    ) -> PronunciationVerdictHeadlineContent {
        // Unreliable short-circuits — the label is still shown but the
        // tone drops to .warn and the title is prefixed.
        if !assessment.isReliable {
            let core = coreHeadline(pattern: pattern, assessment: assessment)
            return PronunciationVerdictHeadlineContent(
                tone: .warn,
                title: "unreliable · \(core.title)",
                subtitle: core.subtitle
            )
        }
        return coreHeadline(pattern: pattern, assessment: assessment)
    }

    private static func coreHeadline(
        pattern: FixturePattern,
        assessment: PhonemeTrialAssessment
    ) -> PronunciationVerdictHeadlineContent {
        switch assessment.label {
        case .unclear:
            return .init(tone: .warn, title: "audio unclear",
                         subtitle: "re-record longer/louder")

        case .matched:
            switch pattern.expectedLabel {
            case .matched:
                return .init(tone: .pass, title: "matched", subtitle: nil)
            case .substitutedBy:
                let sub = pattern.substitutePhonemeIPA ?? "?"
                return .init(
                    tone: .fail, title: "matched",
                    subtitle: "expected substitution /\(sub)/ — re-record with clearer /\(sub)/"
                )
            case .driftedWithin:
                return .init(tone: .fail, title: "matched",
                             subtitle: "expected drift")
            }

        case .substitutedBy(let heard):
            switch pattern.expectedLabel {
            case .matched:
                return .init(
                    tone: .fail, title: "heard /\(heard.ipa)/",
                    subtitle: "expected matched /\(pattern.targetPhonemeIPA)/"
                )
            case .substitutedBy:
                let expected = pattern.substitutePhonemeIPA ?? "?"
                if heard.ipa == expected {
                    return .init(
                        tone: .pass, title: "heard /\(heard.ipa)/",
                        subtitle: "matches expected substitution"
                    )
                } else {
                    return .init(
                        tone: .fail, title: "heard /\(heard.ipa)/",
                        subtitle: "expected substitution /\(expected)/"
                    )
                }
            case .driftedWithin:
                return .init(
                    tone: .fail, title: "heard /\(heard.ipa)/",
                    subtitle: "expected drift"
                )
            }

        case .driftedWithin:
            switch pattern.expectedLabel {
            case .driftedWithin:
                return .init(tone: .pass, title: "drifted", subtitle: nil)
            default:
                return .init(tone: .fail, title: "drifted", subtitle: nil)
            }
        }
    }
}
```

- [ ] **Step 4: Run — expected to pass**

Same command as Step 2. Expected: 8 tests pass.

- [ ] **Step 5: Commit**

```sh
git add recorder/MoraFixtureRecorder/PronunciationVerdictHeadline.swift \
        recorder/MoraFixtureRecorderTests/PronunciationVerdictHeadlineTests.swift
git commit -m "$(cat <<'EOF'
recorder: add PronunciationVerdictHeadline view-model

Pure function mapping (FixturePattern, PhonemeTrialAssessment) into a
tone + title + subtitle triple. Isolates the 7-case truth table from
SwiftUI so it can be unit-tested directly. Unreliable assessments
collapse to a .warn tone with an "unreliable · " title prefix while
preserving the observed label for diagnosis.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Add `VerdictPanel` and embed in `PatternDetailView`

**Files:**
- Create: `recorder/MoraFixtureRecorder/VerdictPanel.swift`
- Modify: `recorder/MoraFixtureRecorder/PatternDetailView.swift`

(This task is primarily SwiftUI surface — no new behavior tests; the view-model already has test coverage.)

- [ ] **Step 1: Create `VerdictPanel.swift`**

Create `recorder/MoraFixtureRecorder/VerdictPanel.swift`:

```swift
import MoraCore
import MoraEngines
import MoraFixtures
import SwiftUI

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
        case .ready(let assessment):
            VerdictSummary(pattern: pattern, assessment: assessment)
        }
    }
}

struct VerdictSummary: View {
    let pattern: FixturePattern
    let assessment: PhonemeTrialAssessment
    @State private var expanded = false

    var body: some View {
        let headline = PronunciationVerdictHeadline.make(
            pattern: pattern, assessment: assessment
        )
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 4) {
                if let score = assessment.score {
                    LabeledContent("score", value: "\(score)/100")
                }
                ForEach(
                    assessment.features.sorted(by: { $0.key < $1.key }),
                    id: \.key
                ) { k, v in
                    LabeledContent(k) {
                        Text(String(format: "%.1f", v)).monospacedDigit()
                    }
                }
                LabeledContent("reliable", value: "\(assessment.isReliable)")
                if let key = assessment.coachingKey {
                    LabeledContent("coaching", value: key)
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        } label: {
            VerdictHeadlineView(content: headline)
        }
    }
}

struct VerdictHeadlineView: View {
    let content: PronunciationVerdictHeadlineContent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(content.title).font(.headline)
                if let subtitle = content.subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch content.tone {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch content.tone {
        case .pass: return .green
        case .fail: return .red
        case .warn: return .orange
        }
    }

    private var accessibilityLabel: String {
        let toneWord: String
        switch content.tone {
        case .pass: toneWord = "pass"
        case .fail: toneWord = "fail"
        case .warn: toneWord = "warning"
        }
        return [toneWord, content.title, content.subtitle ?? ""]
            .joined(separator: ". ")
    }
}
```

- [ ] **Step 2: Embed `VerdictPanel` into `PatternDetailView`'s Capture section**

Edit `recorder/MoraFixtureRecorder/PatternDetailView.swift`. Replace the current Capture section:

```swift
            Section("Capture") {
                Button(store.isRecording ? "Stop" : "Record") {
                    store.toggleRecording(pattern: pattern)
                }
                Button("Save") {
                    store.save(pattern: pattern)
                }
                .disabled(!store.hasCapturedSamples)
                if case let .captured(snapshot) = store.recordingState {
                    Text(String(format: "Captured: %.2fs", snapshot.durationSeconds))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
```

with:

```swift
            Section("Capture") {
                Button(store.isRecording ? "Stop" : "Record") {
                    store.toggleRecording(pattern: pattern)
                }
                Button("Save") {
                    store.save(pattern: pattern)
                }
                .disabled(!store.hasCapturedSamples)
                if case let .captured(snapshot) = store.recordingState {
                    Text(String(format: "Captured: %.2fs", snapshot.durationSeconds))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                VerdictPanel(pattern: pattern, pending: store.pendingVerdict)
            }
```

- [ ] **Step 3: Build the recorder project**

```sh
(cd recorder && xcodebuild build \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10)
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```sh
git add recorder/MoraFixtureRecorder/VerdictPanel.swift \
        recorder/MoraFixtureRecorder/PatternDetailView.swift
git commit -m "$(cat <<'EOF'
recorder: embed VerdictPanel in PatternDetailView Capture section

VerdictPanel shows the pending verdict inline between Stop and Save
with a DisclosureGroup that expands to features / score / isReliable /
coachingKey. Headline tone drives the icon + color.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Add `VerdictBadge` to `TakeRow` + lazy eval on appear

**Files:**
- Create: `recorder/MoraFixtureRecorder/VerdictBadge.swift`
- Modify: `recorder/MoraFixtureRecorder/TakeRow.swift`

- [ ] **Step 1: Create `VerdictBadge.swift`**

Create `recorder/MoraFixtureRecorder/VerdictBadge.swift`:

```swift
import MoraCore
import MoraEngines
import MoraFixtures
import SwiftUI

struct VerdictBadge: View {
    let cached: PhonemeTrialAssessment?
    let pattern: FixturePattern

    var body: some View {
        if let assessment = cached {
            let h = PronunciationVerdictHeadline.make(
                pattern: pattern, assessment: assessment
            )
            HStack(spacing: 4) {
                Image(systemName: iconName(h.tone))
                    .foregroundStyle(tint(h.tone))
                Text(h.title).font(.footnote).foregroundStyle(.secondary)
            }
            .accessibilityLabel(h.title)
        } else {
            ProgressView().controlSize(.mini)
        }
    }

    private func iconName(_ tone: PronunciationVerdictHeadlineContent.Tone) -> String {
        switch tone {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        }
    }

    private func tint(_ tone: PronunciationVerdictHeadlineContent.Tone) -> Color {
        switch tone {
        case .pass: return .green
        case .fail: return .red
        case .warn: return .orange
        }
    }
}
```

- [ ] **Step 2: Update `TakeRow.swift` with the badge + `.task(id:)` lazy eval**

Edit `recorder/MoraFixtureRecorder/TakeRow.swift`. Replace the entire body with:

```swift
import AVFoundation
import MoraFixtures
import SwiftUI

struct TakeRow: View {

    let wavURL: URL
    @Bindable var store: RecorderStore
    let pattern: FixturePattern

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            VerdictBadge(
                cached: store.savedVerdicts[wavURL],
                pattern: pattern
            )
            ShareLink(items: store.takeArtifacts(for: wavURL)) {
                Image(systemName: "square.and.arrow.up")
            }
            Button {
                store.deleteTake(url: wavURL)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .task(id: wavURL) {
            await store.evaluateSavedTake(url: wavURL, pattern: pattern)
        }
    }

    private var label: String {
        let stemPrefix = "\(pattern.filenameStem)-take"
        if let n = RecorderStore.takeNumber(from: wavURL, stemPrefix: stemPrefix) {
            return "take \(n)"
        }
        return "take ?"
    }
}
```

- [ ] **Step 3: Build + test the recorder project**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20)
```
Expected: `BUILD SUCCEEDED` + full test suite green.

- [ ] **Step 4: Commit**

```sh
git add recorder/MoraFixtureRecorder/VerdictBadge.swift \
        recorder/MoraFixtureRecorder/TakeRow.swift
git commit -m "$(cat <<'EOF'
recorder: badge each TakeRow with the cached verdict + lazy eval on appear

VerdictBadge reads store.savedVerdicts[url] and renders either the
tone + title from PronunciationVerdictHeadline or a spinner while
the lazy evaluation runs. `.task(id: wavURL)` fires evaluateSavedTake
exactly once per take URL — subsequent views are cache hits.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Update README, run full test sweep, iPad device smoke

**Files:**
- Modify: `recorder/README.md`

- [ ] **Step 1: Update `recorder/README.md`**

Replace the "Usage" section (lines 31–41 on current HEAD) with:

```markdown
## Usage

1. Launch the app on the iPad.
2. Pick the speaker toggle at the top of the list (adult / child).
3. Tap a pattern row (e.g. "right — /r/ matched").
4. Tap Record, say the word, tap Stop. The Capture section shows a
   verdict inline (✓ / ✗ / ⚠︎ with the label heard and — if different
   from expected — what it was expected to be). Tap the verdict to
   expand feature values, score, reliability, and coaching key.
5. If the verdict disagrees with the expected label, tap Record again
   to discard and re-take. If the verdict agrees (or you want to save
   anyway), tap Save. The take appears in the takes list with a
   matching badge.
6. To export a single take: tap its share icon → AirDrop → Mac.
7. To export the whole session: back on the list screen, tap the
   toolbar Share button ("Share adult takes (N)"). A zip of
   `<Documents>/<speaker>/` is built on the fly; AirDrop it to your Mac.

Takes recorded in previous sessions also show verdict badges in the
takes list — the recorder lazily evaluates them from disk on first view
and caches the result for the rest of the session.
```

Add a new section below Usage:

```markdown
## How the on-device verdict matches bench

The iPad's verdict is produced by `PronunciationEvaluationRunner` in
`MoraEngines`, which is the same type the Mac CLI
(`dev-tools/pronunciation-bench/`) routes `EngineARunner` through. When
the iPad says `matched` for a take, the bench will say `matched` for
the same take. Use the on-device verdict to decide whether to keep or
re-record before exporting; run bench to produce the CSV report for
committed fixtures.

Verdicts are **not persisted**. Killing and relaunching the recorder
wipes the session cache; re-opening a pattern detail lazily
re-evaluates saved takes the first time each `TakeRow` appears.
```

- [ ] **Step 2: Full-stack test sweep**

Run in sequence:

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
(cd Packages/MoraFixtures && swift test)
(cd dev-tools/pronunciation-bench && swift test)
```
Expected: every package green. MoraMLX is `swift build` only.

```sh
(cd Packages/MoraMLX && swift build)
```
Expected: success.

- [ ] **Step 3: Main Mora regression build**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`. This is the canonical regression guard — the main app must not have picked up any MoraEngines change that breaks it.

- [ ] **Step 4: Recorder test sweep**

```sh
(cd recorder && xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30)
```
Expected: all recorder tests green.

- [ ] **Step 5: Strict lint**

```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```
Expected: silent. If not, apply `swift-format format --in-place` to the offending files and rerun.

- [ ] **Step 6: Manual iPad smoke (document in PR body)**

With the recorder generated (run the team-injection dance from Task 3 if the project is stale) and connected to a physical iPad:

1. Record `rl-right-correct` (say "right" normally) → verdict should show ✓ matched inline.
2. Record `rl-light-correct` poorly (clip /l/ short or swap for /r/) → verdict should show ✗ heard /r/ (expected matched /l/). Tap the verdict to expand F3 / score / reliable.
3. Save both. On the list → detail screen, confirm both takes show a matching badge in the Takes section.
4. Kill the app and relaunch. Open rl-right-correct pattern. After a brief spinner, the take should show its cached badge again (lazy eval from disk).
5. Record, then immediately tap Record again before the evaluation completes (~tens of ms window on iPad — may require practice). Confirm the inline verdict never flashes a stale result from the cancelled evaluation.
6. Delete a take — confirm the badge disappears from the list along with the wav+json on disk.

Log any surprises in the PR description under a "smoke notes" heading.

- [ ] **Step 7: Final commit**

```sh
git add recorder/README.md
git commit -m "$(cat <<'EOF'
recorder: document in-app Engine A verdict in README

Walks users through the new Stop → verdict → Save flow, explains
that saved takes are lazily evaluated on appear, and pins the iPad /
Mac bench parity contract via PronunciationEvaluationRunner.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Exit Criteria

The PR is ready to open when:

- All 12 tasks have passed Step 4+ test runs green.
- Main Mora `xcodebuild build` is green (regression guard).
- Bench + recorder tests run green via their respective test commands.
- `swift-format lint --strict` is silent.
- iPad manual smoke produces the behaviors described in Task 12 Step 6.

Open the PR with `gh pr create`, point the body at the spec (`docs/superpowers/specs/2026-04-24-recorder-in-app-engine-a-evaluation-design.md`), list the commits in the body as a walkthrough, and include the smoke notes collected during Task 12 Step 6.
