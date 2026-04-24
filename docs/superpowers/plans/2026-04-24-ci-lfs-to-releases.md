# CI: LFS → GitHub Releases Migration Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the wav2vec2-phoneme CoreML model off Git LFS to a GitHub Release asset, drop all `.gitattributes` LFS rules, and bootstrap the model into CI / Xcode / developer machines via an idempotent shell script — eliminating LFS bandwidth + storage as a CI bottleneck.

**Architecture:** A small bash bootstrap script (`tools/fetch-models.sh`) reads a manifest (`tools/models.manifest`) and downloads release assets to known on-disk locations, SHA-256 verifying. CI replaces every `lfs: true` checkout with `lfs: false` and adds a per-job `actions/cache` keyed on the manifest hash so model download bandwidth stays at zero on cache hits. The Mora Xcode app target gains a Run Script Build Phase that calls the same script, so a clean clone needs only `bash tools/fetch-models.sh && xcodegen generate` to build.

**Tech Stack:** bash, GitHub Actions, GitHub Releases CLI (`gh`), `actions/cache@v4`, `actions/checkout@v4`, XcodeGen, Swift Package Manager.

**Spec:** `docs/superpowers/specs/2026-04-24-ci-lfs-to-releases-design.md`.

**Branch:** `ci-lfs-to-releases` (already created off `main`, with the spec commit on top).

---

## File Structure

### New files

```
tools/
  fetch-models.sh             # idempotent bash bootstrap (Task 2)
  models.manifest             # space-separated: dest tag asset sha256 (Task 2)
```

### Modified files

```
.github/workflows/ci.yml      # all jobs lfs:false + cache + fetch (Task 5)
project.yml                   # add Run Script Build Phase to Mora target (Task 6)
README.md                     # add "First-time setup" section (Task 7)
```

### Deleted files

```
.gitattributes                                                      # Task 4
Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc # Task 3 (re-materialized by script)
```

---

## Task 1: Create the GitHub Release with the model tarball

**Files:** none on disk yet. This task creates a GitHub Release asset that future tasks consume.

**Pre-requisite:** the local working tree already has the materialized model directory at `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/` (it does — `git lfs ls-files` shows the bundle is checked out).

- [ ] **Step 1: Tar and gzip the existing local model directory**

```sh
cd Packages/MoraMLX/Sources/MoraMLX/Resources
tar czf /tmp/wav2vec2-phoneme.mlmodelc.tar.gz wav2vec2-phoneme.mlmodelc
ls -lh /tmp/wav2vec2-phoneme.mlmodelc.tar.gz
```
Expected: file is ≈ 261 MB.

- [ ] **Step 2: Compute the SHA-256 and save it for use in Task 2**

```sh
shasum -a 256 /tmp/wav2vec2-phoneme.mlmodelc.tar.gz | tee /tmp/wav2vec2-phoneme.mlmodelc.tar.gz.sha256
# Format the sidecar to match `gh release upload` convention (sha + two spaces + filename):
sed -i '' 's| .*| wav2vec2-phoneme.mlmodelc.tar.gz|' /tmp/wav2vec2-phoneme.mlmodelc.tar.gz.sha256
cat /tmp/wav2vec2-phoneme.mlmodelc.tar.gz.sha256
```
Expected output looks like: `<64 hex chars>  wav2vec2-phoneme.mlmodelc.tar.gz`. Note the SHA — it goes into the manifest in Task 2.

- [ ] **Step 3: Create the release**

```sh
gh release create models/wav2vec2-phoneme-int8-v1 \
  /tmp/wav2vec2-phoneme.mlmodelc.tar.gz \
  /tmp/wav2vec2-phoneme.mlmodelc.tar.gz.sha256 \
  --title "wav2vec2 phoneme INT8 v1" \
  --notes "INT8-quantized wav2vec2-phoneme CoreML model. Bundled at runtime via tools/fetch-models.sh.

  Source: https://huggingface.co/bookbot/wav2vec2-ljspeech-gruut (subset, INT8 export).

  Schema: tar.gz of the .mlmodelc directory. SHA-256 in the .sha256 sidecar."
```
Expected: `https://github.com/youtalk/mora/releases/tag/models/wav2vec2-phoneme-int8-v1`.

- [ ] **Step 4: Verify the asset is downloadable**

```sh
mkdir -p /tmp/release-verify && cd /tmp/release-verify
gh release download models/wav2vec2-phoneme-int8-v1 -p 'wav2vec2-phoneme.mlmodelc.tar.gz'
shasum -a 256 -c <(printf '%s  wav2vec2-phoneme.mlmodelc.tar.gz\n' "$(awk '{print $1}' /tmp/wav2vec2-phoneme.mlmodelc.tar.gz.sha256)")
```
Expected: `wav2vec2-phoneme.mlmodelc.tar.gz: OK`.

- [ ] **Step 5: Cleanup tmp scratch**

```sh
rm -rf /tmp/release-verify /tmp/wav2vec2-phoneme.mlmodelc.tar.gz /tmp/wav2vec2-phoneme.mlmodelc.tar.gz.sha256
```

(No commit yet — release lives on GitHub. The SHA captured in Step 2 carries into Task 2.)

---

## Task 2: Add `tools/fetch-models.sh` and `tools/models.manifest`

**Files:**
- Create: `tools/fetch-models.sh`
- Create: `tools/models.manifest`

The manifest is space-separated columns. Comments and blank lines ignored. One row per managed artifact.

- [ ] **Step 1: Write `tools/models.manifest`**

```text
# fetch-models.sh manifest. Columns:
#   <destination_path>  <release_tag>  <asset_filename>  <sha256>
# destination_path is the directory the asset extracts INTO (parent of the bundle).
# When present and SHA-matching, the entry is skipped.
Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc models/wav2vec2-phoneme-int8-v1 wav2vec2-phoneme.mlmodelc.tar.gz <PASTE_SHA_FROM_TASK_1_STEP_2>
```

- [ ] **Step 2: Write `tools/fetch-models.sh`**

```bash
#!/usr/bin/env bash
# tools/fetch-models.sh — idempotent CoreML model bootstrap.
#
# Reads tools/models.manifest and ensures every listed bundle is present on
# disk and matches its expected SHA-256. Re-running is cheap: present bundles
# are SHA-checked and skipped without network. Missing or mismatched bundles
# are downloaded from the GitHub Release named in the manifest, extracted in
# place, and SHA-verified.
#
# Used by:
#   - CI (.github/workflows/ci.yml) before swift build / xcodebuild.
#   - Xcode (Run Script Build Phase on the Mora app target) before sources compile.
#   - Developers, once after `git clone`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$REPO_ROOT/tools/models.manifest"
REPO_SLUG="youtalk/mora"

if [[ ! -f "$MANIFEST" ]]; then
  echo "fetch-models: manifest not found at $MANIFEST" >&2
  exit 1
fi

# Compute SHA-256 of a tar.gz built from a directory using the same recipe
# used to upload to the release: parent-relative `tar czf - <basename>`.
hash_dir_as_tarball() {
  local dir="$1"
  local parent base
  parent="$(dirname "$dir")"
  base="$(basename "$dir")"
  if [[ ! -d "$dir" ]]; then
    echo "missing"
    return
  fi
  ( cd "$parent" && tar czf - "$base" ) | shasum -a 256 | awk '{print $1}'
}

# Download via gh if available (works in CI with GITHUB_TOKEN, gives clearer
# errors and rate-limit headroom); fall back to anonymous HTTPS for dev
# machines without gh installed.
download_asset() {
  local tag="$1" asset="$2" out="$3"
  if command -v gh >/dev/null 2>&1; then
    gh release download "$tag" --repo "$REPO_SLUG" --pattern "$asset" --output "$out" --clobber
  else
    curl --fail --location --silent --show-error \
      --output "$out" \
      "https://github.com/$REPO_SLUG/releases/download/$tag/$asset"
  fi
}

verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "fetch-models: SHA mismatch for $file" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
}

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip blanks and comments.
  [[ -z "${line// /}" ]] && continue
  [[ "$line" =~ ^# ]] && continue

  read -r dest tag asset expected_sha <<<"$line"
  abs_dest="$REPO_ROOT/$dest"
  parent_dir="$(dirname "$abs_dest")"

  current_sha="$(hash_dir_as_tarball "$abs_dest")"
  if [[ "$current_sha" == "$expected_sha" ]]; then
    echo "fetch-models: $dest is up to date"
    continue
  fi

  echo "fetch-models: fetching $asset from $tag"
  mkdir -p "$parent_dir"
  tmp_asset="$(mktemp -t fetch-models.XXXXXX.tar.gz)"
  trap 'rm -f "$tmp_asset"' EXIT

  download_asset "$tag" "$asset" "$tmp_asset"
  verify_sha256 "$tmp_asset" "$expected_sha"
  rm -rf "$abs_dest"
  tar xzf "$tmp_asset" -C "$parent_dir"
  rm -f "$tmp_asset"
  trap - EXIT

  refreshed_sha="$(hash_dir_as_tarball "$abs_dest")"
  if [[ "$refreshed_sha" != "$expected_sha" ]]; then
    echo "fetch-models: post-extract SHA mismatch for $dest" >&2
    echo "  expected: $expected_sha" >&2
    echo "  actual:   $refreshed_sha" >&2
    exit 1
  fi
  echo "fetch-models: $dest installed"
done < "$MANIFEST"
```

- [ ] **Step 3: Make the script executable**

```sh
chmod +x tools/fetch-models.sh
```

- [ ] **Step 4: Run it once — should be a no-op because the dir already exists with matching SHA**

```sh
bash tools/fetch-models.sh
```
Expected: `fetch-models: Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc is up to date`.

- [ ] **Step 5: Force a re-fetch by removing the local dir**

```sh
rm -rf Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
bash tools/fetch-models.sh
```
Expected: prints `fetching ...` then `installed`. No error. Directory is back.

- [ ] **Step 6: Confirm the rebuilt directory is build-clean**

```sh
(cd Packages/MoraMLX && swift build)
```
Expected: `Build complete!`.

- [ ] **Step 7: Commit**

```sh
git add tools/fetch-models.sh tools/models.manifest
git commit -m "tools: add fetch-models.sh + manifest for GitHub-Release-hosted CoreML models

Idempotent bash bootstrap that reads tools/models.manifest and ensures every
listed model bundle is present on disk with the expected SHA-256. Re-runs
are sub-second when nothing changed. Used by CI, Xcode build phase, and
developer first-time setup. See spec docs/superpowers/specs/2026-04-24-ci-lfs-to-releases-design.md.
"
```

---

## Task 3: Remove the LFS-tracked model from Git

**Files:**
- Delete from index: `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/**`
- Working tree: re-materialized by `tools/fetch-models.sh` after the rm.

- [ ] **Step 1: Confirm the LFS objects we're about to detach**

```sh
git lfs ls-files
```
Expected output lists the five `wav2vec2-phoneme.mlmodelc/...` files. (No yokai files yet — they'll never enter LFS because we'll remove the rules in Task 4 before any are committed.)

- [ ] **Step 2: Remove the directory from the index**

```sh
git rm -r --cached Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
```
Expected: 5 paths printed as `rm`'d. (`--cached` keeps the working tree intact.)

- [ ] **Step 3: Stage the deletion and verify the working tree still has the materialized files**

```sh
git status
ls Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/
```
Expected: 5 deleted entries staged; working-tree directory still populated (the files are now untracked).

- [ ] **Step 4: Re-add the working tree as a normal `.gitignore` entry so we never accidentally re-commit it**

Edit `.gitignore` (create if needed) to append:

```text
# Materialized by tools/fetch-models.sh — see tools/models.manifest.
Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/
```

- [ ] **Step 5: Confirm the dir is now ignored**

```sh
git status --ignored Packages/MoraMLX/Sources/MoraMLX/Resources/
```
Expected: the `wav2vec2-phoneme.mlmodelc/` directory shows under `Ignored files:`.

- [ ] **Step 6: Verify the build still works (script-materialized files, ignored by Git, present on disk)**

```sh
(cd Packages/MoraMLX && swift build)
```
Expected: `Build complete!`.

- [ ] **Step 7: Commit**

```sh
git add -A .gitignore Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
git commit -m "lfs: remove wav2vec2-phoneme.mlmodelc from index; provided by fetch-models.sh

The bundle is now a GitHub Release asset (tag models/wav2vec2-phoneme-int8-v1)
fetched into Packages/MoraMLX/.../Resources/ by tools/fetch-models.sh. The
directory is gitignored to prevent accidental re-commits. Past commits keep
their LFS pointers — history rewrite is deferred (see spec §10).
"
```

---

## Task 4: Drop `.gitattributes`

**Files:**
- Delete: `.gitattributes`

- [ ] **Step 1: Confirm current contents are LFS-only**

```sh
cat .gitattributes
```
Expected: four lines, all `filter=lfs diff=lfs merge=lfs -text` rules. If anything else is there, stop and ask the user.

- [ ] **Step 2: Delete the file**

```sh
git rm .gitattributes
```

- [ ] **Step 3: Confirm no LFS rules remain**

```sh
git check-attr --all -- Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/coremldata.bin
git check-attr --all -- Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/portrait.png 2>&1 || true
```
Expected: no `filter: lfs` line on either probe.

- [ ] **Step 4: Commit**

```sh
git commit -m "lfs: drop .gitattributes — no more LFS-tracked paths

wav2vec2 model is hosted on GitHub Releases (Task 3). Yokai assets will be
plain Git blobs going forward; commit-sized PNG / m4a per spec §5.5. If a
future binary ever needs special handling, a fresh .gitattributes is one
commit away.
"
```

---

## Task 5: Update `.github/workflows/ci.yml`

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Read the current workflow**

```sh
sed -n '1,60p' .github/workflows/ci.yml
```
Confirm the file structure: top-level `name: CI`, `on:` triggers, `jobs:` map containing `lint`, `build-test`, `changes`, `bench-build`, `recorder-build` (the recorder-build job presence is verified — already exists per `grep -n` in Task 0 prep).

- [ ] **Step 2: Replace every `lfs: true` with `lfs: false`**

```sh
grep -n 'lfs: true' .github/workflows/ci.yml
# expect 6 hits; flip each via your editor or:
perl -pi -e 's/lfs: true/lfs: false/g' .github/workflows/ci.yml
grep -n 'lfs: true' .github/workflows/ci.yml
# expect zero hits
grep -n 'lfs: false' .github/workflows/ci.yml
# expect 6 hits
```

- [ ] **Step 3: Add a reusable model-bootstrap step block to each model-needing job**

The three jobs that need the wav2vec2 model at build / test time are `build-test`, `bench-build`, and `recorder-build`. (Recorder is verified in Step 5 below — if it turns out it does NOT need the model, we drop the block from that job in a follow-up commit on the same task.)

For each of those three jobs, immediately after the `actions/checkout@v4` step, insert:

```yaml
      - name: Restore CoreML model cache
        id: model-cache
        uses: actions/cache@v4
        with:
          path: Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
          key: model-${{ runner.os }}-${{ hashFiles('tools/models.manifest') }}
      - name: Fetch CoreML models on cache miss
        if: steps.model-cache.outputs.cache-hit != 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: bash tools/fetch-models.sh
```

Use exact-string matching: each insertion goes right after the corresponding `lfs: false` block. Open the file and place each block by hand (3 insertions). Indentation is 6 spaces (matches existing step indentation under each job's `steps:` list).

- [ ] **Step 4: Validate the workflow file is parseable YAML**

```sh
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Verify recorder-build's actual model dependency**

```sh
grep -n 'MoraMLX' recorder/MoraFixtureRecorder/**/*.swift recorder/project.yml 2>&1
grep -rn 'MoraMLX' Packages/MoraFixtures/ 2>&1
```
If both grep commands return nothing, the recorder does NOT depend on MoraMLX. **Remove the model-cache + fetch block from the `recorder-build` job** (keep `lfs: false`) and update the commit message accordingly.

If either returns hits, leave the block in.

- [ ] **Step 6: Commit**

```sh
git add .github/workflows/ci.yml
git commit -m "ci: drop LFS fetch from all jobs; cache wav2vec2 model per manifest hash

Every actions/checkout step now sets lfs: false. Jobs that bundle or load
the wav2vec2-phoneme model (build-test, bench-build[, recorder-build if
applicable]) gain an actions/cache step keyed on tools/models.manifest
contents, with a one-time fetch via tools/fetch-models.sh on cache miss.

Closes the LFS bandwidth bottleneck called out in the migration spec §3.
"
```

---

## Task 6: Add a Run Script Build Phase to the Mora Xcode target

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Read the current Mora target definition**

```sh
grep -n 'name: Mora$\|^targets:\|preBuildScripts\|postBuildScripts\|^  Mora:' project.yml
sed -n '/^targets:/,/^[a-zA-Z]/p' project.yml | head -120
```
Locate the `Mora:` target block and identify whether `preBuildScripts:` already exists. If so, append; if not, add the key.

- [ ] **Step 2: Add the build script phase**

Inside the `Mora:` target block, add (or append to existing) `preBuildScripts:`:

```yaml
    preBuildScripts:
      - name: Fetch CoreML models
        script: |
          bash "$SRCROOT/tools/fetch-models.sh"
        basedOnDependencyAnalysis: false
        runOnlyWhenInstalling: false
```

`basedOnDependencyAnalysis: false` ensures the phase runs every build (it's idempotent and sub-second on no-op). `runOnlyWhenInstalling: false` keeps it active for Debug as well as Release.

- [ ] **Step 3: Regenerate the Xcode project**

Per `feedback_mora_xcodegen_team_injection` memory: inject the team ID before generating, then revert.

```sh
# Inject team ID temporarily
perl -i -pe 's/^(  ?)settings:\n/$1settings:\n$1  base:\n$1    DEVELOPMENT_TEAM: 7BT28X9TQ9\n/ if !$done && /^  ?settings:/ && ($done = 1)' project.yml
# Or hand-edit if the perl above doesn't fit your project.yml shape.

xcodegen generate

# Revert team injection
git checkout project.yml.bak 2>/dev/null || git checkout project.yml
# Re-apply your build-script edit if reverted; the safest pattern is:
# 1. commit the build-script change first
# 2. inject the team locally (NOT staged), generate
# 3. git checkout project.yml to drop the injection
```

Concretely the cleanest sequence:
1. Edit `project.yml` to add the script phase only.
2. `git add project.yml && git commit -m "WIP" --no-verify` (temporary).
3. Inject `DEVELOPMENT_TEAM: 7BT28X9TQ9` under `settings.base:` (unstaged).
4. `xcodegen generate`.
5. `git checkout project.yml` to drop the injection (the WIP commit is preserved).
6. `git reset --soft HEAD~1` to un-WIP and continue.

(If this dance is uncomfortable, skip to Step 4 — the regenerate is the test, the team injection is repo policy enforced manually each time.)

- [ ] **Step 4: Verify the build phase fires**

```sh
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E 'fetch-models|wav2vec2-phoneme|Build complete|BUILD SUCCEEDED|error:' | head -20
```
Expected: `fetch-models: ... is up to date` line (since the model is already on disk), plus `BUILD SUCCEEDED`.

- [ ] **Step 5: Confirm the regenerated project did NOT pick up the team injection**

```sh
grep -n 'DEVELOPMENT_TEAM' Mora.xcodeproj/project.pbxproj | head -5
```
Expected: hits (xcodegen wrote the team into the pbxproj for the local build) — but no team in `project.yml`:
```sh
grep -n 'DEVELOPMENT_TEAM' project.yml
```
Expected: no hits.

- [ ] **Step 6: Commit (only `project.yml`, never `Mora.xcodeproj`)**

```sh
git add project.yml
git status
# Should show: modified project.yml (only).
git commit -m "xcodegen: add fetch-models.sh as Mora target preBuildScript

Run on every build (basedOnDependencyAnalysis: false) so a clean clone or a
manifest bump auto-materializes the CoreML model before sources compile.
The script's idempotent fast-path makes warm builds a no-op (< 1s).
"
```

---

## Task 7: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the current README quick-start section**

```sh
sed -n '1,80p' README.md
```

- [ ] **Step 2: Add a "First-time setup" subsection right after the build commands**

Insert (location: between the "Build & test commands" block and the next major heading; the exact spot is judgment-call, but it MUST appear before any `xcodebuild` command since the build needs the model):

```markdown
### First-time setup (clone-fresh)

The wav2vec2-phoneme CoreML model is hosted as a GitHub Release asset
(see `tools/models.manifest`), not in Git. After cloning:

```sh
bash tools/fetch-models.sh
```

This downloads + SHA-verifies the model into
`Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/`.
Re-runs are no-ops when nothing has changed. The Mora Xcode target also
runs this as a preBuildScript so manifest bumps are picked up automatically.

CI does the same via `actions/cache` keyed on the manifest hash, so model
download bandwidth stays at zero on cache hits.
```

- [ ] **Step 3: Commit**

```sh
git add README.md
git commit -m "docs: README — first-time setup runs tools/fetch-models.sh

Bootstraps the GitHub-Release-hosted wav2vec2 CoreML model into the local
working tree. Idempotent; the Xcode preBuildScript takes care of subsequent
runs automatically.
"
```

---

## Task 8: End-to-end verification + open PR

**Files:** none modified — this is a verification + handoff task.

- [ ] **Step 1: Smoke-test from a fresh clone**

```sh
TMP_CLONE=$(mktemp -d)
git clone --branch ci-lfs-to-releases git@github.com:youtalk/mora.git "$TMP_CLONE"
cd "$TMP_CLONE"

# No LFS pull needed — should be fast.
test ! -e .gitattributes && echo "no .gitattributes — OK"

# Model dir does not exist yet:
test ! -e Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc && echo "model absent — OK"

# Bootstrap:
bash tools/fetch-models.sh
test -e Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/coremldata.bin && echo "model present — OK"

# Build everything:
(cd Packages/MoraCore && swift test) | tail -3
(cd Packages/MoraEngines && swift test) | tail -3
(cd Packages/MoraUI && swift test) | tail -3
(cd Packages/MoraTesting && swift test) | tail -3
(cd Packages/MoraMLX && swift build) | tail -3

cd - >/dev/null
rm -rf "$TMP_CLONE"
```
Expected: every line ends in `passed` or `Build complete!`.

- [ ] **Step 2: Push the branch**

```sh
git push -u origin ci-lfs-to-releases
```

- [ ] **Step 3: Open the PR**

```sh
gh pr create --base main --head ci-lfs-to-releases \
  --title "ci: move wav2vec2 CoreML model from LFS to GitHub Releases; drop .gitattributes" \
  --body "$(cat <<'EOF'
## Summary

Closes the LFS bandwidth bottleneck that blocked PR #60's CI. Replaces the
\`actions/checkout lfs: true\` pattern in every CI job with a script-based
fetch from a GitHub Release asset (free, unmetered bandwidth) cached via
\`actions/cache@v4\` keyed on the manifest hash.

- New: \`tools/fetch-models.sh\` + \`tools/models.manifest\` — idempotent
  bootstrap that downloads + SHA-verifies CoreML model bundles. Used by CI,
  Xcode preBuildScript, and developers on first clone.
- Release: \`models/wav2vec2-phoneme-int8-v1\` hosts the 261 MB
  \`wav2vec2-phoneme.mlmodelc.tar.gz\` asset.
- Removed: \`.gitattributes\` (no more LFS-tracked paths). Future yokai
  PNG / m4a will be plain Git blobs per spec §5.5.
- Modified: \`.github/workflows/ci.yml\` (every \`lfs: true\` → \`lfs: false\`,
  three jobs gain a model-cache + fetch step), \`project.yml\` (Mora target
  gains a Run Script preBuild phase), \`README.md\` (first-time setup section).

History rewrite (purge old LFS pointers from past commits) is deferred to a
follow-up PR per spec §10 — explicitly out of scope here so Ubuntu-side asset
work isn't disrupted.

## Test plan
- [x] Fresh clone of this branch + \`bash tools/fetch-models.sh\` materializes the model
- [x] All package \`swift test\` suites green
- [x] \`xcodebuild build\` green with the new preBuildScript firing fetch-models.sh
- [x] CI is the integration test: \`lint\` and \`changes\` jobs run with no LFS
      chatter; \`build-test\` / \`bench-build\` warm up the actions/cache then hit
      it on subsequent runs

## Spec
\`docs/superpowers/specs/2026-04-24-ci-lfs-to-releases-design.md\`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Watch CI**

The first CI run after this push exercises the new pipeline end-to-end. Expectations:

- `lint` and `changes` jobs: no `git lfs fetch` activity in the checkout step.
- `build-test`: cache miss on first run (downloads from release ≈ 261 MB), cache hit on subsequent runs.
- `bench-build`: same.
- All jobs green.

If a failure surfaces, drop into the pr-autofix-loop skill from the conversation root.

---

## Self-review

**Spec coverage:**
- §3 goal "Eliminate LFS bandwidth" → Task 5 (CI), Task 3 (model removal).
- §3 goal "Eliminate LFS storage" → Task 4 (.gitattributes), Task 3.
- §3 goal "Stay free tier" → GitHub Releases (Task 1) + actions/cache (Task 5), no paid services touched.
- §3 goal "≤ 1 extra bootstrap command" → Task 7 README documents the single `bash tools/fetch-models.sh`.
- §3 goal "Visible PNG diffs" → covered by Task 4 (drop LFS rules) — yokai PNG will commit as plain blobs.
- §5.1 release tag/asset/checksum scheme → Task 1 implements it.
- §5.2 fetch-models.sh behavior → Task 2 implements it.
- §5.3 CI cache+fetch → Task 5 implements it.
- §5.4 Xcode build phase → Task 6 implements it.
- §5.5 yokai assets — plain Git → Task 4 (rule removal); no migration needed because no yokai files exist on main yet.
- §5.6 .gitattributes deletion → Task 4.
- §6 migration steps → Tasks 1–8 mirror §6.1–§6.12 directly.
- §7 failure modes → covered by `set -euo pipefail` + SHA verification in Task 2 Step 2.
- §8 developer experience → Task 7 (README), Task 6 (Xcode build phase auto-runs).
- §10 history rewrite deferred → explicitly noted in Task 3 commit message + PR body.

**Placeholder scan:**
- One intentional placeholder: `<PASTE_SHA_FROM_TASK_1_STEP_2>` in Task 2 Step 1 — flagged clearly with the source location.
- Task 5 Step 5 leaves recorder-build's model-cache block conditional on the grep result — the implementer applies the right answer; no bare TODO.
- No other placeholders.

**Type / name consistency:**
- Manifest column order is fixed (`<dest> <tag> <asset> <sha256>`) and the parser in Task 2 reads the same order.
- Release tag (`models/wav2vec2-phoneme-int8-v1`), asset name (`wav2vec2-phoneme.mlmodelc.tar.gz`), and destination path (`Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc`) match across Tasks 1, 2, 5, 7.
- `tools/fetch-models.sh` referenced in Tasks 5, 6, 7 by the same path.

**Scope:** Single migration PR. Sized 6–8 hours of careful work — appropriate for one plan.
