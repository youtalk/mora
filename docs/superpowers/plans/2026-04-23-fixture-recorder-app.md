# Fixture Recorder App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract fixture recording out of the main Mora app into a standalone iPad dev-only app (`recorder/MoraFixtureRecorder/`) driven by a pre-defined 12-pattern catalog, backed by a new shared SPM package (`Packages/MoraFixtures/`) that both the recorder app and `dev-tools/pronunciation-bench/` consume.

**Architecture:** The recorder app owns its own AVAudioEngine-based `FixtureRecorder` and writes sidecar JSON + 16-bit PCM WAV into `<Documents>/<speaker>/<subdir>/<stem>-take<N>.wav`, where `<speaker>` / `<subdir>` / `<stem>` come from the catalog so the user cannot misconfigure metadata. Exports use iOS `ShareLink` (per-take = pair of URLs, bulk = zip via `NSFileCoordinator.forUploading`). Main Mora loses its `#if DEBUG` recorder scaffolding; `dev-tools/pronunciation-bench/` gains a new `MoraFixtures` dependency and its `EngineARunner` starts honoring the catalog-provided phoneme sequence + target index so medial vowels localize correctly (absorbing follow-up plan Task B1's schema extension).

**Tech Stack:** Swift 6.0 (language mode pinned to `.v5`), SwiftUI (iOS 17+), AVFoundation (`AVAudioEngine`, `AVAudioConverter`, `AVAudioFile`), Foundation (`NSFileCoordinator` for zip), XCTest, XcodeGen (for `recorder/project.yml`).

**Design spec:** `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md`.

**Scope:** Five steps land in **one PR**:
- Step A (Tasks 1–7): new `Packages/MoraFixtures/` SPM package
- Step B (Tasks 8–10): `dev-tools/pronunciation-bench/` adopts it
- Step C (Tasks 11–14): main Mora recorder cleanup
- Step D (Tasks 15–22): new `recorder/MoraFixtureRecorder/` iPad app
- Step E (Tasks 23–27): update dependent specs / plans

**Not in scope:**
- Recording audio, trimming, normalizing (stays a Mac-side `sox` step per follow-up plan).
- `FeatureBasedEvaluatorFixtureTests` helper extension for medial vowels (lives in follow-up plan Task B1; lands with Task A1's fixture check-in, not this PR).
- θ/t pair (follow-up plan Task B3).
- CI gates on the recorder app / `Packages/MoraFixtures/`. The main-Mora CI binary gate gets one new assertion (Task 14); no new workflow file.

---

## File structure

### Created

| File | Responsibility |
|---|---|
| `Packages/MoraFixtures/Package.swift` | SPM manifest — iOS 17 + macOS 14, `.v5` language mode, no third-party deps |
| `Packages/MoraFixtures/README.md` | One-paragraph purpose + consumer list |
| `Packages/MoraFixtures/Sources/MoraFixtures/ExpectedLabel.swift` | `enum ExpectedLabel` (moved from MoraEngines) |
| `Packages/MoraFixtures/Sources/MoraFixtures/SpeakerTag.swift` | `enum SpeakerTag` (moved from MoraEngines) |
| `Packages/MoraFixtures/Sources/MoraFixtures/FixtureMetadata.swift` | Codable struct with `phonemeSequenceIPA` + `targetPhonemeIndex` + `patternID` absorbed from follow-up plan Task B1 |
| `Packages/MoraFixtures/Sources/MoraFixtures/FilenameSlug.swift` | IPA → ASCII mapping |
| `Packages/MoraFixtures/Sources/MoraFixtures/FixtureWriter.swift` | `writeTake(pattern:takeNumber:)` + `writeAdHoc(...)` + 16-bit PCM WAV encoding |
| `Packages/MoraFixtures/Sources/MoraFixtures/FixturePattern.swift` | Catalog entry value type |
| `Packages/MoraFixtures/Sources/MoraFixtures/FixtureCatalog.swift` | `v1Patterns: [FixturePattern]` = 12 entries |
| `Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureMetadataTests.swift` | Codable round-trip + legacy decode |
| `Packages/MoraFixtures/Tests/MoraFixturesTests/FilenameSlugTests.swift` | Slug mapping + pass-through |
| `Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureWriterTests.swift` | `writeTake` / `writeAdHoc` filename + WAV round-trip |
| `Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureCatalogTests.swift` | 5 catalog invariants |
| `recorder/project.yml` | XcodeGen input for `MoraFixtureRecorder` (iPad-only, Swift 6 `.v5`) |
| `recorder/README.md` | How to build + usage |
| `recorder/.gitignore` | `*.xcodeproj/`, `DerivedData/` |
| `recorder/MoraFixtureRecorder/Info.plist` | Explicit plist with `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`, `NSMicrophoneUsageDescription` |
| `recorder/MoraFixtureRecorder/MoraFixtureRecorderApp.swift` | `@main` — NavigationStack root |
| `recorder/MoraFixtureRecorder/FixtureRecorder.swift` | AVAudioEngine tap → 16 kHz mono Float32 (moved from MoraEngines) |
| `recorder/MoraFixtureRecorder/RecorderStore.swift` | `@Observable @MainActor` — speaker, recording state, takes on disk, speaker archive |
| `recorder/MoraFixtureRecorder/CatalogListView.swift` | 12-pattern list + speaker toggle + bulk share toolbar |
| `recorder/MoraFixtureRecorder/PatternDetailView.swift` | Record/Stop/Save + takes list |
| `recorder/MoraFixtureRecorder/TakeRow.swift` | Per-take row with per-take ShareLink + delete |
| `recorder/MoraFixtureRecorder/BulkShareButton.swift` | Toolbar button preparing zip + presenting Share Sheet |
| `recorder/MoraFixtureRecorder/Assets.xcassets/Contents.json` | Empty catalog shell |
| `recorder/MoraFixtureRecorder/Assets.xcassets/AppIcon.appiconset/Contents.json` | Placeholder AppIcon |
| `recorder/MoraFixtureRecorder/Assets.xcassets/AccentColor.colorset/Contents.json` | Placeholder accent |
| `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift` | Take count, next-take algorithm, speaker persist |
| `recorder/MoraFixtureRecorderTests/SpeakerArchiveTests.swift` | Zip structure, empty throws |
| `recorder/MoraFixtureRecorderTests/FixtureDirectoryLayoutTests.swift` | Subdir creation, cross-speaker isolation |

### Modified

| File | Change |
|---|---|
| `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` (lines 66–75) | Simplify `wordmark` to a plain `Text` — drop `#if DEBUG` + `debugFixtureRecorderEntry()` |
| `dev-tools/pronunciation-bench/Package.swift` | Add `MoraFixtures` path-dep + product on `Bench` target |
| `dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift` | `import MoraFixtures` (FixtureMetadata now lives there) |
| `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift` | `import MoraFixtures`; build `Word` with `phonemeSequenceIPA` + `targetPhonemeIndex` when present, else fall back to `[target]` |
| `dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift` | `import MoraFixtures` |
| `.github/workflows/ci.yml` | Extend existing binary gate grep to also reject `FixtureRecorder\|FixtureWriter\|FixtureMetadata\|PronunciationRecorderView\|DebugFixtureRecorderEntryModifier` symbols in shipped `Mora.app` |
| `docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md` | Superseding-note block at top |
| `docs/superpowers/plans/2026-04-22-pronunciation-bench-and-calibration.md` | Superseding-note block at top |
| `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` | Rewrite Task A1 / Task A2; reduce Task B1 |

### Deleted

| File | Why |
|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift` | Moved into `MoraFixtures` |
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift` | Moved into `recorder/MoraFixtureRecorder/` |
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureWriter.swift` | Moved into `MoraFixtures` |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift` | Replaced by `MoraFixturesTests/FixtureMetadataTests.swift` |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureWriterTests.swift` | Replaced by `MoraFixturesTests/FixtureWriterTests.swift` |
| `Packages/MoraUI/Sources/MoraUI/Debug/DebugEntryPoint.swift` | No longer needed; recorder is a separate app |
| `Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift` | No longer needed; recorder UI is a separate app |

---

## Conventions

- **English only** in every touched file (code, comments, commit messages, PR body, doc updates).
- **Commit attribution** — `Co-Authored-By: Claude <noreply@anthropic.com>` on every commit (repo opts in via root `CLAUDE.md`).
- **Commit granularity** — one commit per task, message format `area: short description`. Example: `fixtures: add FilenameSlug IPA-to-ASCII mapping`.
- **Use a HEREDOC** for commit messages so the trailer sits on its own line.
- **Swift 6 `.v5` language mode pin** — `Packages/MoraFixtures/Package.swift` sets it on both targets.
- **swift-format strict** runs in CI across `Mora Packages/*/Sources Packages/*/Tests`. Tests under `Packages/MoraFixtures/Tests/MoraFixturesTests/` are picked up automatically; keep 4-space indent, trailing commas on every list element, braces on same line.
- **xcodegen team injection** applies to `recorder/project.yml`. Before `xcodegen generate`, temporarily inject `DEVELOPMENT_TEAM: 2AFT9XT8R2` under the recorder target's `settings.base`; after the generate, `git checkout -- recorder/project.yml` (or the equivalent) so the team ID is never committed.
- **Cannot run** `xcodegen generate` without a team injection — generation will fail or produce un-signable output on a physical device target.
- **Working-tree hygiene** — the `worktree-silly-wiggling-naur` branch may start with an unstaged `project.yml` diff (a local experiment re-adding the Debug `configs` / `postBuildScripts` that never landed on `main`). Task 11 discards it before committing.
- **No `#if DEBUG`** in any new file. `MoraFixtures` types ship unconditionally; recorder app is always on inside its own target.
- **Verification before commit** — after every task, run whichever of these applies:
  - `(cd Packages/MoraFixtures && swift test)` for Step A
  - `(cd dev-tools/pronunciation-bench && swift test)` for Step B
  - `(cd Packages/MoraCore && swift test) && (cd Packages/MoraEngines && swift test) && (cd Packages/MoraUI && swift test) && (cd Packages/MoraTesting && swift test)` for Step C
  - `xcodebuild build -project recorder/"Mora Fixture Recorder.xcodeproj" -scheme MoraFixtureRecorder -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` for Step D code tasks
  - `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` after every code-touching commit.

---

## Step A — `Packages/MoraFixtures/` skeleton and types

Internal dependency graph for this step: 1 → 2 → (3 ∥ 4) → (5 ∥ 6) → 7.

### Task 1: Create the `MoraFixtures` SPM skeleton

**Files:**
- Create: `Packages/MoraFixtures/Package.swift`
- Create: `Packages/MoraFixtures/README.md`
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/.gitkeep`
- Create: `Packages/MoraFixtures/Tests/MoraFixturesTests/.gitkeep`

- [ ] **Step 1: Write `Package.swift`**

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

- [ ] **Step 2: Write `README.md`**

```markdown
# MoraFixtures

Shared value types for fixture audio recording and bench ingestion.

- `FixtureMetadata`, `ExpectedLabel`, `SpeakerTag` — the sidecar-JSON schema the
  recorder writes and the bench reads.
- `FixturePattern`, `FixtureCatalog.v1Patterns` — the 12-entry canonical pattern
  list the recorder UI drives.
- `FixtureWriter`, `FilenameSlug` — pure-Swift 16-bit PCM WAV writer and the
  IPA-to-ASCII filename slug helper.

Consumed by:
- `recorder/MoraFixtureRecorder/` (the iPad recorder app)
- `dev-tools/pronunciation-bench/` (the Mac benchmarking CLI)

Not consumed by the shipped Mora app. Main `Mora.app` has no dependency edge
into this package.
```

- [ ] **Step 3: Placeholder gitkeep files**

Create empty files `Packages/MoraFixtures/Sources/MoraFixtures/.gitkeep` and `Packages/MoraFixtures/Tests/MoraFixturesTests/.gitkeep` so the empty directories are committable. Subsequent tasks overwrite with real sources and delete the gitkeeps once sources exist (Task 2 deletes `Sources/.gitkeep`; Task 3 deletes `Tests/.gitkeep`).

- [ ] **Step 4: Verify Package resolves**

Run: `(cd Packages/MoraFixtures && swift build)`

Expected: `Build complete!` with no sources-compiled output (just the dependency graph resolving to empty).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraFixtures/Package.swift \
        Packages/MoraFixtures/README.md \
        Packages/MoraFixtures/Sources/MoraFixtures/.gitkeep \
        Packages/MoraFixtures/Tests/MoraFixturesTests/.gitkeep
git commit -m "$(cat <<'EOF'
fixtures: add empty MoraFixtures SPM package

Step A.1 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 2: Move `ExpectedLabel` and `SpeakerTag`

**Files:**
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/ExpectedLabel.swift`
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/SpeakerTag.swift`
- Delete: `Packages/MoraFixtures/Sources/MoraFixtures/.gitkeep`

Note: the existing `ExpectedLabel` and `SpeakerTag` currently live inside `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift`. They stay in MoraEngines for now — Task 11 deletes that file as part of Step C. No cross-package duplication concern because the two packages are not linked together.

- [ ] **Step 1: Write `ExpectedLabel.swift`**

```swift
import Foundation

/// Label the fixture author intended to produce. Mirrors
/// `PhonemeAssessmentLabel` but is its own type — the bench compares
/// "what the author intended" against "what Engine A said" per fixture.
public enum ExpectedLabel: String, Codable, Sendable, Hashable {
    case matched
    case substitutedBy
    case driftedWithin
}
```

- [ ] **Step 2: Write `SpeakerTag.swift`**

```swift
import Foundation

/// Who produced the fixture. Adult fixtures are checked into the engines
/// package for regression coverage; child fixtures stay on the developer's
/// laptop per the bench-and-calibration spec.
public enum SpeakerTag: String, Codable, Sendable, Hashable {
    case adult
    case child
}
```

- [ ] **Step 3: Delete the sources gitkeep**

```bash
rm Packages/MoraFixtures/Sources/MoraFixtures/.gitkeep
```

- [ ] **Step 4: Verify build**

Run: `(cd Packages/MoraFixtures && swift build)`

Expected: `Build complete!` with `ExpectedLabel` and `SpeakerTag` compiled.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraFixtures/Sources/MoraFixtures/ExpectedLabel.swift \
        Packages/MoraFixtures/Sources/MoraFixtures/SpeakerTag.swift \
        Packages/MoraFixtures/Sources/MoraFixtures/.gitkeep
git commit -m "$(cat <<'EOF'
fixtures: add ExpectedLabel and SpeakerTag enums

Step A.2 of fixture-recorder-app plan. Same shape as the MoraEngines
Debug/ copies, which Task 11 deletes.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 3: `FilenameSlug` helper + tests

**Files:**
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/FilenameSlug.swift`
- Create: `Packages/MoraFixtures/Tests/MoraFixturesTests/FilenameSlugTests.swift`
- Delete: `Packages/MoraFixtures/Tests/MoraFixturesTests/.gitkeep`

- [ ] **Step 1: Write the failing test**

```swift
// Packages/MoraFixtures/Tests/MoraFixturesTests/FilenameSlugTests.swift
import XCTest
@testable import MoraFixtures

final class FilenameSlugTests: XCTestCase {

    func testMapsShToSh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ʃ"), "sh") }
    func testMapsThToTh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "θ"), "th") }
    func testMapsAeToAe() { XCTAssertEqual(FilenameSlug.ascii(ipa: "æ"), "ae") }
    func testMapsUhToUh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ʌ"), "uh") }
    func testMapsIhToIh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɪ"), "ih") }
    func testMapsEhToEh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɛ"), "eh") }
    func testMapsAwToAw() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɔ"), "aw") }
    func testMapsAhToAh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ɑ"), "ah") }
    func testMapsErToEr() {
        XCTAssertEqual(FilenameSlug.ascii(ipa: "ɜ"), "er")
        XCTAssertEqual(FilenameSlug.ascii(ipa: "ɚ"), "er")
    }
    func testMapsNgToNg() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ŋ"), "ng") }
    func testMapsZhToZh() { XCTAssertEqual(FilenameSlug.ascii(ipa: "ʒ"), "zh") }
    func testPassesThroughUnmapped() {
        XCTAssertEqual(FilenameSlug.ascii(ipa: "r"), "r")
        XCTAssertEqual(FilenameSlug.ascii(ipa: "l"), "l")
        XCTAssertEqual(FilenameSlug.ascii(ipa: "k"), "k")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraFixtures && swift test --filter FilenameSlugTests)`

Expected: FAIL with `Cannot find 'FilenameSlug' in scope`.

- [ ] **Step 3: Write `FilenameSlug.swift`**

```swift
import Foundation

/// Maps IPA characters to ASCII filename components.
/// Unmapped characters pass through unchanged.
public enum FilenameSlug {
    public static func ascii(ipa: String) -> String {
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
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraFixtures && swift test --filter FilenameSlugTests)`

Expected: PASS.

- [ ] **Step 5: Delete the tests gitkeep**

```bash
rm Packages/MoraFixtures/Tests/MoraFixturesTests/.gitkeep
```

- [ ] **Step 6: Commit**

```bash
git add Packages/MoraFixtures/Sources/MoraFixtures/FilenameSlug.swift \
        Packages/MoraFixtures/Tests/MoraFixturesTests/FilenameSlugTests.swift \
        Packages/MoraFixtures/Tests/MoraFixturesTests/.gitkeep
git commit -m "$(cat <<'EOF'
fixtures: add FilenameSlug IPA-to-ASCII helper

Step A.3 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 4: `FixtureMetadata` with Task B1 fields + legacy decode

**Files:**
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/FixtureMetadata.swift`
- Create: `Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureMetadataTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureMetadataTests.swift
import XCTest
@testable import MoraFixtures

final class FixtureMetadataTests: XCTestCase {

    func testRoundTripsThroughCodable() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            sampleRate: 16_000,
            durationSeconds: 0.6,
            speakerTag: .adult,
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            patternID: "aeuh-cat-correct"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testSubstitutePhonemeNilForMatchedLabel() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 0),
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            sampleRate: 16_000,
            durationSeconds: 0.5,
            speakerTag: .adult,
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            patternID: "rl-right-correct"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertNil(decoded.substitutePhonemeIPA)
        XCTAssertEqual(decoded.expectedLabel, .matched)
    }

    func testDecodesLegacyPayloadWithoutTaskB1Fields() throws {
        // Sidecar JSON from before the 2026-04-23 schema extension — it
        // does not include phonemeSequenceIPA, targetPhonemeIndex, or
        // patternID. The decoder must tolerate the absence.
        let legacy = #"""
        {
            "capturedAt" : "2026-04-22T10:00:00Z",
            "targetPhonemeIPA" : "r",
            "expectedLabel" : "matched",
            "wordSurface" : "right",
            "sampleRate" : 16000,
            "durationSeconds" : 0.5,
            "speakerTag" : "adult"
        }
        """#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: legacy)
        XCTAssertEqual(decoded.targetPhonemeIPA, "r")
        XCTAssertNil(decoded.substitutePhonemeIPA)
        XCTAssertNil(decoded.phonemeSequenceIPA)
        XCTAssertNil(decoded.targetPhonemeIndex)
        XCTAssertNil(decoded.patternID)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraFixtures && swift test --filter FixtureMetadataTests)`

Expected: FAIL with `Cannot find 'FixtureMetadata' in scope`.

- [ ] **Step 3: Write `FixtureMetadata.swift`**

```swift
import Foundation

/// Sidecar metadata written alongside each fixture WAV. The recorder
/// app writes this from catalog data; the bench reads it to ingest
/// fixtures.
///
/// Legacy sidecars produced before 2026-04-23 (under the in-main-app
/// DEBUG recorder) lack `phonemeSequenceIPA`, `targetPhonemeIndex`,
/// and `patternID` — those three fields decode as `nil` via
/// `decodeIfPresent`. New sidecars written by the recorder app always
/// have them populated from the `FixturePattern` that produced the
/// take.
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag
    public let phonemeSequenceIPA: [String]?
    public let targetPhonemeIndex: Int?
    public let patternID: String?

    public init(
        capturedAt: Date,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag,
        phonemeSequenceIPA: [String]?,
        targetPhonemeIndex: Int?,
        patternID: String?
    ) {
        self.capturedAt = capturedAt
        self.targetPhonemeIPA = targetPhonemeIPA
        self.expectedLabel = expectedLabel
        self.substitutePhonemeIPA = substitutePhonemeIPA
        self.wordSurface = wordSurface
        self.sampleRate = sampleRate
        self.durationSeconds = durationSeconds
        self.speakerTag = speakerTag
        self.phonemeSequenceIPA = phonemeSequenceIPA
        self.targetPhonemeIndex = targetPhonemeIndex
        self.patternID = patternID
    }

    private enum CodingKeys: String, CodingKey {
        case capturedAt
        case targetPhonemeIPA
        case expectedLabel
        case substitutePhonemeIPA
        case wordSurface
        case sampleRate
        case durationSeconds
        case speakerTag
        case phonemeSequenceIPA
        case targetPhonemeIndex
        case patternID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        capturedAt = try c.decode(Date.self, forKey: .capturedAt)
        targetPhonemeIPA = try c.decode(String.self, forKey: .targetPhonemeIPA)
        expectedLabel = try c.decode(ExpectedLabel.self, forKey: .expectedLabel)
        substitutePhonemeIPA = try c.decodeIfPresent(String.self, forKey: .substitutePhonemeIPA)
        wordSurface = try c.decode(String.self, forKey: .wordSurface)
        sampleRate = try c.decode(Double.self, forKey: .sampleRate)
        durationSeconds = try c.decode(Double.self, forKey: .durationSeconds)
        speakerTag = try c.decode(SpeakerTag.self, forKey: .speakerTag)
        phonemeSequenceIPA = try c.decodeIfPresent([String].self, forKey: .phonemeSequenceIPA)
        targetPhonemeIndex = try c.decodeIfPresent(Int.self, forKey: .targetPhonemeIndex)
        patternID = try c.decodeIfPresent(String.self, forKey: .patternID)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraFixtures && swift test --filter FixtureMetadataTests)`

Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraFixtures/Sources/MoraFixtures/FixtureMetadata.swift \
        Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureMetadataTests.swift
git commit -m "$(cat <<'EOF'
fixtures: add FixtureMetadata with Task B1 fields

Schema absorbs phonemeSequenceIPA + targetPhonemeIndex that followup
plan Task B1 was going to retrofit, plus a new patternID field that
lets the bench reconcile takes with catalog entries. decodeIfPresent
on the three new fields keeps legacy sidecars decodable.

Step A.4 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 5: `FixturePattern`

**Files:**
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/FixturePattern.swift`

No dedicated test file — `FixtureCatalogTests` in Task 7 exercises this type through the catalog invariants. `FixtureWriterTests` (Task 6) also constructs a `FixturePattern` directly.

- [ ] **Step 1: Write `FixturePattern.swift`**

```swift
import Foundation

/// One entry in `FixtureCatalog.v1Patterns`. Owns every metadata field
/// the recorder would otherwise have asked the user for — target phoneme,
/// expected label, substitute phoneme, word, phoneme sequence, target
/// index, output subdirectory, and filename stem. The recorder writes
/// a WAV + sidecar JSON per take; filename is
/// `<filenameStem>-take<N>.wav` under `<speaker>/<outputSubdirectory>/`.
public struct FixturePattern: Sendable, Hashable, Identifiable {
    public let id: String
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let phonemeSequenceIPA: [String]
    public let targetPhonemeIndex: Int
    public let outputSubdirectory: String
    public let filenameStem: String

    public init(
        id: String,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        phonemeSequenceIPA: [String],
        targetPhonemeIndex: Int,
        outputSubdirectory: String,
        filenameStem: String
    ) {
        self.id = id
        self.targetPhonemeIPA = targetPhonemeIPA
        self.expectedLabel = expectedLabel
        self.substitutePhonemeIPA = substitutePhonemeIPA
        self.wordSurface = wordSurface
        self.phonemeSequenceIPA = phonemeSequenceIPA
        self.targetPhonemeIndex = targetPhonemeIndex
        self.outputSubdirectory = outputSubdirectory
        self.filenameStem = filenameStem
    }

    /// Human-readable label the catalog list row displays. Format:
    /// "<word> — /<target>/ <expectedLabel>[ by /<substitute>/]".
    public var displayLabel: String {
        let base = "\(wordSurface) — /\(targetPhonemeIPA)/ \(expectedLabel.rawValue)"
        if let sub = substitutePhonemeIPA {
            return "\(base) by /\(sub)/"
        }
        return base
    }

    /// Builds `FixtureMetadata` for a new take. Fields derived from this
    /// pattern (target, expected, substitute, word, sequence, index,
    /// patternID) are taken from self; runtime fields are supplied by
    /// the recorder.
    public func metadata(
        capturedAt: Date,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag
    ) -> FixtureMetadata {
        FixtureMetadata(
            capturedAt: capturedAt,
            targetPhonemeIPA: targetPhonemeIPA,
            expectedLabel: expectedLabel,
            substitutePhonemeIPA: substitutePhonemeIPA,
            wordSurface: wordSurface,
            sampleRate: sampleRate,
            durationSeconds: durationSeconds,
            speakerTag: speakerTag,
            phonemeSequenceIPA: phonemeSequenceIPA,
            targetPhonemeIndex: targetPhonemeIndex,
            patternID: id
        )
    }
}
```

- [ ] **Step 2: Verify build**

Run: `(cd Packages/MoraFixtures && swift build)`

Expected: `Build complete!`.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraFixtures/Sources/MoraFixtures/FixturePattern.swift
git commit -m "$(cat <<'EOF'
fixtures: add FixturePattern value type

Step A.5 of fixture-recorder-app plan. Carries all fields the recorder
UI would otherwise expose as editable, plus a metadata(capturedAt:...)
factory so the recorder cannot build a partially-correct FixtureMetadata.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 6: `FixtureWriter` with `writeTake` / `writeAdHoc` + tests

**Files:**
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/FixtureWriter.swift`
- Create: `Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureWriterTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureWriterTests.swift
import AVFoundation
import XCTest
@testable import MoraFixtures

final class FixtureWriterTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testWriteTakeFilename() throws {
        let samples: [Float] = Array(repeating: 0, count: 1_600)
        let pattern = FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        )
        let meta = pattern.metadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            sampleRate: 16_000,
            durationSeconds: 0.1,
            speakerTag: .adult
        )
        let out = try FixtureWriter.writeTake(
            samples: samples, metadata: meta,
            pattern: pattern, takeNumber: 1,
            into: tempDir
        )
        XCTAssertEqual(out.wav.lastPathComponent, "right-correct-take1.wav")
        XCTAssertEqual(out.sidecar.lastPathComponent, "right-correct-take1.json")
    }

    func testWriteTakeCreatesMissingSubdirectory() throws {
        let pattern = FixturePattern(
            id: "aeuh-cat-correct",
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            outputSubdirectory: "aeuh",
            filenameStem: "cat-correct"
        )
        let targetDir = tempDir.appendingPathComponent("adult/aeuh")
        // No createDirectory — writeTake must create it.
        let meta = pattern.metadata(
            capturedAt: Date(), sampleRate: 16_000,
            durationSeconds: 0.1, speakerTag: .adult
        )
        _ = try FixtureWriter.writeTake(
            samples: Array(repeating: 0, count: 1_600),
            metadata: meta, pattern: pattern, takeNumber: 2,
            into: targetDir
        )
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: targetDir.appendingPathComponent("cat-correct-take2.wav").path))
    }

    func testWavRoundTripsThroughAvAudioFile() throws {
        let samples: [Float] = (0..<1_600).map { sinf(Float($0) * 2 * .pi * 440 / 16_000) }
        let pattern = FixturePattern(
            id: "rl-right-correct",
            targetPhonemeIPA: "r",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-correct"
        )
        let meta = pattern.metadata(
            capturedAt: Date(), sampleRate: 16_000,
            durationSeconds: 0.1, speakerTag: .adult
        )
        let out = try FixtureWriter.writeTake(
            samples: samples, metadata: meta,
            pattern: pattern, takeNumber: 1, into: tempDir
        )
        let file = try AVAudioFile(forReading: out.wav)
        XCTAssertEqual(file.fileFormat.sampleRate, 16_000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(Int(file.length), samples.count)
    }

    func testSidecarJsonRoundTripsMetadata() throws {
        let pattern = FixturePattern(
            id: "rl-right-as-light",
            targetPhonemeIPA: "r",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "l",
            wordSurface: "right",
            phonemeSequenceIPA: ["r", "aɪ", "t"],
            targetPhonemeIndex: 0,
            outputSubdirectory: "rl",
            filenameStem: "right-as-light"
        )
        let meta = pattern.metadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            sampleRate: 16_000,
            durationSeconds: 0.5,
            speakerTag: .adult
        )
        let out = try FixtureWriter.writeTake(
            samples: Array(repeating: 0, count: 8_000),
            metadata: meta, pattern: pattern, takeNumber: 1,
            into: tempDir
        )
        let data = try Data(contentsOf: out.sidecar)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FixtureMetadata.self, from: data)
        XCTAssertEqual(decoded, meta)
    }

    func testWriteAdHocFilenameIncludesTargetAndLabelSlugs() throws {
        let meta = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "ʃ",
            expectedLabel: .substitutedBy,
            substitutePhonemeIPA: "s",
            wordSurface: "ship",
            sampleRate: 16_000,
            durationSeconds: 0.1,
            speakerTag: .adult,
            phonemeSequenceIPA: nil,
            targetPhonemeIndex: nil,
            patternID: nil
        )
        let out = try FixtureWriter.writeAdHoc(
            samples: Array(repeating: 0, count: 1_600),
            metadata: meta, into: tempDir
        )
        XCTAssertTrue(out.wav.lastPathComponent.contains("sh"))
        XCTAssertTrue(out.wav.lastPathComponent.contains("substitutedBy"))
        XCTAssertTrue(out.wav.lastPathComponent.contains("s.wav"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraFixtures && swift test --filter FixtureWriterTests)`

Expected: FAIL with `Cannot find 'FixtureWriter' in scope`.

- [ ] **Step 3: Write `FixtureWriter.swift`**

```swift
import Foundation

public enum FixtureWriterError: Error, Sendable {
    case directoryUnavailable(URL)
}

public enum FixtureWriter {

    public struct Output: Equatable, Sendable {
        public let wav: URL
        public let sidecar: URL
    }

    /// Catalog-driven take. Filename: `<pattern.filenameStem>-take<N>.wav/.json`
    /// inside `directory`. Creates `directory` if missing.
    public static func writeTake(
        samples: [Float],
        metadata: FixtureMetadata,
        pattern: FixturePattern,
        takeNumber: Int,
        into directory: URL
    ) throws -> Output {
        try ensureDirectory(directory)
        let basename = "\(pattern.filenameStem)-take\(takeNumber)"
        return try write(
            samples: samples, metadata: metadata,
            basename: basename, directory: directory
        )
    }

    /// Ad-hoc take. Filename: `<ISO timestamp>-<targetSlug>-<labelSlug>[-<subSlug>].wav`.
    /// Kept for CLI utilities; the recorder app uses `writeTake` instead.
    public static func writeAdHoc(
        samples: [Float],
        metadata: FixtureMetadata,
        into directory: URL
    ) throws -> Output {
        try ensureDirectory(directory)
        return try write(
            samples: samples, metadata: metadata,
            basename: adHocBasename(for: metadata),
            directory: directory
        )
    }

    private static func ensureDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
    }

    private static func write(
        samples: [Float], metadata: FixtureMetadata,
        basename: String, directory: URL
    ) throws -> Output {
        let wavURL = directory.appendingPathComponent(basename + ".wav")
        let sidecarURL = directory.appendingPathComponent(basename + ".json")

        try encodeWAV(samples: samples, sampleRate: metadata.sampleRate)
            .write(to: wavURL, options: .atomic)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(metadata)
        try json.write(to: sidecarURL, options: .atomic)

        return Output(wav: wavURL, sidecar: sidecarURL)
    }

    private static func adHocBasename(for meta: FixtureMetadata) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let ts = formatter.string(from: meta.capturedAt)
        let target = FilenameSlug.ascii(ipa: meta.targetPhonemeIPA)
        let label = meta.expectedLabel.rawValue
        if let sub = meta.substitutePhonemeIPA {
            return "\(ts)-\(target)-\(label)-\(FilenameSlug.ascii(ipa: sub))"
        }
        return "\(ts)-\(target)-\(label)"
    }

    // 16-bit PCM little-endian mono RIFF/WAVE encoder — matches the shape
    // AVAudioFile(forReading:) can parse.
    private static func encodeWAV(samples: [Float], sampleRate: Double) -> Data {
        var data = Data()
        let byteRate = UInt32(sampleRate) * 2
        let blockAlign: UInt16 = 2
        let bitsPerSample: UInt16 = 16
        let subchunk2Size = UInt32(samples.count) * UInt32(blockAlign)
        let chunkSize = 36 + subchunk2Size

        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: chunkSize.littleEndianBytes)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: UInt32(16).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt16(1).littleEndianBytes)
        data.append(contentsOf: UInt32(sampleRate).littleEndianBytes)
        data.append(contentsOf: byteRate.littleEndianBytes)
        data.append(contentsOf: blockAlign.littleEndianBytes)
        data.append(contentsOf: bitsPerSample.littleEndianBytes)
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: subchunk2Size.littleEndianBytes)

        for f in samples {
            let clamped = max(-1, min(1, f))
            let i: Int16 = clamped == -1 ? .min : Int16(clamped * Float(Int16.max))
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraFixtures && swift test --filter FixtureWriterTests)`

Expected: PASS (5/5).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraFixtures/Sources/MoraFixtures/FixtureWriter.swift \
        Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureWriterTests.swift
git commit -m "$(cat <<'EOF'
fixtures: add FixtureWriter with writeTake/writeAdHoc

writeTake produces catalog-driven filenames (<stem>-take<N>) and
auto-creates the target subdirectory. writeAdHoc preserves the
timestamp+target+label filename convention from the in-main-app
recorder for any residual CLI callers.

Step A.6 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 7: `FixtureCatalog.v1Patterns` (12 entries) + invariant tests

**Files:**
- Create: `Packages/MoraFixtures/Sources/MoraFixtures/FixtureCatalog.swift`
- Create: `Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureCatalogTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureCatalogTests.swift
import XCTest
@testable import MoraFixtures

final class FixtureCatalogTests: XCTestCase {

    func testCountIsTwelve() {
        XCTAssertEqual(FixtureCatalog.v1Patterns.count, 12)
    }

    func testAllIDsAreUnique() {
        let ids = FixtureCatalog.v1Patterns.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testAllFilenameStemsAreUnique() {
        let stems = FixtureCatalog.v1Patterns.map(\.filenameStem)
        XCTAssertEqual(stems.count, Set(stems).count)
    }

    func testSubstituteBijectsWithExpectedLabel() {
        for p in FixtureCatalog.v1Patterns {
            if p.expectedLabel == .substitutedBy {
                XCTAssertNotNil(
                    p.substitutePhonemeIPA,
                    "substitutedBy entry \(p.id) must have substitutePhonemeIPA")
            } else {
                XCTAssertNil(
                    p.substitutePhonemeIPA,
                    "non-substituted entry \(p.id) must not have substitutePhonemeIPA")
            }
        }
    }

    func testTargetIndexIsWithinSequence() {
        for p in FixtureCatalog.v1Patterns {
            XCTAssertTrue(
                p.phonemeSequenceIPA.indices.contains(p.targetPhonemeIndex),
                "\(p.id) targetPhonemeIndex \(p.targetPhonemeIndex) outside " +
                "sequence of length \(p.phonemeSequenceIPA.count)")
            XCTAssertEqual(
                p.phonemeSequenceIPA[p.targetPhonemeIndex],
                p.targetPhonemeIPA,
                "\(p.id) sequence[targetPhonemeIndex] \(p.phonemeSequenceIPA[p.targetPhonemeIndex]) " +
                "does not match targetPhonemeIPA \(p.targetPhonemeIPA)"
            )
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraFixtures && swift test --filter FixtureCatalogTests)`

Expected: FAIL with `Cannot find 'FixtureCatalog' in scope`.

- [ ] **Step 3: Write `FixtureCatalog.swift`**

```swift
import Foundation

public enum FixtureCatalog {

    /// The canonical 12-pattern list the recorder UI walks.
    /// Source of truth: followup plan 2026-04-23-pronunciation-bench-followups.md
    /// Task A1 Step 2. phonemeSequenceIPA / targetPhonemeIndex are
    /// pre-baked so medial vowels localize correctly in downstream
    /// PhonemeRegionLocalizer without user input.
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

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraFixtures && swift test --filter FixtureCatalogTests)`

Expected: PASS (5/5).

- [ ] **Step 5: Run the full MoraFixtures test suite**

Run: `(cd Packages/MoraFixtures && swift test)`

Expected: All tests PASS across `FilenameSlugTests`, `FixtureMetadataTests`, `FixtureWriterTests`, `FixtureCatalogTests`.

- [ ] **Step 6: Run swift-format**

Run: `swift-format lint --strict --recursive Packages/MoraFixtures/Sources Packages/MoraFixtures/Tests`

Expected: silent.

- [ ] **Step 7: Commit**

```bash
git add Packages/MoraFixtures/Sources/MoraFixtures/FixtureCatalog.swift \
        Packages/MoraFixtures/Tests/MoraFixturesTests/FixtureCatalogTests.swift
git commit -m "$(cat <<'EOF'
fixtures: add FixtureCatalog.v1Patterns (12 entries)

Canonical pattern list for r/l, v/b, ae/uh per followup plan Task A1.
Invariant tests guard uniqueness of id + filenameStem, label/substitute
bijection, and targetPhonemeIndex consistency — any typo fails CI.

Step A.7 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Step B — `dev-tools/pronunciation-bench/` adopts `MoraFixtures`

### Task 8: Add `MoraFixtures` dep to bench `Package.swift`

**Files:**
- Modify: `dev-tools/pronunciation-bench/Package.swift`

- [ ] **Step 1: Edit `Package.swift`**

Replace the current `dependencies` and `Bench`-target `dependencies` arrays:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pronunciation-bench",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "bench", targets: ["Bench"]),
    ],
    dependencies: [
        .package(path: "../../Packages/MoraEngines"),
        .package(path: "../../Packages/MoraCore"),
        .package(path: "../../Packages/MoraFixtures"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "Bench",
            dependencies: [
                .product(name: "MoraEngines", package: "MoraEngines"),
                .product(name: "MoraCore", package: "MoraCore"),
                .product(name: "MoraFixtures", package: "MoraFixtures"),
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

- [ ] **Step 2: Resolve dependencies**

Run: `(cd dev-tools/pronunciation-bench && swift package resolve)`

Expected: the resolver picks up `MoraFixtures` (no version — it is a local path dep).

- [ ] **Step 3: Verify it still builds** (will fail at import sites until Tasks 9–10 land)

Run: `(cd dev-tools/pronunciation-bench && swift build) || true`

Expected: Error messages about `FixtureMetadata` being ambiguous (present in both `MoraEngines` and `MoraFixtures`) OR succeed cleanly. If ambiguous errors appear, they are fixed by the import-scope changes in Tasks 9–10.

- [ ] **Step 4: Commit (defer verification to Task 10)**

```bash
git add dev-tools/pronunciation-bench/Package.swift
git commit -m "$(cat <<'EOF'
bench: add MoraFixtures path dependency

Step B.8 of fixture-recorder-app plan. Import swap in the next two tasks.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 9: Swap imports in `FixtureLoader` and `FixtureLoaderTests`

**Files:**
- Modify: `dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift:1–3`
- Modify: `dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift` (import block)

- [ ] **Step 1: Edit `FixtureLoader.swift`**

At the top of the file, replace:

```swift
import AVFoundation
import Foundation
import MoraEngines
```

with:

```swift
import AVFoundation
import Foundation
import MoraFixtures
```

(The body of `FixtureLoader` itself stays unchanged — `FixtureMetadata` now resolves through `MoraFixtures` instead of `MoraEngines`. `AudioClip`, `Word`, `Phoneme`, etc. are still `MoraCore` / `MoraEngines` types and are not referenced in this file.)

- [ ] **Step 2: Edit `FixtureLoaderTests.swift`**

Replace `import MoraEngines` with `import MoraFixtures`. If the file already imports `MoraEngines` for any other purpose, keep that import — add `import MoraFixtures` alongside. Read the file first to confirm.

- [ ] **Step 3: Verify bench tests still pass**

Run: `(cd dev-tools/pronunciation-bench && swift test --filter FixtureLoaderTests)`

Expected: all tests PASS — the behavior is unchanged, only the import scope moved.

- [ ] **Step 4: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/FixtureLoader.swift \
        dev-tools/pronunciation-bench/Tests/BenchTests/FixtureLoaderTests.swift
git commit -m "$(cat <<'EOF'
bench: source FixtureMetadata from MoraFixtures

Step B.9 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 10: `EngineARunner` honors `phonemeSequenceIPA` / `targetPhonemeIndex`

**Files:**
- Modify: `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift`

This absorbs followup plan Task B1 Step 4 (the `EngineARunner` call-site update). The test helper update (Task B1 Step 5) stays in the followup plan, landing with the fixture check-in.

- [ ] **Step 1: Edit `EngineARunner.swift`**

Replace the file body with:

```swift
import Foundation
import MoraCore
import MoraEngines
import MoraFixtures

public struct EngineARunner {

    public init() {}

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        let evaluator = FeatureBasedPronunciationEvaluator()
        let target = Phoneme(ipa: loaded.metadata.targetPhonemeIPA)

        // Use the catalog-provided phoneme sequence + target index when
        // present (new sidecars, post-2026-04-23). Fall back to [target]
        // for legacy sidecars where the recorder did not yet carry the
        // sequence — PhonemeRegionLocalizer treats that as an onset-only
        // evaluation, matching the pre-Task-B1 behavior.
        let phonemes: [Phoneme]
        let targetIndex: Int
        if let seq = loaded.metadata.phonemeSequenceIPA,
           let idx = loaded.metadata.targetPhonemeIndex,
           seq.indices.contains(idx) {
            phonemes = seq.map { Phoneme(ipa: $0) }
            targetIndex = idx
        } else {
            phonemes = [target]
            targetIndex = 0
        }

        let word = Word(
            surface: loaded.metadata.wordSurface,
            graphemes: [Grapheme(letters: loaded.metadata.wordSurface)],
            phonemes: phonemes,
            targetPhoneme: phonemes[targetIndex]
        )
        let audio = AudioClip(samples: loaded.samples, sampleRate: loaded.sampleRate)
        return await evaluator.evaluate(
            audio: audio, expected: word,
            targetPhoneme: phonemes[targetIndex],
            asr: ASRResult(transcript: loaded.metadata.wordSurface, confidence: 1.0)
        )
    }
}
```

- [ ] **Step 2: Verify the bench full test suite**

Run: `(cd dev-tools/pronunciation-bench && swift test)`

Expected: all tests PASS. (Existing `BenchTests` exercise the loader and the SpeechAce client; `EngineARunner` has no dedicated unit test and will be exercised end-to-end when fixtures land post-PR.)

- [ ] **Step 3: swift-format**

Run: `swift-format lint --strict dev-tools/pronunciation-bench/Sources dev-tools/pronunciation-bench/Tests`

Note: the repo's CI lint invocation only covers `Mora Packages/*/Sources Packages/*/Tests`, not `dev-tools/`. Running on the bench here is best-effort for consistency but not a CI gate.

Expected: silent (or acceptable warnings the repo already ignores for bench).

- [ ] **Step 4: Commit**

```bash
git add dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift
git commit -m "$(cat <<'EOF'
bench: honor phonemeSequenceIPA + targetPhonemeIndex in EngineARunner

Absorbs followup plan Task B1 Step 4: when the sidecar carries the
full phoneme sequence and target index (new recorder output), build
the Word with that sequence so PhonemeRegionLocalizer picks the right
region for medial vowels. Legacy sidecars fall back to [target].

Step B.10 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Step C — Remove recorder from main Mora

### Task 11: Delete main-Mora recorder source trees

**Files:**
- Delete directory: `Packages/MoraEngines/Sources/MoraEngines/Debug/`
- Delete directory: `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/`
- Delete directory: `Packages/MoraUI/Sources/MoraUI/Debug/`

- [ ] **Step 1: Restore any unstaged `project.yml` diff first**

If the worktree currently has an unstaged `project.yml` diff re-adding the Debug `configs` / `postBuildScripts` (visible as `M project.yml` in `git status`), discard it — this plan supersedes that attempt. Check with `git status` and `git diff project.yml`; if the diff adds `LSSupportsOpeningDocumentsInPlace` / `UIFileSharingEnabled` blocks, run:

```bash
git restore project.yml
```

If `git status` shows `project.yml` is clean, skip this step.

- [ ] **Step 2: Delete the three Debug directories**

```bash
rm -r Packages/MoraEngines/Sources/MoraEngines/Debug \
      Packages/MoraEngines/Tests/MoraEnginesTests/Debug \
      Packages/MoraUI/Sources/MoraUI/Debug
```

- [ ] **Step 3: Verify the deletions**

```bash
test ! -d Packages/MoraEngines/Sources/MoraEngines/Debug && \
test ! -d Packages/MoraEngines/Tests/MoraEnginesTests/Debug && \
test ! -d Packages/MoraUI/Sources/MoraUI/Debug && \
echo "ok"
```

Expected: `ok`.

- [ ] **Step 4: Commit the deletion alone** (HomeView hook is Task 12, so Engines/UI package tests may fail here because `HomeView.swift` still references `debugFixtureRecorderEntry()`). Commit the three deletions now; Task 12 fixes the compile.

```bash
git add -A Packages/MoraEngines/Sources/MoraEngines/Debug \
           Packages/MoraEngines/Tests/MoraEnginesTests/Debug \
           Packages/MoraUI/Sources/MoraUI/Debug
git commit -m "$(cat <<'EOF'
engines,ui: remove in-main-app fixture recorder source

Extracted into MoraFixtures + recorder/MoraFixtureRecorder/ per
fixture-recorder-app spec. HomeView hook goes next task.

Step C.11 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 12: Drop the `HomeView` wordmark hook

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift:66–75`

- [ ] **Step 1: Edit `HomeView.swift`**

Find the `wordmark` computed property (currently lines ~66–75):

```swift
    private var wordmark: some View {
        let base = Text("Mora")
            .font(MoraType.heading())
            .foregroundStyle(MoraTheme.Accent.orange)
        #if DEBUG
        return base.debugFixtureRecorderEntry()
        #else
        return base
        #endif
    }
```

Replace with:

```swift
    private var wordmark: some View {
        Text("Mora")
            .font(MoraType.heading())
            .foregroundStyle(MoraTheme.Accent.orange)
    }
```

- [ ] **Step 2: Run the MoraUI + MoraEngines test suites**

```bash
(cd Packages/MoraUI && swift test) && (cd Packages/MoraEngines && swift test)
```

Expected: both green.

- [ ] **Step 3: Regenerate Xcode project**

Inject the development team temporarily, generate, then revert (per `feedback_mora_xcodegen_team_injection`):

```bash
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
```

- [ ] **Step 4: Build Mora for iOS Simulator**

```bash
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the other two package suites for good measure**

```bash
(cd Packages/MoraCore && swift test) && (cd Packages/MoraTesting && swift test)
```

Expected: both green.

- [ ] **Step 6: swift-format**

```bash
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

Expected: silent.

- [ ] **Step 7: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "$(cat <<'EOF'
ui: drop #if DEBUG wordmark fixture-recorder entry

The in-main-app fixture recorder is replaced by the standalone
recorder/MoraFixtureRecorder/ app. HomeView's wordmark goes back to a
plain Text.

Step C.12 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 13: Extend the CI binary gate

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Locate the existing binary gate**

Open `.github/workflows/ci.yml` and find the step titled `Binary gate — no cloud symbols in built binary` (around line 117). The existing `nm | grep` rejects `speechace|azure|speechsuper` symbols.

- [ ] **Step 2: Extend the grep with recorder symbols**

Replace:

```yaml
          if nm "$APP/Mora" 2>/dev/null | grep -iE 'speechace|azure|speechsuper'; then
            echo "Cloud pronunciation symbol detected in Mora binary"
            exit 1
          fi
```

with:

```yaml
          if nm "$APP/Mora" 2>/dev/null | grep -iE 'speechace|azure|speechsuper'; then
            echo "Cloud pronunciation symbol detected in Mora binary"
            exit 1
          fi
          if nm "$APP/Mora" 2>/dev/null | grep -iE \
            'FixtureRecorder|FixtureWriter|FixtureMetadata|PronunciationRecorderView|DebugFixtureRecorderEntryModifier'; then
            echo "Recorder symbol detected in Mora binary; recorder code should live in recorder/MoraFixtureRecorder/ only"
            exit 1
          fi
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci: reject recorder symbols in built Mora binary

Guards against accidental re-add of FixtureRecorder / FixtureWriter /
FixtureMetadata / PronunciationRecorderView / DebugFixtureRecorderEntryModifier
in main Mora. Those types live in Packages/MoraFixtures/ and
recorder/MoraFixtureRecorder/ now.

Step C.13 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 14: Regenerate Xcode project and full verification sweep

**Files:** (none modified; verification only)

- [ ] **Step 1: Regenerate project with team injection**

```bash
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
```

- [ ] **Step 2: Build for iOS Simulator — Debug and Release**

```bash
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Release CODE_SIGNING_ALLOWED=NO
```

Expected: both `BUILD SUCCEEDED`.

- [ ] **Step 3: Run the new binary gate locally**

```bash
APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -name 'Mora.app' -path '*Debug-iphonesimulator*' 2>/dev/null | head -1)
nm "$APP/Mora" 2>/dev/null | \
  grep -iE 'FixtureRecorder|FixtureWriter|FixtureMetadata|PronunciationRecorderView|DebugFixtureRecorderEntryModifier' \
  && echo FAIL || echo OK
```

Expected: `OK`.

- [ ] **Step 4: Run every package suite**

```bash
(cd Packages/MoraCore && swift test) && \
(cd Packages/MoraEngines && swift test) && \
(cd Packages/MoraUI && swift test) && \
(cd Packages/MoraTesting && swift test) && \
(cd Packages/MoraMLX && swift test) && \
(cd Packages/MoraFixtures && swift test) && \
(cd dev-tools/pronunciation-bench && swift test)
```

Expected: every suite green.

- [ ] **Step 5: Commit-free checkpoint**

No changes to commit; this task is purely verification. Do NOT commit if `git status` is clean. If uncommitted changes appear (e.g. `Mora.xcodeproj/project.pbxproj` drift from the generate), ensure `Mora.xcodeproj` is listed in `.gitignore` (it already is — check `cat .gitignore | grep Mora.xcodeproj`) and no commit should be needed.

---

## Step D — `recorder/MoraFixtureRecorder/` app

### Task 15: `recorder/` directory skeleton + `project.yml`

**Files:**
- Create: `recorder/project.yml`
- Create: `recorder/README.md`
- Create: `recorder/.gitignore`
- Create: `recorder/MoraFixtureRecorder/Info.plist`
- Create: `recorder/MoraFixtureRecorder/Assets.xcassets/Contents.json`
- Create: `recorder/MoraFixtureRecorder/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `recorder/MoraFixtureRecorder/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `recorder/MoraFixtureRecorderTests/.gitkeep`

- [ ] **Step 1: Write `recorder/project.yml`**

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

- [ ] **Step 2: Write `recorder/README.md`**

```markdown
# Mora Fixture Recorder

iPad-only dev tool for capturing fixture audio that `dev-tools/pronunciation-bench/`
and `FeatureBasedEvaluatorFixtureTests` consume. Not shipped; not distributed
via App Store or TestFlight.

Drives the 12 patterns in `FixtureCatalog.v1Patterns` (r/l, v/b, æ/ʌ × 4). The
user picks a pattern, taps Record / Stop / Save, and exports via the iOS Share
Sheet — per take (two files) or per session (zip of all takes under the current
speaker).

## Build

```sh
cd recorder
# Inject team for physical-device signing, generate, revert (per repo convention)
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
open "Mora Fixture Recorder.xcodeproj"
```

Select `MoraFixtureRecorder` scheme, connect an iPad, and build & run.

## Usage

1. Launch the app on the iPad.
2. Pick the speaker toggle at the top of the list (adult / child).
3. Tap a pattern row (e.g. "right — /r/ matched").
4. Tap Record, say the word, tap Stop, tap Save. The take appears in the takes
   list with a share icon.
5. To export a single take: tap its share icon → AirDrop → Mac.
6. To export the whole session: back on the list screen, tap the toolbar Share
   button ("Share adult takes (N)"). A zip of `<Documents>/<speaker>/` is built
   on the fly; AirDrop it to your Mac.

## Output layout

```
<Documents>/
├── adult/<pattern outputSubdir>/<pattern filenameStem>-take<N>.wav/.json
└── child/<pattern outputSubdir>/<pattern filenameStem>-take<N>.wav/.json
```

See `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md`.
```

- [ ] **Step 3: Write `recorder/.gitignore`**

```gitignore
# Xcode generated
*.xcodeproj/
DerivedData/
```

- [ ] **Step 4: Write `recorder/MoraFixtureRecorder/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>UIFileSharingEnabled</key>
    <true/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Records fixture audio for Engine A calibration.</string>
    <key>UILaunchScreen</key>
    <dict/>
</dict>
</plist>
```

(XcodeGen's `info.properties` block also writes a plist. Providing this file explicitly means the writer uses it directly; either path works.)

- [ ] **Step 5: Write the three `Contents.json` shells**

`recorder/MoraFixtureRecorder/Assets.xcassets/Contents.json`:

```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

`recorder/MoraFixtureRecorder/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`recorder/MoraFixtureRecorder/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    { "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 6: Write the tests gitkeep**

```bash
mkdir -p recorder/MoraFixtureRecorderTests
touch recorder/MoraFixtureRecorderTests/.gitkeep
```

- [ ] **Step 7: Generate the Xcode project**

```bash
cd recorder
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
cd ..
```

Expected: `recorder/Mora Fixture Recorder.xcodeproj` exists. Build will fail until Task 16 adds at least one Swift source.

- [ ] **Step 8: Commit**

```bash
git add recorder/project.yml recorder/README.md recorder/.gitignore \
        recorder/MoraFixtureRecorder/Info.plist \
        recorder/MoraFixtureRecorder/Assets.xcassets \
        recorder/MoraFixtureRecorderTests/.gitkeep
git commit -m "$(cat <<'EOF'
recorder: scaffold MoraFixtureRecorder Xcode project

Step D.15 of fixture-recorder-app plan. Shell only — no Swift sources
yet; later tasks fill in the app code and test target.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 16: `MoraFixtureRecorderApp` + moved `FixtureRecorder`

**Files:**
- Create: `recorder/MoraFixtureRecorder/MoraFixtureRecorderApp.swift`
- Create: `recorder/MoraFixtureRecorder/FixtureRecorder.swift`

The moved `FixtureRecorder` is the same AVAudioEngine-based recorder deleted from `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift` in Task 11 (that file is gone from HEAD by now). Re-reconstruct its body from the git history — `git show HEAD~N:Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureRecorder.swift` — then strip the `#if DEBUG` wrapper and the `import Foundation` duplicate. The content below is the exact expected result so you can write it directly.

- [ ] **Step 1: Write `MoraFixtureRecorderApp.swift`**

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

(`RecorderStore`, `CatalogListView` are declared in later tasks. This file will not compile until Task 18 lands.)

- [ ] **Step 2: Write `FixtureRecorder.swift`**

```swift
import AVFoundation
import Foundation

public enum FixtureRecorderError: Error, Sendable {
    case converterInitFailed
    case audioEngineStartFailed(underlying: Error)
    case notRecording
}

/// Captures mono Float32 samples at 16 kHz from the default input device.
/// Not thread-safe — intended to be used from the main actor inside a
/// SwiftUI view.
@MainActor
public final class FixtureRecorder {

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var isRecording = false
    private var sessionGeneration: UInt64 = 0
    public private(set) var buffer: [Float] = []
    public let targetSampleRate: Double = 16_000

    public init() {}

    public var isRunning: Bool { isRecording }

    public func start() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            )
        else {
            throw FixtureRecorderError.converterInitFailed
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw FixtureRecorderError.converterInitFailed
        }
        self.converter = converter

        buffer.removeAll(keepingCapacity: true)
        sessionGeneration &+= 1
        let capturedGeneration = sessionGeneration

        inputNode.installTap(
            onBus: 0, bufferSize: 4_096, format: hardwareFormat
        ) { [weak self] inBuffer, _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.sessionGeneration == capturedGeneration else { return }
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
        sessionGeneration &+= 1
    }

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
        guard
            let outBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat, frameCapacity: outCapacity
            )
        else { return }

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
```

Note: no `#if DEBUG` wrapping. No `MoraEngines` import (the original file did not have one anyway — verify by searching git history if uncertain).

- [ ] **Step 3: Defer verification to Task 18** (build will not succeed until `RecorderStore`, `CatalogListView`, `PatternDetailView` land).

- [ ] **Step 4: Commit**

```bash
git add recorder/MoraFixtureRecorder/MoraFixtureRecorderApp.swift \
        recorder/MoraFixtureRecorder/FixtureRecorder.swift
git commit -m "$(cat <<'EOF'
recorder: add @main app shell and port FixtureRecorder

FixtureRecorder body is the same AVAudioEngine + AVAudioConverter
wrapper that used to live under Packages/MoraEngines/.../Debug/,
minus the #if DEBUG wrapping. App shell wires a NavigationStack to
CatalogListView (added in Task 18).

Step D.16 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 17: `RecorderStore` with tests

**Files:**
- Create: `recorder/MoraFixtureRecorder/RecorderStore.swift`
- Create: `recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift`
- Create: `recorder/MoraFixtureRecorderTests/FixtureDirectoryLayoutTests.swift`
- Delete: `recorder/MoraFixtureRecorderTests/.gitkeep`

- [ ] **Step 1: Write the failing tests**

`recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift`:

```swift
import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

@MainActor
final class RecorderStoreTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSpeakerTagPersistsAcrossInitializations() async throws {
        let a = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        a.speakerTag = .child
        let b = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        XCTAssertEqual(b.speakerTag, .child)
    }

    func testTakeCountIsZeroOnEmptyDirectory() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns[0]
        XCTAssertEqual(store.takeCount(for: pattern), 0)
    }

    func testTakeCountEnumeratesDiskFiles() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!

        // Seed two takes on disk for speaker = adult.
        let dir = tempDir
            .appendingPathComponent("adult")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        for n in [1, 2] {
            let wav = dir.appendingPathComponent("\(pattern.filenameStem)-take\(n).wav")
            let json = dir.appendingPathComponent("\(pattern.filenameStem)-take\(n).json")
            try Data().write(to: wav)
            try Data().write(to: json)
        }

        store.speakerTag = .adult
        XCTAssertEqual(store.takeCount(for: pattern), 2)
    }

    func testCrossSpeakerIsolation() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!

        // Put a file only under child/.
        let childDir = tempDir
            .appendingPathComponent("child")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: childDir, withIntermediateDirectories: true)
        try Data().write(
            to: childDir.appendingPathComponent("\(pattern.filenameStem)-take1.wav"))
        try Data().write(
            to: childDir.appendingPathComponent("\(pattern.filenameStem)-take1.json"))

        store.speakerTag = .adult
        XCTAssertEqual(store.takeCount(for: pattern), 0)
        store.speakerTag = .child
        XCTAssertEqual(store.takeCount(for: pattern), 1)
    }

    func testNextTakeNumberHandlesGaps() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "rl-right-correct" }!
        let dir = tempDir
            .appendingPathComponent("adult")
            .appendingPathComponent(pattern.outputSubdirectory)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        // Seed take1 and take4 only; take2 and take3 missing.
        for n in [1, 4] {
            try Data().write(
                to: dir.appendingPathComponent(
                    "\(pattern.filenameStem)-take\(n).wav"))
            try Data().write(
                to: dir.appendingPathComponent(
                    "\(pattern.filenameStem)-take\(n).json"))
        }
        store.speakerTag = .adult
        XCTAssertEqual(store.nextTakeNumber(for: pattern), 5)
    }
}
```

`recorder/MoraFixtureRecorderTests/FixtureDirectoryLayoutTests.swift`:

```swift
import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

@MainActor
final class FixtureDirectoryLayoutTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testPatternDirectoryComposesSpeakerAndSubdirectory() {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        let pattern = FixtureCatalog.v1Patterns.first { $0.id == "aeuh-cat-correct" }!
        store.speakerTag = .adult
        XCTAssertEqual(
            store.patternDirectory(for: pattern),
            tempDir.appendingPathComponent("adult/aeuh"))
    }

    func testSpeakerDirectoryIsUnderDocuments() {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        store.speakerTag = .child
        XCTAssertEqual(
            store.speakerDirectory(),
            tempDir.appendingPathComponent("child"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail** (optional — tests cannot build until `RecorderStore` exists):

Run: `cd recorder && xcodebuild test -project "Mora Fixture Recorder.xcodeproj" -scheme MoraFixtureRecorder -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3)' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20`

Expected: compile errors about `RecorderStore` undefined.

(If the iPad Air 11-inch (M3) simulator is unavailable in the local Xcode install, substitute any available iPad simulator name from `xcrun simctl list devices | grep iPad`.)

- [ ] **Step 3: Write `RecorderStore.swift`**

```swift
import Combine
import Foundation
import MoraFixtures
import Observation

public enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case captured(samples: [Float], durationSeconds: Double)
    case saving
    case saveFailed(String)

    public static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.saving, .saving): return true
        case let (.captured(a, b), .captured(c, d)): return a == c && b == d
        case let (.saveFailed(a), .saveFailed(b)): return a == b
        default: return false
        }
    }
}

public enum FixtureExportError: Error, Sendable {
    case emptyDirectory
    case coordinatorFailed(String)
}

private let speakerTagUserDefaultsKey = "MoraFixtureRecorder.speakerTag"

@Observable @MainActor
public final class RecorderStore {

    public var speakerTag: SpeakerTag {
        didSet { userDefaults.set(speakerTag.rawValue, forKey: speakerTagUserDefaultsKey) }
    }

    public var recordingState: RecordingState = .idle
    public var errorMessage: String? {
        if case let .saveFailed(message) = recordingState { return message }
        return nil
    }

    public var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }

    public var hasCapturedSamples: Bool {
        if case .captured = recordingState { return true }
        return false
    }

    public var totalTakesInCurrentSpeaker: Int {
        FixtureCatalog.v1Patterns.reduce(0) { $0 + takeCount(for: $1) }
    }

    private let documentsDirectory: URL
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let recorder: FixtureRecorder

    public init(
        documentsDirectory: URL = RecorderStore.defaultDocumentsDirectory(),
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        recorder: FixtureRecorder = FixtureRecorder()
    ) {
        self.documentsDirectory = documentsDirectory
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.recorder = recorder
        if let raw = userDefaults.string(forKey: speakerTagUserDefaultsKey),
           let tag = SpeakerTag(rawValue: raw) {
            self.speakerTag = tag
        } else {
            self.speakerTag = .adult
        }
    }

    private static func defaultDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public func speakerDirectory() -> URL {
        documentsDirectory.appendingPathComponent(speakerTag.rawValue)
    }

    public func patternDirectory(for pattern: FixturePattern) -> URL {
        speakerDirectory().appendingPathComponent(pattern.outputSubdirectory)
    }

    public func takesOnDisk(for pattern: FixturePattern) -> [URL] {
        let dir = patternDirectory(for: pattern)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return [] }
        let stemPrefix = "\(pattern.filenameStem)-take"
        return entries
            .filter { $0.pathExtension == "wav" }
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(stemPrefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func takeCount(for pattern: FixturePattern) -> Int {
        takesOnDisk(for: pattern).count
    }

    public func nextTakeNumber(for pattern: FixturePattern) -> Int {
        let stemPrefix = "\(pattern.filenameStem)-take"
        let numbers = takesOnDisk(for: pattern)
            .map { $0.deletingPathExtension().lastPathComponent.dropFirst(stemPrefix.count) }
            .compactMap { Int($0) }
        return (numbers.max() ?? 0) + 1
    }

    public func takeArtifacts(for wavURL: URL) -> [URL] {
        [wavURL, wavURL.deletingPathExtension().appendingPathExtension("json")]
    }

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
            recordingState = .captured(samples: samples, durationSeconds: duration)
        case .saving:
            break
        }
    }

    public func save(pattern: FixturePattern) {
        guard case let .captured(samples, duration) = recordingState else { return }
        recordingState = .saving
        do {
            let n = nextTakeNumber(for: pattern)
            let dir = patternDirectory(for: pattern)
            let meta = pattern.metadata(
                capturedAt: Date(),
                sampleRate: recorder.targetSampleRate,
                durationSeconds: duration,
                speakerTag: speakerTag
            )
            _ = try FixtureWriter.writeTake(
                samples: samples, metadata: meta,
                pattern: pattern, takeNumber: n, into: dir
            )
            recordingState = .idle
        } catch {
            recordingState = .saveFailed(String(describing: error))
        }
    }

    public func deleteTake(url: URL) {
        try? fileManager.removeItem(at: url)
        let sidecar = url.deletingPathExtension().appendingPathExtension("json")
        try? fileManager.removeItem(at: sidecar)
    }

    public func prepareSpeakerArchive() throws -> URL {
        let dir = speakerDirectory()
        guard fileManager.fileExists(atPath: dir.path),
              let entries = try? fileManager.contentsOfDirectory(
                  at: dir, includingPropertiesForKeys: nil),
              !entries.isEmpty
        else {
            throw FixtureExportError.emptyDirectory
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var resultURL: URL?

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        coordinator.coordinate(
            readingItemAt: dir,
            options: .forUploading,
            error: &coordinationError
        ) { tempURL in
            let dest = fileManager.temporaryDirectory
                .appendingPathComponent("\(speakerTag.rawValue)-\(timestamp).zip")
            try? fileManager.removeItem(at: dest)
            try? fileManager.copyItem(at: tempURL, to: dest)
            resultURL = dest
        }

        if let coordinationError {
            throw FixtureExportError.coordinatorFailed(coordinationError.localizedDescription)
        }
        guard let url = resultURL else {
            throw FixtureExportError.coordinatorFailed("coordinator produced no zip")
        }
        return url
    }
}
```

- [ ] **Step 4: Run the tests (via xcodebuild test)**

```bash
cd recorder
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml

DEVICE=$(xcrun simctl list devices available 'iPad' | grep -v 'unavailable' | grep 'iPad' | head -1 | grep -oE '[A-Za-z0-9 -]+\([0-9A-F-]+\)' | head -1 | sed 's/ *([0-9A-F-]*)//')
xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
cd ..
```

Expected: `TEST SUCCEEDED` with `RecorderStoreTests` (5 tests) + `FixtureDirectoryLayoutTests` (2 tests) green. App-level compile will still fail until `CatalogListView` + `PatternDetailView` land.

If the xcodebuild test above fails because of missing `CatalogListView` / `PatternDetailView` (app target compile errors), it's fine — the test target depends on the app target, so the test target won't build either. Park the test verification until Task 19 and move on.

- [ ] **Step 5: Remove the tests gitkeep** (already deleted if Task 15 did it, otherwise):

```bash
rm -f recorder/MoraFixtureRecorderTests/.gitkeep
```

- [ ] **Step 6: Commit**

```bash
git add recorder/MoraFixtureRecorder/RecorderStore.swift \
        recorder/MoraFixtureRecorderTests/RecorderStoreTests.swift \
        recorder/MoraFixtureRecorderTests/FixtureDirectoryLayoutTests.swift \
        recorder/MoraFixtureRecorderTests/.gitkeep
git commit -m "$(cat <<'EOF'
recorder: add RecorderStore with take enumeration + speaker archive

Observable store owning speaker state (UserDefaults-persisted),
recording state machine, take-count + next-take-number logic over
the documents directory, and NSFileCoordinator-based speaker archive
for bulk share.

Step D.17 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 18: `CatalogListView`

**Files:**
- Create: `recorder/MoraFixtureRecorder/CatalogListView.swift`
- Create: `recorder/MoraFixtureRecorder/BulkShareButton.swift`

- [ ] **Step 1: Write `BulkShareButton.swift`**

```swift
import MoraFixtures
import SwiftUI

struct BulkShareButton: View {

    @Bindable var store: RecorderStore

    @State private var archiveURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let url = archiveURL {
                ShareLink(item: url) {
                    Label(
                        "Share \(store.speakerTag.rawValue) takes (\(store.totalTakesInCurrentSpeaker))",
                        systemImage: "square.and.arrow.up")
                }
                .disabled(store.totalTakesInCurrentSpeaker == 0)
            } else {
                Button {
                    prepare()
                } label: {
                    Label(
                        "Share \(store.speakerTag.rawValue) takes (\(store.totalTakesInCurrentSpeaker))",
                        systemImage: "square.and.arrow.up")
                }
                .disabled(store.totalTakesInCurrentSpeaker == 0)
            }
        }
        .alert("Archive failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: store.speakerTag) { _, _ in
            // Speaker changed — any cached zip now points at the wrong
            // archive. Force-rebuild on next tap.
            archiveURL = nil
        }
    }

    private func prepare() {
        do {
            archiveURL = try store.prepareSpeakerArchive()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
```

- [ ] **Step 2: Write `CatalogListView.swift`**

```swift
import MoraFixtures
import SwiftUI

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

- [ ] **Step 3: Defer build verification to Task 19** (`PatternDetailView` does not exist yet).

- [ ] **Step 4: Commit**

```bash
git add recorder/MoraFixtureRecorder/CatalogListView.swift \
        recorder/MoraFixtureRecorder/BulkShareButton.swift
git commit -m "$(cat <<'EOF'
recorder: add CatalogListView and BulkShareButton

List screen with speaker toggle, 12-pattern rows showing per-pattern
take counts, and a toolbar Share button that builds a zip of the
current speaker's Documents subtree via NSFileCoordinator.

Step D.18 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 19: `PatternDetailView` + `TakeRow`

**Files:**
- Create: `recorder/MoraFixtureRecorder/PatternDetailView.swift`
- Create: `recorder/MoraFixtureRecorder/TakeRow.swift`

- [ ] **Step 1: Write `TakeRow.swift`**

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
    }

    private var label: String {
        let basename = wavURL.deletingPathExtension().lastPathComponent
        let takeSuffix = basename
            .split(separator: "-take")
            .last.map(String.init) ?? "?"
        return "take \(takeSuffix)"
    }
}
```

- [ ] **Step 2: Write `PatternDetailView.swift`**

```swift
import MoraFixtures
import SwiftUI

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
                LabeledContent(
                    "Sequence",
                    value: pattern.phonemeSequenceIPA.joined(separator: " "))
                LabeledContent(
                    "Target index", value: "\(pattern.targetPhonemeIndex)")
            }

            Section("Capture") {
                Button(store.isRecording ? "Stop" : "Record") {
                    store.toggleRecording()
                }
                Button("Save") {
                    store.save(pattern: pattern)
                }
                .disabled(!store.hasCapturedSamples)
                if case let .captured(_, duration) = store.recordingState {
                    Text(String(format: "Captured: %.2fs", duration))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Takes") {
                ForEach(store.takesOnDisk(for: pattern), id: \.self) { url in
                    TakeRow(wavURL: url, store: store, pattern: pattern)
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

- [ ] **Step 3: Verify simulator build + tests**

```bash
cd recorder
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml

DEVICE=$(xcrun simctl list devices available 'iPad' | grep -v 'unavailable' | grep 'iPad' | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/' | head -1)
xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
cd ..
```

Expected: `TEST SUCCEEDED`, all tests from `RecorderStoreTests` and `FixtureDirectoryLayoutTests` green.

- [ ] **Step 4: swift-format lint on the new recorder target sources**

Note: the repo's CI lint scope is `Mora Packages/*/Sources Packages/*/Tests`. Recorder is outside this scope (same as `bench/`). Running format locally is best-effort:

```bash
swift-format lint --strict --recursive \
  recorder/MoraFixtureRecorder \
  recorder/MoraFixtureRecorderTests || true
```

Fix any `--strict` complaints in this and previous tasks' files before committing.

- [ ] **Step 5: Commit**

```bash
git add recorder/MoraFixtureRecorder/PatternDetailView.swift \
        recorder/MoraFixtureRecorder/TakeRow.swift
git commit -m "$(cat <<'EOF'
recorder: add PatternDetailView and TakeRow

Detail screen for one pattern: Record/Stop toggle, Save, takes list
with per-take ShareLink and delete. Pattern metadata is read-only so
the user cannot misconfigure it.

Step D.19 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 20: `SpeakerArchiveTests`

**Files:**
- Create: `recorder/MoraFixtureRecorderTests/SpeakerArchiveTests.swift`

- [ ] **Step 1: Write the test**

```swift
import MoraFixtures
import XCTest
@testable import MoraFixtureRecorder

@MainActor
final class SpeakerArchiveTests: XCTestCase {

    private var tempDir: URL!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: UUID().uuidString)!
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testThrowsForEmptySpeakerDirectory() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        store.speakerTag = .adult
        XCTAssertThrowsError(try store.prepareSpeakerArchive()) { error in
            guard case FixtureExportError.emptyDirectory = error else {
                XCTFail("expected .emptyDirectory, got \(error)")
                return
            }
        }
    }

    func testProducesZipUnderTempDirForNonEmptySpeaker() async throws {
        let store = RecorderStore(
            documentsDirectory: tempDir, userDefaults: defaults)
        store.speakerTag = .adult

        // Seed one take so the speaker directory is non-empty.
        let pattern = FixtureCatalog.v1Patterns[0]
        let dir = store.patternDirectory(for: pattern)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        try Data(repeating: 0, count: 16)
            .write(to: dir.appendingPathComponent(
                "\(pattern.filenameStem)-take1.wav"))

        let zipURL = try store.prepareSpeakerArchive()
        XCTAssertTrue(zipURL.path.hasPrefix(FileManager.default.temporaryDirectory.path))
        XCTAssertEqual(zipURL.pathExtension, "zip")
        XCTAssertTrue(zipURL.lastPathComponent.contains("adult"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))
    }
}
```

- [ ] **Step 2: Run tests**

```bash
cd recorder
DEVICE=$(xcrun simctl list devices available 'iPad' | grep -v 'unavailable' | grep 'iPad' | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/' | head -1)
xcodebuild test \
  -project "Mora Fixture Recorder.xcodeproj" \
  -scheme MoraFixtureRecorder \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -configuration Debug CODE_SIGNING_ALLOWED=NO \
  -only-testing:MoraFixtureRecorderTests/SpeakerArchiveTests
cd ..
```

Expected: PASS (2/2).

- [ ] **Step 3: Commit**

```bash
git add recorder/MoraFixtureRecorderTests/SpeakerArchiveTests.swift
git commit -m "$(cat <<'EOF'
recorder: add SpeakerArchiveTests

Covers the empty-speaker throw and the non-empty zip output under
NSTemporaryDirectory with the speakerTag + timestamp-based filename.

Step D.20 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 21: iPad physical-device smoke

**Files:** none modified; manual verification only.

This task requires a physical iPad. If no iPad is available at the time of this PR, note it in the PR description and skip to Task 22. The simulator passes exercise the core logic; iPad smoke validates microphone plumbing + Share Sheet end-to-end.

- [ ] **Step 1: Install on iPad**

Open `recorder/Mora Fixture Recorder.xcodeproj` in Xcode (the project was generated by Task 15 / Task 19). Select `MoraFixtureRecorder` scheme + connected iPad device. Run with Cmd-R. Grant microphone permission when prompted.

- [ ] **Step 2: Record two patterns (adult)**

- Confirm the Adult toggle is selected at the top.
- Tap "right — /r/ matched" → tap Record → say "right" → tap Stop → tap Save. Back out to the list; the row should now show "1 takes".
- Tap "cat — /æ/ matched" → Record → say "cat" → Stop → Save → back. Row shows "1 takes".

- [ ] **Step 3: Per-take share**

Open "right — /r/ matched" again. The takes list shows one row. Tap its square.and.arrow.up icon → iOS Share Sheet appears → AirDrop to your Mac. Confirm `right-correct-take1.wav` and `right-correct-take1.json` land in `~/Downloads/` on the Mac.

- [ ] **Step 4: Bulk share**

Back on the list screen, tap the toolbar "Share adult takes (2)" button. The zip builds on the fly, then Share Sheet appears with a single `adult-<timestamp>.zip`. AirDrop it to the Mac. On the Mac:

```bash
cd ~/Downloads && unzip -l adult-*.zip
```

Expected: entries for `adult/rl/right-correct-take1.wav`, `adult/rl/right-correct-take1.json`, `adult/aeuh/cat-correct-take1.wav`, `adult/aeuh/cat-correct-take1.json`.

- [ ] **Step 5: Speaker toggle smoke**

Flip the toggle to Child → list rows update to "0 takes" everywhere; the adult recordings you just made are invisible but still on disk (verify by flipping back to Adult). The bulk-share button shows "Share child takes (0)" and is disabled.

- [ ] **Step 6: Delete take**

Return to "right — /r/ matched" (Adult). Tap the trash icon on the take 1 row. Row disappears. Record row on the list shows "0 takes".

- [ ] **Step 7: No commit**

This is a manual verification; nothing changes in the repo. If any step fails, file the finding in the PR description and fix the relevant task before merging.

### Task 22: Recorder `README.md` cross-link

**Files:**
- Modify: `recorder/README.md`

This task ensures the README written in Task 15 is still accurate after the rest of Step D landed. Re-read it; if anything in the "Build" or "Usage" sections mis-describes the final UI (for example, calls a view by the wrong name), fix inline. Most likely this is a no-op.

- [ ] **Step 1: Re-read**

```bash
cat recorder/README.md
```

- [ ] **Step 2: Amend if needed + commit**

If no changes needed, skip the commit. If changes needed:

```bash
git add recorder/README.md
git commit -m "$(cat <<'EOF'
recorder: reconcile README after full UI landing

Step D.22 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Step E — Update dependent specs and plans

### Task 23: Superseding note on bench-and-calibration design spec

**Files:**
- Modify: `docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md` (top of file, below the frontmatter)

- [ ] **Step 1: Insert the superseding block**

Immediately after the existing horizontal rule (`---`) that follows the frontmatter block, insert:

```markdown
> **Superseded (recorder portion):** See `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md`. The following sections of this spec are overridden: §4.1 (DEBUG-only in-app recorder), §4.4 (Part 2 stays out of Phase 3's file set — no longer relevant for recorder-side), §6.1–§6.4 (FixtureMetadata, FixtureRecorder, FixtureWriter, PronunciationRecorderView + DebugEntryPoint now live outside main Mora), §7.1 (fixture capture flow), §9.1 (release-build invariants for recorder — restated with relaxed privacy stance in the new spec). Bench-side sections (§4.2, §5, §6.5, §6.6, §7.2–§7.3, §8–§12) stay in force; only the consumer type imports swap from `MoraEngines` to `MoraFixtures`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md
git commit -m "$(cat <<'EOF'
docs: supersede bench-and-calibration recorder sections

Point readers at fixture-recorder-app-design.md for the updated
recorder, catalog-driven UI, and Share Sheet export path. Bench-side
sections keep their authority.

Step E.23 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 24: Superseding note on bench-and-calibration plan

**Files:**
- Modify: `docs/superpowers/plans/2026-04-22-pronunciation-bench-and-calibration.md` (top of file)

- [ ] **Step 1: Insert the block**

Immediately below the first header and any "Status / PR" bookkeeping in the document, insert:

```markdown
> **Superseded (recorder portion):** See `docs/superpowers/plans/2026-04-23-fixture-recorder-app.md`. Tasks 1–5 of this plan (FixtureMetadata, FixtureWriter, FixtureRecorder, PronunciationRecorderView, DebugEntryPoint) already merged; they are undone by the fixture-recorder-app plan's Step A (types move to `Packages/MoraFixtures/`), Step C (main-app deletions), and Step D (new `recorder/MoraFixtureRecorder/` app). Tasks 7–14 (dev-tools/pronunciation-bench) are preserved, with the MoraFixtures import swap added by the new plan's Step B.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-04-22-pronunciation-bench-and-calibration.md
git commit -m "$(cat <<'EOF'
docs: supersede bench-and-calibration plan recorder tasks

Tasks 1–5 are undone by fixture-recorder-app plan's Steps A / C / D.
Task rows themselves already marked merged so no task edits needed.

Step E.24 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 25: Rewrite Task A1 in the followup plan

**Files:**
- Modify: `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` — Task A1 block (the `### Task A1: Record adult-proxy fixtures and check in` section)

- [ ] **Step 1: Replace Task A1 Steps 1–6**

Locate the `### Task A1:` header and replace everything from its Step 1 heading (`- [ ] **Step 1:** Rebuild and install the Mora DEBUG build...`) through the end of Step 6's code fence (ending with `ls -l Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/{rl,vb,aeuh}/*.wav`) with:

```markdown
- [ ] **Step 1:** Rebuild and install the recorder app on iPad.

```bash
: "${REPO_ROOT:?Set REPO_ROOT to the Mora repo root before running this task.}"
cd "$REPO_ROOT/recorder"
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 2AFT9XT8R2', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
cd "$REPO_ROOT"
```

In Xcode, open `recorder/Mora Fixture Recorder.xcodeproj`, select the `MoraFixtureRecorder` scheme and the connected iPad, and run (Cmd-R). Grant microphone permission on the iPad.

- [ ] **Step 2:** On the iPad, confirm the speaker toggle is set to **Adult** at the top of the list. Work through the 12 rows below in order. For each row, tap the pattern, tap Record, say the listed word (deliberately pronouncing `-as-X` rows with the substitute phoneme), tap Stop, tap Save. The take count on the list row should increment from 0 to 1.

| # | Pattern row displayed in the list | Output filename the recorder writes |
|---|---|---|
| 1 | right — /r/ matched | `adult/rl/right-correct-take1.wav` + `.json` |
| 2 | right — /r/ substitutedBy by /l/ | `adult/rl/right-as-light-take1.wav` + `.json` |
| 3 | light — /l/ matched | `adult/rl/light-correct-take1.wav` + `.json` |
| 4 | light — /l/ substitutedBy by /r/ | `adult/rl/light-as-right-take1.wav` + `.json` |
| 5 | very — /v/ matched | `adult/vb/very-correct-take1.wav` + `.json` |
| 6 | very — /v/ substitutedBy by /b/ | `adult/vb/very-as-berry-take1.wav` + `.json` |
| 7 | berry — /b/ matched | `adult/vb/berry-correct-take1.wav` + `.json` |
| 8 | berry — /b/ substitutedBy by /v/ | `adult/vb/berry-as-very-take1.wav` + `.json` |
| 9 | cat — /æ/ matched | `adult/aeuh/cat-correct-take1.wav` + `.json` |
| 10 | cat — /æ/ substitutedBy by /ʌ/ | `adult/aeuh/cat-as-cut-take1.wav` + `.json` |
| 11 | cut — /ʌ/ matched | `adult/aeuh/cut-correct-take1.wav` + `.json` |
| 12 | cut — /ʌ/ substitutedBy by /æ/ | `adult/aeuh/cut-as-cat-take1.wav` + `.json` |

If a take came out noisy or mispronounced, delete it from the takes list (trash icon) and re-record; do not tap Save until you are satisfied.

- [ ] **Step 3:** Back on the list screen, tap the toolbar **Share adult takes (12)** button. The zip builds, then the iOS Share Sheet appears. Pick AirDrop → your Mac. The Mac receives `~/Downloads/adult-<timestamp>.zip`.

```bash
cd ~/Downloads
unzip -q adult-*.zip -d ~/mora-fixtures-adult/
ls ~/mora-fixtures-adult/
# Expect: rl/ vb/ aeuh/
```

- [ ] **Step 4:** Sanity-run the bench with `--no-speechace` so Engine A's output can be eyeballed:

```bash
cd "$REPO_ROOT/dev-tools/pronunciation-bench"
swift run bench ~/mora-fixtures-adult/ ~/mora-fixtures-adult/out.csv --no-speechace
```

Scan the CSV. For each `-correct` row the `engine_a_label` column should read `matched`; for each `-as-X` row it should read `substitutedBy(<X>)`. Any mismatch means the fixture is bad — re-record that take through the recorder app, AirDrop the one take, replace the file in `~/mora-fixtures-adult/`, and re-run.

- [ ] **Step 5:** Trim each WAV to ≤ 2 s and **rename the `-take1` suffix off** — the engine-side fixture tests expect `right-correct.wav` etc., not `right-correct-take1.wav`:

```bash
# brew install sox  # once
for subdir in rl vb aeuh; do
    for wav in ~/mora-fixtures-adult/$subdir/*.wav; do
        stem=$(basename "$wav" -take1.wav)
        sox "$wav" -r 16000 -b 16 -c 1 \
            ~/mora-fixtures-adult-trimmed/"$subdir"/"$stem".wav \
            trim 0 2.0
    done
done
```

(Sidecar JSONs stay alongside the trimmed wavs — copy them with the same rename.)

- [ ] **Step 6:** Copy into the repo test fixtures directory and verify filesize ceiling:

```bash
cp -a ~/mora-fixtures-adult-trimmed/{rl,vb,aeuh} \
      "$REPO_ROOT/Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/"
rm -f "$REPO_ROOT/Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures"/{rl,vb,aeuh}/.gitkeep
ls -l "$REPO_ROOT/Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures"/{rl,vb,aeuh}/*.wav
```

Every file should be < 100 KB.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md
git commit -m "$(cat <<'EOF'
docs: rewrite followup Task A1 for recorder app + Share Sheet

Drop the 5-tap DEBUG entry-point instructions and the AirDrop-from-
Files.app flow. Adult adult fixtures now land via the recorder app
and bulk Share Sheet → Mac → unzip → trim → rename -take1 off →
commit.

Step E.25 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 26: Rewrite Task A2 in the followup plan

**Files:**
- Modify: `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` — Task A2 block

- [ ] **Step 1: Replace Task A2**

Locate `### Task A2:` and replace its body with:

```markdown
Same recorder app, but with the speaker toggle flipped to **Child**. Three or more takes per (pattern, speakerTag = child) row. Quiet room; no siblings audible.

- [ ] **Step 1:** Install the recorder (same `xcodegen generate` + Xcode run flow as Task A1 Step 1) if not already installed.
- [ ] **Step 2:** Flip the speaker toggle to **Child**.
- [ ] **Step 3:** Work through the 12 patterns in order. For each, record 3 takes (Record → Stop → Save, three times). The takes list shows take 1, take 2, take 3 after each Save. Adjust microphone distance / re-record any take that came out noisy via its trash icon and a fresh Save.

  Target: 36+ clips (3 × 12 rows).

- [ ] **Step 4:** Single-take share for immediate checks: back on a pattern's detail screen, tap a take row's share icon → Share Sheet → AirDrop → Mac. Useful mid-session to confirm one take before moving on.

- [ ] **Step 5:** End-of-session bulk share: on the list screen, tap toolbar **Share child takes (36)**. AirDrop the `child-<timestamp>.zip` to the Mac. Unzip into `~/mora-fixtures-child/`:

```bash
cd ~/Downloads && unzip -q child-*.zip -d ~/mora-fixtures-child/
ls ~/mora-fixtures-child/
# Expect: rl/ vb/ aeuh/  (each with 12 wav + 12 json files = 3 takes × 4 patterns)
```

- [ ] **Step 6:** No commit. The child fixtures stay on Yutaka's laptop per spec §9.3.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md
git commit -m "$(cat <<'EOF'
docs: rewrite followup Task A2 for recorder app child batch

Child speaker batch uses the recorder app's speaker toggle and
multi-take workflow. Per-take share handles mid-session verification;
bulk share ends the session.

Step E.26 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task 27: Reduce Task B1 in the followup plan

**Files:**
- Modify: `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` — Task B1 block

- [ ] **Step 1: Replace Task B1**

Locate `### Task B1:` and replace its body with:

```markdown
The schema extension (`phonemeSequenceIPA` + `targetPhonemeIndex` on `FixtureMetadata`) and the `EngineARunner` call-site update are **absorbed into `docs/superpowers/plans/2026-04-23-fixture-recorder-app.md` (Steps A and B respectively)**. What remains here is only the in-engine test helper extension so the medial-vowel (`æ/ʌ`) fixture tests localize correctly when fixtures land.

**Why:** `FeatureBasedEvaluatorFixtureTests.evaluate(...)` currently builds the `Word` with `phonemes: [target]`, which `PhonemeRegionLocalizer` interprets as onset. For the 4 `aeuh/` fixtures (`cat-correct`, `cat-as-cut`, `cut-correct`, `cut-as-cat`) the target vowel is medial and this interpretation is wrong. The test helper needs to accept optional `phonemes` + `targetIndex` and pass them through.

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift`

**Recommended landing**: This change lands **in the same commit as Task A1 Step 6's fixture check-in**. Landing it sooner breaks nothing (the helper default still runs as `[target]`), but the medial-vowel tests only exercise it after fixtures are present, so coupling the two minimizes noise.

- [ ] **Step 1:** Extend the helper signature in `FeatureBasedEvaluatorFixtureTests.swift`:

```swift
private func evaluate(
    _ relative: String,
    target ipa: String,
    word surface: String,
    phonemes: [String]? = nil,
    targetIndex: Int? = nil
) async throws -> PhonemeTrialAssessment {
    // ... load WAV unchanged ...
    let targetPhoneme = Phoneme(ipa: ipa)
    let phonemeList = phonemes.map { $0.map { Phoneme(ipa: $0) } } ?? [targetPhoneme]
    let idx = targetIndex ?? 0
    let word = Word(
        surface: surface,
        graphemes: [Grapheme(letters: surface)],
        phonemes: phonemeList,
        targetPhoneme: phonemeList[idx]
    )
    return await evaluator.evaluate(
        audio: audio, expected: word,
        targetPhoneme: phonemeList[idx],
        asr: ASRResult(transcript: surface, confidence: 0.9)
    )
}
```

- [ ] **Step 2:** Update the four `aeuh/` call sites:

```swift
func testCatCorrectMatchesAe() async throws {
    let a = try await evaluate(
        "aeuh/cat-correct.wav",
        target: "æ", word: "cat",
        phonemes: ["k", "æ", "t"], targetIndex: 1
    )
    // assertions unchanged
}

// repeat the pattern for cat-as-cut (phonemes/index same, target/assertions match),
// cut-correct (phonemes: ["k", "ʌ", "t"], targetIndex: 1),
// cut-as-cat (same sequence, substitute æ).
```

Leave the r/l and v/b call sites on the default `[target]` path — they are onset-positioned and the existing tests are correct.

- [ ] **Step 3:** Verify:

```bash
(cd Packages/MoraEngines && swift test)
```

Expected: once fixtures have landed (Task A1 Step 7 here), all 109 tests pass with zero skips. Before fixtures land, this change is an inert refactor — tests remain skipped but the helper signature compiles.

- [ ] **Step 4:** Landing: keep the helper change and the fixture check-in on a single commit. Example message: `engines: add phoneme-sequence fixture fixtures + tests for r/l, v/b, ae/uh`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md
git commit -m "$(cat <<'EOF'
docs: reduce followup Task B1 to test helper extension

Schema extension and EngineARunner update are now part of the
fixture-recorder-app plan (Step A and Step B). The residual
FeatureBasedEvaluatorFixtureTests.evaluate(...) helper extension
stays here and lands with Task A1's fixture check-in.

Step E.27 of fixture-recorder-app plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Completion Checklist

Before opening the PR, verify every gate below is green:

- [ ] `(cd Packages/MoraCore && swift test)` — green.
- [ ] `(cd Packages/MoraEngines && swift test)` — green.
- [ ] `(cd Packages/MoraUI && swift test)` — green.
- [ ] `(cd Packages/MoraTesting && swift test)` — green.
- [ ] `(cd Packages/MoraMLX && swift test)` — green (unchanged by this PR).
- [ ] `(cd Packages/MoraFixtures && swift test)` — green.
- [ ] `(cd dev-tools/pronunciation-bench && swift test)` — green.
- [ ] `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` — BUILD SUCCEEDED.
- [ ] `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Release CODE_SIGNING_ALLOWED=NO` — BUILD SUCCEEDED.
- [ ] `xcodebuild test -project recorder/"Mora Fixture Recorder.xcodeproj" -scheme MoraFixtureRecorder -destination 'platform=iOS Simulator,name=<any iPad>' -configuration Debug CODE_SIGNING_ALLOWED=NO` — TEST SUCCEEDED.
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` — silent.
- [ ] `nm <DerivedData>/Mora.app/Mora | grep -iE 'FixtureRecorder|FixtureWriter|FixtureMetadata|PronunciationRecorderView|DebugFixtureRecorderEntryModifier'` — empty.
- [ ] `git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages` — empty (unchanged from prior).
- [ ] iPad physical smoke per Task 21 — passed or flagged.
- [ ] `git status` clean on the worktree branch.

PR title: `fixtures: extract fixture recorder to standalone app + shared package`

PR body bullets:
- Summary of what's moved and what's new.
- Link to the spec `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md`.
- Link to this plan.
- Note that Task B1 of the followup plan is reduced to the test helper (landed separately with fixtures).
- Note the iPad smoke test status (passed / deferred).
