# Stage 1 Submission Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Submit mora to "Built with Opus 4.7" Stage 1 by 2026-04-26 8:00 PM ET (~7–8 h budget) with all required deliverables (3-min YouTube video, public MPL-2.0 GitHub repo, ~190-word summary, X + LinkedIn posts) plus a github.io landing page bonus.

**Architecture:** Three parallel tracks. Track A (Claude-side, ~90 min) produces all artifacts derivable from the spec — license history rewrite, HEAD relicense commit, github.io landing page, README polish. Track B (User-side, ~3 h, critical path) produces the 3-min demo video. Track C (~30 min) converges the two with force-push, GitHub Pages enable, and the actual form submission + social publish. All deliverable copy is already drafted in `docs/superpowers/specs/2026-04-26-stage1-submission-package-design.md` — tasks transcribe rather than re-author.

**Tech Stack:** `git filter-branch`, GitHub Pages (static HTML, no Jekyll), iOS Screen Recording, iMovie / DaVinci Resolve, YouTube Unlisted, Google Drive (fallback), Cerebral Valley submission platform, X, LinkedIn.

**Owner labels:** `[Cl]` = Claude executes, `[U]` = User executes (Yutaka).

**Branch state at start:** Worktree `starry-swimming-sifakis` is on `docs/2026-04-26-stage1-submission-package` at `c161265` (= `f1624ad` + spec `ccb13e3` + Mike Brown integration `c161265`).

**Sequencing constraints:**
- Filter-branch + force-push is destructive and requires explicit user approval at Task A4 before push.
- User-side recording is the critical path; Track A runs in parallel during Track B.
- All convergence steps wait until both A and B are complete.

---

## Track A — Claude-side prep (parallel during Track B)

### Task A1: [Cl] Merge spec branch into main locally

Bring main up to the spec HEAD so the upcoming filter-branch sweep covers the
spec's own commits.

**Files:** none modified — branch operation only.

- [ ] **Step 1:** Switch the main worktree (`/Users/yutaka.kondo/src/mora`) to main and confirm clean state.

```sh
git -C /Users/yutaka.kondo/src/mora status
git -C /Users/yutaka.kondo/src/mora rev-parse HEAD
```

Expected: branch `main` clean, HEAD = `f1624ad`.

- [ ] **Step 2:** Fast-forward main to the spec branch tip.

```sh
git -C /Users/yutaka.kondo/src/mora merge --ff-only docs/2026-04-26-stage1-submission-package
git -C /Users/yutaka.kondo/src/mora rev-parse HEAD
```

Expected: HEAD = `c161265` (or the latest spec commit), no merge commit, no conflicts.

- [ ] **Step 3:** Verify the spec file landed on main.

```sh
git -C /Users/yutaka.kondo/src/mora ls-tree --name-only HEAD docs/superpowers/specs/2026-04-26-stage1-submission-package-design.md
```

Expected: file path printed.

### Task A2: [Cl] Stage MPL-2.0 license text

Pre-fetch the canonical MPL-2.0 plain-text body so the filter-branch tree-filter
runs offline.

**Files:**
- Create: `/tmp/mpl-2.0.txt` (transient, not committed)

- [ ] **Step 1:** Download MPL-2.0 text.

```sh
curl -fsSL https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt -o /tmp/mpl-2.0.txt
wc -l /tmp/mpl-2.0.txt
head -3 /tmp/mpl-2.0.txt
```

Expected: ≥ 350 lines; first non-empty line begins with `Mozilla Public License Version 2.0`.

- [ ] **Step 2:** Sanity-check that it parses as a license.

```sh
grep -c '^[0-9]\+\. ' /tmp/mpl-2.0.txt
```

Expected: ≥ 9 (sections 1–10 numbered).

### Task A3: [Cl] Filter-branch rewrite LICENSE across history (LOCAL ONLY)

Replace the LICENSE file in every commit on main with MPL-2.0. **Force-push is
deferred to Task C2** — this task only modifies local refs.

**Files:**
- Modify: `LICENSE` (in every commit of main's history)

- [ ] **Step 1:** Confirm working tree is clean before destructive op.

```sh
git -C /Users/yutaka.kondo/src/mora status --porcelain
git -C /Users/yutaka.kondo/src/mora rev-parse HEAD
```

Expected: empty output (clean); HEAD matches Task A1 Step 2.

- [ ] **Step 2:** Tag the pre-rewrite commit so a recovery anchor exists.

```sh
git -C /Users/yutaka.kondo/src/mora tag pre-mpl-rewrite HEAD
```

- [ ] **Step 3:** Run filter-branch tree-filter.

```sh
cd /Users/yutaka.kondo/src/mora
git filter-branch --force --tree-filter '
  if [ -f LICENSE ]; then
    cp /tmp/mpl-2.0.txt LICENSE
  fi
' --tag-name-filter cat -- --all
```

Expected: completes with `Ref 'refs/heads/main' was rewritten`.

- [ ] **Step 4:** Cleanup refs/original.

```sh
git -C /Users/yutaka.kondo/src/mora for-each-ref --format='%(refname)' refs/original/ | xargs -n 1 git -C /Users/yutaka.kondo/src/mora update-ref -d
git -C /Users/yutaka.kondo/src/mora reflog expire --expire=now --all
git -C /Users/yutaka.kondo/src/mora gc --prune=now --aggressive
```

- [ ] **Step 5:** Spot-check that LICENSE in every commit is MPL-2.0.

```sh
cd /Users/yutaka.kondo/src/mora
for sha in $(git rev-list main | head -10); do
  echo "=== $sha ==="
  git show "$sha:LICENSE" 2>/dev/null | head -1
done
```

Expected: every shown line starts with `Mozilla Public License Version 2.0`.

### Task A4: [U] Approve force-push (gate, no execution)

Force-push is destructive. **DO NOT skip this gate.** The user explicitly
confirms that they have backed up `pre-mpl-rewrite` tag and that the rewrite
is intended.

- [ ] **Step 1:** User confirms approval in chat: "force-push approved".

(No command. This is a gate.)

### Task A5: [Cl] HEAD relicense commit — README.md

Update `README.md` to reflect MPL-2.0 + add hackathon-facing hero touches.

**Files:**
- Modify: `README.md` — header badges, License section, add landing-page link, embed video link, "Built with Opus 4.7" note.

- [ ] **Step 1:** Read current README to identify the License section anchor.

```sh
grep -n "PolyForm\|License" /Users/yutaka.kondo/src/mora/README.md
```

- [ ] **Step 2:** Apply targeted edits via Edit tool. Replace each section as follows:

**Top-of-file hero (insert immediately after `# Mora` line):**

```markdown
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)
[![Built with Opus 4.7](https://img.shields.io/badge/Built_with-Opus_4.7-orange.svg)](https://youtalk.github.io/mora/)
[![Hackathon Stage 1](https://img.shields.io/badge/Hackathon-Stage_1_2026--04--26-blue.svg)](https://youtalk.github.io/mora/)

> Submitted to Anthropic × Cerebral Valley **Built with Opus 4.7** hackathon (Apr 21–28, 2026). Demo video and full case study at <https://youtalk.github.io/mora/>.
```

**License section — replace the existing "License" block at file end with:**

```markdown
## License

[Mozilla Public License 2.0](./LICENSE). OSI-approved, App Store-compatible,
file-level weak copyleft.

Note: the yokai asset forge under `tools/yokai-forge/` depends on
**non-commercial** upstream models (FLUX.1-dev, Fish Speech S2 Pro). Any
generated portrait or voice clip inherits that restriction, so a future
commercial release would require regenerating those assets with
commercially-cleared models. See `tools/yokai-forge/README.md` § "Licensing —
commercial release requires swap-outs" for the swap-out checklist.

The bundled `wav2vec2-phoneme.mlmodelc` is derived from
`facebook/wav2vec2-xlsr-53-espeak-cv-ft` (MIT-licensed); attribution preserved
in `Packages/MoraMLX/Sources/MoraMLX/Resources/`.
```

- [ ] **Step 3:** Verify final README parses and renders cleanly.

```sh
grep -c "PolyForm" /Users/yutaka.kondo/src/mora/README.md
```

Expected: `0` (no remaining PolyForm references).

### Task A6: [Cl] HEAD relicense commit — CLAUDE.md

**Files:**
- Modify: `/Users/yutaka.kondo/src/mora/CLAUDE.md` — License section paragraph and any inline references.

- [ ] **Step 1:** Locate and replace the License-related paragraph.

Find:
```
The project is licensed under **PolyForm Noncommercial 1.0.0** (source-available, not OSI-approved). New dependencies must be compatible with noncommercial redistribution; avoid copyleft licenses (GPL family) that would conflict with App Store distribution.
```

Replace with:
```
The project is licensed under **Mozilla Public License 2.0** (OSI-approved,
App Store-compatible, file-level weak copyleft). The repository was relicensed
from PolyForm Noncommercial 1.0.0 on 2026-04-26 to satisfy the
"Built with Opus 4.7" hackathon's open-source requirement. New dependencies
must be MPL-2.0-compatible; avoid AGPL/GPL family licenses that would conflict
with App Store distribution (FSF's long-standing position; VLC removal
precedent).
```

- [ ] **Step 2:** Verify no stale PolyForm references remain.

```sh
grep -c "PolyForm" /Users/yutaka.kondo/src/mora/CLAUDE.md
```

Expected: `0`.

### Task A7: [Cl] HEAD relicense commit — tools/yokai-forge/README.md

**Files:**
- Modify: `/Users/yutaka.kondo/src/mora/tools/yokai-forge/README.md` — repo-level license reference; preserve the swap-out checklist verbatim.

- [ ] **Step 1:** Find and replace the repo-license reference.

Find: `The repo-level license (\`PolyForm Noncommercial 1.0.0\`) already blocks
commercial distribution`

Replace with: `The repo-level license (\`MPL-2.0\`) is OSS-permissive, so the
NC-encumbered assets are now the *only* commercial-distribution blocker`

- [ ] **Step 2:** Confirm.

```sh
grep -n "PolyForm\|MPL" /Users/yutaka.kondo/src/mora/tools/yokai-forge/README.md
```

Expected: only `MPL` appears, no `PolyForm`.

### Task A8: [Cl] HEAD relicense commit — internal specs

Two design specs reference PolyForm in technical context (compatibility
statements). Update those at HEAD. **Historical decision-record specs are
preserved verbatim** — only update specs whose statement-of-fact about license
compatibility would otherwise be wrong post-relicense.

**Files:**
- Modify: `docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md`
- Modify: `docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md` (audit only — change if PolyForm reference is statement-of-fact, not historical)
- Keep verbatim: `docs/superpowers/specs/2026-04-21-license-history-rewrite-design.md`
- Keep verbatim: `docs/superpowers/plans/2026-04-21-license-history-rewrite.md`

- [ ] **Step 1:** Locate and update the engine-B design spec line.

Find: `MIT-licensed and redistribution-compatible with PolyForm Noncommercial 1.0.0`
Replace with: `MIT-licensed and OSS-redistribution-compatible (MPL-2.0)`

- [ ] **Step 2:** Audit the alpha-design spec.

```sh
grep -n "PolyForm" /Users/yutaka.kondo/src/mora/docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md
```

If a statement-of-fact line appears, update it analogously. If it is a
historical narrative line ("the project chose PolyForm…"), leave it.

- [ ] **Step 3:** Verify the historical specs are untouched.

```sh
grep -c "PolyForm" /Users/yutaka.kondo/src/mora/docs/superpowers/specs/2026-04-21-license-history-rewrite-design.md
grep -c "PolyForm" /Users/yutaka.kondo/src/mora/docs/superpowers/plans/2026-04-21-license-history-rewrite.md
```

Expected: both ≥ 1 (historical references preserved).

### Task A9: [Cl] Stage HEAD relicense commit

**Files:**
- Add to staging: `README.md`, `CLAUDE.md`, `tools/yokai-forge/README.md`, the modified specs from Task A8.

- [ ] **Step 1:** Stage the changes in the main worktree.

```sh
cd /Users/yutaka.kondo/src/mora
git add README.md CLAUDE.md tools/yokai-forge/README.md docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md
# only if A8 Step 2 found a fact line:
# git add docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md
git status
```

Expected: 4–5 files staged.

- [ ] **Step 2:** Commit.

```sh
cd /Users/yutaka.kondo/src/mora
git commit -m "$(cat <<'EOF'
docs: relicense to MPL-2.0 — README, CLAUDE.md, yokai-forge, specs

Repository relicensed from PolyForm Noncommercial 1.0.0 to MPL-2.0 on
2026-04-26 to satisfy the "Built with Opus 4.7" hackathon open-source
requirement. PolyForm NC's non-OSI status conflicted with the hackathon's
"approved open source license" rule. MPL-2.0 is the closest spiritually
aligned OSI-approved license: file-level weak copyleft (preserves the
"share modifications" intent), App Store-compatible (Mozilla ships Firefox
iOS under MPL-2.0), and avoids the GPL/AGPL App Store conflicts.

Yokai asset NC inheritance from FLUX.1-dev / Fish Speech S2 Pro is
preserved and remains documented in tools/yokai-forge/README.md.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Task A10: [Cl] Create docs/.nojekyll

Disable Jekyll on GitHub Pages so `docs/index.html` is served raw and
existing markdown specs in `docs/superpowers/` are not auto-built into a
navigation tree.

**Files:**
- Create: `docs/.nojekyll` (empty file)

- [ ] **Step 1:** Touch the file.

```sh
touch /Users/yutaka.kondo/src/mora/docs/.nojekyll
ls -la /Users/yutaka.kondo/src/mora/docs/.nojekyll
```

Expected: file exists, size 0.

### Task A11: [Cl] Author docs/index.html landing page

Self-contained HTML, inline CSS, no external JS, embeds the YouTube video
(placeholder ID until B9 produces the real one).

**Files:**
- Create: `docs/index.html`

- [ ] **Step 1:** Write the landing page from the spec §9 sections.

Content (verbatim — write to `/Users/yutaka.kondo/src/mora/docs/index.html`):

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Mora — Built with Opus 4.7</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="An on-device, dyslexia-aware ESL tutor for L1-Japanese kids. Built in 5 days for the Built with Opus 4.7 hackathon.">
<meta property="og:title" content="Mora — Built with Opus 4.7">
<meta property="og:description" content="An on-device, dyslexia-aware ESL tutor for L1-Japanese kids. Built in 5 days for the Built with Opus 4.7 hackathon.">
<meta property="og:type" content="website">
<meta property="og:url" content="https://youtalk.github.io/mora/">
<style>
  :root { --bg:#0d0f11; --fg:#f1f4f6; --muted:#9aa4ad; --accent:#ffb86b; --rule:#1f242a; }
  * { box-sizing: border-box; }
  html, body { margin:0; padding:0; background:var(--bg); color:var(--fg); }
  body { font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; }
  main { max-width: 760px; margin: 0 auto; padding: 48px 24px 96px; }
  h1 { font-size: 40px; margin: 0 0 8px; letter-spacing: -0.02em; }
  h2 { font-size: 24px; margin: 48px 0 12px; letter-spacing: -0.01em; }
  h3 { font-size: 18px; margin: 24px 0 8px; }
  p { margin: 0 0 16px; }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }
  .lede { color: var(--muted); font-size: 18px; margin-bottom: 32px; }
  .badges a { display:inline-block; margin: 0 8px 8px 0; padding: 4px 12px; border-radius: 14px; background: var(--rule); color: var(--fg); font-size: 13px; }
  .video-wrap { position: relative; padding-top: 56.25%; margin: 24px 0 32px; background: #000; border-radius: 8px; overflow: hidden; }
  .video-wrap iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
  hr { border: 0; border-top: 1px solid var(--rule); margin: 48px 0; }
  ul { padding-left: 20px; }
  li { margin-bottom: 8px; }
  code { background: var(--rule); padding: 1px 6px; border-radius: 3px; font-size: 14px; }
  pre { background: var(--rule); padding: 12px 16px; border-radius: 6px; overflow-x: auto; font-size: 13px; }
  footer { color: var(--muted); font-size: 14px; margin-top: 64px; border-top: 1px solid var(--rule); padding-top: 24px; }
</style>
</head>
<body>
<main>

<h1>Mora — Built with Opus 4.7</h1>
<p class="lede">An on-device, dyslexia-aware ESL tutor for L1-Japanese kids. Built in 5 days for the <strong>Built with Opus 4.7</strong> hackathon (Anthropic × Cerebral Valley, Apr 21–28, 2026).</p>

<div class="badges">
  <a href="https://github.com/youtalk/mora">GitHub repo →</a>
  <a href="https://opensource.org/licenses/MPL-2.0">License: MPL-2.0</a>
  <a href="https://www.anthropic.com/claude-code">Built with Claude Code</a>
</div>

<div class="video-wrap">
  <iframe src="https://www.youtube.com/embed/REPLACE_WITH_YOUTUBE_ID" title="Mora — 3-min demo (Built with Opus 4.7)" allowfullscreen></iframe>
</div>

<h2>The problem</h2>
<p>My son is eight. He has dyslexia. He's also learning English as a second language — his first language is Japanese, and our family moved from Japan to the US last year.</p>
<p>His school's IEP — the structured plan for dyslexia support — is gated behind finishing ESL. That's a one-year delay before he gets the help he actually needs. Barton tutoring, the gold-standard structured-literacy program, is priced out of reach for a family-funded effort.</p>
<p>For a child user, on-device privacy is non-negotiable: no audio, no transcripts, no per-trial details may leave the iPad.</p>

<h2>What it does</h2>

<h3>Yokai mentor + warmup</h3>
<p>Each week, a hand-illustrated yokai mentor introduces the practice arc with a voiced clip. The yokai shell turns daily phonics practice into a quest, not a drill.</p>

<h3>Tile-board decoding (multisensory phonics)</h3>
<p>The tile board breaks every word into graphemes the learner has explicitly mastered, so what shows up on screen is always decodable, never guessed from context. Multisensory phonics — Orton-Gillingham's core — means moving the letters yourself.</p>

<h3>On-device pronunciation feedback</h3>
<p>The learner speaks. An INT8-quantized <code>wav2vec2-xlsr-53-espeak-cv-ft</code> phoneme posterior runs in CoreML. The engine catches L1-Japanese substitutions — <em>v</em> as <em>b</em>, <em>l</em> as <em>r</em>, <em>sh</em> as <em>s</em> — and turns them into targeted coaching, not red Xs. No audio leaves the device.</p>

<h3>Decodable sentences</h3>
<p>Each sentence is generated against the learner's mastered grapheme set. The yokai reads first; the tiles fill as the child speaks.</p>

<hr>

<h2>How it's built</h2>
<p>Five local Swift packages with one-way dependencies — <code>MoraCore ← MoraEngines ← MoraUI</code>, with <code>MoraTesting</code> and <code>MoraMLX</code> cross-cutting. The thin <code>Mora/</code> iOS app target wires SwiftData and presents <code>RootView</code>; all real logic lives in the packages.</p>
<ul>
  <li><strong>MoraCore</strong> — domain model + SwiftData persistence; <code>L1Profile</code> protocol with <code>JapaneseL1Profile</code> as the v1 implementation.</li>
  <li><strong>MoraEngines</strong> — <code>SessionOrchestrator</code> state machine, <code>AssessmentEngine</code>, <code>SpeechEngine</code> / <code>TTSEngine</code> protocols, <code>CurriculumEngine</code>, <code>ContentProvider</code>, <code>TemplateEngine</code>.</li>
  <li><strong>MoraUI</strong> — SwiftUI only; views observe the orchestrator, never own business logic.</li>
  <li><strong>MoraTesting</strong> — fakes shared across test targets.</li>
  <li><strong>MoraMLX</strong> — CoreML-bundled wav2vec2 phoneme posterior; reserved for future MLX-hosted on-device LLM work.</li>
</ul>
<p><strong>On-device invariant:</strong> no raw audio, transcripts, or per-trial details leave the device. The only planned cloud touchpoint is CloudKit private DB for parent-mode sync — not in the v1 scope.</p>

<h2>Built with Claude Code</h2>
<p>I'm not a Swift engineer by trade. I built mora in five days with Claude Code and Opus 4.7. Some of the workflow was deliberately structured to push the model:</p>
<ul>
  <li><strong>100+ structured PRs in 5 days</strong> — every one backed by a written spec under <code>docs/superpowers/specs/</code> and an implementation plan under <code>docs/superpowers/plans/</code>. Spec → plan → execute, repeat.</li>
  <li><strong>Parallel sub-agents on isolated git worktrees.</strong> A four-phoneme decodable-sentence content batch that would have taken six hours sequential, finished in one — each phase ran as a separate sub-agent on its own git worktree, no cross-batch state. The default "no parallel implementation agents" guidance from the superpowers skill set applies to single-worktree conflicts; <code>isolation: "worktree"</code> defeats it because each agent gets its own filesystem copy.</li>
  <li><strong>Custom <code>oslog-stream-to-file</code> skill.</strong> Streams Apple OSLog from the running iPad into <code>/tmp/&lt;repo&gt;.log</code>, which Claude reads directly via the <code>Read</code> tool. The classic debug round-trip ("user takes a screenshot of Console.app, pastes it") collapses into a conversation.</li>
  <li><strong>Spec-driven discipline.</strong> Brainstorming → writing-plans → executing-plans, with the user-side review gate at each step. Self-authored skills include <code>pr-autofix-loop</code> (monitor GitHub Actions + Copilot reviews, fix, push, repeat until green) and <code>conduit-archive-to-app-store</code> (CLI orchestration of <code>Product → Archive → Validate → Distribute</code> in parallel for iOS + Mac Catalyst).</li>
</ul>

<h2>Try it</h2>
<pre>git clone https://github.com/youtalk/mora.git
cd mora
bash tools/fetch-models.sh   # downloads + SHA-verifies the wav2vec2 CoreML model
xcodegen generate
open Mora.xcodeproj</pre>
<p>Build the <code>Mora</code> scheme against an iPad simulator. Code is licensed under <a href="https://opensource.org/licenses/MPL-2.0">MPL-2.0</a>; bundled yokai portraits and voice clips inherit non-commercial restrictions from FLUX.1-dev and Fish Speech S2 Pro — disclosed in <code>tools/yokai-forge/README.md</code>.</p>

<footer>
  <p>Built with <a href="https://www.anthropic.com/claude-code">Claude Code</a> + <strong>Opus 4.7</strong> during the <a href="https://www.cerebralvalley.ai/">Cerebral Valley</a> × <a href="https://www.anthropic.com">Anthropic</a> hackathon, Apr 21–28, 2026. <a href="https://github.com/youtalk/mora">github.com/youtalk/mora</a> · <a href="https://x.com/y_kondoh">@y_kondoh</a></p>
</footer>

</main>
</body>
</html>
```

- [ ] **Step 2:** Lint check for unmatched tags / placeholder.

```sh
grep -c "REPLACE_WITH_YOUTUBE_ID" /Users/yutaka.kondo/src/mora/docs/index.html
```

Expected: `1` (one placeholder, replaced in Task C7).

### Task A12: [Cl] Stage landing-page commit

**Files:**
- Add: `docs/.nojekyll`, `docs/index.html`

- [ ] **Step 1:** Commit.

```sh
cd /Users/yutaka.kondo/src/mora
git add docs/.nojekyll docs/index.html
git commit -m "$(cat <<'EOF'
docs: github.io landing page for hackathon submission

Self-contained docs/index.html (inline CSS, no JS, no build step) at
https://youtalk.github.io/mora/. Embeds the 3-min YouTube demo, recaps the
problem / what it does / how it's built / Built with Claude Code workflow
innovations / try-it instructions. docs/.nojekyll disables Jekyll so the
existing docs/superpowers/ markdown is served raw rather than built into a
navigation tree.

YouTube embed ID is a placeholder pending Task B9 upload completion.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2:** Confirm history.

```sh
git -C /Users/yutaka.kondo/src/mora log --oneline -5
```

Expected: top three commits are the spec, the relicense, the landing page (in
some order on top of the rewritten f1624ad-equivalent).

### Task A13: [Cl] Local CI dry-run before force-push

Verify that the rewritten history + HEAD changes still build and lint clean.

- [ ] **Step 1:** swift-format strict (matches CI).

```sh
cd /Users/yutaka.kondo/src/mora
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

Expected: no output (clean) or only warnings; exit code 0.

- [ ] **Step 2:** Build (matches CI).

```sh
cd /Users/yutaka.kondo/src/mora
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3:** Per-package SPM tests (sample one to confirm nothing broke).

```sh
cd /Users/yutaka.kondo/src/mora/Packages/MoraCore
swift test 2>&1 | tail -3
```

Expected: `Test Suite '...' passed`.

(Auto mode discretion: if all three steps pass, skip running the other four
package suites — the existing CI on push will cover them.)

---

## Track B — User-side video production (critical path, sequential)

### Task B1: [U] Listen-pass on the script

Mike Brown's rule: hear the script before recording. A 5-minute self-listen
catches awkward phrasing the eye misses.

- [ ] **Step 1:** From the spec §6.2, save the voiceover script (just the
spoken lines, one pod per file) into `/tmp/script.txt`. The spec content
is already finalized — copy verbatim, strip stage directions.

- [ ] **Step 2:** macOS TTS readback.

```sh
say -v "Daniel" -r 140 -f /tmp/script.txt
```

Note any awkward phrasing; adjust before recording. Total runtime ~2:30 (TTS
slightly faster than human VO).

### Task B2: [U] Capture iPad screen recordings — one per pod

Pods 1.3, 2.1, 2.2, 2.3 are all in-app screens. Capture them in distinct,
focused takes — not as one continuous run-through.

- [ ] **Step 1:** Enable iOS Screen Recording: Settings → Control Center →
add Screen Recording.
- [ ] **Step 2:** Open mora on iPad. Begin a new A-day session.
- [ ] **Step 3:** Pod 1.3 — Yokai weekly intro. Tap-record from Control
Center; let the yokai voice clip finish; stop. Save with a clear name (e.g.
`pod_1_3_yokai.mp4`).
- [ ] **Step 4:** Pod 2.1 — Tile-board decoding. Re-enter the tile board
view; record finger taps assembling a word with a `sh` cell (most polished
phoneme).
- [ ] **Step 5:** Pod 2.2 — Pronunciation feedback. Record the say-the-word
activity. Speak deliberately; let Engine A surface a coaching response.
- [ ] **Step 6:** Pod 2.3 — Decodable sentences. Record sentence dictation
with the yokai reading first.
- [ ] **Step 7:** AirDrop all four files to the Mac, into a fresh
`~/mora-stage1-video/` folder.

### Task B3: [U] Capture opening shot (Pod 1.1)

5–10s of son's hands on iPad. **No face.** One take is enough.

- [ ] **Step 1:** Set up iPad on a table or lap with mora's home screen
visible. Daylight if possible (window light is fine).
- [ ] **Step 2:** Use a phone (held by Yutaka or spouse) to record the son's
hands tapping the screen. Frame from the side or over-shoulder; verify face
is out of frame.
- [ ] **Step 3:** AirDrop to Mac into `~/mora-stage1-video/pod_1_1_hands.mp4`.

### Task B4: [U] Capture B-roll for Act 3

- [ ] **Step 1:** Pod 3.1 — Terminal screen recording.

```sh
cd /Users/yutaka.kondo/src/mora
git log --oneline | wc -l
ls docs/superpowers/specs/ | wc -l
ls docs/superpowers/plans/ | wc -l
```

QuickTime → New Screen Recording → frame the terminal → run the commands
sequentially with deliberate pauses (~1 s each). Keep total clip ≤ 20 s.

- [ ] **Step 2:** Pod 3.2 — `git worktree list` recording.

```sh
git -C /Users/yutaka.kondo/src/mora worktree list | head -10
```

Same QuickTime workflow. Highlight the multiple `agent-*` worktree entries
to show parallel sub-agent reality.

- [ ] **Step 3:** Pod 3.3 — Claude Code TUI session recording.

Open a Claude Code session, run a quick query, optionally with the
`oslog-stream-to-file` skill output visible. Aim for ~15s of "Claude
reading live device logs" feel. If that's hard to stage on short notice,
substitute a recording of `tail -f /tmp/mora.log` showing live OSLog rows.

### Task B5: [U] Record voiceover

- [ ] **Step 1:** Quiet room (clothes closet works for kill-echo). AirPods
Pro plugged in, or USB mic if available.
- [ ] **Step 2:** Open QuickTime → New Audio Recording. Verify input source.
- [ ] **Step 3:** Record each pod as a separate take. Pause between pods.
9 takes total.
- [ ] **Step 4:** Listen back. If a pod is rushed/flat, redo it. Don't
perfect — Mike's rule: "you'll hate all of them, but there's going to be
moments where you're like, that's not so bad."

### Task B6: [U] Lock the timeline at 2:59 in editor

- [ ] **Step 1:** Open chosen editor (iMovie / DaVinci Resolve / Premiere).
- [ ] **Step 2:** Create new 16:9 1920×1080 24fps project.
- [ ] **Step 3:** Set the project end / out-point at 2:59:00 (iMovie:
Modify → Project Properties → set duration; DaVinci: Inspector → set out;
Premiere: O key at 02:59:23 frame).
- [ ] **Step 4:** Drop pod video clips on the V1 track in script order.
Drop voiceover takes on A1.

### Task B7: [U] Cut and assemble

- [ ] **Step 1:** Trim each pod video to ~20s, aligning with the matching VO
take. Allow ~0.5s of breath between pods.
- [ ] **Step 2:** Add a one-second yokai logo card at 2:59 → 3:00 fade-out
(simple title clip with "Mora · MPL-2.0 · github.com/youtalk/mora").
- [ ] **Step 3:** Verify the timeline ends at exactly 3:00:00 or earlier.
**Hard cap.**

### Task B8: [U] Add captions

- [ ] **Step 1:** Generate SRT from the §6.2 script. Easiest path:
YouTube auto-generate after upload (Task B9), then download SRT and re-upload
as official captions.
- [ ] **Step 2:** Alternative — burn captions in via the editor (iMovie:
Titles; DaVinci: Subtitle track). Keeps muted-autoplay social distribution
working from day 1.

### Task B9: [U] Render and upload to YouTube unlisted

- [ ] **Step 1:** Export 1920×1080 24fps H.264 .mp4 at ≤ 256 MB.
- [ ] **Step 2:** YouTube Studio → Upload → set Visibility = **Unlisted** (NOT Private).
- [ ] **Step 3:** Title: `Mora — Built with Opus 4.7 (3-min demo)`.
- [ ] **Step 4:** Description (paste):

```
Mora — an on-device, dyslexia-aware ESL tutor for L1-Japanese kids. Built in 5 days for Anthropic × Cerebral Valley's "Built with Opus 4.7" hackathon (Apr 21–28, 2026).

Repo: https://github.com/youtalk/mora
Landing page: https://youtalk.github.io/mora/
License: MPL-2.0

#BuiltWithClaude #ClaudeCode
```

- [ ] **Step 5:** Wait for processing. Note the 11-character video ID from the URL (e.g. `https://youtu.be/AbCdEfGhIjK` → `AbCdEfGhIjK`).
- [ ] **Step 6:** Share the video ID back to Claude in chat for Task C7.

### Task B10: [U] Upload Google Drive backup

- [ ] **Step 1:** Upload the same .mp4 to Google Drive.
- [ ] **Step 2:** Set sharing → "Anyone with the link, Viewer".
- [ ] **Step 3:** Copy the share URL. Keep it ready as fallback for Task C8 if
YouTube has issues.

---

## Track C — Convergence (final, sequential, after A and B)

### Task C1: [U] Source the "Built with Opus 4.7" graphic image

PDF references "the photo we have attached separately" — the PNG is required
for X + LinkedIn posts.

- [ ] **Step 1:** Check email / Discord / Drive for the asset attachment.
- [ ] **Step 2:** Save into `~/Downloads/built-with-opus-4-7.png`.

### Task C2: [Cl] Force-push main to origin (destructive — gated by Task A4)

**This step requires Task A4 confirmation in chat before execution.**

- [ ] **Step 1:** Verify `pre-mpl-rewrite` tag still exists locally (recovery anchor).

```sh
git -C /Users/yutaka.kondo/src/mora tag -l | grep pre-mpl-rewrite
```

Expected: `pre-mpl-rewrite`.

- [ ] **Step 2:** Force-push.

```sh
git -C /Users/yutaka.kondo/src/mora push --force origin main
```

Expected: `+ <old-sha>...<new-sha> main -> main (forced update)`.

### Task C3: [Cl] Watch CI on the new main HEAD

- [ ] **Step 1:** Watch the CI run. Allow up to 15 min for full pipeline (cache miss + cold build).

```sh
gh run watch --exit-status $(gh run list --branch main --limit 1 --json databaseId --jq '.[0].databaseId')
```

Expected: `✓` exit on success.

- [ ] **Step 2:** If any job fails, pull logs and fix on a new commit.

```sh
gh run view $(gh run list --branch main --limit 1 --json databaseId --jq '.[0].databaseId') --log-failed | tail -100
```

(If failure is in cache-keying, no fix needed — second push will warm.)

### Task C4: [U] Enable GitHub Pages

GitHub UI step — Claude can verify but not click.

- [ ] **Step 1:** Open https://github.com/youtalk/mora/settings/pages.
- [ ] **Step 2:** Source = `Deploy from a branch`. Branch = `main`. Folder = `/docs`. Save.
- [ ] **Step 3:** Wait ~1 min for first deploy. UI shows
"Your site is live at https://youtalk.github.io/mora/".

### Task C5: [Cl] Verify landing page renders

- [ ] **Step 1:** HTTP-fetch and confirm 200.

```sh
curl -fsSI https://youtalk.github.io/mora/ | head -1
```

Expected: `HTTP/2 200`.

- [ ] **Step 2:** Sanity-check served content.

```sh
curl -fsS https://youtalk.github.io/mora/ | grep -o '<title>[^<]*</title>'
```

Expected: `<title>Mora — Built with Opus 4.7</title>`.

### Task C6: [Cl] Substitute YouTube ID into landing page

User provides the YouTube ID from Task B9 Step 6 in chat.

- [ ] **Step 1:** Edit `docs/index.html`, replacing `REPLACE_WITH_YOUTUBE_ID`
with the actual 11-character ID.

- [ ] **Step 2:** Commit and push.

```sh
cd /Users/yutaka.kondo/src/mora
git add docs/index.html
git commit -m "$(cat <<'EOF'
docs: wire YouTube video ID into landing page

Replaces the REPLACE_WITH_YOUTUBE_ID placeholder with the unlisted demo
video ID from Task B9 of the Stage 1 submission plan.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 3:** Wait ~1 min for Pages to redeploy. Confirm:

```sh
curl -fsS https://youtalk.github.io/mora/ | grep -o "youtube.com/embed/[A-Za-z0-9_-]*"
```

Expected: real ID, not placeholder.

### Task C7: [U] Verify CV form structure

- [ ] **Step 1:** Open Cerebral Valley submission platform (URL provided by
the hackathon comms).
- [ ] **Step 2:** Inspect form fields. Two cases:
  - **Case A — separate fields** (expected): video URL field, repo URL
    field, summary text field. Use the standard path (Task C8).
  - **Case B — single URL** (fallback): submit `https://youtalk.github.io/mora/`
    as the unified link; the landing page contains all three deliverables.

### Task C8: [U] Submit the CV form

Using whichever path Task C7 confirmed.

- [ ] **Step 1 (Case A):**
  - Video URL: paste YouTube unlisted URL.
  - GitHub repo URL: `https://github.com/youtalk/mora`.
  - Summary: paste from spec §7 (verbatim, 188 words).

- [ ] **Step 1 (Case B):**
  - Submission URL: `https://youtalk.github.io/mora/`.

- [ ] **Step 2:** Submit. Capture the confirmation screenshot.

### Task C9: [U] Publish X / Twitter post

- [ ] **Step 1:** Compose new post on x.com. Paste from spec §11.1 verbatim.
- [ ] **Step 2:** Attach `~/Downloads/built-with-opus-4-7.png`.
- [ ] **Step 3:** Verify @claudeai @claudedevs @cerebral_valley are tagged
correctly (autocomplete may resolve them).
- [ ] **Step 4:** Verify `#BuiltWithClaude #ClaudeCode` are present.
- [ ] **Step 5:** Verify the landing page URL is intact.
- [ ] **Step 6:** Post.

### Task C10: [U] Publish LinkedIn post

- [ ] **Step 1:** Compose new post on linkedin.com. Paste from spec §11.2.
- [ ] **Step 2:** Attach `~/Downloads/built-with-opus-4-7.png`.
- [ ] **Step 3:** Add hashtags `#BuiltWithClaude #ClaudeCode`.
- [ ] **Step 4:** Post.

### Task C11: [Cl] Acceptance verification

Run through the spec's §15 acceptance criteria.

- [ ] **Step 1:** Confirm every commit on main has MPL-2.0 LICENSE.

```sh
for sha in $(git -C /Users/yutaka.kondo/src/mora rev-list main | head -10); do
  git -C /Users/yutaka.kondo/src/mora show "$sha:LICENSE" 2>/dev/null | head -1
done | sort -u
```

Expected: a single line — `Mozilla Public License Version 2.0`.

- [ ] **Step 2:** Confirm landing page is live and embedding the YouTube video.

```sh
curl -fsS https://youtalk.github.io/mora/ | grep -c "youtube.com/embed/[A-Za-z0-9_-]\{11\}"
```

Expected: `1`.

- [ ] **Step 3:** Confirm CI is green on main.

```sh
gh run list --branch main --limit 3 --json conclusion --jq '.[].conclusion'
```

Expected: top entry is `success`.

- [ ] **Step 4:** Confirm CV form submitted (user reports timestamp).
- [ ] **Step 5:** Confirm X + LinkedIn posts live (user reports URLs).

---

## Self-review notes

- **Spec coverage:** every spec section §1–§15 has at least one task. License
  rewrite §8 → A2/A3/A4/A5–A9/C2. Landing page §9 → A10/A11/A12/C5/C6.
  README polish §10 → A5. Social posts §11 → C9/C10. Order of operations §12
  → entire plan (Tracks A/B/C). Acceptance §15 → C11.
- **Placeholder scan:** `REPLACE_WITH_YOUTUBE_ID` in `docs/index.html` is the
  only intentional placeholder; resolved in Task C6.
- **Type / signature consistency:** N/A (no library code).
- **Destructive op gate:** Task A4 is the gate; Task C2 is the action; both
  reference each other.

---

## Risk register

| Risk | Probability | Mitigation |
|---|---|---|
| YouTube processing stalls past 8 PM ET | low | Task B10 Google Drive backup; Task C8 Case B uses Drive URL |
| iPad ASR/TTS unstable in a take | medium | Per-pod re-takes (B2 Step 3–6); fallback to simulator screen recording for the affected pod only |
| Force-push CI failure | low | Task C3 catches it; recovery via `pre-mpl-rewrite` tag if catastrophic |
| Cerebral Valley form differs from assumption | low | Task C7 Case B (single-URL via landing page) handles it |
| Built with Opus 4.7 graphic not findable | medium | Task C1 sources before C9/C10; if missing, post without graphic and add later |
| swift-format strict fail on rewritten history | very low | Task A13 catches before push |
| Pages doesn't pick up changes | low | Task C5 verifies; manual cache bust by re-saving Pages source if stuck |
