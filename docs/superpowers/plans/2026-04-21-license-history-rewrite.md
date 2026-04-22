# License History Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt PolyForm Noncommercial 1.0.0 for the mora repository and rewrite Git history so `LICENSE` is present in every commit starting from the initial commit.

**Architecture:** Prepare LICENSE content locally, tag a backup, use `git rebase -i --root` to amend the initial commit with the LICENSE file, verify, fast-forward `main`, force-push with lease, then clean up merged feature branches.

**Tech Stack:** Git, GitHub CLI (`gh`), macOS BSD `sed`.

**Spec:** `docs/superpowers/specs/2026-04-21-license-history-rewrite-design.md`

**Working directory for every task:** `/Users/yutaka.kondo/src/mora`

---

## File Structure

- Create: `LICENSE` (repository root) — PolyForm Noncommercial 1.0.0 text with copyright line.
- No code files are modified. No per-package LICENSE files are added.

---

## Task 1: Preflight Checks

**Files:** none (read-only verification)

- [ ] **Step 1: Confirm clean working tree and expected HEAD**

Run:
```bash
cd /Users/yutaka.kondo/src/mora
git status
git log --oneline -3
```

Expected:
- `git status` shows untracked-only items (`.DS_Store`, `.claude/settings.json` are acceptable). No staged/modified tracked files.
- Latest commit is `Add license selection and history rewrite design`.
- `main` is on a commit no earlier than `5376427`.

If the tree has modified tracked files, stop and ask the user before proceeding.

- [ ] **Step 2: Confirm no in-flight CI runs on `main`**

Run:
```bash
gh run list --branch main --limit 5
```

Expected: no workflow run in `in_progress` or `queued` state on `main`. If any exist, wait for them to finish before the rewrite to avoid orphaned CI runs against SHAs that will disappear.

- [ ] **Step 3: Confirm no active worktrees other than the main checkout**

Run:
```bash
git worktree list
```

Expected: a single line pointing at `/Users/yutaka.kondo/src/mora`. If additional worktrees appear, stop and ask the user — their state must be handled before rewriting.

- [ ] **Step 4: Record the current initial-commit SHA and author date for later use**

Run:
```bash
INITIAL_SHA=$(git rev-list --max-parents=0 HEAD)
INITIAL_DATE=$(git log -1 --format=%aI "$INITIAL_SHA")
echo "INITIAL_SHA=$INITIAL_SHA"
echo "INITIAL_DATE=$INITIAL_DATE"
```

Expected:
- `INITIAL_SHA=38a378118af9028288d46e87435771595cad2c2a`
- `INITIAL_DATE=2026-04-21T10:18:05-07:00`

Keep this terminal session open — `$INITIAL_DATE` is needed in Task 3. If the session is lost, re-run this step before Task 3.

---

## Task 2: Create the Backup Tag

**Files:** none (git ref creation only)

- [ ] **Step 1: Tag the current `main` tip as the recovery point**

Run:
```bash
git tag backup/pre-license-rewrite main
```

Expected: no output. Tag created locally only.

- [ ] **Step 2: Verify the tag**

Run:
```bash
git show --no-patch --format="%H %s" backup/pre-license-rewrite
```

Expected: the SHA and subject match the current tip of `main` (the `Add license selection and history rewrite design` commit).

Do **not** push this tag to the remote. It is a local recovery point only.

---

## Task 3: Prepare the Rewrite on a Working Branch

**Files:**
- Create: `LICENSE`

- [ ] **Step 1: Create and switch to the rewrite working branch**

Run:
```bash
git checkout -b rewrite/license-from-root main
```

Expected: `Switched to a new branch 'rewrite/license-from-root'`.

- [ ] **Step 2: Start a non-interactive rebase that marks the initial commit for `edit`**

Run:
```bash
GIT_SEQUENCE_EDITOR="sed -i '' '1s/^pick/edit/'" git rebase -i --root
```

Expected: rebase stops on the initial commit with a message like:
```
Stopped at <SHA>... Initial commit
You can amend the commit now, with ...
```

Verify with:
```bash
git log --oneline HEAD  # only one commit: the initial commit
git status              # on a detached rebase HEAD
```

- [ ] **Step 3: Write the `LICENSE` file at the repository root**

Create `/Users/yutaka.kondo/src/mora/LICENSE` with exactly the following content:

```
Copyright 2026 Yutaka Kondo <yutaka.kondo@youtalk.jp>

# PolyForm Noncommercial License 1.0.0

<https://polyformproject.org/licenses/noncommercial/1.0.0>

## Acceptance

In order to get any license under these terms, you must agree
to them as both strict obligations and conditions to all
your licenses.

## Copyright License

The licensor grants you a copyright license for the software
to do everything you might do with the software that would
otherwise infringe the licensor's copyright in it for any
permitted purpose.  However, you may only distribute the
software according to [Distribution License](#distribution-license)
and make changes or new works based on the software according
to [Changes and New Works License](#changes-and-new-works-license).

## Distribution License

The licensor grants you an additional copyright license to
distribute copies of the software.  Your license to distribute
covers distributing the software with changes and new works
permitted by [Changes and New Works License](#changes-and-new-works-license).

## Notices

You must ensure that anyone who gets a copy of any part of
the software from you also gets a copy of these terms or the
URL for them above, as well as copies of any plain-text lines
beginning with `Required Notice:` that the licensor provided
with the software.  For example:

> Required Notice: Copyright Yoyodyne, Inc. (http://example.com)

## Changes and New Works License

The licensor grants you an additional copyright license to
make changes and new works based on the software for any
permitted purpose.

## Patent License

The licensor grants you a patent license for the software that
covers patent claims the licensor can license, or becomes able
to license, that you would infringe by using the software.

## Noncommercial Purposes

Any noncommercial purpose is a permitted purpose.

## Personal Uses

Personal use for research, experiment, and testing for
the benefit of public knowledge, personal study, private
entertainment, hobby projects, amateur pursuits, or religious
observance, without any anticipated commercial application,
is use for a permitted purpose.

## Noncommercial Organizations

Use by any charitable organization, educational institution,
public research organization, public safety or health
organization, environmental protection organization,
or government institution is use for a permitted purpose
regardless of the source of funding or obligations resulting
from the funding.

## Fair Use

You may have "fair use" rights for the software under the
law. These terms do not limit them.

## No Other Rights

These terms do not allow you to sublicense or transfer any of
your licenses to anyone else, or prevent the licensor from
granting licenses to anyone else.  These terms do not imply
any other licenses.

## Patent Defense

If you make any written claim that the software infringes or
contributes to infringement of any patent, your patent license
for the software granted under these terms ends immediately. If
your company makes such a claim, your patent license ends
immediately for work on behalf of your company.

## Violations

The first time you are notified in writing that you have
violated any of these terms, or done anything with the software
not covered by your licenses, your licenses can nonetheless
continue if you come into full compliance with these terms, and
take practical steps to correct past violations, within 32 days
of receiving notice.  Otherwise, all your licenses end
immediately.

## No Liability

***As far as the law allows, the software comes as is, without
any warranty or condition, and the licensor will not be liable
to you for any damages arising out of these terms or the use
or nature of the software, under any kind of legal claim.***

## Definitions

The **licensor** is the individual or entity offering these
terms, and the **software** is the software the licensor makes
available under these terms.

**You** refers to the individual or entity agreeing to these
terms.

**Your company** is any legal entity, sole proprietorship,
or other kind of organization that you work for, plus all
organizations that have control over, are under the control of,
or are under common control with that organization.  **Control**
means ownership of substantially all the assets of an entity,
or the power to direct its management and policies by vote,
contract, or otherwise.  Control can be direct or indirect.

**Your licenses** are all the licenses granted to you for the
software under these terms.

**Use** means anything you do with the software requiring one
of your licenses.
```

- [ ] **Step 4: Verify the file was written**

Run:
```bash
head -1 LICENSE
wc -l LICENSE
```

Expected:
- First line: `Copyright 2026 Yutaka Kondo <yutaka.kondo@youtalk.jp>`
- Line count is in the 130–135 range.

- [ ] **Step 5: Stage the file and amend the initial commit, preserving the original author date**

Run:
```bash
git add LICENSE
git commit --amend --no-edit --date="$INITIAL_DATE"
```

Expected: amended commit with subject `Initial commit` and the original author date. If `$INITIAL_DATE` is empty, re-run Task 1 Step 4, then repeat.

- [ ] **Step 6: Continue the rebase to replay all subsequent commits**

Run:
```bash
git rebase --continue
```

Expected: `Successfully rebased and updated refs/heads/rewrite/license-from-root.` No conflicts — no other commit touches `LICENSE`.

---

## Task 4: Verify the Rewrite

**Files:** none (read-only checks)

- [ ] **Step 1: Confirm commit count is unchanged**

Run:
```bash
git log --oneline rewrite/license-from-root | wc -l
```

Expected: `14`.

- [ ] **Step 2: Confirm `LICENSE` was added exactly once, at the root commit**

Run:
```bash
git log --all --diff-filter=A --oneline -- LICENSE
git log --all --diff-filter=D --oneline -- LICENSE
git log --all --diff-filter=M --oneline -- LICENSE
```

Expected:
- First command lists exactly one commit whose subject is `Initial commit` (the rewritten root commit on `rewrite/license-from-root`).
- Second and third commands produce no output (LICENSE is never deleted or modified across the history).

- [ ] **Step 3: Confirm every commit contains `LICENSE` in its tree**

Run:
```bash
for sha in $(git rev-list rewrite/license-from-root); do
  git cat-file -e "$sha:LICENSE" 2>/dev/null || echo "MISSING in $sha"
done
```

Expected: no output. Any `MISSING in ...` line indicates failure — stop and investigate.

- [ ] **Step 4: Confirm the working-tree diff vs. `main` is LICENSE-only**

Run:
```bash
git diff --stat main..rewrite/license-from-root
```

Expected: exactly one line, `LICENSE | <N> +++...`, with `<N>` matching the line count from Task 3 Step 4. No other files appear.

- [ ] **Step 5: Confirm author dates are preserved across the rewritten history**

Run:
```bash
diff <(git log --format="%an %ae %aI %s" main) \
     <(git log --format="%an %ae %aI %s" rewrite/license-from-root)
```

Expected: no output. Author name, email, date, and subject match one-for-one between `main` and the rewritten branch.

If any verification step fails, do **not** proceed to Task 5. Recovery: `git rebase --abort` (if still rebasing), then delete the working branch (`git branch -D rewrite/license-from-root`) and restart from Task 3. The `main` branch and `backup/pre-license-rewrite` tag are untouched until Task 5.

---

## Task 5: Publish the Rewritten History

**Files:** none (ref updates + remote push)

**Confirmation gate:** This is the destructive step. Pause and confirm with the user before running Step 2. Past this point, recovery requires the backup tag.

- [ ] **Step 1: Fast-forward `main` to the verified rewrite**

Run:
```bash
git checkout main
git reset --hard rewrite/license-from-root
git log --oneline -3
```

Expected: `main` HEAD now matches the rewritten branch (same SHAs).

- [ ] **Step 2: Force-push `main` with lease**

Run:
```bash
git push --force-with-lease origin main
```

Expected: push succeeds. If the remote has advanced since the last fetch, `--force-with-lease` aborts — in that case, investigate the remote state with `git fetch && git log origin/main..main` before retrying.

- [ ] **Step 3: Confirm remote `main` matches local**

Run:
```bash
git fetch origin
git log --oneline origin/main -3
git rev-parse main origin/main
```

Expected: `main` and `origin/main` point at the same SHA.

---

## Task 6: Verify GitHub-Side License Detection

**Files:** none (remote read-only checks)

- [ ] **Step 1: Confirm GitHub detected the license**

Run:
```bash
gh repo view youtalk/mora --json licenseInfo
```

Expected:
```json
{"licenseInfo":{"key":"polyform-noncommercial-1.0.0","name":"PolyForm Noncommercial License 1.0.0","nickname":null,"spdxId":"PolyForm-Noncommercial-1.0.0","url":"..."}}
```

Detection may lag the push by up to ~1 minute. If the first call still returns `null`, wait 30 seconds and retry.

- [ ] **Step 2: Confirm `LICENSE` is present at the current `main` and at the initial commit on GitHub**

Run:
```bash
gh api repos/youtalk/mora/contents/LICENSE --jq '.name, .size'
gh api "repos/youtalk/mora/contents/LICENSE?ref=$(git rev-list --max-parents=0 origin/main)" --jq '.name, .size'
```

Expected: both calls return `LICENSE` and a non-zero byte size.

---

## Task 7: Clean Up Merged Feature Branches

**Files:** none (local ref deletions)

All nine branches have been merged into `main` via PRs `#1`–`#12`. Their upstream remote branches are already deleted (`[origin/...: gone]`). After the rewrite they still point at orphan SHAs; deleting them removes the orphan references.

- [ ] **Step 1: Verify each target branch is the "gone" state seen during planning**

Run:
```bash
git branch -vv | grep ': gone]'
```

Expected: exactly the nine branches listed below, each marked `[origin/<name>: gone]`.

- [ ] **Step 2: Delete the nine merged branches locally**

Run:
```bash
git branch -D \
  chore/add-pr-autofix-skill \
  ci/github-actions-macos \
  feature/phase-3-l1-profile \
  feature/phase-4-content-template-engine \
  feature/phase-5-assessment-curriculum \
  feature/phase-6-speech-tts \
  feature/phase-7-swiftdata-persistence \
  feature/phase-8-session-orchestrator \
  feature/phase-9-swiftui
```

Expected: nine `Deleted branch ... (was <sha>).` lines.

- [ ] **Step 3: Delete the rewrite working branch (no longer needed — `main` carries the result)**

Run:
```bash
git branch -D rewrite/license-from-root
```

Expected: `Deleted branch rewrite/license-from-root (was <sha>).`

- [ ] **Step 4: Confirm final branch state**

Run:
```bash
git branch
```

Expected: only `* main` is listed.

---

## Task 8: Final State Snapshot

**Files:** none (read-only)

- [ ] **Step 1: Record the post-rewrite repository state**

Run:
```bash
git log --oneline | head -14
git status
git rev-parse main origin/main
gh repo view youtalk/mora --json licenseInfo
```

Expected:
- 14 commits listed, oldest is `Initial commit`, newest is `Add license selection and history rewrite design`.
- Working tree clean (ignoring `.DS_Store`, `.claude/settings.json` untracked).
- `main` and `origin/main` match.
- `licenseInfo.spdxId` equals `PolyForm-Noncommercial-1.0.0`.

- [ ] **Step 2: Note the backup tag retention plan**

The tag `backup/pre-license-rewrite` is kept locally for approximately one week as a recovery anchor. It is **not** pushed to the remote. After about a week of stability, delete with:

```bash
git tag -d backup/pre-license-rewrite
```

Do not delete it as part of this plan. Schedule or note this separately.

---

## Recovery Procedure (only if something goes catastrophically wrong after Task 5)

```bash
git checkout main
git reset --hard backup/pre-license-rewrite
git push --force-with-lease origin main
```

This restores `main` to the exact pre-rewrite tip. CI history, PR references, and old SHAs become canonical again.
