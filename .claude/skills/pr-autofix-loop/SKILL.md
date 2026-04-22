---
name: pr-autofix-loop
description: After a pull request is opened or updated, enter a monitoring-and-auto-fix loop — watch every triggered GitHub Actions run via `gh run watch`, pull Copilot / human review comments via `gh api`, diagnose failures, apply fixes locally, run local build/test verification, commit, push, and repeat until CI is green and reviews are addressed. Use this skill whenever the user says "monitor and fix it after opening the PR", "keep auto-fixing until CI passes", "watch and autofix", "babysit the PR", "handle review feedback and monitor CI for this PR", or anything asking Claude to take a PR from red/reviewed to green/addressed without manual polling in between. Also trigger when the user hands off a just-pushed branch and expects Claude to drive it to a merge-ready state.
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

## When to invoke

Trigger on any of:

- The user just ran `gh pr create` (or asked you to) and said something like "watch it", "babysit", "monitor and fix", "keep pushing until green".
- The user posted a link to a specific failing Actions run or review on the current PR and says "fix this".
- A previous iteration of this loop ran and the user said "keep going" / "continue".

Don't invoke for unrelated tasks like "run the tests" one-off or generic debugging — this skill is specifically for the **push → watch → diagnose → fix → push** cycle.

## The loop

```
loop:
  1. Find the latest run for the head commit on the PR branch
  2. gh run watch <id> --exit-status
     - success → step 4
     - failure → step 3
  3. Diagnose with `gh run view <id> --log-failed`, fix locally,
     run local verification, commit, push, go to step 1
  4. Fetch review comments; if any new ones are unaddressed, handle
     them (code change OR a reply explaining) and go to step 1
  5. If run is green AND review comments are all addressed → stop
```

The most important discipline: **always reproduce locally and verify the fix before pushing**. CI is slow and expensive and seeing your own fix fail on the runner tells you very little you couldn't have learned in seconds locally. The one exception is when the failure is environment-specific (e.g., the runner's toolchain differs from yours) and the local repro isn't possible — in that case, name the hypothesis in the commit message so the next failing log either confirms or refutes it.

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
- **Never auto-merge**. Stop at "CI green, reviews addressed" and tell the user. They decide when to merge.
- **If you can't reproduce locally after 2 attempts**, stop and ask the user. Pushing "let's see what happens" to CI is rude to the runner and to future-you reading the history.
- **Destructive git operations** (`git reset --hard`, `git clean -fd`, branch deletion, force-push to shared branches) always require explicit user confirmation, even mid-loop.

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

## Auto mode vs. confirm-first

In auto mode (user explicitly hands off and wants autonomy), run the loop continuously, only pausing for the safety rules above. Otherwise, after the first diagnosis, present your proposed fix and wait for a nod before pushing. When in doubt, err toward asking once up front — "I see X failing, I'm going to try Y and keep iterating, OK?" — then go heads-down until you hit the stop condition.
