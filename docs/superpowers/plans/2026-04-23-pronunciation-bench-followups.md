# Pronunciation Bench & Calibration — Follow-up Work

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to pick tasks from this document task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status on 2026-04-23:** Phase A + Phase B + Phase C-code of `2026-04-22-pronunciation-bench-and-calibration.md` shipped via [#41](https://github.com/youtalk/mora/pull/41) and [#42](https://github.com/youtalk/mora/pull/42). Engine B Part 1 + Part 2 landed via [#43](https://github.com/youtalk/mora/pull/43) / [#45](https://github.com/youtalk/mora/pull/45). This document captures the work that was explicitly deferred from those PRs plus a handful of code-quality items raised in Copilot review.

**Goal:** Close the calibration loop so the `FeatureBasedEvaluatorFixtureTests` suite stops skipping, then tune `PhonemeThresholds` for child-speaker audio.

---

## What's already merged

From `2026-04-22-pronunciation-bench-and-calibration.md`:

| Plan task | PR | Notes |
|---|---|---|
| 1. `FixtureMetadata` | #41 | `#if DEBUG`-wrapped value type + ExpectedLabel / SpeakerTag |
| 2. `FixtureWriter` | #41 | Pure-Swift 16-bit PCM WAV + sidecar JSON |
| 3. `FixtureRecorder` | #41 | `AVAudioEngine` tap → 16 kHz mono Float32 |
| 4. `PronunciationRecorderView` | #41 | DEBUG-only SwiftUI form |
| 5. `DebugEntryPoint` modifier | #41 | 5-tap-in-3-seconds gesture on HomeView wordmark |
| 6. Scaffold `dev-tools/pronunciation-bench/` | #41 | SPM package with `path:` deps |
| 7. `FixtureLoader` | #41 | WAV+JSON pair enumeration + AVFoundation decode |
| 8. `EngineARunner` | #41 | Thin adapter over `FeatureBasedPronunciationEvaluator` |
| 9. `SpeechAceClient` | #41 | URLSession multipart POST |
| 10. `CSVWriter` | #41 | RFC 4180 escaping, 13-column header |
| 11. Wire `BenchCLI` end to end | #41 | Loader → runner → SpeechAce → CSV |
| 12. Declare `Fixtures` as test resource | #42 | `resources: [.copy("Fixtures")]` + placeholders |
| 14. `FeatureBasedEvaluatorFixtureTests` + delete 3 TODO bullets | #42 | 12 tests, `XCTSkip` when fixtures absent |

Not yet done (from the original plan):

| Plan task | Why not landed |
|---|---|
| 13. Record adult-proxy WAV fixtures | Manual hardware step (requires physical iPad + human speaker) |
| 15. Record son's fixtures | Manual hardware step (same) |
| 16. Run bench against son's fixtures | Depends on 15 |
| 17. Update `PhonemeThresholds` | Depends on 16 |

This follow-up plan schedules the manual steps above and captures three code items raised during PR review.

---

## Scope

### In scope

- **Task A1 — Record 12 adult-proxy WAV fixtures on iPad and check them in.** Unblocks the 12 `XCTSkip` tests in `FeatureBasedEvaluatorFixtureTests`. Equivalent to the original plan's Task 13.
- **Task A2 — Record son's child-speaker fixtures (not committed).** Original plan's Task 15.
- **Task A3 — Run the bench against son's fixtures and review.** Original plan's Task 16.
- **Task A4 — Update `PhonemeThresholds` numeric constants if the child data warrants.** Original plan's Task 17.
- **Task B1 — Extend `FixtureMetadata` with an optional phoneme sequence + target index.** Required so `PhonemeRegionLocalizer` slices medial-vowel fixtures (`æ`/`ʌ` in `cat`/`cut`) correctly instead of falling back to whole-clip evaluation. Raised by Copilot on both #41 and #42.
- **Task B2 — Tighten `FeatureBasedEvaluatorFixtureTests` assertions after B1.** Convert onset-fixture assertions from `if let score = …` conditional bounds to `XCTAssertTrue(isReliable) && XCTAssertNotNil(score)` unconditional bounds where reliability is guaranteed post-B1.
- **Task B3 — Address `θ/t` (onset burst slope).** Decide whether to add the asymmetric two-fixture pair or extend Engine A's coaching map to be symmetric. Was intentionally out of scope on the original plan.

### Out of scope

- Session-capture during normal A-day play (deferred in spec §4.5 / Appendix A).
- Automated threshold suggestion / Swift patch generation.
- Per-speaker profile layer.
- CI integration for `dev-tools/` — the bench still runs only on the developer's laptop.
- `PronunciationTrialLog` extensions (that's Engine B territory, already merged via #43).

---

## File map

**Files modified:**

| File | Change |
|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift` | Task B1: add optional `phonemeSequence: [String]?` + `targetPhonemeIndex: Int?` with migration-safe defaults |
| `Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift` | Task B1: surface new fields (probably as one text field accepting `k æ t` with a manual index, or a phoneme chip editor) |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift` | Task B1: round-trip coverage for the new fields |
| `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift` | Task B1: build `Word` with the sequence + index when present; keep `[target]` fallback |
| `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift` | Task A1: verify all 12 tests pass (fixtures now present). Task B2: tighten onset assertions. |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeThresholds.swift` | Task A4 only: numeric centroid / boundary updates |

**Files added (test-only):**

| File | Responsibility |
|---|---|
| `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/rl/*.wav` (4) | Adult-proxy recordings of `right` / `light` × {correct, substituted} |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/vb/*.wav` (4) | Adult-proxy recordings of `very` / `berry` × {correct, substituted} |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/aeuh/*.wav` (4) | Adult-proxy recordings of `cat` / `cut` × {correct, substituted} |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/th/*.wav` (optional, Task B3) | Adult-proxy recordings of `thin` / `tin` etc. if B3 chooses the symmetric four-fixture approach |

**Not committed:** son's child-speaker fixtures (`~/mora-fixtures-child/`). Kept on Yutaka's laptop per spec §9.3.

---

## Conventions

Inherit the originals from `2026-04-22-pronunciation-bench-and-calibration.md` §Conventions. In particular:

- English only in all governance / code / commit artifacts (CLAUDE.md rule).
- `#if DEBUG` wraps every file in `Debug/` directories.
- swift-format runs `--strict` in CI.
- Commit messages follow `area: short description`; include `Co-Authored-By: Claude <noreply@anthropic.com>` (repo opts in, per CLAUDE.md).
- Use a HEREDOC for commit messages so the trailer stays on its own line.
- Do not touch files in the Phase 3 conflict boundary table — Engine B has landed and the files are live code now, but the principle of scope isolation still applies here.
- `xcodegen generate` requires a temporary `project.yml` edit: add `DEVELOPMENT_TEAM: 7BT28X9TQ9` under the repo's `settings.base` (or equivalent — see the inline snippet in Task A1 Step 1 below), run `xcodegen generate`, then restore `project.yml` so the team ID is never committed.

---

## Phase A — Manual hardware data collection

These tasks cannot be automated; they require a physical iPad + quiet room + a human speaking into the microphone. Do them in order.

### Task A1: Record adult-proxy fixtures and check in

**Prerequisites:** iPad with Mora DEBUG build installed. macOS with AirDrop to iPad.

- [ ] **Step 1:** Rebuild and install the Mora DEBUG build on iPad.

```bash
: "${REPO_ROOT:?Set REPO_ROOT to the Mora repo root before running this task.}"
cd "$REPO_ROOT"
# inject team, generate, revert
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 7BT28X9TQ9', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
xcodebuild -project Mora.xcodeproj -scheme Mora -configuration Debug \
  -destination 'generic/platform=iOS' build
```

Install via Xcode → the physical iPad target.

- [ ] **Step 2:** 5-tap the Mora wordmark on HomeView → navigate to `Fixture Recorder` → record the 12 rows below with speaker tag `adult`. For every `substitutedBy` row, deliberately pronounce the word with the substitute phoneme.

| # | Target | Expected | Substitute | Word | Output filename after trim |
|---|---|---|---|---|---|
| 1 | r | matched | — | right | `rl/right-correct.wav` |
| 2 | r | substitutedBy | l | right | `rl/right-as-light.wav` |
| 3 | l | matched | — | light | `rl/light-correct.wav` |
| 4 | l | substitutedBy | r | light | `rl/light-as-right.wav` |
| 5 | v | matched | — | very | `vb/very-correct.wav` |
| 6 | v | substitutedBy | b | very | `vb/very-as-berry.wav` |
| 7 | b | matched | — | berry | `vb/berry-correct.wav` |
| 8 | b | substitutedBy | v | berry | `vb/berry-as-very.wav` |
| 9 | æ | matched | — | cat | `aeuh/cat-correct.wav` |
| 10 | æ | substitutedBy | ʌ | cat | `aeuh/cat-as-cut.wav` |
| 11 | ʌ | matched | — | cut | `aeuh/cut-correct.wav` |
| 12 | ʌ | substitutedBy | æ | cut | `aeuh/cut-as-cat.wav` |

- [ ] **Step 3:** AirDrop `/On My iPad/Mora/` → `~/mora-fixtures/` on the Mac.

- [ ] **Step 4:** Sanity-run the bench with `--no-speechace`:

```bash
cd "$REPO_ROOT/dev-tools/pronunciation-bench"
swift run bench ~/mora-fixtures/ ~/mora-fixtures/out.csv --no-speechace
```

Scan the CSV. If any `-correct.wav` labels as `.substitutedBy(...)` or any `-as-X.wav` labels as `.matched`, re-record — the fixture is noisy or mispronounced. Do **not** widen the test assertion bounds to compensate.

- [ ] **Step 5:** Trim each WAV to keep clips ≤ 2 s per the original plan's guidance (16 kHz × 16-bit × mono ≈ 32 KB/s, so 2 s ≈ 65 KB + header, well under the 100 KB ceiling):

```bash
# brew install sox  # once
sox in.wav -r 16000 -b 16 -c 1 out.wav trim 0 2.0
```

- [ ] **Step 6:** Rename per the filename table and check in. Keep the sidecar JSONs alongside the WAVs — the engine tests read labels from the filename, but `dev-tools/pronunciation-bench/FixtureLoader.enumerate` requires a matching `.json` for each `.wav`, so the committed fixtures stay re-bench-able without re-recording.

```bash
cp -a ~/mora-fixtures-trimmed/{rl,vb,aeuh} Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/
# remove the .gitkeep placeholders now that real WAVs are present
rm -f Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/{rl,vb,aeuh}/.gitkeep
ls -l Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/{rl,vb,aeuh}/*.wav
```

Every file should be < 100 KB.

- [ ] **Step 7:** Run the engine test suite and confirm all 12 previously-skipped tests pass:

```bash
(cd Packages/MoraEngines && swift test 2>&1 | tail -5)
```

Expected: `Executed 109 tests, with 0 failures (0 unexpected)`. **Any `skipped` in the summary means Step 6 missed a file.**

If any fixture test fails at this point, the recording is the problem — re-record that specific file, do **not** widen bounds.

- [ ] **Step 8:** Commit:

```bash
git add Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/
git commit -m "$(cat <<'EOF'
engines: add adult-proxy recorded fixtures for r/l, v/b, ae/uh

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Verification gate before moving on:**
- [ ] `git status` clean.
- [ ] `(cd Packages/MoraEngines && swift test)` green with zero skips.
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` silent.

---

### Task A2: Record son's child-speaker fixtures (not committed)

Same DEBUG fixture recorder, speaker tag `child`, minimum 3 takes per (target, expectedLabel) row from Task A1's table. Quiet room. No siblings audible.

- [ ] **Step 1:** Record. Aim for 36+ clips (3 × 12 rows).
- [ ] **Step 2:** AirDrop to `~/mora-fixtures-child/`. Do **not** copy into the repo.
- [ ] **Step 3:** Confirm sidecar JSONs came across (the bench's SpeechAce path needs them).
- [ ] **Step 4:** No commit — these stay on the laptop per spec §9.3.

---

### Task A3: Run the bench against son's fixtures

- [ ] **Step 1:** Configure SpeechAce:

```bash
cd dev-tools/pronunciation-bench
cp .env.example .env
# paste SPEECHACE_API_KEY into .env
source .env
export SPEECHACE_API_KEY
```

- [ ] **Step 2:** Run the bench:

```bash
swift run bench ~/mora-fixtures-child/ ~/mora-fixtures-child/child-out.csv
```

- [ ] **Step 3:** Review `child-out.csv` in Numbers or pandas. For each (target, expectedLabel) pair:
  - Mean Engine A score for `matched` rows. Below 60 suggests adult-literature centroid is miscalibrated.
  - Cross-check against SpeechAce `quality_score`. If SpeechAce is > 80 but Engine A is low, the fix is on Engine A.
  - For `substitutedBy` rows, confirm Engine A labels the substitute correctly; label disagreements flag boundary issues.

- [ ] **Step 4:** Write down the proposed threshold shifts for Task A4 (one per phoneme). Target shifts are typically ± 10 % on F-features; keep within ± 15 % of the literature value.

- [ ] **Step 5:** No commit.

---

### Task A4: Update `PhonemeThresholds` (numeric only)

Only if Task A3 identified shifts. Skip this task entirely if Task A3 concluded no threshold changes are needed (that outcome is acceptable per the original plan).

- [ ] **Step 1:** Pick one threshold at a time. Edit the relevant `SubstitutionThresholds(...)` entry inside `PhonemeThresholds.primary(for:against:)` or the `DriftThresholds(...)` inside `PhonemeThresholds.drift(for:)`.
- [ ] **Step 2:** Run the adult-proxy fixture tests:

```bash
(cd Packages/MoraEngines && swift test)
```

If a `matched` bound fails, widen by ≤ 5 points (70 → 65). If a `substitutedBy` bound fails, widen by ≤ 5 points (40 → 45). Document the widening in the commit message. Anything wider than 5 points means the child shift is too aggressive — roll back and try smaller.

- [ ] **Step 3:** Re-run the bench against son's fixtures (Task A3, Step 2) and confirm the targeted `matched` rows now cluster ≥ 60.

- [ ] **Step 4:** Commit. One phoneme per commit; do not batch.

```bash
git commit -m "$(cat <<'EOF'
engines: calibrate /r/ F3 centroid for child speakers (+10%)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Repeat Task A4 once per threshold.

---

## Phase B — Code follow-ups

These do not depend on Phase A recordings, but Task B2's tighter assertions are validated by running against the fixtures from A1, so B2 should land after A1.

### Task B1: Extend `FixtureMetadata` with phoneme sequence + target index

**Why:** In both the bench (`EngineARunner.evaluate`) and the in-engine tests (`FeatureBasedEvaluatorFixtureTests.evaluate`), the `Word` is built with `phonemes: [target]`. `PhonemeRegionLocalizer.position(of:in:)` then returns `.onset` because the target sits at index 0 of a 1-element array. This is correct for onset consonants (`r`, `l`, `v`, `b` in `right`, `light`, `very`, `berry`) but wrong for medial vowels (`æ`, `ʌ` in `cat`, `cut`) — the localizer either slices the initial `/k/` or falls back to the whole clip, depending on downstream logic. Engine A still evaluates *something*, but not the intended region.

Copilot flagged this on both #41 (EngineARunner) and #42 (FeatureBasedEvaluatorFixtureTests). The fix is a schema extension, not a one-line tweak.

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Debug/FixtureMetadata.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Debug/PronunciationRecorderView.swift`
- Modify: `dev-tools/pronunciation-bench/Sources/Bench/EngineARunner.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/Debug/FixtureMetadataTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift`

#### Step 1 (TDD): Write the failing Codable round-trip test

Add to `FixtureMetadataTests`:

```swift
func testRoundTripsPhonemeSequenceAndIndex() throws {
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
        targetPhonemeIndex: 1
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(meta)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(FixtureMetadata.self, from: data)
    XCTAssertEqual(decoded.phonemeSequenceIPA, ["k", "æ", "t"])
    XCTAssertEqual(decoded.targetPhonemeIndex, 1)
}

func testDecodesLegacyPayloadWithoutPhonemeSequence() throws {
    // Sidecar files recorded before B1 won't have the new fields;
    // decode must still succeed with nil defaults so old fixtures load.
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
    XCTAssertNil(decoded.phonemeSequenceIPA)
    XCTAssertNil(decoded.targetPhonemeIndex)
}
```

Run and confirm FAIL.

#### Step 2: Add the fields to `FixtureMetadata`

```swift
public struct FixtureMetadata: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let targetPhonemeIPA: String
    public let expectedLabel: ExpectedLabel
    public let substitutePhonemeIPA: String?
    public let wordSurface: String
    public let sampleRate: Double
    public let durationSeconds: Double
    public let speakerTag: SpeakerTag
    // Optional: full phoneme sequence and the index of the target within it.
    // nil on legacy sidecar files recorded before 2026-04-23 — callers must
    // fall back to `phonemes: [target]` when either is nil.
    public let phonemeSequenceIPA: [String]?
    public let targetPhonemeIndex: Int?

    public init(
        capturedAt: Date,
        targetPhonemeIPA: String,
        expectedLabel: ExpectedLabel,
        substitutePhonemeIPA: String?,
        wordSurface: String,
        sampleRate: Double,
        durationSeconds: Double,
        speakerTag: SpeakerTag,
        phonemeSequenceIPA: [String]? = nil,
        targetPhonemeIndex: Int? = nil
    ) {
        // ... assign all ...
    }
}
```

Default-nil parameters keep the call sites inside #41's view + tests compiling unchanged.

#### Step 3: Add phoneme sequence + index UI to `PronunciationRecorderView`

Two extra form rows:

- `TextField("Phoneme sequence (space-separated IPA, optional)", text: $phonemeSequenceRaw)` — split on whitespace when non-empty.
- `Stepper("Target index: \(targetPhonemeIndex)", value: $targetPhonemeIndex, in: 0...10)` — visible only when phoneme sequence is non-empty.

Wire them into the `FixtureMetadata` init inside `save()`. Keep the fields empty by default so the recorder stays usable for onset-only cases without the extra step.

#### Step 4: Update `EngineARunner.evaluate`

```swift
public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
    let evaluator = FeatureBasedPronunciationEvaluator()
    let target = Phoneme(ipa: loaded.metadata.targetPhonemeIPA)

    let phonemes: [Phoneme]
    let targetIndex: Int
    if let seq = loaded.metadata.phonemeSequenceIPA,
       let idx = loaded.metadata.targetPhonemeIndex,
       idx < seq.count {
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
    // ... rest unchanged ...
}
```

#### Step 5: Apply the same upgrade to `FeatureBasedEvaluatorFixtureTests.evaluate`

The test helper currently takes `target ipa: String, word surface: String`. Extend it:

```swift
private func evaluate(
    _ relative: String,
    target ipa: String,
    word surface: String,
    phonemes: [String]? = nil,
    targetIndex: Int? = nil
) async throws -> PhonemeTrialAssessment {
    // ... load WAV ...
    let targetPhoneme = Phoneme(ipa: ipa)
    let phonemeList = phonemes.map { $0.map { Phoneme(ipa: $0) } } ?? [targetPhoneme]
    let idx = targetIndex ?? 0
    let word = Word(
        surface: surface,
        graphemes: [Grapheme(letters: surface)],
        phonemes: phonemeList,
        targetPhoneme: phonemeList[idx]
    )
    // ... evaluator.evaluate ...
}
```

Then update the medial-vowel call sites:

```swift
func testCatCorrectMatchesAe() async throws {
    let a = try await evaluate(
        "aeuh/cat-correct.wav",
        target: "æ", word: "cat",
        phonemes: ["k", "æ", "t"], targetIndex: 1
    )
    // ...
}
// repeat for the three other aeuh tests
```

Leave the consonant tests (`r/l`, `v/b`) on the default `[target]` path since they're onset-positioned.

#### Step 6: Verify

```bash
(cd Packages/MoraEngines && swift test)
(cd dev-tools/pronunciation-bench && swift test)
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

All green.

#### Step 7: Commit

```bash
git commit -m "$(cat <<'EOF'
engines: extend FixtureMetadata with optional phoneme sequence + target index

Address PR #41 / #42 Copilot review: Word built with phonemes: [target]
forces PhonemeRegionLocalizer to pick .onset even when the target is
medial. Optional phonemeSequenceIPA + targetPhonemeIndex let callers
(EngineARunner, FeatureBasedEvaluatorFixtureTests) pass the full
sequence so localization matches the intended position. nil on
legacy sidecars — callers fall back to [target].

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task B2: Tighten onset-fixture assertions after B1

**Why:** Copilot flagged that `if let score = assessment.score { XCTAssertGreaterThanOrEqual(score, 70) }` lets a regression where Engine A returns `.matched` with `score == nil` slide past the test. After B1, the onset-consonant fixtures have a reliable localized region, so we can assert `XCTAssertTrue(isReliable)` and `XCTAssertNotNil(score)` unconditionally for those cases.

- [ ] **Step 1:** In `FeatureBasedEvaluatorFixtureTests`, for every `r/l` and `v/b` test, replace:

```swift
XCTAssertEqual(a.label, .matched)
if let s = a.score { XCTAssertGreaterThanOrEqual(s, 70) }
```

with:

```swift
XCTAssertEqual(a.label, .matched)
XCTAssertTrue(a.isReliable, "onset fixture should be reliable after B1")
let score = try XCTUnwrap(a.score)
XCTAssertGreaterThanOrEqual(score, 70)
```

and the symmetric change for `.substitutedBy(...)` tests (`XCTAssertLessThanOrEqual(score, 40)`).

- [ ] **Step 2:** For `æ/ʌ` tests — reliability depends on Phase D tuning. Either:
  - Keep the conditional form with a TODO comment linking to Task A4, OR
  - If Task A4 has already shifted thresholds and the vowel tests are stable, promote them too.

Make the choice based on what Task A4 landed; don't promote speculatively.

- [ ] **Step 3:** Run:

```bash
(cd Packages/MoraEngines && swift test)
```

All 109 tests green, zero skips.

- [ ] **Step 4:** Commit:

```bash
git commit -m "$(cat <<'EOF'
engines: assert isReliable + non-nil score on onset fixture tests

Address PR #42 Copilot review: conditional `if let score = ...` bounds
let regressions slide past where Engine A returns .matched without a
numeric score. Post-B1 the onset fixtures (r/l, v/b) localize reliably,
so unconditional XCTAssertTrue(isReliable) + XCTUnwrap(score) is safe.
Medial-vowel tests stay conditional pending Phase D calibration.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task B3: Decide on `θ/t` (onset burst slope)

**Why:** The original plan explicitly punted on the fourth TODO'd synthetic stub because Engine A's coaching map is asymmetric for `θ/t` — only `(θ, t)` produces a coaching key, `(t, θ)` does not. The symmetric four-fixture pattern used for `r/l`, `v/b`, `æ/ʌ` doesn't fit.

**Decision needed first (ask the user, don't code blindly):**

1. **Option A — symmetric, extend Engine A first.** Add a `(t, θ)` entry to the coaching map (plus matching thresholds), then record the standard four-fixture pattern (`thin-correct`, `thin-as-tin`, `tin-correct`, `tin-as-thin`). Engine A change is scoped — one map entry — but philosophically that's Engine A coaching coverage, not calibration work.
2. **Option B — asymmetric, bench only.** Keep Engine A's coaching asymmetric; record only the two fixtures that exercise the existing path (`thin-correct`, `thin-as-tin`). Write only two new test cases.
3. **Option C — defer indefinitely.** Leave the TODO bullet in `FeatureBasedEvaluatorTests.swift` as-is.

**Recommended:** **Option A**, because the asymmetry was never a deliberate design choice — it was an implementation-time omission in Engine A's coaching map during `2026-04-22-pronunciation-feedback-engine-a.md` §X. Documenting the reason for asymmetry in the coaching map, then either fixing it (A) or keeping it (C), is a prerequisite to any recording work.

- [ ] **Step 1:** Audit Engine A's coaching map to confirm whether the asymmetry is intentional. If unclear, ask Yutaka.
- [ ] **Step 2:** If Option A is chosen, extend `PhonemeThresholds.primary(for:against:)` with the `(t, θ)` case. Add tests for the new coaching key. (Plan this as its own sub-task; it's Engine A work, not bench work.)
- [ ] **Step 3:** Record fixtures per the chosen option's table. Commit them under `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/th/`.
- [ ] **Step 4:** Add `FeatureBasedEvaluatorFixtureTests` cases.
- [ ] **Step 5:** Delete the remaining TODO bullet from `FeatureBasedEvaluatorTests.swift` (the whole `// MARK: - Skipped substitution pairs` block can go if no TODOs remain).

---

## Completion Checklist

After Task A4 and Task B2 land, verify the same gates as the original plan:

- [ ] `(cd Packages/MoraCore && swift test)` green.
- [ ] `(cd Packages/MoraEngines && swift test)` green, zero skips in `FeatureBasedEvaluatorFixtureTests`.
- [ ] `(cd Packages/MoraUI && swift test)` green.
- [ ] `(cd Packages/MoraTesting && swift test)` green.
- [ ] `(cd dev-tools/pronunciation-bench && swift test)` green.
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` silent.
- [ ] `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` succeeds.
- [ ] `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Release CODE_SIGNING_ALLOWED=NO` succeeds.
- [ ] `nm <Release Mora.app>/Mora | grep -iE 'FixtureRecorder|FixtureWriter|PronunciationRecorderView|DebugFixtureRecorderEntryModifier'` empty.
- [ ] `git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages` empty.

Task B3 may or may not land in this cycle depending on the Option A/B/C choice.

---

## Handoff notes

- **Fixture recording is the bottleneck.** Without Task A1 WAVs, the 12 engine tests stay skipped; without Task A2/A3, Phase D can't run. Block on A1 before any code task if the aim is closing the skip gap.
- **Task B1 is independent of recordings** and can start anytime — it's a schema change plus two call-site updates. Landing B1 first actually makes Task A1 smoother because the recorder UI will already capture the phoneme sequence, so re-recording won't be needed to pick up the richer localization signal.
- **Task A4 may legitimately be a no-op.** If son's fixtures score within literature-derived bounds everywhere, the Phase D calibration outcome is "no threshold changes needed" — skip the commit and add a note in the PR description per the original plan §Task 17 Step 6.
- **θ/t is still explicitly optional.** Don't let it block the rest of Phase D.
- **Copilot deferred items** from #41 / #42 are covered by Task B1 and Task B2. After those two land, the review threads on #41 (EngineARunner line 17) and #42 (FeatureBasedEvaluatorFixtureTests lines 42 + 122) can be re-visited and marked resolved.
