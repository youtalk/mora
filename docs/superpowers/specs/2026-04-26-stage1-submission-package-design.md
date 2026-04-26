# Stage 1 Submission Package — Design

**Status:** Draft, 2026-04-26
**Hackathon:** Built with Opus 4.7 — A Claude Code Hackathon (Apr 21–28, 2026)
**Stage 1 deadline:** 2026-04-26 8:00 PM ET (Cerebral Valley submission platform)
**Author:** Yutaka Kondo

---

## 1. Goals

- **Primary:** Reach the Top 6 in Stage 1 async judging so that mora advances to the
  Stage 2 live final round on 2026-04-28 12:00 PM ET, competing for the
  $50K / $30K / $10K Top 3 prizes.
- **Secondary:** Naturally hit the **"Keep Thinking" $5K special prize** criterion —
  *"a real-world problem nobody thought to point Claude at."* Special prizes are
  drawn from all submissions, independent of Top 6.
- **Constraint:** All submission artifacts must be in English. Conversations with
  Claude during preparation may continue in Japanese.

## 2. Hackathon-confirmed requirements (from kickoff + 2026-04-26 official heads-up)

| Requirement | Status |
|---|---|
| Built from scratch during hackathon (Apr 21–28) | ✅ First commit `6398d63` is 2026-04-21; 100+ PRs in 5 days |
| 3-minute demo video on YouTube / Loom / Google Drive | YouTube unlisted (primary), Google Drive backup |
| Public GitHub repository during judging | github.com/youtalk/mora — public, MPL-2.0 (post-relicense) |
| Written description / summary in submission form | ~190-word draft below (§7) |
| Approved open source license, every component | MPL-2.0 for code, MIT for wav2vec2 model, NC inheritance disclosed for yokai assets |
| **Judging weights** (revised 2026-04-26) | Impact 30% / Demo 25% / **Opus 4.7 Use 25%** / Depth 20% |
| Top 6 advance to Stage 2 (2026-04-28) | n/a until results announced |
| Special prizes selected from all submissions | n/a |

## 3. Positioning narrative

**Lead:** "Build From What You Know" problem statement. A father builds an
on-device, dyslexia-aware ESL tutor for his own 8-year-old L1-Japanese son after
moving from Japan to the US, after the school's IEP-blocked-by-ESL policy adds a
one-year delay before his son gets structured dyslexia support, and after Barton
tutoring is priced out of reach.

**Supporting layer (Opus 4.7 Use 25%):** Built in 5 days with Claude Code and
Opus 4.7 — 100+ structured PRs each backed by a written spec and an
implementation plan, parallel sub-agents on isolated git worktrees collapsing
multi-phase content batches from 6h sequential to ~1h, and a custom Claude Code
skill that streams Apple OSLog from the running iPad straight into Claude's
context so debugging becomes a conversation instead of a screenshot round-trip.

**Why this combination:** Impact (30%) is mora's strongest pillar — a real domain
expert (the father) building for a real specific user (his own son) addresses
the highest-weighted criterion head-on. The Claude Code workflow innovations
directly hit Opus 4.7 Use (25%). Together they cover 55% of the rubric. Demo
(25%) is carried by the iPad recording itself; Depth (20%) is carried by the
five-package SPM architecture, the on-device CoreML wav2vec2 phoneme posterior,
and the volume of merged PRs.

## 4. Inputs (confirmed via brainstorming, this session)

| | |
|---|---|
| License | MPL-2.0 via `git filter-branch` rewrite over full history |
| Video shape | Hybrid — 5–10s opening shot of son's hands on iPad (no face), remainder iPad screen capture + voiceover |
| Voiceover | Yutaka's own voice in English — Japanese accent reinforces the "L1-Japanese family" authenticity |
| Yokai assets retention | Keep in demo and in the bundled app; document NC inheritance in README + landing page |
| Submission form | Cerebral Valley platform, separate fields for video URL / repo URL / summary |
| Bonus deliverable | github.io landing page at `https://youtalk.github.io/mora/` (YouTube embed + summary + deep dive), source under `docs/index.html` |

## 5. Deliverables

1. **3-minute demo video** — uploaded to YouTube as unlisted before submission;
   secondary copy on Google Drive shared link as redundancy.
2. **Public GitHub repository** — github.com/youtalk/mora, license rewritten to
   MPL-2.0 across all history, README and CLAUDE.md updated at HEAD.
3. **Written summary** — ~190 words, English, pasted into the CV submission form.
4. **github.io landing page** — `docs/index.html` rendered at
   `https://youtalk.github.io/mora/`, embedding the YouTube video, the written
   summary, and a Claude Code workflow deep-dive section.
5. **X/Twitter post** — English, ≤280 characters, tagging @claudeai @claudedevs
   @cerebral_valley with `#BuiltWithClaude #ClaudeCode`, attaching the
   "Built with Opus 4.7" graphic, linking to the landing page.
6. **LinkedIn post** — English, ~120 words, same tags + graphic, linking to the
   landing page.

## 6. Video script + storyboard

Restructured against Mike Brown's three-act × nine-pod framework
(Live Session 3, Built with Opus 4.6 winner): three acts of 60s, three pods of
~20s per act, one main message per pod. Nine messages total, in order.

### 6.1 Beat sheet (180s budget — 3 acts × 3 pods)

| Pod | Time | Visual | Message | Criterion |
|---|---|---|---|---|
| **Act 1 — The Problem** | | | | |
| 1.1 — Who | 0:00–0:20 | Opening shot: son's hands on iPad (no face) → home screen | Father, dyslexic 8yo son, L1-Japanese, US ESL | Impact |
| 1.2 — Why | 0:20–0:40 | Cut to a calendar/clock motif over the home screen | IEP gated behind ESL → 1-year delay; Barton priced out | Impact |
| 1.3 — What | 0:40–1:00 | Yokai weekly intro screen, voice clip plays under VO | "So I built mora" — OG phonics + yokai shell, fully on-device | Impact + Demo |
| **Act 2 — The Solution** | | | | |
| 2.1 — Multisensory decode | 1:00–1:20 | Tile-board activity, finger taps assembling a word | Multisensory phonics, every word decodable | Demo + Depth |
| 2.2 — On-device pronunciation | 1:20–1:40 | Say-the-word, mic icon, Engine A surfaces L1-Japanese substitution | INT8 wav2vec2 CoreML, v→b/l→r/sh→s coaching | Depth + Opus 4.7 Use |
| 2.3 — Decodable sentences | 1:40–2:00 | Sentence dictation, yokai voice, tiles fill in time | Generated against learner's mastered set | Demo + Depth |
| **Act 3 — The Build** | | | | |
| 3.1 — Velocity | 2:00–2:20 | Terminal: `git log --oneline \| wc -l` → 112; spec dir count | 100+ PRs in 5 days, every one with spec + plan | **Opus 4.7 Use** |
| 3.2 — Parallelism | 2:20–2:40 | Visualization of `git worktree list` + parallel agents | 4-phoneme batch: 6h sequential → 1h parallel sub-agents | **Opus 4.7 Use** |
| 3.3 — Custom skill + outro | 2:40–3:00 | Claude Code TUI consuming live OSLog → mora logo card | OSLog skill turns debug into a conversation; CTA | **Opus 4.7 Use** |

### 6.2 Voiceover script (English, ~340 words at ~140 wpm; pod-locked)

> **[Pod 1.1 — 0:00–0:20]**
> *(over: opening shot — son's hands on iPad, app's home screen)*
> "My son is eight. He has dyslexia. He's also learning English as a second
> language — his first language is Japanese, and our family moved from Japan
> to the US last year."

> **[Pod 1.2 — 0:20–0:40]**
> *(over: calendar / clock motif over home screen)*
> "His school's IEP — the structured plan for dyslexia support — is gated
> behind finishing ESL. That's a one-year delay before he gets the help he
> actually needs. Barton tutoring is priced out of reach."

> **[Pod 1.3 — 0:40–1:00]**
> *(over: weekly yokai intro screen, voice clip plays softly under the VO)*
> "So I built mora — an iPad app that pairs Orton-Gillingham phonics, the
> gold-standard dyslexia method, with a yokai mentor that greets him every
> week. Fully on-device. Nothing leaves the iPad."

> **[Pod 2.1 — 1:00–1:20]**
> *(over: tile-board decode activity, finger taps assembling 'sh-i-p')*
> "Multisensory phonics means moving the letters yourself. The tile board
> breaks every word into graphemes the learner has explicitly mastered, so
> what shows up is always decodable, never guessed from context."

> **[Pod 2.2 — 1:20–1:40]**
> *(over: say-the-word activity, mic icon, Engine A coaching feedback)*
> "Then he speaks. An INT8-quantized wav2vec2 phoneme posterior runs in
> CoreML. The engine catches L1-Japanese substitutions — v as b, l as r,
> sh as s — and turns them into coaching, not red Xs."

> **[Pod 2.3 — 1:40–2:00]**
> *(over: sentence dictation, yokai voice reads, tiles fill in real time)*
> "Decodable sentences round out the day. Each one is generated against the
> learner's mastered grapheme set. The yokai reads first; the tiles fill
> as the child speaks."

> **[Pod 3.1 — 2:00–2:20]**
> *(over: terminal showing `git log --oneline | wc -l` → 112; `ls docs/superpowers/specs | wc -l`)*
> "I'm not a Swift engineer. I built mora in five days with Claude Code and
> Opus 4.7. Over a hundred merged PRs — every one backed by a written spec
> and an implementation plan in the repo."

> **[Pod 3.2 — 2:20–2:40]**
> *(over: `git worktree list` output highlighted; parallel agents firing)*
> "Independent batches ran as parallel sub-agents on isolated git worktrees.
> A four-phoneme content library that would have taken six hours sequential,
> finished in one. Spec, plan, ship."

> **[Pod 3.3 — 2:40–3:00]**
> *(over: Claude Code TUI consuming live OSLog → mora logo card with URL,
> license, hashtags)*
> "I authored a Claude Code skill that streams iPad OSLog into Claude's
> context — debugging became a conversation. Mora is on-device, MPL-licensed,
> github.com slash youtalk slash mora. My son will keep using it on Monday.
> Built with Opus 4.7."

### 6.3 Production notes (Mike Brown framework, compressed)

**Order of operations (paper-cut first, then visuals):**

1. **Lock the script** (already done — §6.2 above). Mike's rule: voice track
   first, visuals second. Don't start cutting until the words are right.
2. **Hear the script before recording**. Either:
   - macOS `say -v Samantha -f script.txt` for a 5-min sanity pass, OR
   - 11labs / Whisper Flow voice clone of Yutaka's own voice → run the
     script through it once. Mike's specific advice: "I hate listening to
     my own voice. Don't use 11labs' library voices — use your own. You'll
     get the inflection."
3. **Record VO yourself** (Yutaka, English). Mike: "I was genuinely
   passionate about this thing. It comes across in my voice." Japanese
   accent reinforces the L1-Japanese family authenticity.
4. **Capture iPad B-roll while recording is being polished** (parallelizable).
   Each pod's visual is a separate clip; record each one focused, not as
   one continuous run-through.
5. **Lock the timeline at 2:59 BEFORE you start editing**. Mike's rule:
   "set the out point at 2:59:23 frames in Premiere; Black Magic / iMovie
   equivalent: trim to 03:00 max." Going over 3:00 = "you're going to get
   dinged."
6. **Cut, render, upload to YouTube unlisted**. Don't wait until the form
   is open — upload first, paste URL second.

**Recording mechanics:**

- **iPad screen capture**: Settings → Control Center → enable Screen
  Recording. Tap to record. AirDrop to Mac.
- **Opening shot of son's hands** (Pod 1.1): handheld phone, daylight,
  ~10s, no face. One take is enough.
- **B-roll for Act 3**: terminal recordings via `script -t timing.log
  output.log` or just QuickTime "New Screen Recording" of the terminal
  window. Claude Code TUI session can be screen-captured live with the
  `oslog-stream-to-file` skill running.

**Microphone**:
- AirPods Pro built-in is acceptable. MacBook internal mic floor is too
  high — avoid.
- Record in a small, soft-furnished room (clothes closet works) to kill
  echo.

**Editing tools** (pick one):
- **iMovie** (free, comes with macOS) — sufficient for a 3-min cut with
  voiceover and B-roll.
- **DaVinci Resolve / Black Magic** (free) — Mike's recommended free
  option, more powerful than iMovie if comfort allows.
- **Final Cut / Premiere** — paid, only if Yutaka already owns one.
- **XML import shortcut**: Mike's tip — Claude can write a Premiere /
  Resolve XML timeline from the paper-cut script + B-roll filenames.
  Available on request once footage is named.

**Captions**:
- Required for accessibility and muted-autoplay social distribution.
- Burn into the export, OR upload SRT alongside the YouTube unlisted video
  (YouTube will overlay).
- A timed-text SRT can be auto-generated from the §6.2 script if VO
  timestamps land on the pod boundaries.

**Aspect ratio + format**:
- 16:9 1920×1080 H.264 .mp4.
- Frame rate 24 or 30 fps; consistent throughout.

**Hard constraints**:
- Duration ≤ 180.0s (judges visibly cap and dock for over-runs).
- File size ≤ 256 MB recommended for fast YouTube processing.
- Upload to YouTube as **Unlisted** (not Private — judges need to view
  without sign-in).

**Backup**:
- Copy of the rendered file uploaded to Google Drive with a shared
  view-only link, kept ready in case YouTube processing stalls past the
  submission window.

## 7. Written summary draft (~190 words, English)

> **mora — an on-device, dyslexia-aware ESL tutor for L1-Japanese kids,
> built in 5 days with Claude Code and Opus 4.7.**
>
> My 8-year-old son has dyslexia. He's also learning English as a second
> language — we moved from Japan to the US last year. His school's IEP for
> dyslexia is gated behind finishing ESL, costing him a year. Barton
> tutoring is too expensive. So I built mora.
>
> Mora is an iPad app that pairs Orton-Gillingham phonics with a yokai RPG
> shell. A tile-board decoder enforces grapheme mastery. An on-device
> CoreML wav2vec2 phoneme model catches L1-Japanese substitutions
> (v→b, l→r, sh→s) and turns them into coaching, not red Xs. Nothing leaves
> the device.
>
> I'm not a Swift engineer. I shipped 100+ PRs in 5 days using Claude Code
> and Opus 4.7 — every PR backed by a written spec and a plan, parallel
> sub-agents on isolated git worktrees collapsing 4-phase content batches
> from 6 hours to 1, and a custom Claude Code skill that pipes live OSLog
> from the iPad into Claude's context so debugging becomes a conversation.
>
> 5 SPM packages, 456 files, MPL-2.0, fully open source.

## 8. License rewrite plan

### 8.1 Strategy: LICENSE-only history rewrite + HEAD relicense commit

Rewrite the `LICENSE` file in every commit via `git filter-branch --tree-filter`
to MPL-2.0. Leave README, CLAUDE.md, and historical specs/plans untouched in
history; update them at HEAD with a single relicense commit. Historical specs
that document the *decision-making journey* (e.g. `2026-04-21-license-history-rewrite-design.md`)
are kept verbatim as the project's own narrative record.

### 8.2 Filter-branch one-liner

```sh
# 1. MPL-2.0 full text staged
curl -fsSL https://www.mozilla.org/media/MPL/2.0/index.815ca599c9df.txt -o /tmp/mpl-2.0.txt
head -1 /tmp/mpl-2.0.txt | grep -Fqx 'Mozilla Public License Version 2.0'

# 2. Tree-filter rewrites LICENSE in every commit
git filter-branch --force --tree-filter '
  if [ -f LICENSE ]; then
    cp /tmp/mpl-2.0.txt LICENSE
  fi
' --tag-name-filter cat -- --all

# 3. Cleanup
git for-each-ref --format='%(refname)' refs/original/ | xargs -n 1 git update-ref -d
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

`filter-branch` is deprecated in favor of `git-filter-repo`; the time budget
favors the already-installed tool.

### 8.3 HEAD relicense commit (single PR, fast-track merged)

Updates required at HEAD only:

| File | Change |
|---|---|
| `README.md` | License section: PolyForm NC → MPL-2.0; link badge update; preserve yokai NC inheritance note |
| `CLAUDE.md` | License section refresh; note the 2026-04-26 relicense; preserve attribution opt-in policy |
| `tools/yokai-forge/README.md` | Repo-level license reference: PolyForm NC → MPL-2.0; commercial swap-out checklist preserved verbatim |
| `docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md` | "MIT-licensed and redistribution-compatible with PolyForm Noncommercial 1.0.0" → "MIT-licensed and OSS-redistribution-compatible" |
| `docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md` | Audit + adjust any PolyForm reference |
| `docs/superpowers/specs/2026-04-21-license-history-rewrite-design.md` | **Keep verbatim** — historical record |
| `docs/superpowers/plans/2026-04-21-license-history-rewrite.md` | **Keep verbatim** — historical record |

### 8.4 Risks & mitigations

- **Open PRs**: confirm none open before force-push; if any, close → rebase → reopen.
- **CI cache miss**: SHA-keyed caches will all miss after history rewrite —
  expect a slower first CI run after force-push. Buffer 15min in the timeline.
- **Existing forks**: youtalk/mora is unlikely to have forks (personal project).
  If any exist, force-push will leave them stranded; acceptable.
- **Release artifacts**: `models/wav2vec2-phoneme-int8-v1` GitHub Release tag is
  a separate object — its manifest references the upstream MIT model and is
  unaffected by the repo license change. No action.
- **Force-push approval**: filter-branch + force-push is destructive. Claude
  performs the rewrite locally, but the user explicitly approves the final
  `git push --force origin main` before it runs.

## 9. github.io landing page

### 9.1 Setup

- **Source**: `main` branch, `/docs` folder, GitHub Pages enabled in repo
  Settings → Pages.
- **Jekyll**: disabled via empty `docs/.nojekyll` so the existing
  `docs/superpowers/` markdown is served as raw files instead of being
  auto-built into navigation.
- **Single HTML file**: `docs/index.html` — self-contained, inline CSS, no
  external JS or build step.
- **URL**: `https://youtalk.github.io/mora/`.

### 9.2 Sections

```
[Hero]
  Mora — Built with Opus 4.7
  An on-device, dyslexia-aware ESL tutor for L1-Japanese kids.
  Built in 5 days for the Built with Opus 4.7 hackathon.

  [YouTube embed — 3-min demo]

  [GitHub repo →]   [License: MPL-2.0]   [Built with Claude Code]

[The problem]
  Father → son personal narrative (3 paragraphs).
  IEP-blocked-by-ESL structural gap.
  Barton tutoring out of reach.
  On-device privacy as a non-negotiable for a child user.

[What it does]
  - Yokai mentor + warmup
  - Tile-board decoding (multisensory phonics)
  - On-device pronunciation feedback (CoreML wav2vec2)
  - Decodable sentences
  Each ~80 words + a screenshot.

[How it's built]
  Architecture overview: 5 SPM packages, Core ← Engines ← UI, MLX & Testing
  cross-cut. No-cloud invariant. L1Profile abstraction. SwiftData persistence.

[Built with Claude Code]
  - 100+ structured PRs in 5 days, every one backed by spec + plan in the repo
  - Parallel sub-agents on isolated git worktrees: 6h → 1h on a 4-phoneme content batch
  - Custom skill `oslog-stream-to-file`: live OSLog from iPad piped into Claude's context
  - Spec-driven discipline: brainstorming → writing-plans → executing-plans
  - Authored skills: pr-autofix-loop, conduit-archive-to-app-store, oslog-stream-to-file

[Try it / Contribute]
  - Clone, xcodegen generate, build instructions
  - License: MPL-2.0; yokai assets carry NC inheritance — disclosed
  - Repo + author handles
```

### 9.3 Style

Dark theme matching mora's UI palette. System font stack. Max-width 760px.
Generous line-height. Inline CSS ≤80 lines. The "Built with Opus 4.7" graphic
is positioned in the hero.

## 10. README polish (judge-facing, HEAD commit)

- Hero badge row: `[License: MPL-2.0]` `[Built with Opus 4.7]`
  `[Hackathon Stage 1: 2026-04-26]`.
- Opening paragraph: elevator pitch matching the landing page hero.
- Move "Try it" / "First-time setup" near the top.
- Prominent link to `https://youtalk.github.io/mora/`.
- Embed YouTube video link.
- "Built with Opus 4.7" graphic image embed.
- Existing build/test instructions (XcodeGen / xcodebuild / swift-format) kept
  verbatim.

## 11. Social posts

### 11.1 X / Twitter

```
Built mora during @claudeai @claudedevs @cerebral_valley's Built with Opus 4.7 hackathon —
an iPad dyslexia + ESL tutor for my 8yo son.
On-device CoreML wav2vec2 catches L1-Japanese substitutions (v→b, l→r).
100+ PRs in 5 days w/ Claude Code.
https://youtalk.github.io/mora/
#BuiltWithClaude #ClaudeCode
```

Attach: "Built with Opus 4.7" graphic.
Character budget: ≤280 (current draft ~270 ASCII).

### 11.2 LinkedIn

```
I'm participating in Built with Opus 4.7, a Claude Code hackathon by Anthropic and Cerebral Valley.
It's a one-week sprint to build something with Claude Code and Opus 4.7.

I built mora — an iPad app for my 8-year-old son. He has dyslexia, and he's learning
English as a second language after our family moved from Japan to the US last year.
His school's IEP is gated behind finishing ESL — costing him a year of structured support.

Mora pairs Orton-Gillingham phonics with on-device CoreML pronunciation feedback. A
wav2vec2 phoneme model catches L1-Japanese substitutions (v→b, l→r) and turns them into
coaching, not red Xs. Nothing leaves the device.

I'm not a Swift engineer by trade. 100+ PRs in 5 days, every one backed by a written
spec, parallel sub-agents on isolated git worktrees, and a custom Claude Code skill that
streams live OSLog from the iPad into Claude's context.

https://youtalk.github.io/mora/

#BuiltWithClaude #ClaudeCode
```

Attach: "Built with Opus 4.7" graphic.

## 12. Order of operations (8-hour budget; deadline 8:00 PM ET)

### Phase 1 — Independent Claude-side prep (parallelizable, ~90 min)

- License filter-branch rewrite executed locally (force-push deferred to Phase 3).
- HEAD relicense commit drafted on a branch, ready to merge.
- README HEAD update drafted.
- `docs/index.html` + `docs/.nojekyll` authored.
- Written summary final pass.
- X / LinkedIn social post final pass.
- Video script + storyboard final pass; B-roll list handed to user.

### Phase 2 — User-side recording (sequential, ~3h)

- iPad screen recording per beat (yokai intro / tile-board / pronunciation /
  decodable sentence) → AirDrop to Mac.
- Opening shot — son's hands on iPad, 5–10s, no face.
- Voiceover record (Yutaka, English).
- Editing in iMovie or QuickTime.
- Render → upload to YouTube as unlisted.

### Phase 3 — Convergence & submit (~30 min)

- User approves force-push; Claude executes `git push --force origin main`.
- User enables GitHub Pages: Settings → Pages → Source = main / /docs.
- Claude verifies landing page renders with YouTube ID injected.
- Claude pushes README HEAD commit.
- User submits via Cerebral Valley platform: paste video URL, repo URL,
  ~190-word summary.
- User publishes X + LinkedIn posts with the Opus 4.7 graphic and the landing
  page URL.

**Buffer**: 30 min reserved at the tail.

### Critical-path risks

- **iPad ASR/TTS unstable on a fresh take** → fall back to a simulator screen
  recording for that single beat; rest of the video stays on real device.
- **YouTube upload stuck in processing** → use the Google Drive shared-link copy
  in the form; swap YouTube link in afterward via form edit (if supported).
- **Force-push CI fail** → re-run; the buffer absorbs one cycle.

## 13. Open items

- **Built with Opus 4.7 graphic image file** — PDF references "the photo we
  have attached separately"; the PNG itself is not yet on disk. User to source
  before social posts publish.
- **Cerebral Valley submission form fields** — not directly inspected; assumed
  to follow the standard pattern (separate fields for video URL, repo URL,
  summary). Verify when the user opens the form.
- **Live Session 3 video advice** — full transcript ingested 2026-04-26;
  Mike Brown's three-act × nine-pod framework, paper-cut-first ordering, voice
  cloning fallback, hard 2:59 out-point, XML-import shortcut, and tool
  selection (DaVinci Resolve as free Premiere alternative) are all folded into
  §6.1–§6.3. No remaining gap.

## 14. Out of scope

- **Stage 2 demo preparation** — only relevant if mora advances to the Top 6.
  A separate spec will be written between 2026-04-27 and 2026-04-28 if needed.
- **Post-event repo private toggle** — the hackathon allows it, but mora
  remains public for the foreseeable future as part of the project's
  open-source positioning.
- **Asset relicensing** — yokai portraits and voice clips remain under their
  upstream NC licenses. Replacing them with commercially-cleared equivalents
  is a future commercial-release concern, already documented in
  `tools/yokai-forge/README.md`.
- **Cloud telemetry / metrics** — no analytics added for the hackathon;
  on-device privacy invariant preserved.

## 15. Acceptance

- Filter-branch rewrite produces a `main` branch where every commit's `LICENSE`
  is the MPL-2.0 full text and CI is green after force-push.
- `https://youtalk.github.io/mora/` renders the landing page with the YouTube
  embed playing the 3-min demo.
- The Cerebral Valley form is submitted before 8:00 PM ET on 2026-04-26.
- X and LinkedIn posts are live with the Opus 4.7 graphic and the landing page
  URL, tagging @claudeai @claudedevs @cerebral_valley with the required
  hashtags.
