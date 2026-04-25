---
name: pr-autofix-loop
description: After a pull request is opened or updated, enter a monitoring-and-auto-fix loop — watch every triggered GitHub Actions run via `gh run watch`, pull Copilot / human review comments via `gh api`, diagnose failures, apply fixes locally, run local build/test verification, commit, push, and repeat until CI is green and reviews are addressed. Handles **stacked PRs**: when the bottom PR in a stack is merged, automatically rebase the next PR onto its new base, minimize the diff, and re-enter the monitoring loop, repeating up the stack until the whole chain lands. Use this skill whenever the user says "monitor and fix it after opening the PR", "keep auto-fixing until CI passes", "watch and autofix", "babysit the PR", "handle review feedback and monitor CI for this PR", "watch the stack", "drive this stack of PRs to merge", "rebase the next one when the base merges", or anything asking Claude to take a single PR or a chain of stacked PRs from red/reviewed to green/merged without manual polling in between. Also trigger when the user hands off a just-pushed branch (or a stack of branches) and expects Claude to drive it to a merge-ready state.
---

# PR Autofix Loop

## What this skill is for

The user opens a pull request (or pushes to an existing one) and wants Claude to drive it to a merge-ready state without them polling GitHub themselves. That means:

1. Watching every GitHub Actions run triggered by the push.
2. Reading failure logs and formulating a fix — not a bypass.
3. Verifying the fix locally (`swift test`, `cargo test`, `pytest`, `xcodebuild`, whatever the repo uses) so we don't burn CI credits re-pushing blind attempts.
4. Committing with a clear message, pushing, and going back to step 1.
5. In parallel, reading new review comments (Copilot, humans) and addressing them with code changes.

Keep going until CI is green and there are no unaddressed review threads, then stop and summarize for the user. Do **not** merge — that's the user's call.

When the user is driving a **stack** of PRs (PR #2 based on PR #1's branch, PR #3 based on PR #2's, and so on), extend the loop up the chain: once the bottom PR is merged by the user, rebase the next PR onto its new base to minimize the diff, re-enter the per-PR monitoring loop, and repeat to the top of the stack. See "Stacked PRs" below for the detection logic, the meta-loop, and the rebase details.

## When to invoke

Trigger on any of:

- The user just ran `gh pr create` (or asked you to) and said something like "watch it", "babysit", "monitor and fix", "keep pushing until green".
- The user posted a link to a specific failing Actions run or review on the current PR and says "fix this".
- A previous iteration of this loop ran and the user said "keep going" / "continue".
- The user hands off a **stack** of PRs and wants Claude to drive the whole chain through merge — phrasings like "watch the stack", "rebase the next one when the bottom merges", "drive these stacked PRs to merge", or listing multiple PR numbers with a "work through all of them" intent.

Don't invoke for unrelated tasks like "run the tests" one-off or generic debugging — this skill is specifically for the **push → watch → diagnose → fix → push** cycle (and its stack-aware extension, **watch → merge-detect → rebase-next → push → watch**).

## The loop

Review comments usually arrive before CI finishes. **Handle them first**, then wait for CI — so one CI cycle validates the combined result. If you wait for CI to go green before reading reviews, pushing the review fixes triggers a fresh ~10-minute CI cycle on top, doubling the wall-clock time for no reason.

```
loop:
  1. Find the latest run for the head commit; start `gh run watch <id> --exit-status`
     in the background (fire-and-forget — the harness notifies you on exit).
  2. Fetch review comments. Copilot typically lands 1–3 minutes after push; humans
     arrive later. If there are unaddressed comments:
       a. Address each (code change, or a threaded reply where a change isn't right).
       b. Verify locally (build/test the minimal affected slice).
       c. Commit and push. In repos with `concurrency.cancel-in-progress: true`,
          this cancels the in-flight CI; otherwise a new run is queued on top.
       d. Go to step 1 with the new HEAD.
  3. No unaddressed reviews → wait for the background CI watch to exit.
       - exit 0 (green) → step 4.
       - non-zero (failure) → `gh run view <id> --log-failed`, diagnose, fix
         locally, verify, commit, push, go to step 1.
  4. Final gate: CI green for the current HEAD AND all review threads addressed?
     - If a review landed while you waited in step 3, go to step 2.
     - Otherwise stop and summarize.
```

**Why reviews first:** CI typically takes 5–15 minutes; Copilot posts its review in 1–3. If you wait on CI first, the Copilot fixes always land on a second push — a second CI cycle for the same PR. Reading reviews while CI is still running lets you batch the fixes into the next (or the same) push, so a single CI cycle covers the whole thing.

One-cycle path (what we want):
```
push #N  → CI #N starts, watch in background
  ↓ 1–3 min
Copilot review posted → fix locally → verify → commit → push #N+1
  ↓ CI #N canceled (or superseded), CI #N+1 starts
  ↓ 5–15 min
CI #N+1 green → stop.
```

Two-cycle anti-pattern (what we don't want):
```
push #N → CI #N starts → wait 10 min → green → read Copilot → fix → push #N+1 → CI #N+1 starts → wait another 10 min → green → stop.
```

Same fixes land either way; the second path doubles the clock.

**Initial wait window:** right after a push, reviews haven't posted yet. Rather than launching into a long CI wait immediately, give Copilot ~60–120 seconds to show up. If it has, handle it; if not, start the CI watch and poll reviews again when the watch notification arrives. Don't treat "no reviews now" as "no reviews ever" until CI has finished too.

The most important discipline is still **always reproduce locally and verify the fix before pushing**. CI is slow and expensive and seeing your own fix fail on the runner tells you very little you couldn't have learned in seconds locally. The one exception is when the failure is environment-specific (e.g., the runner's toolchain differs from yours) and the local repro isn't possible — in that case, name the hypothesis in the commit message so the next failing log either confirms or refutes it.

## Stacked PRs

A **stack** is a chain of PRs where each PR's base branch is the head of the previous PR. Example: PR #12 (base `main`, head `feat/a`) → PR #13 (base `feat/a`, head `feat/b`) → PR #14 (base `feat/b`, head `feat/c`). Stacks keep individual PRs small and reviewable while letting dependent work land in order.

When the user hands off a stack, the single-PR loop above becomes the **inner** loop. An **outer** loop advances up the stack one PR at a time, restructuring each upper PR after its predecessor is merged so its diff stays minimal and the CI signal is meaningful. The per-PR loop still stops at merge-ready — Claude doesn't merge. What the stack extension adds is what happens *after* the human merges: detect it, rebase the next PR, re-enter the inner loop.

### Detecting a stack

Inspect the current PR's base. If the base branch is itself the head of another open PR, you're in a stack:

```bash
BASE=$(gh pr view <N> --json baseRefName -q .baseRefName)
PARENT=$(gh pr list --head "$BASE" --state open --json number -q '.[0].number // empty')
```

If `PARENT` is non-empty, walk down (`gh pr view <PARENT> --json baseRefName`, repeat) until you hit a PR whose base is the default branch — that's the bottom. Walk up the same way from the top PR the user mentioned to enumerate the full chain.

If the user hands you an ordered list of PRs explicitly ("#12, #13, #14 — work through them"), trust that ordering. They know the intended stack even if the base pointers on GitHub are misconfigured.

Before the parent PR merges, save the parent branch's tip SHA — it's the reference point for the `--onto` rebase form and is harder to recover once the branch is auto-deleted post-merge:

```bash
OLD_PARENT_TIP=$(git rev-parse "origin/<parent-head>")
```

Note it alongside the PR number in your working notes for each PR in the stack.

### The stack-aware meta-loop

```
For each PR in the stack, from bottom to top:
  1. Run the per-PR autofix loop (see "The loop" above) until:
       - CI is green for the current HEAD, AND
       - No unaddressed review threads.
  2. Announce ready-to-merge. STOP — do not merge. The user decides when,
     and with what strategy (squash vs. rebase vs. merge-commit) — that
     strategy choice affects step 4c.
  3. Watch for the merge. Poll `gh pr view <N> --json state,mergedAt` every
     60–120s in the background so the session stays responsive while you
     wait:
       - state MERGED → go to step 4.
       - state CLOSED without merge → the user rethought the stack. Exit
         the meta-loop and summarize.
       - Still OPEN after a long time → keep waiting; humans merge on
         their own schedule.
  4. Restructure the next PR up the stack onto its new base:
       a. `git fetch origin --prune`
       b. `git checkout <next-head>`
       c. Rebase onto the new base (usually `main`, sometimes a still-open
          lower PR if the stack skipped a level):
          - Default: `git rebase origin/<new-base>`.
          - If the parent was **squash-and-merged**, plain rebase can get
            confused — the squashed commit has the same content as the
            feature branch's commits but a different SHA. Use the
            explicit range form so only the commits unique to the next
            PR get replayed:
            `git rebase --onto origin/<new-base> <OLD_PARENT_TIP> <next-head>`
          - On conflicts: stop and ask the user. A conflict means the
            parent PR's final form drifted from what the upper PR was
            built against; auto-resolving risks silently losing changes.
       d. Update the PR's base on GitHub if it didn't auto-update:
          `gh pr edit <next-N> --base <new-base>`. (GitHub usually
          auto-updates stacked PRs when the parent branch is deleted on
          merge; if the repo disables branch deletion, do it manually.)
       e. Push: `git push --force-with-lease origin <next-head>`. Never
          plain `--force` — lease protects against clobbering a push
          someone else made since your last fetch.
       f. Re-enter the per-PR loop on the new HEAD. The first CI run after
          rebase is the real signal for this PR; any earlier runs
          included commits that are now part of main.
  5. Repeat 1–4 until the top of the stack is merged, then summarize.
```

### Why rebase, not merge

Both `git rebase origin/main` and `git merge origin/main` yield the same PR-vs-base diff. The difference is the branch's commit history:

- **Rebase** replays only the next PR's own commits on top of the new base. The linear history matches the PR diff exactly — no noise.
- **Merge** keeps the parent's commits in place and adds a merge commit. The PR-vs-base diff is the same, but the branch history has duplicate-looking commits (same subjects as the now-merged parent) plus a merge commit. Reviewers re-scanning the branch see clutter.

The user's "minimize the diff" ask means rebase. Use merge only if the repo convention forbids rebasing shared branches — uncommon for feature branches in a stack.

### Parallel reviews during the stack

Reviewers often comment on upper PRs while you're still iterating on the bottom. Don't context-switch mid push-cycle, but at natural seams (e.g., just after a CI-green checkpoint on the bottom PR, before announcing merge-ready), scan every stack PR for new review comments. Handle them where they were filed: a review on PR #13 gets fixed in PR #13's branch. If a review on an upper PR implies a change that logically belongs at the bottom (e.g., "rename this API"), fix it at the bottom and expect to re-rebase the upper PRs after the next merge.

If a reviewer asks to reshape the stack itself — collapse #13 into #12, split #12 in two, swap the order — stop and ask the user. Reshaping the stack is their call.

## Commands cheatsheet

Finding the run triggered by *this* push — always filter by the head commit SHA, not just the branch, because `--branch` on its own will happily include stale runs from earlier commits:
```bash
HEAD_SHA=$(git rev-parse HEAD)
gh run list --branch <branch> --commit "$HEAD_SHA" --limit 5 \
  --json databaseId,status,conclusion,headSha,workflowName,createdAt
```
If the PR is open against a fork or the head branch isn't your local one, substitute the SHA / branch from `gh pr view <N> --json headRefOid,headRefName`.

Blocking wait for a run:
```bash
gh run watch <run-id> --exit-status
```
`--exit-status` makes the command exit non-zero on failure so you can branch cleanly.

### Watching in the background

CI runs often take 2–10 minutes. Blocking the session for that long wastes the user's time and burns your context on idle output. Instead, run the watch in the background and let the harness notify you when it finishes:

- In Claude Code, start the watch with `Bash(..., run_in_background=true)`. You will be notified when the shell exits, with the exit code. Exit 0 → green → go to review handling. Non-zero → fetch `gh run view <id> --log-failed` and diagnose.
- While the watch runs in the background, do productive work the user has queued up, or hand control back and let them keep typing. Don't sit in a `sleep` loop polling; the harness is already watching the PID for you.
- If the user wants a clean hand-off and no further Claude involvement until CI finishes, `gh run watch <id> --exit-status &` in a detached shell with `nohup` and log to a file, then tell the user how to check on it themselves.
- For the common case of "push and wait", `gh pr checks <N> --watch` is an alternative that waits on *all* required checks for the PR (not just one run) and exits when every check settles. Use it when the workflow emits multiple jobs / multiple workflows you care about.

Avoid the anti-pattern of `sleep 300 && gh run view` — you lose the prompt cache past the 5-min window and you don't get signal any earlier than the real completion event.

Getting failure logs (only the failed steps — much shorter than `--log`):
```bash
gh run view <run-id> --log-failed
```

Re-running a single failed job (rarely useful — usually you want to fix first):
```bash
gh run rerun <run-id> --failed
```

PR state and merge status:
```bash
gh pr view <N> --json baseRefName,headRefName,mergeable,mergeStateStatus,statusCheckRollup
```

Review threads and inline comments:
```bash
gh api "repos/<owner>/<repo>/pulls/<N>/reviews"
gh api "repos/<owner>/<repo>/pulls/<N>/comments"   # inline review comments
gh api "repos/<owner>/<repo>/issues/<N>/comments"  # conversation comments
```

Pipe any of those through `python3 -c "import sys,json; ..."` to extract the fields you need — jq works too but isn't always installed.

## Handling failures

Read `--log-failed` first. Then classify:

### Formatter / linter failures
Run the formatter locally (`swift-format format -i`, `prettier --write`, `ruff format`, `cargo fmt`, etc.), re-run the linter to confirm clean, commit as "Format <area> to satisfy <tool>". These are usually the cheapest to auto-fix.

### Compile / build failures
Reproduce the exact command from the log (often pasted verbatim in the step). If it reproduces, fix the code. If it doesn't, the environment differs — check tool versions (`xcodebuild -version`, `swift --version`, `node --version`) between runner and local. The Xcode-15-vs-16 / project-format-77 case is a classic example: the fix was `runs-on: macos-14 → macos-15`, not a code change.

### Test failures
Re-run just the failing test locally first (`swift test --filter`, `pytest -k`, `cargo test --test`). If it reproduces, fix the code or the test — whichever is actually wrong. If it doesn't reproduce locally, suspect flakiness or environment drift; gather evidence (rerun the job, check timing/order) before assuming the test is flaky and disabling it. **Never** disable or `skip` a test just to get CI green — if a test is genuinely flaky, use the test framework's own skip mechanism with a TODO and a linked issue (XCTest: `throw XCTSkip("...")`; Swift Testing / JUnit / pytest each have their own equivalent), and tell the user explicitly that you did so.

### Base branch advanced during the loop
If the log mentions missing files the PR branch doesn't have, or the PR page shows "out of date", `git fetch origin main && git merge origin/main` (or `git rebase` if that's the repo convention). Resolve conflicts normally — don't `--strategy-option=ours` your way out. Then re-run local verification on the merged tree; new files from main may introduce their own formatter/build issues that need fixing in the same push.

## Handling review comments

List reviews + inline comments, filter to those newer than your last address cycle. For each:

- **Copilot / bot reviews with `suggestion` blocks**: treat the suggestion as a starting hypothesis, not truth. Evaluate whether the reasoning is correct before applying. If you apply, credit the change in the commit message ("Address PR review: ..."). If you disagree, say so in a reply and explain — blind deference to review bots is worse than honest disagreement.
- **Human reviews with code change requests**: apply the change, run local verification, push.
- **Questions / discussion**: reply in the right place. Use `gh pr comment <N> --body "..."` only for the top-level PR conversation. For an inline review comment/thread, that command won't attach to the thread — use the review-comment reply endpoint so the response is threaded:
  ```bash
  gh api -X POST "repos/<owner>/<repo>/pulls/<N>/comments/<comment-id>/replies" \
    -f body="your reply"
  ```
  Don't silently ignore questions.

Batch related review fixes into one commit when they're logically connected; split them if they're independent. Always mention "PR review" in the commit subject so the history is scannable.

## Safety rules

- **Iteration cap**: stop after 5 consecutive push cycles on the same failure class and hand back to the user with a summary. Infinite loops waste CI minutes and usually mean the fix direction is wrong.
- **Never force-push** unless a rebase or amend you performed requires it — and even then, use `--force-with-lease`, not `--force`. Notice-level: call it out in the user-facing summary when you force-pushed.
- **Never disable hooks** (`--no-verify`), skip signing, or bypass branch protection.
- **Never auto-merge**. Stop at "CI green, reviews addressed" and tell the user. They decide when to merge. This is especially important in stacks: the user's choice of merge strategy (squash vs. rebase vs. merge-commit) on the bottom PR directly affects how you rebase the next one, so you can't pre-empt that decision.
- **If you can't reproduce locally after 2 attempts**, stop and ask the user. Pushing "let's see what happens" to CI is rude to the runner and to future-you reading the history.
- **Destructive git operations** (`git reset --hard`, `git clean -fd`, branch deletion, force-push to shared branches) always require explicit user confirmation, even mid-loop.
- **Stack rebase conflicts**: stop and ask the user. A conflict during the post-merge rebase means the parent PR's final form (as it landed on main) drifted from what the upper PR was built against. Auto-resolving with `--strategy-option=ours`/`theirs` risks silently losing changes the user cares about; it's always cheap for the user to take a look.
- **Parent PR closed without merging**: exit the whole meta-loop and summarize. Don't advance to the next PR — the user has rethought the stack's shape and any rebase you do now would be working off an obsolete plan.

## Commit style

Each push in this loop should have a commit message that makes the history readable months later:

- Subject line explains *what* changed and *why* in one clause.
- Body (when useful) names the failing step / review comment the commit addresses, and the local verification that was run.
- Follow whatever attribution policy the repo uses. Some repos strip Co-Authored-By, some keep it — check for a CLAUDE.md note before assuming.

Example subjects that read well in hindsight:
- `Run CI on macos-15 for Xcode 16+ compatibility`
- `Format Phase 3 L1 profile sources to satisfy swift-format lint`
- `Address PR review: stabilize brew install and cover MoraMLX`

Avoid: `fix ci`, `wip`, `retry`, `another try`.

## Summarizing to the user

When the loop exits (success or cap hit), post a short summary:

- Which runs ran, final conclusion, and link(s).
- Commits added in the loop (one-line each).
- Review comments addressed (who, what).
- Anything still outstanding that needs the user's attention (e.g., flaky test that was disabled, a Copilot comment you disagreed with).

Keep it scannable — the user came back from lunch and wants the shape of what happened in 10 seconds, not a blow-by-blow.

For **stack runs**, group the summary by PR and make the stack state obvious: which PRs have landed, which is the currently active one, which are still queued behind it. One block per PR keeps it scannable. Example shape:

- PR #12 — **merged** at 14:22. 3 autofix commits; 2 Copilot reviews addressed.
- PR #13 — **merged** at 15:48. Rebased onto main after #12 (1 force-push-with-lease, no conflicts). 1 autofix commit; 0 new reviews.
- PR #14 — **active, ready-to-merge**. Rebased onto main after #13. 2 autofix commits, 1 human review addressed. CI green.
- PR #15 — queued; will restructure after #14 merges.

If you force-pushed-with-lease during a stack rebase, always call it out per-PR so the user can double-check the branch state before merging.

## Auto mode vs. confirm-first

In auto mode (user explicitly hands off and wants autonomy), run the loop continuously, only pausing for the safety rules above. Otherwise, after the first diagnosis, present your proposed fix and wait for a nod before pushing. When in doubt, err toward asking once up front — "I see X failing, I'm going to try Y and keep iterating, OK?" — then go heads-down until you hit the stop condition.
