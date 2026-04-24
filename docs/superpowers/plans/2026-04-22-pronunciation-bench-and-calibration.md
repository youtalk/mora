# Pronunciation Bench & Child-Speaker Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Superseded (recorder portion):** See `docs/superpowers/plans/2026-04-23-fixture-recorder-app.md`. Tasks 1–5 of this plan (FixtureMetadata, FixtureWriter, FixtureRecorder, PronunciationRecorderView, DebugEntryPoint) already merged; they are undone by the fixture-recorder-app plan's Step A (types move to `Packages/MoraFixtures/`), Step C (main-app deletions), and Step D (new `recorder/MoraFixtureRecorder/` app). Tasks 7–14 (dev-tools/pronunciation-bench) are preserved, with the MoraFixtures import swap added by the new plan's Step B.

**Goal:** Build the calibration loop for Engine A — a DEBUG-only in-app fixture recorder, a repo-root `dev-tools/pronunciation-bench/` Swift Package that compares Engine A against SpeechAce via CSV, recorded WAV fixtures replacing three of the four TODO'd synthetic tests in `FeatureBasedEvaluatorTests` (`r/l`, `v/b`, `æ/ʌ`; the fourth, `θ/t`, is intentionally out of scope — see "Not in scope" below), and one child-speaker calibration pass that tunes `PhonemeThresholds` numerically.

**Architecture:** iPad records labeled WAV + sidecar JSON via a DEBUG-only SwiftUI screen reachable from HomeView by a hidden 5-tap gesture. Files surface to Files.app, get AirDropped to a Mac, and feed `swift run bench <fixtures-dir>`. The bench links Engine A via `path:` reference, posts audio to SpeechAce, and emits a 13-column CSV. No shipped runtime code path changes except the numeric table in `PhonemeThresholds` at the end of Phase D.

**Tech Stack:** Swift 5.9, SwiftUI, AVFoundation (`AVAudioEngine`, `AVAudioConverter`, `AVAudioFile`), swift-argument-parser for the CLI, URLSession for SpeechAce. XCTest throughout.

**Scope:** Phases A–D of `docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md`. This plan is independent of the parent spec `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md` Phase 1/2/3 numbering — Engine A (Phase 1/2) is already shipped, Engine B / shadow mode (Phase 3) lives in a separate plan (`2026-04-22-pronunciation-feedback-engine-b.md`). Whenever this plan says "Phase 3" without further qualification it means Engine B.

**Not in scope of this plan:**

- Session-capture during normal A-day play. Deferred; see spec §4.5 / Appendix A.
- Automated threshold suggestion, Swift patch generation, per-speaker profile layer.
- `PronunciationTrialLog` SwiftData entity (belongs to Phase 3).
- Any CoreML model conversion or MoraMLX activation (Phase 3).
- CI integration for `dev-tools/`. The bench's tests run only on Yutaka's laptop.
- The fourth TODO'd synthetic stub in `FeatureBasedEvaluatorTests`, `θ/t` (onset burst slope). Engine A's coaching map is asymmetric for this pair — only `(θ, t)` produces a coaching key, `(t, θ)` does not — so the symmetric four-fixture pattern used for `r/l`, `v/b`, `æ/ʌ` (correct + cross-substituted on both sides) does not fit. Leaving it for a follow-up that decides whether to record the asymmetric two-fixture pair only or to extend Engine A's coverage first.

---

## Phase 3 conflict boundary

**Never modify these files in this plan.** Phase 3 (Engine B) is in flight on a separate worktree and will conflict:

| Path | Reserved for Phase 3 | Status in current Engine B plan |
|---|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/AssessmentEngine.swift` | shadow-mode parallel evaluator fanout | not edited by current Engine B plan; reserved as a safety margin in case the design grows the fanout layer |
| `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift` | shadow-mode orchestration | not edited by current Engine B plan; same safety margin |
| `Packages/MoraEngines/Sources/MoraEngines/Speech/AppleSpeechEngine.swift` | shadow-mode PCM sink | not edited by current Engine B plan; same safety margin |
| `Packages/MoraEngines/Sources/MoraEngines/Speech/SpeechEvent.swift` | Phase 3 event surface | not edited by current Engine B plan; same safety margin |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationEvaluator.swift` | protocol (Engine B conformer) | not edited by current Engine B plan; reserved because new conformers may force a protocol tweak |
| `Packages/MoraMLX/**` | Engine B home | edited by Engine B plan (Tasks 16, 23–25) |
| `Packages/MoraCore/Sources/MoraCore/Persistence/**` | `PronunciationTrialLog` + retention policy | edited by Engine B plan (Tasks 9, 10) |
| `.github/workflows/**` | Phase 3 LFS opt-in | edited by Engine B plan (Task 27) |
| `project.yml` | future MLX target wiring | not edited by current Engine B plan (`MoraMLX` is already a declared package + dependency); reserved in case Part 2 needs to add build settings |
| `Mora/MoraApp.swift` | shadow factory + retention cleanup | edited by Engine B plan (Task 17) |

Touching any of them in a commit produced by this plan is a planning bug — stop and re-plan. The "Status" column reflects the Engine B plan as of `2026-04-22-pronunciation-feedback-engine-b.md`; if Engine B's plan changes, the boundary remains the conservative superset.

---

## File map

**New files (shipped source tree, DEBUG-gated):**

| File | Responsibility |
|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift` | `Codable` struct describing a fixture (targetPhoneme, expectedLabel, word, sampleRate, durationSeconds, speakerTag, capturedAt). Entire file wrapped in `#if DEBUG`. |
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureWriter.swift` | Pure-Swift 16-bit PCM WAV writer + sidecar JSON writer. Filename slug helper. `#if DEBUG`. |
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift` | `AVAudioEngine` wrapper: install tap, downmix + resample to 16 kHz mono Float32 via `AVAudioConverter`, accumulate into internal buffer, expose `start()` / `stop()` / `drain()`. `#if DEBUG`. |
| `Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift` | SwiftUI form with phoneme + label + word pickers, Record/Stop/Save buttons, saved-file row. `#if DEBUG`. |
| `Packages/MoraUI/Sources/MoraUI/Debug/DebugEntryPoint.swift` | `ViewModifier` that attaches a hidden 5-tap gesture revealing a `NavigationLink` to `PronunciationRecorderView`. `#if DEBUG`. |

The recorder UI lives in `Packages/MoraUI/Sources/MoraUI/Debug/` (matching spec §6.4) so the 5-tap hook can attach to `HomeView` — which lives in MoraUI — without touching `Mora/MoraApp.swift` (reserved for Phase 3, see boundary table above). Release-binary gating is identical to anywhere else: `#if DEBUG` wraps the entire file.

**New files (tests):**

| File | Responsibility |
|---|---|
| `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift` | Codable round-trip, filename slug contract. `#if DEBUG`. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureWriterTests.swift` | WAV round-trip via `AVAudioFile`, sidecar JSON structure. `#if DEBUG`. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift` | Real-audio behavioral tests for `r/l`, `v/b`, `æ/ʌ`. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/rl/*.wav`, `vb/*.wav`, `aeuh/*.wav` | 12 short (<100 KB) mono 16 kHz 16-bit WAV fixtures (Yutaka as adult proxy). |

**New files (repo-root dev-tools, never shipped):**

| File | Responsibility |
|---|---|
| `dev-tools/pronunciation-bench/Package.swift` | Swift package declaration. Depends on MoraEngines + MoraCore via `path:`, plus `apple/swift-argument-parser`. |
| `dev-tools/pronunciation-bench/.env.example` | `SPEECHACE_API_KEY=` template. |
| `dev-tools/pronunciation-bench/.gitignore` | `.env`, `.build/`, `*.csv`. |
| `dev-tools/pronunciation-bench/README.md` | Usage: `swift run bench <fixtures-dir>`. |
| `dev-tools/pronunciation-bench/Sources/Bench/main.swift` | `BenchCLI` struct using `ArgumentParser`. |
| `dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift` | Enumerate `*.wav`+`*.json` pairs, decode to 16 kHz mono `[Float]`. |
| `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift` | Wrap `FeatureBasedPronunciationEvaluator` call. |
| `dev-tools/pronunciation-bench/Sources/Bench/SpeechAceClient.swift` | URLSession multipart POST, score extraction. |
| `dev-tools/pronunciation-bench/Sources/Bench/CSVWriter.swift` | RFC-4180-escaped writer, 13 fixed columns. |
| `dev-tools/pronunciation-bench/Tests/BenchTests/SpeechAceClientTests.swift` | Response decoding, request encoding. URLSession mocked via protocol. |
| `dev-tools/pronunciation-bench/Tests/BenchTests/CSVWriterTests.swift` | RFC-4180 escaping edge cases. |
| `dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift` | Orphan handling, pair matching. |

**Modified files:**

| File | Change |
|---|---|
| `Packages/MoraEngines/Package.swift` | Add `resources: [.copy("Fixtures")]` to the `MoraEnginesTests` test target. |
| `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` | Attach `DebugEntryPoint` modifier under `#if DEBUG`. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift` | Inside the single `// MARK: - Skipped substitution pairs` block, delete the three TODO bullet lines for `r/l`, `v/b`, `æ/ʌ`; coverage migrates into `FeatureBasedEvaluatorFixtureTests`. The fourth bullet (`θ/t`) and the surrounding MARK + explanatory prose are left untouched (see "Not in scope"). |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeThresholds.swift` | **Phase D only:** update numeric centroids/boundaries if child-speaker fixtures warrant it. |
| `.gitignore` | Add `dev-tools/pronunciation-bench/.env` and `dev-tools/pronunciation-bench/.build/`. |

---

## Conventions

- **Imports:** `Foundation` first, then Apple frameworks, then `MoraCore`/`MoraEngines`/`MoraUI`.
- **Sendable / Codable / Hashable:** every new public value type conforms.
- **#if DEBUG wrapping:** every file in `Debug/` directories begins with `#if DEBUG` and ends with `#endif`. Tests that exercise those files do the same.
- **XCTest** style: `import XCTest; final class XxxTests: XCTestCase`. `@MainActor` only where the view or orchestrator requires it.
- **swift-format** runs `--strict` in CI: 4-space indent, trailing commas on every list element, braces on same line. `Package.swift` files are excluded.
- **Commit after every task.** Messages follow `area: short description`. Project CLAUDE.md opts in to `Co-Authored-By: Claude <noreply@anthropic.com>` at commit-message end; include it (matching the Engine A and Engine B plans). Use a HEREDOC so the trailer stays on its own line.
- **No Release-binary changes** until Phase D, and then only `PhonemeThresholds` numeric constants.

---

## Phase A — DEBUG fixture recorder (iPad side)

Phase A adds the on-device fixture-capture pipeline. End of Phase A: Yutaka can open Mora on an iPad (DEBUG build), 5-tap the HomeView greeting, land on `PronunciationRecorderView`, record a word, save it, and see a WAV + JSON pair in Files.app. No Release-binary change; no Phase 3 file touched.

### Task 1: Add `FixtureMetadata` value type

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift
#if DEBUG
import XCTest
@testable import MoraEngines

final class FixtureMetadataTests: XCTestCase {

    func testRoundTripsThroughCodable() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "s",
            wordSurface: "ship",
            sampleRate: 16_000,
            durationSeconds: 0.84,
            speakerTag: .adult
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testSubstitutePhonemeIsNilForMatchedLabel() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            sampleRate: 16_000,
            durationSeconds: 0.5,
            speakerTag: .adult
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(FixtureMetadata.self, from: data)
        XCTAssertNil(decoded.substitutePhonemeIPA)
        XCTAssertEqual(decoded.expectedLabel, .matched)
    }
}
#endif
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `(cd Packages/MoraEngines && swift test --filter FixtureMetadataTests)`
Expected: FAIL — `FixtureMetadata` not in scope.

- [ ] **Step 3: Create `FixtureMetadata.swift`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift
#if DEBUG
import Foundation

/// Label the fixture author intended to produce. Mirrors
/// `PhonemeAssessmentLabel` but is its own type — the bench compares
/// "what Yutaka intended" against "what Engine A said" per fixture.
public enum ExpectedLabel: String, Codable, Sendable, Hashable {
    case matched
    case substitutedBy
    case driftedWithin
}

/// Who produced the fixture. Adult fixtures are committed as regression
/// test input; child fixtures stay on Yutaka's laptop (see spec §9.3).
public enum SpeakerTag: String, Codable, Sendable, Hashable {
    case adult
    case child
}

/// Sidecar metadata written alongside each fixture WAV. Bench tools read
/// this file to know what the fixture represents; regression tests on the
/// committed adult fixtures read labels from filename instead and do not
/// rely on sidecar JSON being present.
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag

    public init(
        capturedAt: Date,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag
    ) {
        self.capturedAt = capturedAt
        self.targetPhonemeIPA = targetPhonemeIPA
        self.expectedLabel = expectedLabel
        self.substitutePhonemeIPA = substitutePhonemeIPA
        self.wordSurface = wordSurface
        self.sampleRate = sampleRate
        self.durationSeconds = durationSeconds
        self.speakerTag = speakerTag
    }
}
#endif
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `(cd Packages/MoraEngines && swift test --filter FixtureMetadataTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift
git commit -m "$(cat <<'EOF'
engines: add FixtureMetadata for DEBUG fixture recorder

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add `FixtureWriter` (WAV + sidecar JSON + filename slug)

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureWriter.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureWriterTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureWriterTests.swift
#if DEBUG
import AVFoundation
import XCTest
@testable import MoraEngines

final class FixtureWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSlugMapsIpaToAscii() {
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "ʃ"), "sh")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "θ"), "th")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "æ"), "ae")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "ʌ"), "uh")
        XCTAssertEqual(FixtureWriter.filenameSlug(ipa: "r"), "r")
    }

    func testWavRoundTripsThroughAvAudioFile() throws {
        let samples: [Float] = (0..<1_600).map { sinf(Float($0) * 2 * .pi * 440 / 16_000) }
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ", expectedLabel: .matched,
            substitutePhonemeIPA: nil, wordSurface: "ship",
            sampleRate: 16_000, durationSeconds: 0.1, speakerTag: .adult
        )

        let urls = try FixtureWriter.write(
            samples: samples, metadata: meta, into: tempDir
        )

        let file = try AVAudioFile(forReading: urls.wav)
        XCTAssertEqual(file.fileFormat.sampleRate, 16_000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(Int(file.length), samples.count)
    }

    func testSidecarJsonMatchesMetadata() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "r", expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l", wordSurface: "right",
            sampleRate: 16_000, durationSeconds: 0.1, speakerTag: .adult
        )
        let urls = try FixtureWriter.write(
            samples: Array(repeating: 0.0, count: 1_600),
            metadata: meta, into: tempDir
        )

        let data = try Data(contentsOf: urls.sidecar)
        let decoded = try JSONDecoder().decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testFilenameIncludesTargetAndLabelSlugs() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ", expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "s", wordSurface: "ship",
            sampleRate: 16_000, durationSeconds: 0.1, speakerTag: .adult
        )
        let urls = try FixtureWriter.write(
            samples: Array(repeating: 0.0, count: 1_600),
            metadata: meta, into: tempDir
        )
        XCTAssertTrue(urls.wav.lastPathComponent.contains("sh"))
        XCTAssertTrue(urls.wav.lastPathComponent.contains("substitutedBy"))
        XCTAssertTrue(urls.wav.lastPathComponent.contains("s.wav"))
        XCTAssertEqual(urls.wav.deletingPathExtension().lastPathComponent,
                       urls.sidecar.deletingPathExtension().lastPathComponent)
    }
}
#endif
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `(cd Packages/MoraEngines && swift test --filter FixtureWriterTests)`
Expected: FAIL — `FixtureWriter` not in scope.

- [ ] **Step 3: Create `FixtureWriter.swift`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureWriter.swift
#if DEBUG
import Foundation

public enum FixtureWriter {

    public struct Output: Equatable {
        public let wav: URL
        public let sidecar: URL
    }

    /// Writes a 16-bit PCM WAV and a sidecar JSON into `directory`.
    /// Returns the URLs of both files. `samples` are Float32 in [-1, 1].
    public static func write(
        samples: [Float], metadata: FixtureMetadata, into directory: URL
    ) throws -> Output {
        let basename = filename(for: metadata)
        let wavURL = directory.appendingPathComponent(basename + ".wav")
        let jsonURL = directory.appendingPathComponent(basename + ".json")

        let wavData = encodeWAV(samples: samples, sampleRate: metadata.sampleRate)
        try wavData.write(to: wavURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(metadata)
        try jsonData.write(to: jsonURL, options: .atomic)

        return Output(wav: wavURL, sidecar: jsonURL)
    }

    // MARK: - Filename

    static func filename(for meta: FixtureMetadata) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ts = formatter.string(from: meta.capturedAt)
        let target = filenameSlug(ipa: meta.targetPhonemeIPA)
        let label = meta.expectedLabel.rawValue
        if let sub = meta.substitutePhonemeIPA {
            return "\(ts)-\(target)-\(label)-\(filenameSlug(ipa: sub))"
        }
        return "\(ts)-\(target)-\(label)"
    }

    static func filenameSlug(ipa: String) -> String {
        switch ipa {
        case "ʃ": return "sh"
        case "θ": return "th"
        case "æ": return "ae"
        case "ʌ": return "uh"
        case "ɪ": return "ih"
        case "ɛ": return "eh"
        case "ɔ": return "aw"
        case "ɑ": return "ah"
        case "ɜ": return "er"
        case "ɚ": return "er"
        case "ŋ": return "ng"
        case "ʒ": return "zh"
        default: return ipa
        }
    }

    // MARK: - WAV encoding

    /// Encode mono Float32 samples to 16-bit PCM WAV. Layout follows the
    /// canonical RIFF/WAVE spec. Keeps dependencies minimal so the writer
    /// can run without AVFoundation on unit-test hosts.
    private static func encodeWAV(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()
        let byteRate = UInt32(sampleRate) * 2         // mono, 16-bit
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let subchunk2Size = UInt32(samples.count) * UInt32(blockAlign)
        let chunkSize = 36 + subchunk2Size

        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: chunkSize.littleEndianBytes)
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: UInt32(16).littleEndianBytes)   // subchunk1Size for PCM
        data.append(contentsOf: UInt16(1).littleEndianBytes)    // audio format PCM
        data.append(contentsOf: UInt16(1).littleEndianBytes)    // channels (mono)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: byteRate.littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)

        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: subchunk2Size.littleEndianBytes)

        for f in samples {
            let clamped = max(-1, min(1, f))
            let i = Int16(clamped * Float(Int16.max))
            data.append(contentsOf: i.littleEndianBytes)
        }
        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianBytes: [UInt8] {
        withUnsafeBytes(of: self.littleEndian) { Array($0) }
    }
}
#endif
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `(cd Packages/MoraEngines && swift test --filter FixtureWriterTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureWriter.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureWriterTests.swift
git commit -m "$(cat <<'EOF'
engines: add FixtureWriter (WAV + sidecar JSON + filename slug)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Add `FixtureRecorder` (AVAudioEngine wrapper)

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift`

No unit tests for this file. `AVAudioEngine` and `AVAudioConverter` are Apple-provided; the recorder is verified manually on iPad during Task 10. A construction smoke test is included in Task 4's view file because it needs one to initialize.

- [ ] **Step 1: Create `FixtureRecorder.swift`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift
#if DEBUG
import AVFoundation
import Foundation

public enum FixtureRecorderError: Error, Sendable {
    case converterInitFailed
    case audioEngineStartFailed(underlying: Error)
    case notRecording
}

/// Captures mono Float32 samples at 16 kHz from the default input device.
/// Not thread-safe — intended to be used from the main actor inside a
/// DEBUG-only SwiftUI view. The recorder does not request microphone
/// permission itself; the main-session `PermissionCoordinator` is the
/// canonical place for that, and the DEBUG recorder presumes permission
/// already granted (alerting if not).
@MainActor
public final class FixtureRecorder {

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var isRecording = false
    private(set) public var buffer: [Float] = []
    public let targetSampleRate: Double = 16_000

    public init() {}

    public var isRunning: Bool { isRecording }

    public func start() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw FixtureRecorderError.converterInitFailed
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw FixtureRecorderError.converterInitFailed
        }
        self.converter = converter

        buffer.removeAll(keepingCapacity: true)

        inputNode.installTap(
            onBus: 0, bufferSize: 4_096, format: hardwareFormat
        ) { [weak self] inBuffer, _ in
            guard let self else { return }
            Task { @MainActor in
                self.append(convert: inBuffer, with: converter, to: targetFormat)
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw FixtureRecorderError.audioEngineStartFailed(underlying: error)
        }

        isRecording = true
    }

    public func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }

    /// Returns captured samples and clears the internal buffer.
    public func drain() -> [Float] {
        let out = buffer
        buffer.removeAll(keepingCapacity: false)
        return out
    }

    private func append(
        convert inBuffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to targetFormat: AVAudioFormat
    ) {
        let ratio = targetFormat.sampleRate / inBuffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: outCapacity
        ) else { return }

        var done = false
        let input: AVAudioConverterInputBlock = { _, outStatus in
            if done {
                outStatus.pointee = .noDataNow
                return nil
            }
            done = true
            outStatus.pointee = .haveData
            return inBuffer
        }

        var error: NSError?
        _ = converter.convert(to: outBuffer, error: &error, withInputFrom: input)
        guard error == nil, let channelData = outBuffer.floatChannelData else { return }

        let frameCount = Int(outBuffer.frameLength)
        buffer.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }
}
#endif
```

- [ ] **Step 2: Build the package**

Run: `(cd Packages/MoraEngines && swift build)`
Expected: PASS (no new tests yet; construction test lives in Task 4's view).

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift
git commit -m "$(cat <<'EOF'
engines: add FixtureRecorder (AVAudioEngine tap + 16kHz resample)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Add `PronunciationRecorderView` (SwiftUI form)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift`

Manual verification only. The view composes existing parts; unit-testing SwiftUI body trees is not the repo's practice.

- [ ] **Step 1: Create the view**

```swift
// Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift
#if DEBUG
import MoraCore
import MoraEngines
import SwiftUI

public struct PronunciationRecorderView: View {
    @State private var recorder = FixtureRecorder()
    @State private var isRecording = false
    @State private var capturedSamples: [Float] = []
    @State private var targetPhonemeIPA: String = "ʃ"
    @State private var expectedLabel: ExpectedLabel = .matched
    @State private var substitutePhonemeIPA: String = "s"
    @State private var wordSurface: String = "ship"
    @State private var speakerTag: SpeakerTag = .adult
    @State private var lastSaveURL: URL?
    @State private var errorMessage: String?

    public init() {}

    private let supportedTargets: [String] = [
        "ʃ", "r", "l", "f", "h", "v", "b", "θ", "s", "t", "æ", "ʌ",
    ]

    public var body: some View {
        Form {
            Section("Fixture") {
                Picker("Target phoneme", selection: $targetPhonemeIPA) {
                    ForEach(supportedTargets, id: \.self) { Text($0).tag($0) }
                }
                Picker("Expected label", selection: $expectedLabel) {
                    Text("matched").tag(ExpectedLabel.matched)
                    Text("substitutedBy").tag(ExpectedLabel.substitutedBy)
                    Text("driftedWithin").tag(ExpectedLabel.driftedWithin)
                }
                if expectedLabel == .substitutedBy {
                    Picker("Substitute phoneme", selection: $substitutePhonemeIPA) {
                        ForEach(supportedTargets, id: \.self) { Text($0).tag($0) }
                    }
                }
                TextField("Word", text: $wordSurface)
                Picker("Speaker", selection: $speakerTag) {
                    Text("adult").tag(SpeakerTag.adult)
                    Text("child").tag(SpeakerTag.child)
                }
            }

            Section("Capture") {
                Button(isRecording ? "Stop" : "Record") {
                    if isRecording {
                        recorder.stop()
                        capturedSamples = recorder.drain()
                        isRecording = false
                    } else {
                        do {
                            try recorder.start()
                            isRecording = true
                        } catch {
                            errorMessage = String(describing: error)
                        }
                    }
                }
                Button("Save") { save() }
                    .disabled(capturedSamples.isEmpty)
                if let url = lastSaveURL {
                    Text("Saved: \(url.lastPathComponent)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Fixture Recorder")
    }

    private func save() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sub = (expectedLabel == .substitutedBy) ? substitutePhonemeIPA : nil
        let meta = FixtureMetadata(
            capturedAt: Date(),
            targetPhonemeIPA: targetPhonemeIPA,
            expectedLabel: expectedLabel,
            substitutePhonemeIPA: sub,
            wordSurface: wordSurface,
            sampleRate: recorder.targetSampleRate,
            durationSeconds: Double(capturedSamples.count) / recorder.targetSampleRate,
            speakerTag: speakerTag
        )
        do {
            let out = try FixtureWriter.write(
                samples: capturedSamples, metadata: meta, into: documents
            )
            lastSaveURL = out.wav
            capturedSamples.removeAll()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
#endif
```

- [ ] **Step 2: Build the package**

Run: `(cd Packages/MoraUI && swift build)`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift
git commit -m "$(cat <<'EOF'
ui: add PronunciationRecorderView DEBUG-only fixture form

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Add `DebugEntryPoint` modifier and wire into `HomeView`

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Debug/DebugEntryPoint.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

Five taps within a 3-second window reveal the NavigationLink. The modifier is self-contained and attaches to any view; it observes nothing from the environment.

- [ ] **Step 1: Create `DebugEntryPoint.swift`**

```swift
// Packages/MoraUI/Sources/MoraUI/Debug/DebugEntryPoint.swift
#if DEBUG
import SwiftUI

/// Attaches a hidden 5-tap gesture to any view. Every tap on the
/// attached content is timestamped; taps older than `window` seconds
/// are discarded, and once `threshold` fresh taps have accumulated,
/// a NavigationLink to `PronunciationRecorderView` is revealed in an
/// overlay below the content. Activation is sticky — once the link is
/// shown it stays visible for the lifetime of the view; there is no
/// deactivation path. Taps outside the attached content are not seen
/// by this modifier and therefore have no effect on the counter.
public struct DebugFixtureRecorderEntryModifier: ViewModifier {

    @State private var taps: [Date] = []
    @State private var isActivated = false
    private let threshold: Int = 5
    private let window: TimeInterval = 3

    public init() {}

    public func body(content: Content) -> some View {
        VStack(spacing: 8) {
            content
                .contentShape(Rectangle())
                .onTapGesture { registerTap() }
            if isActivated {
                NavigationLink("Fixture Recorder") {
                    PronunciationRecorderView()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
    }

    private func registerTap() {
        let now = Date()
        taps.append(now)
        taps = taps.filter { now.timeIntervalSince($0) <= window }
        if taps.count >= threshold {
            isActivated = true
            taps.removeAll()
        }
    }
}

public extension View {
    func debugFixtureRecorderEntry() -> some View {
        modifier(DebugFixtureRecorderEntryModifier())
    }
}
#endif
```

- [ ] **Step 2: Attach to `HomeView`**

Find the top-level title text or header in `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`. Look for a `Text(...)` that renders the greeting or wordmark (the file is 218 lines — open it, locate the first rendered header Text in the view's body, and attach the modifier under `#if DEBUG`).

Example change (adjust to the actual greeting Text in HomeView):

```swift
// Before
Text(strings.homeGreeting)
    .font(.largeTitle)

// After
Text(strings.homeGreeting)
    .font(.largeTitle)
    #if DEBUG
    .debugFixtureRecorderEntry()
    #endif
```

If no greeting Text exists as a natural anchor, attach the modifier to the mora wordmark or the top-level VStack. Pick a stable, always-rendered anchor — not one gated on any state.

- [ ] **Step 3: Build**

Run:
```
(cd Packages/MoraUI && swift build)
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: PASS (Debug config).

- [ ] **Step 4: Confirm Release binary does not include DEBUG symbols**

Run:
```
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Release CODE_SIGNING_ALLOWED=NO
BIN=$(find ~/Library/Developer/Xcode/DerivedData -type d -name 'Mora.app' -path '*Release-iphonesimulator*' | head -1)
if nm "$BIN/Mora" | grep -iE 'FixtureRecorder|FixtureWriter|PronunciationRecorderView'; then
  echo "DEBUG symbols leaked into Release binary"
  exit 1
fi
```
Expected: no symbol matches. The `#if DEBUG` wrap excludes them from Release compilation.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Debug/DebugEntryPoint.swift \
        Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
ui: add 5-tap DEBUG entry point for fixture recorder

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Phase B — dev-tools/pronunciation-bench (Mac side)

Phase B stands up the repo-root Swift Package that consumes fixture WAVs on a Mac and produces a CSV. End of Phase B: Yutaka can `cd dev-tools/pronunciation-bench && swift run bench ~/fixtures/ out.csv` and get Engine A + SpeechAce numbers for every fixture.

### Task 6: Scaffold `dev-tools/pronunciation-bench/` package

**Files:**
- Create: `dev-tools/pronunciation-bench/Package.swift`
- Create: `dev-tools/pronunciation-bench/.env.example`
- Create: `dev-tools/pronunciation-bench/.gitignore`
- Create: `dev-tools/pronunciation-bench/README.md`
- Create: `dev-tools/pronunciation-bench/Sources/Bench/main.swift` (stub)
- Modify: `.gitignore` (repo root)

- [ ] **Step 1: Create `Package.swift`**

```swift
// dev-tools/pronunciation-bench/Package.swift
// swift-tools-version: 5.9
import PackageDescription

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
            ],
            path: "Sources/Bench"
        ),
        .testTarget(
            name: "BenchTests",
            dependencies: ["Bench"],
            path: "Tests/BenchTests"
        ),
    ]
)
```

- [ ] **Step 2: Create dev-tools ignore + env template + README**

```
# dev-tools/pronunciation-bench/.env.example
SPEECHACE_API_KEY=
```

```
# dev-tools/pronunciation-bench/.gitignore
.env
.build/
*.csv
```

```markdown
<!-- dev-tools/pronunciation-bench/README.md -->
# pronunciation-bench

Local-only benchmark harness for mora's Engine A pronunciation evaluator.

**Not shipped.** This package is not referenced by `project.yml` or by any
`Package.swift` under `Packages/`. It exists at the repo root to stay
out of the production build graph.

## Usage

1. Copy `.env.example` to `.env` and fill in `SPEECHACE_API_KEY`. The
   CLI reads the key from `ProcessInfo.processInfo.environment`, not
   from `.env` directly, so the file has to be loaded into your shell
   before running the bench — e.g. `source .env`, or export the
   variable in your shell profile. (Pass `--no-speechace` to skip this
   step entirely and run Engine A only.)
2. Export fixtures (WAV + sidecar JSON) from an iPad running a DEBUG
   build of mora via the DEBUG fixture recorder — revealed by a hidden
   5-tap gesture on the HomeView header anchor.
3. Run:

```sh
cd dev-tools/pronunciation-bench
source .env   # or: export SPEECHACE_API_KEY=...
swift run bench ~/path/to/fixtures/ out.csv
```

Pass `--no-speechace` to skip the SpeechAce API call (offline mode).
```

- [ ] **Step 3: Stub `main.swift`**

```swift
// dev-tools/pronunciation-bench/Sources/Bench/main.swift
import ArgumentParser
import Foundation

@main
struct BenchCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "bench",
        abstract: "Compare Engine A against SpeechAce for a directory of fixtures."
    )

    @Argument(help: "Directory containing WAV + sidecar JSON pairs.")
    var fixturesDirectory: String

    @Argument(help: "Output CSV path.")
    var outputPath: String = "bench-out.csv"

    @Flag(name: .long, help: "Skip SpeechAce; Engine A only.")
    var noSpeechace: Bool = false

    mutating func run() async throws {
        print("bench stub — fixtures=\(fixturesDirectory) out=\(outputPath) noSpeechace=\(noSpeechace)")
    }
}
```

- [ ] **Step 4: Update repo-root `.gitignore`**

Append to `.gitignore`:

```
/dev-tools/pronunciation-bench/.env
/dev-tools/pronunciation-bench/.build/
/dev-tools/pronunciation-bench/*.csv
```

- [ ] **Step 5: Resolve dependencies and build**

Run:
```
cd dev-tools/pronunciation-bench && swift build
```
Expected: compiles cleanly. First run fetches swift-argument-parser and resolves the local MoraEngines + MoraCore paths.

- [ ] **Step 6: Commit**

```bash
git add dev-tools/pronunciation-bench/ .gitignore
git commit -m "$(cat <<'EOF'
dev-tools: scaffold pronunciation-bench Swift Package

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Add `FixtureLoader`

**Files:**
- Create: `dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift`
- Create: `dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift
import XCTest
@testable import Bench

final class FixtureLoaderTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testPairsWavWithJsonBySharedBasename() throws {
        try writeFile("a.wav", data: Data([0x01]))
        try writeFile("a.json", data: #"{"x":1}"#.data(using: .utf8)!)
        try writeFile("b.wav", data: Data([0x02]))    // orphan

        let pairs = FixtureLoader.enumerate(directory: tempDir)
        XCTAssertEqual(pairs.map(\.basename), ["a"])
    }

    func testIgnoresJsonWithoutWav() throws {
        try writeFile("x.json", data: #"{}"#.data(using: .utf8)!)
        XCTAssertEqual(FixtureLoader.enumerate(directory: tempDir).count, 0)
    }

    private func writeFile(_ name: String, data: Data) throws {
        try data.write(to: tempDir.appendingPathComponent(name))
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd dev-tools/pronunciation-bench && swift test --filter FixtureLoaderTests`
Expected: FAIL — `FixtureLoader` not in scope.

- [ ] **Step 3: Create `FixtureLoader.swift`**

```swift
// dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift
import AVFoundation
import Foundation
import MoraEngines

public struct FixturePair {
    public let basename: String
    public let wavURL: URL
    public let sidecarURL: URL
}

public struct LoadedFixture {
    public let pair: FixturePair
    public let metadata: FixtureMetadata
    public let samples: [Float]
    public let sampleRate: Double
}

public enum FixtureLoader {

    public static func enumerate(directory: URL) -> [FixturePair] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }

        let byBasename = Dictionary(grouping: entries, by: {
            $0.deletingPathExtension().lastPathComponent
        })
        return byBasename.compactMap { basename, urls -> FixturePair? in
            let wav = urls.first { $0.pathExtension.lowercased() == "wav" }
            let json = urls.first { $0.pathExtension.lowercased() == "json" }
            guard let wav, let json else { return nil }
            return FixturePair(basename: basename, wavURL: wav, sidecarURL: json)
        }
        .sorted { $0.basename < $1.basename }
    }

    public static func load(_ pair: FixturePair) throws -> LoadedFixture {
        let metaData = try Data(contentsOf: pair.sidecarURL)
        let metadata = try JSONDecoder.iso8601.decode(FixtureMetadata.self, from: metaData)

        let (samples, sampleRate) = try readMono16kFloat(from: pair.wavURL)
        return LoadedFixture(
            pair: pair, metadata: metadata,
            samples: samples, sampleRate: sampleRate
        )
    }

    private static func readMono16kFloat(from url: URL) throws -> ([Float], Double) {
        let file = try AVAudioFile(forReading: url)
        let hardwareFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000, channels: 1, interleaved: false
        ) else { throw NSError(domain: "FixtureLoader", code: 1) }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw NSError(domain: "FixtureLoader", code: 2)
        }

        guard let inBuffer = AVAudioPCMBuffer(
            pcmFormat: hardwareFormat, frameCapacity: AVAudioFrameCount(file.length)
        ) else { throw NSError(domain: "FixtureLoader", code: 3) }
        try file.read(into: inBuffer)

        let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 16
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: outCapacity
        ) else { throw NSError(domain: "FixtureLoader", code: 4) }

        var done = false
        let input: AVAudioConverterInputBlock = { _, outStatus in
            if done { outStatus.pointee = .noDataNow; return nil }
            done = true; outStatus.pointee = .haveData; return inBuffer
        }
        var error: NSError?
        _ = converter.convert(to: outBuffer, error: &error, withInputFrom: input)
        if let error { throw error }
        guard let channel = outBuffer.floatChannelData else {
            throw NSError(domain: "FixtureLoader", code: 5)
        }
        let samples = Array(UnsafeBufferPointer(start: channel[0],
                                                count: Int(outBuffer.frameLength)))
        return (samples, targetFormat.sampleRate)
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd dev-tools/pronunciation-bench && swift test --filter FixtureLoaderTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift \
        dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift
git commit -m "$(cat <<'EOF'
dev-tools: add FixtureLoader for bench input

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Add `EngineARunner`

**Files:**
- Create: `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift`

No dedicated tests. `EngineARunner` is a thin adapter over `FeatureBasedPronunciationEvaluator`; its correctness is covered by the evaluator's own unit and fixture tests added in Phase C.

- [ ] **Step 1: Create `EngineARunner.swift`**

```swift
// dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift
import Foundation
import MoraCore
import MoraEngines

public struct EngineARunner {

    public init() {}

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        let evaluator = FeatureBasedPronunciationEvaluator()
        let target = Phoneme(ipa: loaded.metadata.targetPhonemeIPA)
        let word = Word(
            surface: loaded.metadata.wordSurface,
            graphemes: [Grapheme(letters: loaded.metadata.wordSurface)],
            phonemes: [target],
            targetPhoneme: target
        )
        let audio = AudioClip(samples: loaded.samples, sampleRate: loaded.sampleRate)
        return await evaluator.evaluate(
            audio: audio, expected: word,
            targetPhoneme: target,
            asr: ASRResult(transcript: loaded.metadata.wordSurface, confidence: 1.0)
        )
    }
}
```

- [ ] **Step 2: Build**

Run: `cd dev-tools/pronunciation-bench && swift build`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift
git commit -m "$(cat <<'EOF'
dev-tools: add EngineARunner adapter

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Add `SpeechAceClient`

**Files:**
- Create: `dev-tools/pronunciation-bench/Sources/Bench/SpeechAceClient.swift`
- Create: `dev-tools/pronunciation-bench/Tests/BenchTests/SpeechAceClientTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// dev-tools/pronunciation-bench/Tests/BenchTests/SpeechAceClientTests.swift
import XCTest
@testable import Bench

final class SpeechAceClientTests: XCTestCase {

    func testParsesOverallScoreFromSuccessPayload() throws {
        let json = #"""
        {
          "status": "success",
          "text_score": { "text": "ship", "quality_score": 82.5 }
        }
        """#.data(using: .utf8)!

        let result = SpeechAceClient.parse(responseData: json)
        XCTAssertEqual(result.score ?? 0, 82.5, accuracy: 0.001)
        XCTAssertNotNil(result.rawJSON)
    }

    func testReturnsNilScoreForErrorPayload() throws {
        let json = #"""
        {"status": "error", "message": "quota exceeded"}
        """#.data(using: .utf8)!
        let result = SpeechAceClient.parse(responseData: json)
        XCTAssertNil(result.score)
    }

    func testBuildsMultipartRequestWithAudioAndText() throws {
        let client = SpeechAceClient(apiKey: "abc", session: URLSession.shared)
        let audio = Data([0x01, 0x02])
        let req = client.buildRequest(audio: audio, text: "ship")
        XCTAssertEqual(req.url?.scheme, "https")
        XCTAssertTrue(req.url?.host?.contains("speechace") ?? false)
        XCTAssertNotNil(req.httpBody)
        XCTAssertTrue(req.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") ?? false)
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd dev-tools/pronunciation-bench && swift test --filter SpeechAceClientTests`
Expected: FAIL.

- [ ] **Step 3: Create `SpeechAceClient.swift`**

```swift
// dev-tools/pronunciation-bench/Sources/Bench/SpeechAceClient.swift
import Foundation

public struct SpeechAceResult {
    public let score: Double?
    public let rawJSON: String?
}

public struct SpeechAceClient {

    public let apiKey: String
    public let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.speechace.co/api/scoring/text/v9/json")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func score(audio: Data, text: String) async -> SpeechAceResult {
        let request = buildRequest(audio: audio, text: text)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return SpeechAceResult(score: nil, rawJSON: String(data: data, encoding: .utf8))
            }
            return Self.parse(responseData: data)
        } catch {
            return SpeechAceResult(score: nil, rawJSON: nil)
        }
    }

    public func buildRequest(audio: Data, text: String) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "dialect", value: "en-us"),
        ]
        var req = URLRequest(url: components.url!)
        req.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = Self.multipartBody(boundary: boundary, audio: audio, text: text)
        return req
    }

    static func multipartBody(boundary: String, audio: Data, text: String) -> Data {
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"text\"\r\n\r\n\(text)\r\n")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"user_audio_file\"; filename=\"clip.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(audio)
        append("\r\n--\(boundary)--\r\n")
        return body
    }

    static func parse(responseData data: Data) -> SpeechAceResult {
        let raw = String(data: data, encoding: .utf8)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let textScore = json["text_score"] as? [String: Any],
            let quality = textScore["quality_score"] as? Double
        else {
            return SpeechAceResult(score: nil, rawJSON: raw)
        }
        return SpeechAceResult(score: quality, rawJSON: raw)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd dev-tools/pronunciation-bench && swift test --filter SpeechAceClientTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/SpeechAceClient.swift \
        dev-tools/pronunciation-bench/Tests/BenchTests/SpeechAceClientTests.swift
git commit -m "$(cat <<'EOF'
dev-tools: add SpeechAceClient for bench oracle calls

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Add `CSVWriter`

**Files:**
- Create: `dev-tools/pronunciation-bench/Sources/Bench/CSVWriter.swift`
- Create: `dev-tools/pronunciation-bench/Tests/BenchTests/CSVWriterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// dev-tools/pronunciation-bench/Tests/BenchTests/CSVWriterTests.swift
import XCTest
@testable import Bench

final class CSVWriterTests: XCTestCase {

    func testHeaderHasThirteenColumnsInFixedOrder() {
        XCTAssertEqual(CSVWriter.header, [
            "fixture", "captured_at", "target_phoneme", "expected_label",
            "substitute_phoneme", "word", "speaker_tag", "engine_a_label",
            "engine_a_score", "engine_a_is_reliable", "engine_a_features_json",
            "speechace_score", "speechace_raw_json",
        ])
    }

    func testEscapesCommasAndQuotesAndNewlines() {
        XCTAssertEqual(CSVWriter.escape("plain"), "plain")
        XCTAssertEqual(CSVWriter.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVWriter.escape("a\"b"), "\"a\"\"b\"")
        XCTAssertEqual(CSVWriter.escape("a\nb"), "\"a\nb\"")
        XCTAssertEqual(CSVWriter.escape(""), "")
    }

    func testRowJoinsEscapedCellsWithCommas() {
        let row = CSVWriter.row(cells: ["a", "b,c", "d\"e", ""])
        XCTAssertEqual(row, "a,\"b,c\",\"d\"\"e\",")
    }
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd dev-tools/pronunciation-bench && swift test --filter CSVWriterTests`
Expected: FAIL.

- [ ] **Step 3: Create `CSVWriter.swift`**

```swift
// dev-tools/pronunciation-bench/Sources/Bench/CSVWriter.swift
import Foundation

public struct CSVWriter {

    public static let header: [String] = [
        "fixture", "captured_at", "target_phoneme", "expected_label",
        "substitute_phoneme", "word", "speaker_tag", "engine_a_label",
        "engine_a_score", "engine_a_is_reliable", "engine_a_features_json",
        "speechace_score", "speechace_raw_json",
    ]

    private let output: FileHandle
    private let lineSeparator = "\n"

    public init(output: FileHandle) {
        self.output = output
    }

    public static func create(at url: URL) throws -> CSVWriter {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        let writer = CSVWriter(output: handle)
        try writer.writeLine(Self.row(cells: Self.header))
        return writer
    }

    public func write(row cells: [String]) throws {
        precondition(cells.count == Self.header.count)
        try writeLine(Self.row(cells: cells))
    }

    private func writeLine(_ line: String) throws {
        try output.write(contentsOf: Data((line + lineSeparator).utf8))
    }

    public func close() { try? output.close() }

    public static func row(cells: [String]) -> String {
        cells.map(escape).joined(separator: ",")
    }

    public static func escape(_ s: String) -> String {
        let needsQuotes = s.contains(",") || s.contains("\"") || s.contains("\n")
        guard needsQuotes else { return s }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd dev-tools/pronunciation-bench && swift test --filter CSVWriterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/CSVWriter.swift \
        dev-tools/pronunciation-bench/Tests/BenchTests/CSVWriterTests.swift
git commit -m "$(cat <<'EOF'
dev-tools: add CSVWriter with RFC 4180 escaping

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: Wire `BenchCLI` end to end

**Files:**
- Modify: `dev-tools/pronunciation-bench/Sources/Bench/main.swift`

- [ ] **Step 1: Replace the stub with the full CLI**

```swift
// dev-tools/pronunciation-bench/Sources/Bench/main.swift
import ArgumentParser
import Foundation
import MoraEngines

@main
struct BenchCLI: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "bench",
        abstract: "Compare Engine A against SpeechAce for a directory of fixtures."
    )

    @Argument(help: "Directory containing WAV + sidecar JSON pairs.")
    var fixturesDirectory: String

    @Argument(help: "Output CSV path.")
    var outputPath: String = "bench-out.csv"

    @Flag(name: .long, help: "Skip SpeechAce; Engine A only.")
    var noSpeechace: Bool = false

    mutating func run() async throws {
        let fixturesURL = URL(fileURLWithPath: fixturesDirectory)
        let outputURL = URL(fileURLWithPath: outputPath)
        let pairs = FixtureLoader.enumerate(directory: fixturesURL)
        guard !pairs.isEmpty else {
            FileHandle.standardError.write(
                Data("no fixtures found in \(fixturesDirectory)\n".utf8)
            )
            throw ExitCode(1)
        }

        let apiKey = ProcessInfo.processInfo.environment["SPEECHACE_API_KEY"] ?? ""
        if !noSpeechace && apiKey.isEmpty {
            FileHandle.standardError.write(Data(
                "SPEECHACE_API_KEY not set. Export it or pass --no-speechace.\n".utf8
            ))
            throw ExitCode(2)
        }

        let client: SpeechAceClient? = noSpeechace ? nil : SpeechAceClient(apiKey: apiKey)
        let runner = EngineARunner()
        let writer = try CSVWriter.create(at: outputURL)
        defer { writer.close() }

        for pair in pairs {
            let loaded: LoadedFixture
            do {
                loaded = try FixtureLoader.load(pair)
            } catch {
                FileHandle.standardError.write(Data(
                    "skip \(pair.basename): \(error)\n".utf8
                ))
                continue
            }

            let assessment = await runner.evaluate(loaded)

            var speechaceScore: String = ""
            var speechaceRaw: String = ""
            if let client {
                let wavData = (try? Data(contentsOf: pair.wavURL)) ?? Data()
                let r = await client.score(audio: wavData, text: loaded.metadata.wordSurface)
                if let s = r.score { speechaceScore = String(s) }
                speechaceRaw = r.rawJSON ?? ""
            }

            let labelJSON = (try? String(
                data: JSONEncoder().encode(assessment.label), encoding: .utf8
            )) ?? ""
            let featuresJSON = (try? String(
                data: JSONEncoder().encode(assessment.features), encoding: .utf8
            )) ?? ""
            let isoTimestamp = ISO8601DateFormatter().string(from: loaded.metadata.capturedAt)

            try writer.write(row: [
                pair.basename,
                isoTimestamp,
                loaded.metadata.targetPhonemeIPA,
                loaded.metadata.expectedLabel.rawValue,
                loaded.metadata.substitutePhonemeIPA ?? "",
                loaded.metadata.wordSurface,
                loaded.metadata.speakerTag.rawValue,
                labelJSON,
                assessment.score.map { "\($0)" } ?? "",
                "\(assessment.isReliable)",
                featuresJSON,
                speechaceScore,
                speechaceRaw,
            ])
        }
        print("wrote \(outputURL.path)")
    }
}
```

- [ ] **Step 2: Smoke-run with a single synthetic fixture**

Create a tiny fixture by hand for smoke verification. In a scratch dir:

```bash
mkdir -p /tmp/bench-smoke
# copy a WAV you already have (any mono or stereo file — bench resamples)
cp /path/to/any.wav /tmp/bench-smoke/smoke.wav
cat > /tmp/bench-smoke/smoke.json <<'EOF'
{
  "capturedAt" : "2026-04-22T10:00:00Z",
  "durationSeconds" : 0.5,
  "expectedLabel" : "matched",
  "sampleRate" : 16000,
  "speakerTag" : "adult",
  "substitutePhonemeIPA" : null,
  "targetPhonemeIPA" : "r",
  "wordSurface" : "right"
}
EOF
cd dev-tools/pronunciation-bench
swift run bench /tmp/bench-smoke /tmp/bench-smoke/out.csv --no-speechace
cat /tmp/bench-smoke/out.csv
```

Expected: 1-row CSV, Engine A label non-empty. The row's `speechace_score` and `speechace_raw_json` columns are empty (`--no-speechace`).

- [ ] **Step 3: Run full bench test suite**

Run: `cd dev-tools/pronunciation-bench && swift test`
Expected: PASS (FixtureLoader, SpeechAceClient, CSVWriter tests all green).

- [ ] **Step 4: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/main.swift
git commit -m "$(cat <<'EOF'
dev-tools: wire BenchCLI end to end

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Phase C — Fixture collection and test adoption

Phase C records the adult-proxy WAV fixtures, checks them in, and replaces three of the four TODO'd synthetic stubs in `FeatureBasedEvaluatorTests` (`r/l`, `v/b`, `æ/ʌ`) with real-audio behavioral tests. The fourth TODO bullet (`θ/t`) is intentionally left in place — see the top-level "Not in scope" note for the rationale.

### Task 12: Declare fixtures as a test resource

**Files:**
- Modify: `Packages/MoraEngines/Package.swift`

- [ ] **Step 1: Add `resources:` to the test target**

Edit `Packages/MoraEngines/Package.swift`. Replace the test target line:

```swift
.testTarget(name: "MoraEnginesTests", dependencies: ["MoraEngines"]),
```

with:

```swift
.testTarget(
    name: "MoraEnginesTests",
    dependencies: ["MoraEngines"],
    resources: [.copy("Fixtures")]
),
```

- [ ] **Step 2: Create a placeholder fixtures directory** so SPM does not complain before Task 13 lands the WAVs.

```bash
mkdir -p Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/rl
mkdir -p Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/vb
mkdir -p Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/aeuh
printf '# real WAVs land in Task 13\n' > Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/README.md
```

- [ ] **Step 3: Build + test**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS. The empty Fixtures directory is harmless.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraEngines/Package.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/
git commit -m "$(cat <<'EOF'
engines: declare Fixtures as a test resource

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: Record + check in adult-proxy fixtures

**Files:**
- Create: 12 WAV files under `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/`

This task is a manual hardware step. The DEBUG recorder from Phase A produces WAVs directly usable here.

- [ ] **Step 1: Set up DEBUG build on an iPad**

```
xcodegen generate
xcodebuild -project Mora.xcodeproj -scheme Mora \
  -configuration Debug -destination 'generic/platform=iOS' build
```
Install on a physical iPad via Xcode.

- [ ] **Step 2: Record the 12 fixtures**

For each of the 12 (target, label) pairs, use the DEBUG fixture recorder (5-tap HomeView header → Fixture Recorder):

| Target | Expected label | Substitute | Word | Filename (after rename) |
|---|---|---|---|---|
| r | matched | — | right | `rl/right-correct.wav` |
| r | substitutedBy | l | right | `rl/right-as-light.wav` |
| l | matched | — | light | `rl/light-correct.wav` |
| l | substitutedBy | r | light | `rl/light-as-right.wav` |
| v | matched | — | very | `vb/very-correct.wav` |
| v | substitutedBy | b | very | `vb/very-as-berry.wav` |
| b | matched | — | berry | `vb/berry-correct.wav` |
| b | substitutedBy | v | berry | `vb/berry-as-very.wav` |
| æ | matched | — | cat | `aeuh/cat-correct.wav` |
| æ | substitutedBy | ʌ | cat | `aeuh/cat-as-cut.wav` |
| ʌ | matched | — | cut | `aeuh/cut-correct.wav` |
| ʌ | substitutedBy | æ | cut | `aeuh/cut-as-cat.wav` |

Speaker tag: `adult` for all. Say each word clearly; for the `substitutedBy` rows deliberately pronounce the word with the substitute phoneme.

- [ ] **Step 3: Export fixtures to the Mac**

Files.app → On My iPad → Mora → select all → AirDrop to Mac.
Drop into a scratch folder `~/mora-fixtures/` on the Mac.

- [ ] **Step 4: Sanity-run the bench with `--no-speechace`**

```bash
cd dev-tools/pronunciation-bench
swift run bench ~/mora-fixtures/ ~/mora-fixtures/out.csv --no-speechace
```

Expected: 12-row CSV. Scan `engine_a_label` and `engine_a_score` to spot obvious miscalls *before* checking the fixtures in. If a `right-correct.wav` labels as `.substitutedBy(/l/)`, re-record; the fixture is mispronounced or noisy.

- [ ] **Step 5: Trim and rename**

Each WAV should be ≤100 KB, ≤2 s long, mono 16 kHz 16-bit. The DEBUG recorder already emits mono 16 kHz; trim with `sox` or QuickTime if a clip runs long:

```bash
sox input.wav -r 16000 -b 16 -c 1 trimmed.wav trim 0 1.5
```

Rename to the filename table above. Drop sidecar JSON files — they are not committed; the test reads labels from filename.

- [ ] **Step 6: Check files in**

```bash
cp ~/mora-fixtures-trimmed/rl/*.wav Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/rl/
cp ~/mora-fixtures-trimmed/vb/*.wav Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/vb/
cp ~/mora-fixtures-trimmed/aeuh/*.wav Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/aeuh/
ls -l Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/{rl,vb,aeuh}/*.wav
```

Each file should be under 100 KB.

- [ ] **Step 7: Commit**

```bash
git add Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/
git commit -m "$(cat <<'EOF'
engines: add adult-proxy recorded fixtures for r/l, v/b, ae/uh

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 14: Add `FeatureBasedEvaluatorFixtureTests` + delete synthetic TODO stubs

**Files:**
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift`

- [ ] **Step 1: Write the fixture-based tests**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift
import AVFoundation
import MoraCore
import XCTest
@testable import MoraEngines

final class FeatureBasedEvaluatorFixtureTests: XCTestCase {

    private let evaluator = FeatureBasedPronunciationEvaluator()

    // MARK: - r / l

    func testRightCorrectMatchesR() async throws {
        let assessment = try await evaluate("rl/right-correct.wav",
                                            target: "r", word: "right")
        XCTAssertEqual(assessment.label, .matched)
        if let score = assessment.score { XCTAssertGreaterThanOrEqual(score, 70) }
    }

    func testRightAsLightSubstitutedByL() async throws {
        let assessment = try await evaluate("rl/right-as-light.wav",
                                            target: "r", word: "right")
        XCTAssertEqual(assessment.label, .substitutedBy(Phoneme(ipa: "l")))
        if let score = assessment.score { XCTAssertLessThanOrEqual(score, 40) }
    }

    func testLightCorrectMatchesL() async throws {
        let assessment = try await evaluate("rl/light-correct.wav",
                                            target: "l", word: "light")
        XCTAssertEqual(assessment.label, .matched)
        if let score = assessment.score { XCTAssertGreaterThanOrEqual(score, 70) }
    }

    func testLightAsRightSubstitutedByR() async throws {
        let assessment = try await evaluate("rl/light-as-right.wav",
                                            target: "l", word: "light")
        XCTAssertEqual(assessment.label, .substitutedBy(Phoneme(ipa: "r")))
        if let score = assessment.score { XCTAssertLessThanOrEqual(score, 40) }
    }

    // MARK: - v / b

    func testVeryCorrectMatchesV() async throws {
        let a = try await evaluate("vb/very-correct.wav", target: "v", word: "very")
        XCTAssertEqual(a.label, .matched)
        if let s = a.score { XCTAssertGreaterThanOrEqual(s, 70) }
    }

    func testVeryAsBerrySubstitutedByB() async throws {
        let a = try await evaluate("vb/very-as-berry.wav", target: "v", word: "very")
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "b")))
        if let s = a.score { XCTAssertLessThanOrEqual(s, 40) }
    }

    func testBerryCorrectMatchesB() async throws {
        let a = try await evaluate("vb/berry-correct.wav", target: "b", word: "berry")
        XCTAssertEqual(a.label, .matched)
        if let s = a.score { XCTAssertGreaterThanOrEqual(s, 70) }
    }

    func testBerryAsVerySubstitutedByV() async throws {
        let a = try await evaluate("vb/berry-as-very.wav", target: "b", word: "berry")
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "v")))
        if let s = a.score { XCTAssertLessThanOrEqual(s, 40) }
    }

    // MARK: - æ / ʌ

    func testCatCorrectMatchesAe() async throws {
        let a = try await evaluate("aeuh/cat-correct.wav", target: "æ", word: "cat")
        XCTAssertEqual(a.label, .matched)
        if let s = a.score { XCTAssertGreaterThanOrEqual(s, 70) }
    }

    func testCatAsCutSubstitutedByUh() async throws {
        let a = try await evaluate("aeuh/cat-as-cut.wav", target: "æ", word: "cat")
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "ʌ")))
        if let s = a.score { XCTAssertLessThanOrEqual(s, 40) }
    }

    func testCutCorrectMatchesUh() async throws {
        let a = try await evaluate("aeuh/cut-correct.wav", target: "ʌ", word: "cut")
        XCTAssertEqual(a.label, .matched)
        if let s = a.score { XCTAssertGreaterThanOrEqual(s, 70) }
    }

    func testCutAsCatSubstitutedByAe() async throws {
        let a = try await evaluate("aeuh/cut-as-cat.wav", target: "ʌ", word: "cut")
        XCTAssertEqual(a.label, .substitutedBy(Phoneme(ipa: "æ")))
        if let s = a.score { XCTAssertLessThanOrEqual(s, 40) }
    }

    // MARK: - Loader

    private func evaluate(
        _ relative: String, target ipa: String, word surface: String
    ) async throws -> PhonemeTrialAssessment {
        let relNS = relative as NSString
        let basename = (relNS.deletingPathExtension as NSString).lastPathComponent
        let subdir = "Fixtures/" + relNS.deletingLastPathComponent
        guard let url = Bundle.module.url(
            forResource: basename,
            withExtension: "wav",
            subdirectory: subdir
        ) else {
            throw XCTSkip("fixture not found: \(relative)")
        }

        let (samples, sampleRate) = try readMono16k(from: url)
        let audio = AudioClip(samples: samples, sampleRate: sampleRate)
        let target = Phoneme(ipa: ipa)
        let word = Word(
            surface: surface,
            graphemes: [Grapheme(letters: surface)],
            phonemes: [target],
            targetPhoneme: target
        )
        return await evaluator.evaluate(
            audio: audio, expected: word, targetPhoneme: target,
            asr: ASRResult(transcript: surface, confidence: 0.9)
        )
    }

    private func readMono16k(from url: URL) throws -> ([Float], Double) {
        let file = try AVAudioFile(forReading: url)
        let hardwareFormat = file.processingFormat
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
            channels: 1, interleaved: false
        ), let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat),
           let inBuf = AVAudioPCMBuffer(
             pcmFormat: hardwareFormat, frameCapacity: AVAudioFrameCount(file.length)
           )
        else { throw NSError(domain: "FixtureLoad", code: 1) }

        try file.read(into: inBuf)
        let ratio = targetFormat.sampleRate / hardwareFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 16
        guard let outBuf = AVAudioPCMBuffer(
            pcmFormat: targetFormat, frameCapacity: capacity
        ) else { throw NSError(domain: "FixtureLoad", code: 2) }

        var done = false
        var err: NSError?
        _ = converter.convert(to: outBuf, error: &err) { _, s in
            if done { s.pointee = .noDataNow; return nil }
            done = true; s.pointee = .haveData; return inBuf
        }
        if let err { throw err }
        guard let ch = outBuf.floatChannelData else {
            throw NSError(domain: "FixtureLoad", code: 3)
        }
        let samples = Array(UnsafeBufferPointer(start: ch[0],
                                                count: Int(outBuf.frameLength)))
        return (samples, targetFormat.sampleRate)
    }
}
```

- [ ] **Step 2: Delete the three TODO bullets covered by fixtures**

Open `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift`. The four `TODO(post-alpha): needs recorded fixture` markers live as four bullet lines inside one `// MARK: - Skipped substitution pairs` block near the bottom of the file (currently around lines 158–164). The block looks like:

```swift
    // MARK: - Skipped substitution pairs
    // Synthetic audio is not reliable for these pairs; each needs a recorded
    // fixture to exercise the measurement path in a meaningful way.
    // - /r/ vs /l/  — TODO(post-alpha): needs recorded fixture (F3 formant)
    // - /v/ vs /b/  — TODO(post-alpha): needs recorded fixture (voicing onset time)
    // - /æ/ vs /ʌ/ — TODO(post-alpha): needs recorded fixture (F1 formant)
    // - /θ/ vs /t/ — TODO(post-alpha): needs recorded fixture (onset burst slope)
```

Delete only the three bullet lines that this plan covers (`r/l`, `v/b`, `æ/ʌ`). Keep the `// MARK:` header, the two prose lines that follow it, and the `θ/t` bullet — `θ/t` is intentionally out of scope per the top-level "Not in scope" note. After the edit the block should read:

```swift
    // MARK: - Skipped substitution pairs
    // Synthetic audio is not reliable for these pairs; each needs a recorded
    // fixture to exercise the measurement path in a meaningful way.
    // - /θ/ vs /t/ — TODO(post-alpha): needs recorded fixture (onset burst slope)
```

Do NOT touch the existing `f/h` and `θ/s` behavioral tests (in the `// --- f/h ---` and `// --- θ / s ---` sections higher up, currently around lines 110 and 134) — those are real synthetic-audio tests and remain valid. Do NOT remove their section-header comments either.

- [ ] **Step 3: Run all engine tests**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS. All 12 fixture-based tests green. The three pairs previously marked TODO now have real coverage.

If any `-correct` test fails with `.substitutedBy(...)` or any `-as-X` test fails with `.matched`, the fixture recording is the problem — re-record and commit the updated WAV. Do not widen the tolerance bounds at this stage. Tolerance widening is reserved for Phase D, where child-speaker numbers justify it.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift
git commit -m "$(cat <<'EOF'
engines: replace TODO'd synthetic stubs with fixture-based tests

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Phase D — Child-speaker calibration pass

Phase D is a measurement + tuning exercise, not feature work. The son's fixtures stay on Yutaka's laptop and are never committed. The PR output of Phase D is a numeric update to `PhonemeThresholds.swift` (possibly a no-op if the data agrees with literature).

### Task 15: Record son's fixtures (local only)

**Files:** none committed. This task produces local WAVs.

- [ ] **Step 1: Record**

Using the same DEBUG fixture recorder on iPad (with Yutaka sitting next to the son):

- Minimum 3 takes per (target, label) row from Task 13's table — ideally more.
- Speaker tag: `child`.
- Keep takes clean (no background TV, no sibling voices).

- [ ] **Step 2: Export to Mac**

AirDrop → `~/mora-fixtures-child/`. Do NOT copy into the repo.

- [ ] **Step 3: Confirm sidecar JSONs are present**

The DEBUG recorder emits sidecar JSON alongside each WAV. The bench needs them. Spot-check one:

```bash
ls ~/mora-fixtures-child/*.json | head -1 | xargs cat
```

- [ ] **Step 4: No commit**

Nothing to check in. Proceed to Task 16.

---

### Task 16: Run bench against son's fixtures

**Files:** none committed. This task produces a local CSV.

- [ ] **Step 1: Configure SpeechAce**

```bash
cd dev-tools/pronunciation-bench
cp .env.example .env
# edit .env, paste SPEECHACE_API_KEY
```

- [ ] **Step 2: Run the bench**

```bash
source .env
export SPEECHACE_API_KEY
swift run bench ~/mora-fixtures-child/ ~/mora-fixtures-child/child-out.csv
```

Expected: one row per fixture, with both Engine A and SpeechAce columns populated.

- [ ] **Step 3: Review**

Open `child-out.csv` in Numbers or pandas. For each (target, expectedLabel) pair:

- Compute mean Engine A score for the `matched` rows. Low (< 60) suggests the adult-literature centroid is miscalibrated for child speech — likely a formant shift.
- Cross-check against SpeechAce's overall_score. If SpeechAce rates the same audio highly (>80) but Engine A is low, the fix is on Engine A's side.
- For `substitutedBy` rows, confirm Engine A labels the substitute correctly. Label disagreements flag boundary issues.

No code changes in this task. The outcome is a set of proposed shifts for Task 17.

- [ ] **Step 4: No commit**

---

### Task 17: Update `PhonemeThresholds` (numeric only)

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeThresholds.swift`

Only if Task 16's review identifies a threshold that the child-speaker data cannot clear. Do not touch any other file; this task is scoped to numeric centroid/boundary adjustments.

- [ ] **Step 1: Identify the threshold to adjust**

From the CSV, pick the threshold whose shift best explains the divergence. Spec §6.6 (parent spec §14.6) predicts roughly +10 % on F-features (F1, F2, F3). Concrete example: if `/r/` matched-trials score 40–60 when they should score ≥ 70, shift `SubstitutionThresholds(feature: .formantF3Hz, targetCentroid: 1_700, …)` by +10 % → `targetCentroid: 1_870`. Do the same arithmetic for the boundary if it needs to move in sympathy.

Keep the shift within ±15 % of the literature value (spec §6 of the parent spec), otherwise flag for discussion.

- [ ] **Step 2: Apply the change**

Edit the relevant `SubstitutionThresholds(...)` entry inside `PhonemeThresholds.primary(for:against:)` or the `DriftThresholds(...)` entry inside `PhonemeThresholds.drift(for:)`. One threshold per commit; do not batch.

- [ ] **Step 3: Run the adult-proxy fixture tests**

Run: `(cd Packages/MoraEngines && swift test)`

If a test now fails because the adult-proxy fixture score has drifted outside its assertion bound, widen the bound by at most 5 points (70 → 65 for `matched`, 40 → 45 for `substitutedBy`). Document the widening in the commit message. Any wider widening means the child shift is too aggressive — roll back and try a smaller shift.

- [ ] **Step 4: Re-run the bench against son's fixtures**

Same command as Task 16, step 2. Compare the new Engine A numbers. Expected: the targeted `matched` rows for the shifted phoneme now cluster ≥ 60, closer to parity with SpeechAce.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeThresholds.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift
git commit -m "$(cat <<'EOF'
engines: calibrate /r/ F3 centroid for child speakers (+10%)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

(Commit message names the specific phoneme and shift. Repeat Task 17 once per threshold; each commit is scoped to one phoneme.)

- [ ] **Step 6: If no thresholds need adjusting**

That outcome is acceptable. Do not create an empty commit. Close Phase D with a short note in the PR description: "Child-speaker calibration pass: no threshold changes needed. Son's fixtures score within literature-derived bounds for all supported pairs."

---

## Completion Checklist

After Task 17, verify:

- [ ] `(cd Packages/MoraCore && swift test)` green.
- [ ] `(cd Packages/MoraEngines && swift test)` green — `FeatureBasedEvaluatorFixtureTests` included.
- [ ] `(cd Packages/MoraUI && swift test)` green.
- [ ] `(cd Packages/MoraTesting && swift test)` green.
- [ ] `(cd dev-tools/pronunciation-bench && swift test)` green (local only).
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` passes.
- [ ] `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` succeeds.
- [ ] `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Release CODE_SIGNING_ALLOWED=NO` succeeds.
- [ ] `nm <Release-built Mora.app>/Mora | grep -iE 'FixtureRecorder|FixtureWriter|PronunciationRecorderView'` is empty (Release binary does not include DEBUG code).
- [ ] `git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages` is empty (existing Part 1 source gate still green).
- [ ] No file from the "Phase 3 conflict boundary" table was modified on this branch: `git diff --name-only main..HEAD | grep -E '(AssessmentEngine|SessionOrchestrator|AppleSpeechEngine|SpeechEvent|PronunciationEvaluator|MoraMLX|Persistence|MoraApp.swift|project.yml|github/workflows)'` returns empty.
- [ ] DEBUG build on a physical iPad shows the Fixture Recorder after a 5-tap on HomeView; Record + Save writes a WAV + JSON pair surfaced in Files.app.
- [ ] `swift run bench <fixtures-dir> out.csv` with a small local fixture set produces a CSV whose columns match the schema in spec §7.3.

## Handoff notes

- **If Phase 3 merges first:** rebase this branch onto the new main. The only likely conflict is `.gitignore`; accept both sides. `Packages/MoraEngines/Package.swift` is only touched in the `MoraEnginesTests` target stanza, which Phase 3 does not modify.
- **If Part 2 merges first:** Phase 3's rebase will be clean. Nothing in Part 2's file set overlaps with Phase 3's shipped-code modifications.
- **Future session-capture:** once Phase 3's `PronunciationTrialLog` entity exists, consider extending it with an optional `audioBytes` field under `#if DEBUG` to eliminate the need for the manual DEBUG recorder during session capture. That is a new spec, not a Part 2 task.
- **Second calibration pass:** if threshold drift persists after Phase D, consider introducing a `PhonemeThresholds` JSON loader so calibration output stops being a Swift-source edit. That is a follow-up plan, also out of scope here.
