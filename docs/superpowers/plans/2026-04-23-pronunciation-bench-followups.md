# Pronunciation Bench & Calibration — Follow-up Work

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to pick tasks from this document task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status on 2026-04-23:** Phase A + Phase B + Phase C-code of `2026-04-22-pronunciation-bench-and-calibration.md` shipped via [#41](https://github.com/youtalk/mora/pull/41) and [#42](https://github.com/youtalk/mora/pull/42). Engine B Part 1 + Part 2 landed via [#43](https://github.com/youtalk/mora/pull/43) / [#45](https://github.com/youtalk/mora/pull/45). This document captures the work that was explicitly deferred from those PRs plus a handful of code-quality items raised in Copilot review.

**Update on 2026-04-24:** Engine A whole-word + medial-vowel prerequisites landed via `docs/superpowers/plans/2026-04-24-engine-a-whole-word-and-medial-vowel.md` (`maxDurationMs` raised to 2000 ms; `PhonemeRegionLocalizer` medial slice now flagged reliable). Task A1 can proceed against the existing `~/mora-fixtures-adult/` recordings without the previously-required hard cap.

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

**Prerequisites:** iPad with the standalone recorder app installed. macOS with AirDrop to iPad.

- [ ] **Step 1:** Rebuild and install the recorder app on iPad.

```bash
: "${REPO_ROOT:?Set REPO_ROOT to the Mora repo root before running this task.}"
cd "$REPO_ROOT/recorder"
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 7BT28X9TQ9', p, count=1)
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
| 2 | right — /r/ substituted by /l/ | `adult/rl/right-as-light-take1.wav` + `.json` |
| 3 | light — /l/ matched | `adult/rl/light-correct-take1.wav` + `.json` |
| 4 | light — /l/ substituted by /r/ | `adult/rl/light-as-right-take1.wav` + `.json` |
| 5 | very — /v/ matched | `adult/vb/very-correct-take1.wav` + `.json` |
| 6 | very — /v/ substituted by /b/ | `adult/vb/very-as-berry-take1.wav` + `.json` |
| 7 | berry — /b/ matched | `adult/vb/berry-correct-take1.wav` + `.json` |
| 8 | berry — /b/ substituted by /v/ | `adult/vb/berry-as-very-take1.wav` + `.json` |
| 9 | cat — /æ/ matched | `adult/aeuh/cat-correct-take1.wav` + `.json` |
| 10 | cat — /æ/ substituted by /ʌ/ | `adult/aeuh/cat-as-cut-take1.wav` + `.json` |
| 11 | cut — /ʌ/ matched | `adult/aeuh/cut-correct-take1.wav` + `.json` |
| 12 | cut — /ʌ/ substituted by /æ/ | `adult/aeuh/cut-as-cat-take1.wav` + `.json` |

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

- [ ] **Step 2:** For `æ/ʌ` tests — `PhonemeRegionLocalizer` now flags medial slices as reliable (landed in `2026-04-24-engine-a-whole-word-and-medial-vowel.md`). Apply the same unconditional `XCTAssertTrue(isReliable)` + `XCTUnwrap(score)` pattern as the onset cases. Numeric bounds may still need Task A4 calibration to land within tight ranges; widen by ≤ 5 points per Task A4's rule rather than dropping to a conditional.

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
