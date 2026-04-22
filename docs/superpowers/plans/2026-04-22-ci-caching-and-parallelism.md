# CI Caching & Parallelism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce CI wall time on `.github/workflows/ci.yml` by (1) parallelizing independent jobs, (2) caching Homebrew tooling, (3) caching SwiftPM `.build` dirs for `swift test`, and (4) caching Xcode `DerivedData` + SPM clones for `xcodebuild build`. Target: keep every job green; measurable speedup on PRs that touch only a subset of sources.

**Architecture:** All changes land in a single file, `.github/workflows/ci.yml`. No code changes. Four existing jobs (`lint`, `build-test`, `changes`, `bench-build`) are kept, but `build-test` and `bench-build` stop depending on `lint` (they run in parallel). Each macOS job gains cache steps before its install/build steps. Cache keys combine OS + tool version (for Homebrew) or content hashes (`hashFiles('**/Package.swift')`, `hashFiles('project.yml')`, `hashFiles('Mora/**/*.swift')`) with prefix-only `restore-keys` so near-miss PRs still restore the closest cache and let incremental compilation fill in the delta. The `bench-build` job gets the largest win because its MLX / HuggingFace / swift-transformers packages are heavy to resolve + build from scratch.

**Tech Stack:** GitHub Actions `macos-15` + `ubuntu-latest` runners, `actions/cache@v4`, `actions/checkout@v4`, Homebrew, XcodeGen, `xcodebuild`, `swift test`. No new actions marketplace dependencies beyond `actions/cache@v4` (already GitHub-owned).

**Reference files:**
- `.github/workflows/ci.yml` — the only file we modify
- `CLAUDE.md` — "Build & test commands" section (CI must stay equivalent to the documented local invocation)
- `project.yml`, `Packages/*/Package.swift`, `bench/project.yml` — cache-key inputs (never edited here)

---

## Baseline & measurement strategy

Before changing anything, Task 1 records the current timings so later tasks can prove speedup. Tasks 2–6 (parallelism + all cache steps) are then bundled into a single commit on branch `ci/cache-and-parallelize`; Task 3 triggers a warm run (empty commit) once the seed run is green, and records cold-vs-warm timings in the Measurements table. This deviates from the original per-task commit structure to save ~150 macOS-minutes of CI wait; the detailed per-task YAML snippets below are retained as reference for what changed.

---

## File structure

Single file modified across all tasks: `.github/workflows/ci.yml`.

Each task edits specific line ranges of that file. Line numbers below are anchored to `main` at commit `ef0f039` (HEAD at plan authoring time); if `main` advances before execution, re-anchor by searching for the surrounding `name:` keys shown in each task's "Modify" pointer.

---

## Task 1: Record baseline timings

**Files:**
- Read-only: `.github/workflows/ci.yml`

This task writes no code. It captures the "before" numbers so later tasks can be compared.

- [ ] **Step 1: Create the branch**

```bash
git switch -c ci/cache-and-parallelize
```

- [ ] **Step 2: Identify the most recent green CI run on `main`**

Run:

```bash
gh run list --workflow=ci.yml --branch=main --status=success --limit=5
```

Pick the most recent successful run ID (first row in the output) — call it `$RUN_ID`.

- [ ] **Step 3: Dump per-job timings**

Run:

```bash
gh run view "$RUN_ID" --json jobs \
  --jq '.jobs[] | {name, conclusion, startedAt, completedAt}'
```

Read each job's `startedAt` → `completedAt` and compute wall-time minutes per job. Expected jobs: `swift-format`, `Build / Test`, `Changes`, and either a skipped or run `Bench Build / Test`.

- [ ] **Step 4: Fill in the baseline row of the Measurements table**

Edit this file's **Measurements** section at the bottom. In the row labelled "Task 1 (baseline)", fill in per-job minutes. Leave every other row empty — later tasks populate them.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-04-22-ci-caching-and-parallelism.md
git commit -m "docs(ci): record baseline CI timings before caching work"
```

---

## Task 2: Run lint, build-test, and bench-build in parallel

**Files:**
- Modify: `.github/workflows/ci.yml` — `build-test` and `bench-build` job `needs:` keys

Rationale: `lint` finishes in ~1–2 minutes and is independent of the build. Gating `build-test` (and `bench-build`) on it serializes two long jobs behind a short one for no real benefit — lint failures are surfaced in the same PR checks list either way. The `Changes` job remains a dependency of `bench-build` because its output (`bench` boolean) decides whether bench-build runs at all.

- [ ] **Step 1: Read the current file to anchor the edit**

Open `.github/workflows/ci.yml` and confirm these lines still exist:

```yaml
  build-test:
    name: Build / Test
    needs: lint
    runs-on: macos-15
```

and

```yaml
  bench-build:
    name: Bench Build / Test
    needs: [lint, changes]
    if: ${{ needs.changes.outputs.bench == 'true' || github.event_name == 'workflow_dispatch' }}
```

- [ ] **Step 2: Remove `lint` from `build-test.needs`**

Change:

```yaml
  build-test:
    name: Build / Test
    needs: lint
    runs-on: macos-15
    timeout-minutes: 30
```

to:

```yaml
  build-test:
    name: Build / Test
    runs-on: macos-15
    timeout-minutes: 30
```

- [ ] **Step 3: Remove `lint` from `bench-build.needs` (keep `changes`)**

Change:

```yaml
  bench-build:
    name: Bench Build / Test
    needs: [lint, changes]
```

to:

```yaml
  bench-build:
    name: Bench Build / Test
    needs: changes
```

- [ ] **Step 4: Lint the workflow YAML**

Run:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML parses OK"
```

Expected output: `YAML parses OK`. If `actionlint` is installed locally (optional; `brew install actionlint`), also run `actionlint .github/workflows/ci.yml` — expect zero findings.

- [ ] **Step 5: Commit & push**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: run lint in parallel with build-test and bench-build"
git push -u origin ci/cache-and-parallelize
```

- [ ] **Step 6: Open the PR**

```bash
gh pr create --title "ci: cache and parallelize" --base main --body "$(cat <<'EOF'
Speeds up CI by running independent jobs in parallel and caching Homebrew, SwiftPM, and Xcode DerivedData. See docs/superpowers/plans/2026-04-22-ci-caching-and-parallelism.md for the per-task breakdown and measurement table.
EOF
)"
```

- [ ] **Step 7: Wait for the CI run to complete, then record timings**

```bash
gh pr checks --watch
gh run view "$(gh run list --branch=ci/cache-and-parallelize --limit=1 --json databaseId --jq '.[0].databaseId')" \
  --json jobs --jq '.jobs[] | {name, conclusion, startedAt, completedAt}'
```

Fill in the "Task 2 (parallel jobs)" row of the Measurements table. Expected: `Build / Test` starts at roughly the same time as `swift-format` (no longer waits). Total workflow wall time = max(lint, build-test) instead of lint+build-test.

If `build-test` is still green, proceed. If it fails for a reason unrelated to parallelism, revert and debug before Task 3.

---

## Task 3: Cache Homebrew formulae (`swift-format`, `xcodegen`)

**Files:**
- Modify: `.github/workflows/ci.yml` — `lint` job (add cache step), `build-test` job (add cache step), `bench-build` job (add cache step)

Rationale: `brew install swift-format` and `brew install xcodegen` each take 30–90s on a cold runner. Caching Homebrew's download cache makes the install a no-op bottle pour after the first successful run per week/month.

We cache `~/Library/Caches/Homebrew/downloads` (the bottle tarballs) keyed on the formula name + a manually-bumped cache version. We do NOT cache `/opt/homebrew/Cellar` itself because that creates symlink drift with the runner image's pre-installed tools.

- [ ] **Step 1: Insert the Homebrew cache step in the `lint` job**

Find this block in `.github/workflows/ci.yml`:

```yaml
      - uses: actions/checkout@v4

      - name: Install swift-format
        env:
          HOMEBREW_NO_AUTO_UPDATE: "1"
          HOMEBREW_NO_INSTALL_CLEANUP: "1"
        run: brew install swift-format
```

Replace with:

```yaml
      - uses: actions/checkout@v4

      - name: Cache Homebrew downloads (swift-format)
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/Homebrew/downloads
          key: brew-${{ runner.os }}-swift-format-v1
          restore-keys: |
            brew-${{ runner.os }}-swift-format-

      - name: Install swift-format
        env:
          HOMEBREW_NO_AUTO_UPDATE: "1"
          HOMEBREW_NO_INSTALL_CLEANUP: "1"
        run: brew install swift-format
```

- [ ] **Step 2: Insert the Homebrew cache step in the `build-test` job**

Find this block:

```yaml
      - uses: actions/checkout@v4

      - name: Install xcodegen
        env:
          HOMEBREW_NO_AUTO_UPDATE: "1"
          HOMEBREW_NO_INSTALL_CLEANUP: "1"
        run: brew install xcodegen
```

Replace with:

```yaml
      - uses: actions/checkout@v4

      - name: Cache Homebrew downloads (xcodegen)
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/Homebrew/downloads
          key: brew-${{ runner.os }}-xcodegen-v1
          restore-keys: |
            brew-${{ runner.os }}-xcodegen-

      - name: Install xcodegen
        env:
          HOMEBREW_NO_AUTO_UPDATE: "1"
          HOMEBREW_NO_INSTALL_CLEANUP: "1"
        run: brew install xcodegen
```

- [ ] **Step 3: Insert the same Homebrew cache step in the `bench-build` job**

Find this block (inside `bench-build:`):

```yaml
      - uses: actions/checkout@v4

      - name: Install xcodegen
        env:
          HOMEBREW_NO_AUTO_UPDATE: "1"
          HOMEBREW_NO_INSTALL_CLEANUP: "1"
        run: brew install xcodegen
```

Replace with:

```yaml
      - uses: actions/checkout@v4

      - name: Cache Homebrew downloads (xcodegen)
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/Homebrew/downloads
          key: brew-${{ runner.os }}-xcodegen-v1
          restore-keys: |
            brew-${{ runner.os }}-xcodegen-

      - name: Install xcodegen
        env:
          HOMEBREW_NO_AUTO_UPDATE: "1"
          HOMEBREW_NO_INSTALL_CLEANUP: "1"
        run: brew install xcodegen
```

Note: `build-test` and `bench-build` intentionally share the same cache key (`brew-${{ runner.os }}-xcodegen-v1`) — both jobs need the same xcodegen bottle and sharing lets the second job pull what the first job uploaded in the same run.

- [ ] **Step 4: Lint the workflow YAML**

Run:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML parses OK"
```

Expected: `YAML parses OK`.

- [ ] **Step 5: Commit & push**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: cache Homebrew bottle downloads for swift-format and xcodegen"
git push
```

- [ ] **Step 6: Verify the cache behavior**

First CI run after push = cold cache (miss). Second CI run (push any empty commit or wait for the next PR sync) = warm cache.

```bash
# Seed run
gh pr checks --watch
# Trigger a second run to exercise the cache
git commit --allow-empty -m "ci: second run to exercise Homebrew cache"
git push
gh pr checks --watch
```

In the warm run, expand each "Install swift-format" / "Install xcodegen" step in the UI and confirm the line `Pouring <formula>-<version>.bottle.tar.gz` appears *without* a preceding download log line. Record both runs' timings in the "Task 3" row of the Measurements table.

---

## Task 4: Cache SwiftPM `.build` for package tests

**Files:**
- Modify: `.github/workflows/ci.yml` — `build-test` job (add 4 cache steps before "Test SPM packages" and one before "Build MoraMLX")

Rationale: `swift test` / `swift build` does a full clean build when there's no `.build` directory. None of our five local packages have external SPM dependencies (they only reference each other by path), so the entire `.build` artifact is Swift module compilation output + linked test binaries. Caching `Packages/<pkg>/.build` lets subsequent runs do incremental compilation, which Swift 5.9 handles well.

Key design:
- Primary key includes a hash of the package's sources + its dependencies' `Package.swift` files, so any source change within the dependency graph invalidates.
- `restore-keys` fall back to a prefix-only key so near-miss runs still restore the closest `.build` and only recompile changed modules.

Dependency graph (from inspection of each `Package.swift`):
- `MoraCore` → no deps
- `MoraEngines` → `MoraCore`
- `MoraUI` → `MoraCore`, `MoraEngines`
- `MoraTesting` → `MoraCore`, `MoraEngines`
- `MoraMLX` → no deps

- [ ] **Step 1: Add a cache step before "Test SPM packages" covering all four tested packages**

Find this block in `.github/workflows/ci.yml`:

```yaml
      - name: Test SPM packages
        run: |
          set -e
          for pkg in MoraCore MoraEngines MoraUI MoraTesting; do
            echo "::group::swift test — $pkg"
            (cd Packages/$pkg && swift test)
            echo "::endgroup::"
          done
```

Insert this block **immediately before** it:

```yaml
      - name: Cache SwiftPM .build (MoraCore)
        uses: actions/cache@v4
        with:
          path: Packages/MoraCore/.build
          key: spm-MoraCore-${{ runner.os }}-${{ hashFiles('Packages/MoraCore/**/*.swift', 'Packages/MoraCore/Package.swift') }}
          restore-keys: |
            spm-MoraCore-${{ runner.os }}-

      - name: Cache SwiftPM .build (MoraEngines)
        uses: actions/cache@v4
        with:
          path: Packages/MoraEngines/.build
          key: spm-MoraEngines-${{ runner.os }}-${{ hashFiles('Packages/MoraCore/**/*.swift', 'Packages/MoraCore/Package.swift', 'Packages/MoraEngines/**/*.swift', 'Packages/MoraEngines/Package.swift') }}
          restore-keys: |
            spm-MoraEngines-${{ runner.os }}-

      - name: Cache SwiftPM .build (MoraUI)
        uses: actions/cache@v4
        with:
          path: Packages/MoraUI/.build
          key: spm-MoraUI-${{ runner.os }}-${{ hashFiles('Packages/MoraCore/**/*.swift', 'Packages/MoraCore/Package.swift', 'Packages/MoraEngines/**/*.swift', 'Packages/MoraEngines/Package.swift', 'Packages/MoraUI/**/*.swift', 'Packages/MoraUI/Package.swift') }}
          restore-keys: |
            spm-MoraUI-${{ runner.os }}-

      - name: Cache SwiftPM .build (MoraTesting)
        uses: actions/cache@v4
        with:
          path: Packages/MoraTesting/.build
          key: spm-MoraTesting-${{ runner.os }}-${{ hashFiles('Packages/MoraCore/**/*.swift', 'Packages/MoraCore/Package.swift', 'Packages/MoraEngines/**/*.swift', 'Packages/MoraEngines/Package.swift', 'Packages/MoraTesting/**/*.swift', 'Packages/MoraTesting/Package.swift') }}
          restore-keys: |
            spm-MoraTesting-${{ runner.os }}-
```

- [ ] **Step 2: Add a cache step before "Build MoraMLX"**

Find this block:

```yaml
      - name: Build MoraMLX (no test target)
        run: |
          echo "::group::swift build — MoraMLX"
          (cd Packages/MoraMLX && swift build)
          echo "::endgroup::"
```

Insert **immediately before** it:

```yaml
      - name: Cache SwiftPM .build (MoraMLX)
        uses: actions/cache@v4
        with:
          path: Packages/MoraMLX/.build
          key: spm-MoraMLX-${{ runner.os }}-${{ hashFiles('Packages/MoraMLX/**/*.swift', 'Packages/MoraMLX/Package.swift') }}
          restore-keys: |
            spm-MoraMLX-${{ runner.os }}-
```

- [ ] **Step 3: Lint the workflow YAML**

Run:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML parses OK"
```

Expected: `YAML parses OK`.

- [ ] **Step 4: Commit & push (seed run)**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: cache SwiftPM .build for each package"
git push
gh pr checks --watch
```

First run: caches miss and seed. `swift test` still does a full build, but the `.build` directory is uploaded at job-end.

- [ ] **Step 5: Trigger a warm run and measure**

```bash
git commit --allow-empty -m "ci: second run to exercise SwiftPM cache"
git push
gh pr checks --watch
```

Expand the `swift test — MoraCore` step in the warm run and look for lines like `Build complete!` coming quickly after a few `Compiling` lines (instead of hundreds). Fill in the "Task 4" row of the Measurements table.

- [ ] **Step 6: Verify cache invalidation works**

Touch a single Swift file in MoraCore to change its hash, push, and confirm: (1) `Cache SwiftPM .build (MoraCore)` step logs a cache miss on the primary key but a hit on the restore-key prefix (partial restore), and (2) `swift test — MoraCore` only recompiles the changed module.

```bash
# Make a trivial whitespace change that changes the file hash but not behavior
# (Pick any file under Packages/MoraCore/Sources — example: append a newline)
printf "\n" >> Packages/MoraCore/Sources/MoraCore/$(ls Packages/MoraCore/Sources/MoraCore | head -1)
git add -A
git commit -m "ci: verify SwiftPM cache restore-keys with trivial touch"
git push
gh pr checks --watch
# After confirming partial restore + incremental rebuild, revert the whitespace change:
git revert HEAD --no-edit
git push
```

Record the partial-restore timing for the "Task 4 (partial restore)" sub-row.

---

## Task 5: Cache Xcode `DerivedData` and SPM checkouts for `build-test`'s xcodebuild step

**Files:**
- Modify: `.github/workflows/ci.yml` — `build-test` job (add cache step before "Build Mora (iOS Simulator)")

Rationale: `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator'` is the slowest single step of `build-test` because it builds the app target plus all five SPM packages from scratch. Caching the Xcode-owned `DerivedData` directory (which holds compiled modules, resolved SPM checkouts, and linked binaries) turns subsequent runs into incremental builds.

Key inputs: `project.yml` (project structure), all `Package.swift` files (dependency graph), all Swift sources under `Mora/` and `Packages/*/Sources`. Resource files (`.xcassets`, etc.) are excluded from the key because their contents don't affect module compilation — asset changes that matter will still trigger resource compile steps regardless of cache.

- [ ] **Step 1: Add the DerivedData cache step before "Build Mora (iOS Simulator)"**

Find this block in `build-test`:

```yaml
      - name: Generate Xcode project
        run: xcodegen generate

      - name: Build Mora (iOS Simulator)
        run: |
          set -o pipefail
          xcodebuild build \
            -project Mora.xcodeproj \
            -scheme Mora \
            -destination 'generic/platform=iOS Simulator' \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO
```

Insert **between** "Generate Xcode project" and "Build Mora (iOS Simulator)":

```yaml
      - name: Cache Xcode DerivedData (Mora app)
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: xcode-deriveddata-mora-${{ runner.os }}-${{ hashFiles('project.yml', 'Packages/*/Package.swift', 'Mora/**/*.swift', 'Packages/*/Sources/**/*.swift') }}
          restore-keys: |
            xcode-deriveddata-mora-${{ runner.os }}-
```

- [ ] **Step 2: Lint the workflow YAML**

Run:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML parses OK"
```

Expected: `YAML parses OK`.

- [ ] **Step 3: Commit & push (seed run)**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: cache Xcode DerivedData for Mora app build"
git push
gh pr checks --watch
```

Note: GitHub Actions caches have a 10 GB per-repo quota. `DerivedData` for this project is a few hundred MB at most — well under the limit. If future growth becomes a concern, switch the `path:` to specific subdirs (`Build/Products`, `ModuleCache.noindex`, `SourcePackages`) rather than the whole dir.

- [ ] **Step 4: Trigger a warm run and measure**

```bash
git commit --allow-empty -m "ci: second run to exercise DerivedData cache"
git push
gh pr checks --watch
```

Expand "Build Mora (iOS Simulator)" in the warm run. Expect the `xcodebuild` log to show far fewer `CompileSwift` lines than the cold run (only touched modules recompile). Record timings in the "Task 5" row.

---

## Task 6: Cache Xcode `DerivedData` + SPM checkouts for `bench-build`

**Files:**
- Modify: `.github/workflows/ci.yml` — `bench-build` job (add cache step before "Build MoraBench (iOS Simulator)")

Rationale: This is the biggest single win. `bench/project.yml` pulls three external SPM packages that are *massive* to clone + resolve + compile:

- `mlx-swift-lm` (from 3.31.3) — transitively pulls `mlx-swift`, which itself pulls Metal shaders + MLX C++ core
- `swift-huggingface` (from 0.9.0)
- `swift-transformers` (from 1.3.0)

Fresh `xcodebuild` on `bench` spends the majority of its wall time resolving + building these. They only change when `bench/project.yml` pins are bumped, so a content-hash key is almost always a hit.

We also cache across the two destinations (iOS Simulator + Mac Catalyst + Test) because they share a single `DerivedData` directory — the second and third `xcodebuild` invocations within the same job already benefit from the first one's output, but the cache makes the *first* invocation fast too.

- [ ] **Step 1: Add the DerivedData cache step in the `bench-build` job**

Find this block in `bench-build`:

```yaml
      - name: Generate bench project
        working-directory: bench
        run: xcodegen generate

      - name: Build MoraBench (iOS Simulator)
        working-directory: bench
        run: |
          set -o pipefail
          xcodebuild build \
            -project 'Mora Bench.xcodeproj' \
            -scheme MoraBench \
            -destination 'generic/platform=iOS Simulator' \
            -configuration Debug \
            -skipMacroValidation \
            CODE_SIGNING_ALLOWED=NO
```

Insert **between** "Generate bench project" and "Build MoraBench (iOS Simulator)":

```yaml
      - name: Cache Xcode DerivedData (bench)
        uses: actions/cache@v4
        with:
          path: ~/Library/Developer/Xcode/DerivedData
          key: xcode-deriveddata-bench-${{ runner.os }}-${{ hashFiles('bench/project.yml', 'bench/MoraBench/**/*.swift', 'bench/MoraBenchTests/**/*.swift') }}
          restore-keys: |
            xcode-deriveddata-bench-${{ runner.os }}-
```

The key deliberately depends on `bench/project.yml` because that's where the external SPM pins live — when a pin is bumped, the cache invalidates and a fresh SPM resolve runs. Source-only changes fall through to the restore-key and reuse the heavy dependency builds.

- [ ] **Step 2: Lint the workflow YAML**

Run:

```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML parses OK"
```

Expected: `YAML parses OK`.

- [ ] **Step 3: Trigger a `bench-build` run**

`bench-build` only runs when `bench/**` or `.github/workflows/ci.yml` changes. This commit changes `ci.yml`, so it will run.

```bash
git add .github/workflows/ci.yml
git commit -m "ci: cache Xcode DerivedData and SPM checkouts for bench build"
git push
gh pr checks --watch
```

First run: cold cache, seeds DerivedData upload at job-end.

- [ ] **Step 4: Trigger a warm run and measure the big win**

```bash
git commit --allow-empty -m "ci: second run to exercise bench DerivedData cache"
git push
gh pr checks --watch
```

Expand "Build MoraBench (iOS Simulator)" in the warm run. Expect the "Resolving package graph" and "Fetching …" lines for MLX / HF / Transformers to be absent or near-instant. Record timings in the "Task 6" row.

---

## Task 7: Validate + tune, merge

**Files:**
- Modify: `docs/superpowers/plans/2026-04-22-ci-caching-and-parallelism.md` — fill out final Measurements table + "Summary" section

- [ ] **Step 1: Confirm all PR checks are green**

```bash
gh pr checks
```

Every check must be `pass`. If a cache step is logging `Cache not found for key: …` on the *second* run of the same key, investigate before merging — likely the `path:` doesn't exist at save time (e.g. `DerivedData` not created because xcodebuild never ran). Fix the path and re-push.

- [ ] **Step 2: Run one more "typical PR" simulation**

Open a trivial edit on the PR branch that mirrors a realistic PR — e.g., change one line in `Packages/MoraUI/Sources/MoraUI/` — and push. Watch the run:

```bash
# Pick any file in MoraUI/Sources/MoraUI and add a harmless comment line
FILE=$(find Packages/MoraUI/Sources -name "*.swift" | head -1)
printf "\n// ci-cache validation touch\n" >> "$FILE"
git add "$FILE"
git commit -m "ci: validate cache behavior with a typical source touch"
git push
gh pr checks --watch
# After confirming timings, revert:
git revert HEAD --no-edit
git push
```

Expect `Build / Test` to finish noticeably faster than the Task 1 baseline. Record in "Task 7 (typical PR)" row.

- [ ] **Step 3: Fill out the Summary section below**

In this file, update the **Summary** section with:
- Baseline `Build / Test` wall time (from Task 1)
- Warm-cache `Build / Test` wall time (from Task 7)
- Baseline `Bench Build / Test` wall time (from Task 1 if bench-build ran, else note "N/A")
- Warm-cache `Bench Build / Test` wall time (from Task 6)

- [ ] **Step 4: Commit the final measurements**

```bash
git add docs/superpowers/plans/2026-04-22-ci-caching-and-parallelism.md
git commit -m "docs(ci): record post-caching CI timings"
git push
```

- [ ] **Step 5: Merge**

```bash
gh pr merge --squash --delete-branch
```

---

## Measurements

Fill this in as tasks execute. Times are wall-clock minutes (Started → Completed) per job, from `gh run view --json jobs`.

| Task / scenario | `swift-format` | `Build / Test` | `Bench Build / Test` | Notes |
|---|---|---|---|---|
| Baseline (main, no bench changes) | 0.3 | 3.9 | skipped | Run ID: 24794759855 |
| Baseline (historical, bench ran) | 0.3 | 3.0 | 14.1 | Run ID: 24765928314 (PR #15) |
| Bundle, cold cache | 0.4 | 5.8 | 17.0 | Run ID: 24795735049 (PR #29 seed run; cache saves add ~1 min overhead on miss) |
| Bundle, warm cache | | | | |
| Typical PR (MoraUI single-file touch) | | | | partial restore |

## Summary

Fill in after Task 7:

- `Build / Test`: **X** min (baseline) → **Y** min (warm, typical PR) — **Z%** faster
- `Bench Build / Test`: **X** min (baseline) → **Y** min (warm) — **Z%** faster
- `swift-format`: **X** min (baseline) → **Y** min (warm) — **Z%** faster
- Lint no longer gates build-test; total workflow wall time reduced by max(lint) per run.

---

## Out of scope (YAGNI)

The following optimizations were considered but rejected for this plan. Document-only — do not implement unless measurements after Task 7 show remaining pain.

- **Matrix-parallelize per-package `swift test`.** Would split the four packages into four concurrent `macos-15` runners. Saves wall time but multiplies runner-minute cost by ~4× and each runner pays ~30s startup overhead. Revisit only if `Build / Test` is still the workflow bottleneck after Task 7.
- **Replace `brew install` with a pre-built `swift-format` download from the upstream release.** More brittle (URL/tag drift) for a ~30s saving that Task 3 mostly already captures.
- **`irgaly/xcode-cache@v1` marketplace action.** It's a thin wrapper around `actions/cache` with more opinionated defaults. Our hand-rolled cache steps are explicit and audit-friendly; switching to a third-party action for modest ergonomics isn't a fair trade.
- **Split `build-test` into `build` + `test` jobs that share cache.** Adds a second macOS runner's startup overhead. The in-job caching from Tasks 4–5 already gives us the incremental-build win without that cost.
- **Path-filter `build-test` to skip when only docs change.** The current workflow always runs on every push to PR branches; skipping doc-only PRs is a future enhancement that needs careful filter design to avoid hiding real regressions.
