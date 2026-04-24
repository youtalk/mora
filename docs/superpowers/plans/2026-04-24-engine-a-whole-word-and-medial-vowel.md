# Engine A: whole-word audio + medial-vowel localizer

> Prerequisite for `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` Task A1 (record adult-proxy fixtures and check them in). Engine A's current sanity threshold and localizer reject the natural recordings the new fixture-recorder app (#53) produces. This plan addresses both blockers as one PR so Task A1 can resume.

## Status

- **Date:** 2026-04-24
- **Author:** Yutaka Kondo (with Claude Code)
- **Blocks:** `2026-04-23-pronunciation-bench-followups.md` Task A1 / A2 / A3 / A4 / B2 (every step that depends on running Engine A over real recordings).
- **Does not block:** Engine B work (`2026-04-23-engine-b-followup-real-model-bundling.md`); independent code path. Recorder app work (#53); already merged.

## What was discovered

While walking through Task A1 with all 12 adult-proxy WAVs recorded via the fixture-recorder app and AirDropped to `~/mora-fixtures-adult/`, every fixture failed end-to-end through `dev-tools/pronunciation-bench/`:

1. **`maxDurationMs = 600` rejects whole-word recordings.** `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift:19` caps `isAudioUsable` at 600 ms. Recorder takes are 1.3–1.6 s end-to-end. Even after `sox silence 1 0.05 0.5%` trim from both ends, two-syllable words (`berry`, `very`) stay 0.65–0.83 s and are rejected → `.unclear` / `isReliable=false` for every clip. Hard-capping with `trim 0 0.59` chops the trailing syllable and degrades substitution detection in r/l and v/b.
2. **`PhonemeRegionLocalizer` flags every medial position as `isReliable=false`.** `PhonemeRegionLocalizer.swift:46` returns `reliable: false` unconditionally for `.medial(...)`. Docstring at line 23 explicitly says *"medial positions are flagged unreliable."* This means the four `aeuh/` fixtures (target æ/ʌ at index 1 in `cat`/`cut`) cannot ever produce a reliable assessment, regardless of recording quality or the `phonemeSequenceIPA` + `targetPhonemeIndex` schema landed in `2026-04-23-fixture-recorder-app-design.md` §6.3.

Both predate the fixture-recorder spec and were latent: Engine A's existing in-package tests use synthetic short clips that fit under 600 ms, and the 12 `FeatureBasedEvaluatorFixtureTests` are still `XCTSkip`ed pending the fixtures this plan unblocks. The mismatch surfaced only when real recordings + the bench were combined for the first time.

## Reproduction (today, 2026-04-23 main)

```sh
# Recorder app: record all 12 patterns at adult, AirDrop the bulk zip,
# unzip into ~/mora-fixtures-adult/{rl,vb,aeuh}/ — see Task A1 Steps 1–3.

# Trim with the gentlest viable silence threshold (0.5%) + 590ms hard cap:
for subdir in rl vb aeuh; do
  for wav in ~/mora-fixtures-adult/$subdir/*.wav; do
    stem=$(basename "$wav" -take1.wav)
    sox "$wav" -r 16000 -b 16 -c 1 \
        ~/mora-fixtures-adult-trimmed/$subdir/$stem.wav \
        silence 1 0.05 0.5% reverse silence 1 0.05 0.5% reverse trim 0 0.59
    cp "$(dirname "$wav")/$stem-take1.json" \
       ~/mora-fixtures-adult-trimmed/$subdir/$stem.json
  done
done

cd dev-tools/pronunciation-bench
for d in rl vb aeuh; do
  swift run bench ~/mora-fixtures-adult-trimmed/$d \
                  ~/mora-fixtures-adult-trimmed/out-$d.csv --no-speechace
done
```

Result on `main` at HEAD `96f6e04`:

| Category | Match expected label | Notes |
|---|---|---|
| r/l | 3/4 | `light-correct` mislabeled as substituted-by-/r/. Unclear if the recording is borderline or a threshold issue; cannot disentangle until Fix 1 + Fix 2 land. |
| v/b | 1/4 | All 4 hit the 590 ms cap; trailing syllable lost; substitution detection collapses. |
| æ/ʌ | 0/4 reliable | `isReliable=false` on every take regardless of label correctness. Engine cannot evaluate medial position. |
| **Total** | **4/12** | The bench-followups Task A1 Step 4 expectation ("`-correct` → `matched`, `-as-X` → `substitutedBy(<X>)`") is unreachable. |

Without the hard cap (just bilateral silence trim), v/b clips stay around 0.4–0.6 s and 2/4 land correctly, but æ/ʌ stays 0/4 reliable — the medial-position issue is independent of duration.

## Goals and non-goals

### Goals

- Raise `FeatureBasedPronunciationEvaluator.maxDurationMs` to a value compatible with whole-word English recordings (≥ 2000 ms).
- Make `PhonemeRegionLocalizer` produce `isReliable=true` for medial positions when the slice is well-defined, so æ/ʌ in `cat`/`cut` can be evaluated end-to-end.
- Add unit tests that exercise both fixes independently of the recorded-fixture suite.
- Update `2026-04-23-pronunciation-bench-followups.md` so Task A1's `sox` step matches the new threshold and Task B2's "depends on Phase D tuning" caveat for medial vowels is removed.

### Non-goals

- Re-recording fixtures or re-running the bench. That work resumes (in `2026-04-23-pronunciation-bench-followups.md` Task A1 Steps 4–8) **after** this plan's PR merges.
- Calibrating `PhonemeThresholds` numeric constants. That is Task A4 of the followups plan; it should land after Fix 2 so calibration data reflects reliable medial measurements.
- Engine B (`PhonemeModelPronunciationEvaluator`). Independent code path, untouched here.
- Replacing the equal-time-slice localizer with a voicing/RMS-based segmenter. Considered as Fix 2b below; deferred unless Fix 2a's equal-segment slice misclassifies on real recordings.
- Changing `PronunciationTrialLog` schema or any Engine A consumer protocol. The fixes are internal to `FeatureBasedPronunciationEvaluator` + `PhonemeRegionLocalizer`.

## Design

### Fix 1 — relax `maxDurationMs`

```diff
-    private static let maxDurationMs: Double = 600
+    private static let maxDurationMs: Double = 2_000
```

Rationale: `PhonemeRegionLocalizer.region(...)` already slices a fixed 150 ms window (or 25% of clip duration, whichever is smaller) for onset and coda. Downstream feature extraction sees the same window length regardless of the full clip duration. The 600 ms cap on the entire clip was a residue of synthetic-test-only assumptions and is inconsistent with the bench-followups plan's `sox trim 0 2.0` step.

`minDurationMs = 40` stays — it still guards against pathologically short clicks.

`AppendixDurationCheck` in `FeatureBasedEvaluatorTests.swift` (if present, otherwise added) asserts the new behavior with a 1.5 s synthetic clip.

### Fix 2 — make medial vowels reliable (Option 2a: equal-segment slice marked reliable)

```diff
-        case .medial(let position, let count):
-            guard count > 0 else {
-                return LocalizedRegion(clip: clip, startMs: 0, durationMs: totalMs, isReliable: false)
-            }
-            let unit = totalMs / Double(count)
-            let startMs = Double(position) * unit
-            return slice(clip: clip, startMs: startMs, durationMs: unit, reliable: false)
+        case .medial(let position, let count):
+            guard count > 0, position >= 0, position < count else {
+                return LocalizedRegion(clip: clip, startMs: 0, durationMs: totalMs, isReliable: false)
+            }
+            let unit = totalMs / Double(count)
+            let startMs = Double(position) * unit
+            return slice(clip: clip, startMs: startMs, durationMs: unit, reliable: true)
```

Rationale: the equal-time-slice heuristic is the same shape used for onset and coda, both of which are flagged reliable today. For short CVC words (`cat`, `cut`, `bat`, `but`) the medial vowel sits in roughly the middle third of the clip, which is what the equal-segment slice produces. The unconditional `reliable: false` was conservative at the time medial cases didn't exist in any fixture; with the recorder app's catalog now writing `phonemeSequenceIPA` + `targetPhonemeIndex` on every medial-vowel take, the slice is well-defined and the conservatism becomes a hard blocker.

Update the docstring at line 23 to drop the "medial positions are flagged unreliable" sentence and explain the equal-segment slice is the same heuristic used for onset/coda.

### Fix 2b — energy/voicing-based segmentation (deferred)

If after Fix 2a the four `aeuh/` fixture tests still fail in `FeatureBasedEvaluatorFixtureTests` despite clean recordings (i.e., the equal-segment slice catches consonant transition rather than the vowel nucleus), revisit with a lightweight RMS + formant-trajectory segmenter. Out of scope for this PR; create a follow-up plan if needed.

### Tests

Add to `Packages/MoraEngines/Tests/MoraEnginesTests/`:

- **`FeatureBasedEvaluatorWholeWordTests.swift`** — feeds a 1.5 s synthetic vowel-like clip (sine + noise mixture, RMS within `noiseFloorDbFS`) to `FeatureBasedPronunciationEvaluator.evaluate(...)` and asserts the result is **not** `.unclear` from the audio sanity check. Without Fix 1 this test fails.
- **`PhonemeRegionLocalizerMedialReliabilityTests.swift`** — constructs a `Word` with `phonemes: ["k", "æ", "t"]`, target index 1, calls `PhonemeRegionLocalizer.region(...)` on a synthetic 600 ms clip, and asserts `isReliable == true` and `startMs == 200` (1/3 into the clip), `durationMs == 200`. Without Fix 2 this test fails on the reliability flag.

Existing tests:

- `FeatureBasedEvaluatorTests.swift` — should remain green; both fixes are strictly more permissive on previously-rejected inputs.
- `FeatureBasedEvaluatorFixtureTests.swift` — still `XCTSkip`s until Task A1 Step 6 lands the actual WAV files. The skips in this file are not unblocked by *this* PR; they are unblocked by `2026-04-23-pronunciation-bench-followups.md` Task A1 finishing once this PR merges.

## Implementation steps

Land as one PR. Order the commits as 1 → 2 → 3 → 4 so reviewers can read them in logical flow.

- [ ] **Step 1 — Fix 1.** Bump `maxDurationMs` to 2_000 in `FeatureBasedPronunciationEvaluator.swift`. Add `FeatureBasedEvaluatorWholeWordTests.swift`. Run `(cd Packages/MoraEngines && swift test)` — green.
- [ ] **Step 2 — Fix 2 (Option 2a).** Switch `.medial(...)` to `reliable: true` and add the bounds guard. Update the localizer docstring. Add `PhonemeRegionLocalizerMedialReliabilityTests.swift`. Run `(cd Packages/MoraEngines && swift test)` — green.
- [ ] **Step 3 — Update the bench-followups plan.**
  - In `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` Task A1 Step 5, drop the rationale about the 600 ms threshold (now obsolete) and keep `sox trim 0 2.0` as a length cap that matches the new threshold.
  - In Task B2 Step 2, delete the *"For `æ/ʌ` tests — reliability depends on Phase D tuning"* clause; medial reliability is now a code property.
  - Add a one-line note at the top of the followups plan: *"As of 2026-04-24, prerequisites in `2026-04-24-engine-a-whole-word-and-medial-vowel.md` have landed; Task A1 can resume."*
- [ ] **Step 4 — Lint + final verify.**
  - `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` silent.
  - `(cd Packages/MoraEngines && swift test)` green.
  - `(cd Packages/MoraCore && swift test)` green.
  - `(cd Packages/MoraUI && swift test)` green.
  - `(cd dev-tools/pronunciation-bench && swift test)` green.
  - `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` green.

## Verification after merge (handoff to bench-followups Task A1)

Once this PR merges, re-run the Task A1 Step 4 sanity check on the previously-recorded `~/mora-fixtures-adult/` recordings (no re-record needed) without the 590 ms hard cap:

```sh
for subdir in rl vb aeuh; do
  for wav in ~/mora-fixtures-adult/$subdir/*.wav; do
    stem=$(basename "$wav" -take1.wav)
    sox "$wav" -r 16000 -b 16 -c 1 \
        ~/mora-fixtures-adult-trimmed/$subdir/$stem.wav \
        silence 1 0.05 0.5% reverse silence 1 0.05 0.5% reverse trim 0 2.0
  done
done

cd dev-tools/pronunciation-bench
for d in rl vb aeuh; do
  swift run bench ~/mora-fixtures-adult-trimmed/$d \
                  ~/mora-fixtures-adult-trimmed/out-$d.csv --no-speechace
done
```

Expected: r/l and v/b all 4/4 match expected label; æ/ʌ produces `isReliable=true` on every take and `matched` / `substitutedBy(...)` labels match the expected column. If any row still misses, that is a recording-quality issue (re-record per Task A1 Step 4) or a calibration issue (escalate to Task A4), no longer an engine-level blocker.

## Open questions

1. **Should `maxDurationMs` be configurable?** Likely no — 2 s covers the longest decodable English word a v1 lesson is going to use. Revisit if a sentence-level evaluator path is added later (out of scope here).
2. **Does Fix 2a regress synthetic onset/coda tests?** No, because `PhonemeRegionLocalizer.position(...)` still routes index 0 to `.onset` and `count - 1` to `.coda`; only true-medial positions reach the new `reliable: true` branch. Existing tests construct CVC words with single-phoneme targets that fall on onset/coda.
3. **Does the equal-segment slice need a minimum duration?** The slice can be as small as 50 ms for a 4-phoneme word at 200 ms total clip duration (under `minDurationMs` so the audio sanity already rejects). Above the 200 ms floor the slice is at least 50 ms, comparable to the existing onset 150 ms slice. Skip the floor unless Fix 2a's empirical results suggest one.

## References

- Blocked plan: `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` Task A1 Steps 4 + 7
- Recorder spec assuming engine handles whole words: `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md` §7.1
- Engine A constraints to fix: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift:17-19`, `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeRegionLocalizer.swift:23-46`
- Catalog providing `phonemeSequenceIPA` + `targetPhonemeIndex` per take: `Packages/MoraFixtures/Sources/MoraFixtures/FixtureCatalog.swift` (landed in #53)
