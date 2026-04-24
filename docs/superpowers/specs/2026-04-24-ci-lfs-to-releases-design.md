# CI: Move Large Binaries off Git LFS to GitHub Releases

**Status:** approved (B-1 with deferred history rewrite)
**Author session:** 2026-04-24
**Related:** PR #60 was blocked by `batch response: This repository exceeded its LFS budget`. PRs #45 / #51 introduced the LFS pipeline; PR #59 added LFS rules for yokai assets.

## 1. Problem

The repo's only large binary on Git LFS is the wav2vec2 phoneme CoreML model (`Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/`, ≈ 319 MB total — `weights/weight.bin` is 318 MB on its own). The CI pipeline has six jobs and every one of them does `actions/checkout@v4` with `lfs: true`, so a single full CI run pulls roughly 1.9 GB through LFS bandwidth. GitHub's free tier is **1 GB per month**, so the budget is exhausted by a single CI run after a model touch.

The R4 yokai asset pipeline is about to ship its first five portrait PNGs and ~40 voice clips (5 yokai × ~8 m4a clips), and yokai are expected to grow over time. Any solution that keeps using LFS for these will hit the same wall — both bandwidth and the 1 GB storage cap.

## 2. Goal

- Eliminate Git LFS bandwidth as a CI bottleneck.
- Eliminate Git LFS storage as a long-term constraint on yokai asset growth.
- Stay on the free tier of every service involved.
- Keep the developer experience close to "clone and build" — at most one extra bootstrap command.
- Preserve the ability to review yokai PNG diffs visually in PRs.

## 3. Non-goals

- Rewriting Git history to purge old LFS pointers. Deferred until Ubuntu-side asset work is past the iteration phase, then handled in a separate PR.
- Hosting the model on Hugging Face / S3 / a custom CDN. GitHub Releases is the simplest free path and we already have GitHub auth available everywhere.
- Adding model versioning beyond a single tag per artifact bundle (one model = one release).
- Changing the runtime model loader (`MoraMLX.MoraMLXModelCatalog` / `CoreMLPhonemePosteriorProvider`). Files end up in the same on-disk locations they're in today.

## 4. Approach summary (B-1)

1. The wav2vec2 model leaves Git LFS and lives as a tarball asset on a dedicated GitHub Release.
2. Yokai PNG / m4a assets leave Git LFS and become **plain Git-tracked files** (commit-sized, viewable in PR diffs, fine up to several hundred MB cumulatively).
3. `.gitattributes` LFS rules are removed. New large model artifacts in the future follow the Release-asset pattern; new image / audio assets stay plain Git until their cumulative size becomes a problem (re-evaluate at ~500 MB total).
4. A bootstrap script (`tools/fetch-models.sh`) downloads and verifies the model from its release. CI calls it; developers call it once after `git clone`. Xcode build phase calls it on demand so it's a no-op on subsequent builds.
5. CI replaces every `lfs: true` checkout with `lfs: false` and (where the model is needed) wraps the bootstrap script in an Actions cache keyed on the model's release tag. Cache hit → 0 network. Cache miss → one download from the Release asset (which has no bandwidth cap).
6. Git history's LFS pointers are left untouched for now. New work goes through the Release path; old commits keep referencing LFS objects but nothing on `main` will need them after the migration commit.

## 5. Components

### 5.1 GitHub Release as model store

- **Tag scheme:** `models/wav2vec2-phoneme-int8-v1` for this model. Each model that needs distribution gets its own `models/<name>-<variant>-v<n>` tag. No reuse — bumping the model means a new tag.
- **Asset:** `wav2vec2-phoneme.mlmodelc.tar.gz` (the entire compiled bundle directory, gzip-tarred).
- **Checksum:** `wav2vec2-phoneme.mlmodelc.tar.gz.sha256` published alongside.
- **Release visibility:** public (matches the repo's source-available license; the model is derived from a public Hugging Face checkpoint).
- **Authoring:** `gh release create models/wav2vec2-phoneme-int8-v1 wav2vec2-phoneme.mlmodelc.tar.gz wav2vec2-phoneme.mlmodelc.tar.gz.sha256 --title "wav2vec2 phoneme INT8 v1" --notes "..."`. One-time per model version.

### 5.2 `tools/fetch-models.sh`

Single bash script, idempotent:

- Reads a manifest at `tools/models.manifest` (simple line-based: `<destination-path> <release-tag> <asset-name> <sha256>`).
- For each entry, checks whether the destination directory exists and its SHA-256 matches. If yes → skip.
- If miss → `gh release download <tag> -p <asset> -O - | tar xz -C <destination-parent>`, verify SHA, fail loudly on mismatch.
- Uses `gh` if present (preferred — works in CI with `GITHUB_TOKEN`), falls back to anonymous `curl https://github.com/youtalk/mora/releases/download/<tag>/<asset>` for developer machines without `gh`.
- Exits zero when everything is up to date so it's safe to chain into other build steps.

The manifest checked into `tools/models.manifest`:

```
Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc models/wav2vec2-phoneme-int8-v1 wav2vec2-phoneme.mlmodelc.tar.gz <sha256>
```

The SHA-256 is computed once when the release is cut and pasted into the manifest. A manifest change is the only thing that bumps the model version on consumers.

### 5.3 CI integration

- Every `actions/checkout@v4` invocation in `.github/workflows/ci.yml` switches to `lfs: false`.
- Jobs that need the model (`build-test`, `bench-build`, and `recorder-build` if it ends up needing it — to be confirmed during implementation) gain a step pair:
  ```yaml
  - name: Restore model cache
    id: model-cache
    uses: actions/cache@v4
    with:
      path: Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
      key: model-${{ runner.os }}-${{ hashFiles('tools/models.manifest') }}
  - name: Fetch models on cache miss
    if: steps.model-cache.outputs.cache-hit != 'true'
    env:
      GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    run: tools/fetch-models.sh
  ```
- Cache key is the manifest hash, so a model bump invalidates exactly when needed and not before.
- Actions cache quota: 10 GB per repo, free, separate from LFS bandwidth.
- `lint` and `changes` jobs skip the cache+fetch entirely.

### 5.4 Xcode integration

- `project.yml` gains a Run Script Build Phase on the `Mora` app target that runs `tools/fetch-models.sh` before sources compile. The script's idempotent fast-path means already-downloaded models add < 1 s.
- The `MoraMLX` SPM package itself does not run the script — SPM resource declarations don't run scripts. The Run Script Phase on the app target is the integration point that ensures the bundled resources exist before the build copies them.
- `xcodegen generate` regenerates the project with the phase intact.

### 5.5 Yokai assets — plain Git

- All entries under `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/**/*.{png,m4a}` are committed as plain Git blobs.
- `.gitattributes` rules for these globs are removed.
- PR reviews show PNG diffs natively in the GitHub UI.
- Sizing budget: re-evaluate when cumulative yokai assets approach 500 MB. At first-five (R4), expected total < 30 MB.

### 5.6 `.gitattributes`

After the migration commit, the file contains zero LFS rules — all four current rules are removed. The file can either be left in place empty (or with comments documenting the policy) or deleted. **Decision:** delete it. If a future binary needs special handling, a new `.gitattributes` is one commit away.

## 6. Migration steps

1. Create the model release manually via `gh release create`.
2. Compute SHA-256, paste into `tools/models.manifest`.
3. Add `tools/fetch-models.sh` and `tools/models.manifest`.
4. Run `tools/fetch-models.sh` locally to confirm it downloads + extracts cleanly into the expected path.
5. `git rm -r Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/` (removes the LFS pointers from `main` only — past commits are untouched).
6. Re-run `tools/fetch-models.sh` so the working tree has the real files for the local build.
7. Edit `.gitattributes` to drop all four LFS rules. Delete the file.
8. Edit `.github/workflows/ci.yml` — flip every `lfs: true` to `lfs: false`, add the cache+fetch steps where needed.
9. Edit `project.yml` to add the Run Script Build Phase, regenerate.
10. Verify locally: clean clone in a temp dir → `tools/fetch-models.sh` → `swift test` per package + `xcodebuild` succeeds.
11. README gets a new "First-time setup" line: `bash tools/fetch-models.sh` after clone.
12. Open the migration PR. CI must pass (this is the proof that the new pipeline works end-to-end).

## 7. Failure modes

| Failure | Detection | Recovery |
|---|---|---|
| Release asset missing | `gh release download` exits non-zero | Script aborts; user re-creates the release |
| SHA-256 mismatch | Verification step fails | Script aborts loudly; manifest or release was tampered |
| Network down (developer) | `curl` / `gh` failure | Script aborts; developer retries when online |
| Model file modified locally | SHA mismatch on next run | Script re-downloads, overwriting local mods (the model is not source) |
| GitHub Releases bandwidth limit | None known — Releases is unmetered for public repos | n/a |
| `gh` not installed (developer) | Script falls back to anonymous `curl`; works for public assets | n/a |

## 8. Developer experience

```sh
git clone git@github.com:youtalk/mora.git
cd mora
bash tools/fetch-models.sh   # one extra step after clone
xcodegen generate
xcodebuild build -scheme Mora -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

After the first fetch, subsequent runs of `fetch-models.sh` SHA-check and exit in well under a second.

## 9. Testing

- Unit tests are unaffected (model load path is unchanged).
- The migration PR's CI run is itself the integration test for the new pipeline. Specifically:
  - `lint` and `changes` should run without LFS chatter.
  - `build-test` should hit the cache on its second run (the first one in the PR) and fetch from Release on the first.
  - The MLX-loading tests (`MoraEngines` Engine B suite) still pass.

## 10. History rewrite — deferred

Out of scope for this PR. When Ubuntu-side asset work stabilises, a follow-up PR will:

- Run `git filter-repo` to drop all LFS pointer paths from history.
- Force-push (with prior coordination — at minimum the Ubuntu clone needs re-clone).
- Delete the LFS objects from the GitHub side to reclaim storage budget.

Until then, `clone` size stays roughly where it is today, but new development burns 0 LFS bandwidth.

## 11. Open questions

- **Recorder-build LFS need:** the recorder app does not depend on `MoraMLX` per `Packages/MoraFixtures` ownership notes, so it should be safe at `lfs: false` with no fetch. Implementation step verifies by running its CI job.
- **`gh` auth in CI:** `secrets.GITHUB_TOKEN` is automatically available in workflows; for public release assets it's strictly redundant but it raises rate limits and matches what `gh` already expects.
- **Future per-locale or learner-tuned models:** the manifest format extends naturally to multiple entries. No change needed today.
