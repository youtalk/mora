# License Selection and History Rewrite Design

**Date:** 2026-04-21
**Status:** Approved, ready for implementation plan
**Repository:** `youtalk/mora` (public)

## Goal

Adopt a license for the mora repository and rewrite Git history so the license
file is present in every commit, starting from the initial commit
(`38a3781`).

## License Decision: PolyForm Noncommercial 1.0.0

### Why this license

The repository owner wants the codebase to be publicly readable and usable by
non-commercial actors (educators, researchers, individual learners, non-profit
organizations), but does not want third parties to fork it and ship competing
commercial products or SaaS offerings.

No OSI-approved open source license can express this preference, because the
Open Source Definition requires permitting commercial use and redistribution.
The viable source-available options are:

- **All rights reserved** — too restrictive; blocks legitimate non-commercial
  adaptation that fits mora's dyslexia/ESL education domain.
- **PolyForm Noncommercial 1.0.0** — purpose-built for code; explicit patent
  grant; short (~500 words); recognized by GitHub's license detection; clear
  "noncommercial" definition (Section 1).
- **Business Source License** — time-delayed OSS conversion; mora does not
  need the future-OSS guarantee right now.

PolyForm Noncommercial 1.0.0 is chosen.

### Why GPL v3.0 is rejected

mora is targeted for App Store distribution. GPL v3.0 is effectively
incompatible with the App Store's per-user usage restrictions (FSF's
long-standing position; see the VLC removal precedent). Adopting GPL v3.0
would block mora's primary distribution channel.

### Implications accepted

- GitHub will label the repository "Non-commercial", not "Open source".
- Corporate contributors whose employers prohibit non-OSI licenses cannot
  contribute.
- SonarCloud's free plan is unavailable (requires OSI license); Codecov,
  Coveralls, GitHub Actions for public repositories, Dependabot, CodeQL, and
  all other GitHub-native free tiers remain available because they are
  license-agnostic.
- The repository owner (sole copyright holder) retains full rights to
  distribute compiled binaries via the App Store under separate terms.

## LICENSE File

### Placement

- Single file at repository root: `LICENSE`
- No per-package LICENSE inside `Packages/MoraCore`, `Packages/MoraEngines`,
  etc. Swift Package Manager convention inherits the root LICENSE in a
  monorepo layout.

### Content

- Verbatim text of PolyForm Noncommercial 1.0.0 from the PolyForm Project
  official distribution.
- Copyright line: `Copyright 2026 Yutaka Kondo <yutaka.kondo@youtalk.jp>`
- SPDX identifier: `PolyForm-Noncommercial-1.0.0`
- Trailing link preserved: `https://polyformproject.org/licenses/noncommercial/1.0.0`

## History Rewrite Mechanics

### Approach: `git rebase -i --root`

The initial commit currently contains only `.gitignore`. No subsequent commit
touches a `LICENSE` file. Injecting `LICENSE` into the root commit and
replaying the 13 child commits as-is therefore produces no conflicts.

`git filter-repo` is rejected as unnecessary tooling overhead for 14 commits
with a single-file change localized to the root.

### Procedure

```bash
# 1. Pre-rewrite safety tag
git tag backup/pre-license-rewrite main

# 2. Work on a dedicated branch, leave main untouched until verified
git checkout -b rewrite/license-from-root main

# 3. Mark initial commit for edit in a non-interactive rebase
GIT_SEQUENCE_EDITOR="sed -i '' '1s/^pick/edit/'" git rebase -i --root

# 4. Write LICENSE and amend into the initial commit, preserving author date
#    (LICENSE content prepared separately)
git add LICENSE
git commit --amend --no-edit --date="$(git log -1 --format=%aI 38a3781)"
git rebase --continue

# 5. Verify: every commit should contain LICENSE; the only diff vs. main
#    should be the LICENSE addition
git log --all --diff-filter=A -- LICENSE   # expect: only rewritten root commit
git log --all --diff-filter=D -- LICENSE   # expect: empty
git diff main..rewrite/license-from-root   # expect: LICENSE added, nothing else

# 6. Fast-forward main and force-push with lease
git checkout main
git reset --hard rewrite/license-from-root
git push --force-with-lease origin main
```

### What changes

- All 14 commit SHAs change (root's tree changes, so every descendant's SHA
  changes).
- Author dates are preserved via `--date`.
- Committer dates are updated to rewrite time (acceptable and unavoidable).
- No tags exist today, so no tags need re-pointing.
- No commits are GPG-signed, so no signatures need re-generation.

### What is preserved

- Commit messages (unchanged).
- Author identity and date on every commit.
- Parent relationships (linear history stays linear).
- PR page associations on GitHub: pages `#1`–`#12` remain accessible; the
  commit SHAs referenced from those pages become orphaned but remain in
  GitHub's storage for the repository's retention window.

## Safety Measures

1. **Backup tag** `backup/pre-license-rewrite` pins the pre-rewrite tip.
   Recovery path: `git reset --hard backup/pre-license-rewrite && git push
   --force-with-lease origin main`.
2. **`--force-with-lease`** is used instead of `--force` so a concurrent push
   (should it happen) aborts the rewrite push rather than overwriting it.
3. **Pre-rewrite CI check**: `gh run list --branch main --limit 3` to
   confirm no in-flight workflow runs; rewriting while CI is running against
   old SHAs produces orphaned runs that complicate the picture.
4. **Worktree check**: the `worktree-elegant-frolicking-moon` worktree may
   hold uncommitted changes or point at a rewritten commit. Inspect and
   stash or discard before the rewrite; re-sync after.
5. **Post-rewrite verification**: commit count is 14, `LICENSE` exists at
   every commit (see commands in "Procedure" step 5).

## Post-Rewrite Cleanup

1. **Delete merged feature branches** locally (all nine have been merged to
   `main` via PRs and would otherwise keep orphan references alive):
   - `chore/add-pr-autofix-skill`
   - `ci/github-actions-macos`
   - `feature/phase-3-l1-profile`
   - `feature/phase-4-content-template-engine`
   - `feature/phase-5-assessment-curriculum`
   - `feature/phase-6-speech-tts`
   - `feature/phase-7-swiftdata-persistence`
   - `feature/phase-8-session-orchestrator`
   - `feature/phase-9-swiftui`
2. **Re-sync worktree** `worktree-elegant-frolicking-moon` if it was based on
   a rewritten commit.
3. **Confirm GitHub license detection** with
   `gh repo view youtalk/mora --json licenseInfo` — expected result includes
   SPDX key `PolyForm-Noncommercial-1.0.0`.
4. **Retain backup tag locally** for ~1 week, then delete with
   `git tag -d backup/pre-license-rewrite`. Do not push the backup tag to
   the remote.

## Out of Scope

- Adding a `README.md` (repository has none; license adoption is independent
  of documentation).
- `NOTICE` file (not required by PolyForm Noncommercial 1.0.0).
- Dual-licensing for future commercial licensees (defer until demand).
- Re-signing historical commits with GPG (none were signed originally).
