# Engine B Follow-up: Real Model Bundling + Device Verification

> Continuation of `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md`. PRs #43 (Part 1) and #45 (Part 2) are merged. This file captures every remaining step needed to flip shadow mode from "code ready, placeholder bundled" to "real wav2vec2 running on device" and to prepare for Engine B promotion.

## Current state (as of 2026-04-23, post-#45 merge)

- `main` contains the full Engine B code path: `PhonemeModelPronunciationEvaluator`, `ShadowLoggingPronunciationEvaluator`, SwiftData `PronunciationTrialLog`, MoraMLX loader, CoreML provider, `dev-tools/model-conversion/` toolchain, CI LFS, latency benchmark scaffold, docs.
- `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/` is a **placeholder directory** containing only `placeholder.txt`. `phoneme-labels.json` is a **placeholder file** containing only `["<pad>"]`.
- `MoraMLXModelCatalog.loadPhonemeEvaluator()` reaches `MLModel(contentsOf:)`, which fails because the placeholder isn't a real compiled model → throws `MoraMLXError.modelLoadFailed`. The app's `ShadowEvaluatorFactory` catches this and falls back to bare Engine A. End-user behavior is unchanged.
- MoraMLX test suite: 3 tests, 3 skipped via `PlaceholderDetection.isPlaceholderModelBundled()` (positive detection on `phoneme-labels.json` entry count ≤ 1).
- Git LFS is initialized locally (`git lfs install` ran), `.gitattributes` patterns are in place, CI checkout uses `lfs: true`.

## Blockers preventing the real model from landing

1. **Local compute** — `convert.py` takes ~10 min on an M2 MacBook Pro, produces a ~150 MB `.mlmodelc`. Agentic sessions with restricted network/disk can't run it end-to-end.
2. **CoreML compile tool** — the script calls `xcrun coremlcompiler`, so the conversion must run on macOS with Xcode Command Line Tools. Linux / Docker are not viable hosts.

The upstream model `facebook/wav2vec2-xlsr-53-espeak-cv-ft` is **public** (HF API `gated: False`), so no Hugging Face access token is required.

## Remaining work

### 1. Bundle the real model (Task 22 Steps 2–5)

**Prereqs**: macOS with Xcode Command Line Tools and [`uv`](https://github.com/astral-sh/uv) (`brew install uv`). The upstream model is public — no Hugging Face token is needed.

```sh
: "${REPO_ROOT:?Set REPO_ROOT to the Mora repo root before running this task.}"
cd "$REPO_ROOT"
git checkout -b followup/engine-b-real-model main

cd "$REPO_ROOT/dev-tools/model-conversion"
uv venv --python 3.11
uv pip install -r requirements.txt
source .venv/bin/activate

python convert.py --output-dir ../../Packages/MoraMLX/Sources/MoraMLX/Resources
cd "$REPO_ROOT"

# convert.py writes `.mlpackage` to a tempfile and cleans it up; only `.mlmodelc`
# and `phoneme-labels.json` end up in Resources/.

# Delete placeholders (convert.py should overwrite but check):
rm -f Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/placeholder.txt

# Verify LFS captured the heavy files:
git lfs ls-files | grep wav2vec2-phoneme   # should list ~several .mlmodelc/ contents

# Verify the CoreML model actually loads:
(cd Packages/MoraMLX && swift test)        # 3 tests must all PASS (no skips)

git add .gitattributes \
        Packages/MoraMLX/Sources/MoraMLX/Resources/phoneme-labels.json \
        Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
git commit -m "mlx: bundle wav2vec2-phoneme.mlmodelc + phoneme-labels.json via Git LFS"
git push -u origin followup/engine-b-real-model
gh pr create --title "mlx: bundle real wav2vec2 CoreML model via Git LFS" --body ...
```

**Verification gauntlet** before pushing:
- `(cd Packages/MoraMLX && swift test)` — all 3 tests PASS, none skipped (placeholder detection returns false because `phoneme-labels.json` now has ~390 entries).
- `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` — clean.
- `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` — BUILD SUCCEEDED.
- `(cd Packages/MoraCore && swift test) && (cd Packages/MoraEngines && swift test) && (cd Packages/MoraUI && swift test) && (cd Packages/MoraTesting && swift test)` — all green (no regressions from the bundle).

Commit the LFS artifacts in one commit. Update the progress table in `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` to mark Task 22 as **landed** (replace the "deferred" row with the commit SHA).

### 2. Create the real `short-sh-clip.wav` fixture (Task 26)

The smoke test `CoreMLPhonemePosteriorProviderSmokeTests.testPosteriorHasFramesAndPhonemes` currently XCTSkips on fixture-missing. Once the real model is bundled, generate a small /ʃ/-like clip and drop it at `Packages/MoraMLX/Tests/MoraMLXTests/Fixtures/short-sh-clip.wav`.

Options (pick one — content doesn't matter, only that it's valid 16 kHz mono PCM):

```sh
# Option A: sox (install via `brew install sox`)
sox -r 16000 -c 1 -n \
    Packages/MoraMLX/Tests/MoraMLXTests/Fixtures/short-sh-clip.wav \
    synth 1.0 pinknoise band -n 4000 1500 vol 0.3
```

Option B: record yourself saying "ship" into QuickTime / Voice Memos, export as 16 kHz mono WAV, trim to ~1 sec.

Delete the `Fixtures/README.md` placeholder after adding the clip. Verify:

```sh
(cd Packages/MoraMLX && swift test --filter CoreMLPhonemePosteriorProviderSmokeTests)
# Expected: 1 test PASS (not skip), reports posterior.frameCount > 0
```

Commit: `mlx: add real short-sh-clip fixture for smoke test`.

Can go in the same PR as step 1 or a follow-up — either is fine.

### 3. Device verification on iPad Air M2 (Task 29 + completion checklist)

Once the real model is bundled:

**3a. Latency benchmark** — the plan's Task 29 ships `Mora/Benchmarks/Phase3LatencyBenchmark.swift`. On a physical iPad Air M2:

```swift
// From a debug-menu button or `MoraApp.init()` one-off hook:
Task { await Phase3LatencyBenchmark.run() }
```

Expected console output (look for p50 / p95 in Xcode's device console):

```
Phase3LatencyBenchmark: p50=XXXms p95=YYYms (budget 1000ms)
```

Success criterion: **p95 < 1000 ms**. If it exceeds, investigate:
- Is `ComputeUnit.ALL` actually using the Neural Engine? Check `MLModelConfiguration.computeUnits` in `MoraMLXModelCatalog` (currently defaults to whatever CoreML picks; may need `.cpuAndNeuralEngine` explicitly).
- Is `withTimeout` cancelling mid-inference? Bump the `timeout` in `makeShadowFactory` (`Mora/MoraApp.swift`) if needed.
- Recompile the model with `minimum_deployment_target=ct.target.iOS17` (already in `convert.py`) — confirm the shipped `.mlmodelc` has that target baked in.

**3b. End-to-end shadow logging** — run a real A-day session on the iPad Air, attempt a /ʃ/-target word (e.g. "ship"). Then check the `PronunciationTrialLog` table:

Simplest approach: add a one-off DEBUG-only print in `MoraApp` (or a Parent-Mode diagnostic screen when that lands) that runs:

```swift
let ctx = container.mainContext
let rows = try ctx.fetch(FetchDescriptor<PronunciationTrialLog>(
    sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
))
for row in rows.prefix(5) {
    print("\(row.timestamp) \(row.wordSurface) /\(row.targetPhonemeIPA)/ "
        + "A=\(row.engineAScore ?? -1) B=\(row.engineBState) "
        + "(\(row.engineBScore ?? -1)) latency=\(row.engineBLatencyMs ?? -1)ms")
}
```

Success criteria (plan's Completion Checklist):
- Rows appear in `PronunciationTrialLog` (retention cap 1000 is enforced at launch).
- `engineBState` is `completed` (not `timedOut` / `unsupported`) for supported IPA targets.
- `engineBLatencyMs` is realistic (≤ 1000 under normal load).
- No UI regression in the session flow (Engine A still drives the UI — Engine B's results should be invisible to the learner).

Not blocking for merge; log observations back into the plan's Completion Checklist as `[x]` once verified.

### 4. Update CI to run the real model (after step 1)

Once `.mlmodelc` is on main, the CI's MoraMLX test suite should run the smoke test instead of skipping. Verify:

1. After step 1's PR is merged, open a new CI run and check `(cd Packages/MoraMLX && swift test)` output in the `Build / Test` job logs — it should report "3 tests, 0 skipped, 0 failures", not "3 skipped".
2. If CI still skips, investigate `PlaceholderDetection.isPlaceholderModelBundled()` — is `Bundle.module` resolving `phoneme-labels.json` correctly on CI? LFS might not have pulled in the file despite `lfs: true`. Check the CI log for `actions/checkout` LFS stats.

## Promotion roadmap (parent spec §6.3 — separate PR, not this follow-up)

After shadow mode collects enough data (the parent spec suggests a few weeks of real-user trials), a promotion PR flips `preferredEvaluator` from `.featureBased` to `.phonemeModel`. Plan notes already written at `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` "Handoff notes for the follow-up promotion PR (not in scope of this plan)". Key steps when the time comes:

1. Introduce `SettingsStore.preferredEvaluator: {.featureBased, .phonemeModel}` (default `.featureBased`). Read it inside `ShadowEvaluatorFactory.makeShadowFactory` to decide which evaluator is `primary` and which is `shadow`.
2. Calibrate `GOPScorer.k` and `GOPScorer.gopZero` using CSVs produced by `dev-tools/pronunciation-bench/` (see PR #41 / #42 scaffolding).
3. Promotion gates (parent spec §6.3): Spearman ρ with SpeechAce ≥ 0.80; Cohen's κ with Engine A ≥ 0.70. Measured in `pronunciation-bench/`.
4. Land the flip as a single-commit toggle so rollback is trivial.

Out of scope here — will be a separate plan file when ready.

## Completion checklist (of this follow-up)

Pre-merge gates for the real-model PR:

- [ ] `python convert.py --output-dir ../../Packages/MoraMLX/Sources/MoraMLX/Resources` succeeded; `phoneme-labels.json` has ~390 entries; `.mlmodelc/` contains `coremldata.bin` and supporting files.
- [ ] `git lfs ls-files | grep wav2vec2-phoneme` shows the model directory contents.
- [ ] `(cd Packages/MoraMLX && swift test)` — 3/3 PASS, 0 skipped.
- [ ] All other SPM suites green (`MoraCore`, `MoraEngines`, `MoraUI`, `MoraTesting`).
- [ ] `swift-format lint --strict ...` clean.
- [ ] iOS Simulator build passes.
- [ ] Source gate: `git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages` is empty.
- [ ] `short-sh-clip.wav` fixture added (optional — can be follow-up).
- [ ] Plan's progress table updated: Task 22 marked landed, Task 26 marked landed (if fixture included).
- [ ] PR opened, CI green, Copilot / human reviews addressed.

Post-merge device verification (can land in a follow-up PR — not a merge blocker):

- [ ] Run `Phase3LatencyBenchmark.run()` on iPad Air M2; record p50 / p95 in the plan's Completion Checklist.
- [ ] Complete one A-day session on device targeting /ʃ/; confirm `PronunciationTrialLog` rows land with `completed` state and realistic latencies.

## Useful pointers

- **Plan file**: `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` (Tasks 22, 26, 29, and the promotion handoff notes).
- **Conversion tool**: `dev-tools/model-conversion/README.md` + `convert.py`.
- **Placeholder detection**: `Packages/MoraMLX/Tests/MoraMLXTests/TestSupport/PlaceholderDetection.swift`.
- **Error cases**: `Packages/MoraMLX/Sources/MoraMLX/MoraMLXError.swift` — `modelNotBundled` (file missing) vs `modelLoadFailed(String)` (file present but corrupt/invalid) vs `inferenceFailed(String)` (runtime prediction error).
- **App fallback path**: `Mora/MoraApp.swift` `makeShadowFactory` — catches any `MoraMLXError`, logs at `.info` for `.modelNotBundled`, `.error` otherwise, falls back to bare Engine A.

## Memory / convention reminders

The repo's `CLAUDE.md` and `~/.claude/projects/-Users-yutaka-kondo-src-mora/memory/MEMORY.md` capture these; re-read both at session start:

- **English-only** for all checked-in artifacts (code, comments, commits, PR bodies, issues). Conversations can be Japanese.
- **Co-author attribution allowed** in mora commits (`Co-Authored-By: Claude <noreply@anthropic.com>`) and PR bodies (`🤖 Generated with [Claude Code]`). This is an explicit opt-in via the repo's `CLAUDE.md`.
- **xcodegen team injection** — before `xcodegen generate`, inject `DEVELOPMENT_TEAM: 7BT28X9TQ9` into `project.yml`, then immediately revert (`git checkout -- project.yml`). The team ID stays out of git.
- **Swift 6 language mode pin** — every SPM `Package.swift` at tools-version 6.0 must pin `.swiftLanguageMode(.v5)` on every target and testTarget. Without it, CI's Xcode 16 trips strict concurrency on SwiftData / CoreML types.
