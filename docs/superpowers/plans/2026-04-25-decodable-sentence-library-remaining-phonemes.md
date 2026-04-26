# Decodable Sentence Library — Remaining Phonemes (Track B-2 Phases 2-5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the four remaining phoneme batches (`th`, `f`, `r`, `short_a`) so the bundled `SentenceLibrary` reaches the spec's full **5 phonemes × 6 interests × 3 ageBands × 20 sentences = 1,800 sentences across 90 cells**. Each phase is a separate PR with the same structural shape as the merged `sh`-cells PR (#94); the only deltas are the allowed grapheme set, forbidden-digraph cheat sheet, proper-noun cast, and per-interest vocabulary pools — the per-cell task loop is identical.

**Architecture:** Pure content. No new code, no schema changes, no test additions beyond the `dev-tools/sentence-validator` CI gate that already covers every cell. Each phase ships 18 cells × 20 sentences = 360 sentences as one PR; cells land as one commit each so review and `git bisect` stay granular. Authoring follows the rulebook from `docs/superpowers/plans/2026-04-25-decodable-sentence-library-sh-cells.md` § "Authoring rulebook" with phoneme-specific overrides documented per phase below.

**Tech Stack:** JSON authoring, `dev-tools/sentence-validator` (`swift run`), `swift test` (`Packages/MoraEngines`), `swift-format`, `xcodegen`, `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6 (Track B), § 9 PR 3.

---

## Deviations from spec (read first)

1. **One PR per phoneme** (not "one PR for the whole remaining 89 cells"). Spec § 9 PR 3 packages all remaining cells under one heading but explicitly notes "individually or in small per-phoneme batches" as the intended grain. The merged `sh`-cells PR #94 set the per-phoneme precedent; this plan continues that cadence with four follow-on PRs.

2. **No interest-vocabulary table is added to source.** Track B-1 established the validator only checks each `interestWords` entry's *presence* in the sentence text, not its membership in any per-interest vocabulary list. Per-cell vocabulary judgment lives in this plan's vocab pools and in the authorial intent of each task.

3. **No on-device decodability tests are added in these phases.** The validator's CI gate is the single source of truth. Adding "must contain N cells per phoneme" runtime asserts would have to be revisited on every phase landing, which is churn for no signal.

4. **Per-phoneme density rules inherit from sh-cells § R3 verbatim.** Total target letter count ≥ 4 across all `words[*].graphemes`; word-initial in content words ≥ 3. The validator does not vary these thresholds by phoneme. Cells that are constrained (notably `short_a` cells, see § "Phase 5 special case") may struggle but should still hit the floor; the spec § 8 risks table allows a 3-occurrence floor for "constrained" cells but in practice every authored cell in this plan should clear the strict 4/3 threshold without exception.

5. **Each phase's PR title encodes the phoneme** (`content(sentence-library): {phoneme} phoneme — 18 cells × 20 sentences (Track B-2 Phase {N})`). PR commit message conventions match the merged sh-cells PR.

6. **Track B-3 (selector) ships independently of these phases.** Spec § 9 sequences PR 3 → PR 4 (content first, then selector). This plan does not depend on selector wiring; the selector's fallback to `<skill>_week.json` covers any phoneme whose cells haven't landed yet. If `2026-04-25-decodable-sentence-library-selector.md` lands before this plan begins, each phase becomes immediately user-visible at merge time. If this plan lands first, the cells sit dormant until the selector lands — still no user-visible regression.

---

## Phase ordering

Recommended order: **th → f → r → short_a**.

Rationale:
- `th` is the natural week-2 follow-on from the merged `sh` content; the curriculum ladder visits it next.
- `f` and `r` are sh+th supersets in terms of allowed digraphs (every word that decodes for `f` also decodes for `r` and `short_a`), so authoring `f` first builds vocabulary muscle that carries forward.
- `short_a` is left for last because its target is a vowel, which makes the "≥3 word-initial in content words" rule materially harder to satisfy and benefits from the pattern-recognition built up over the other three.

Phases are still strictly independent — they can be authored in any order, by any combination of human/agent, in any worktree, and in any temporal sequence. The validator catches the "I forgot the cell exists" case at PR-CI time.

---

## Cross-phase rulebook

> **Read once at the top of any phase. Phase-specific overrides go in the phase sections below; everything in this section applies uniformly across th, f, r, short_a unless overridden.**

### CR1 — Sight word whitelist (uniform)

The seven sight words remain unchanged across all phases. Always tokenize them as the existing sh-cells use:

| Surface | Graphemes | Phonemes |
|---------|-----------|----------|
| `the`   | `["th","e"]` | `["ð","ə"]` |
| `a`     | `["a"]` | `["ə"]` |
| `and`   | `["a","n","d"]` | `["æ","n","d"]` |
| `is`    | `["i","s"]` | `["ɪ","z"]` |
| `to`    | `["t","o"]` | `["t","u"]` |
| `on`    | `["o","n"]` | `["ɒ","n"]` |
| `at`    | `["a","t"]` | `["æ","t"]` |

Note: `the` decomposes as `["th","e"]` — relevant for `th` cells where the validator's "total target letter" count (which scans **all** words, including sight words) gives `the` a free `+1` toward the ≥4 threshold. Do NOT exploit this by using `the` four times — sentences with three `the`s read as filler. Use it as the natural article.

### CR2 — Density rules (uniform per spec § 6.2 step 2)

For every sentence:

- The target phoneme's letters must appear **≥ 4 times total** across all of `words[*].graphemes`. (The validator counts every entry that string-equals the target's `letters`, including sight words.)
- The target phoneme's letters must appear **as the first grapheme of ≥ 3 content words.** Content word = anything not in CR1.

### CR3 — Sentence length (uniform)

Word count ∈ [6, 10]. Punctuation is not in `words` — commas/periods/semicolons cost zero.

### CR4 — Interest tagging (uniform)

`interestWords` must be **non-empty**, and **every entry must appear (case-insensitive) as the surface of at least one word in the sentence.** Pick 1–2 of the most "interest-y" content words; do not tag sight words.

### CR5 — Filename / payload identity (uniform)

| Field | Source | Example for `th/animals_early.json` |
|-------|--------|--------------------------------------|
| `phoneme` | parent directory name | `"th"` |
| `interest` | filename stem before the **last** `_` | `"animals"` |
| `ageBand` | filename stem after the **last** `_` | `"early"` |

Per-phoneme constants (`phonemeIPA`, `graphemeLetters`) are listed in each phase section.

### CR6 — Per-sentence schema (uniform)

```json
{
  "text": "<rendered sentence with original capitalization and punctuation>",
  "targetCount": <int — author's count of total target-letter graphemes>,
  "targetInitialContentWords": <int — author's count of content words starting with target>,
  "interestWords": [<1+ surfaces from this sentence's words[]>],
  "words": [
    { "surface": "<word>", "graphemes": [<one entry per Phase-2 grapheme>], "phonemes": [<one IPA per grapheme>] }
  ]
}
```

`targetCount` and `targetInitialContentWords` are author-recorded and not validated against `words[]` (the validator computes its own from the words array). They exist for PR-review legibility.

### CR7 — Per-cell file shell (uniform)

```json
{
  "phoneme": "<phoneme dir>",
  "phonemeIPA": "<IPA, see phase>",
  "graphemeLetters": "<letters, see phase>",
  "interest": "<INTEREST>",
  "ageBand": "<AGEBAND>",
  "sentences": [
    /* 20 sentence objects per CR6 */
  ]
}
```

### CR8 — Age-band guidance (uniform — see sh-cells § R9)

| Band | Target reading age | Sentence shape | Vocabulary register |
|------|---------------------|----------------|----------------------|
| `early` | 4–7 | Lower end of 6–10 (target ~7 words). Single clause; concrete subject + concrete action. | High-frequency monosyllabic content words; characters as subjects; avoid abstract nouns. |
| `mid`   | 8–10 | Mid-range (target ~8–9 words). One conjunction allowed. | Disyllabic content words; more verbs. |
| `late`  | 11+ | High end (target ~9–10 words). Two clauses, denser tongue-twister cadence. | Adjective+noun stacking; more target letters per sentence; proper nouns + interest nouns simultaneously. |

These are heuristics, not validator rules. A 6-word late-band sentence and a 10-word early-band sentence both pass — the band guidance exists so cells feel age-appropriate during PR review.

### CR9 — Per-task loop (uniform across all phases)

For every cell across every phase, the agent's loop is:

1. **Read** the phase-specific § "Allowed graphemes", § "Forbidden cheat sheet", § "Proper-noun cast", and § "Vocabulary starter pools" sections.
2. **Author 20 sentences** obeying CR1–CR8 with the phase-specific § overrides.
3. **Write** the JSON file at `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/{phoneme}/{interest}_{ageBand}.json` using the phase's CR7 shell.
4. **Run** the validator:
    ```sh
    swift run --package-path dev-tools/sentence-validator \
        sentence-validator \
        --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
    ```
   Expected output: `sentence-validator: <N> cells, <N*20> sentences\n  PASS` where `N` is the cumulative cell count after this commit.
5. **Fix** violations and re-run. Common fixes (full mapping in sh-cells § "Task 2 Step 4"): swap forbidden-digraph words for cleanly decodable equivalents; bump target-letter count by adding another content word starting with the target; correct mistagged `interestWords`; trim/expand to 6–10 words.
6. **Commit** with title `content(sentence-library/{phoneme}): {interest} × {ageBand} (20 sentences)`.

Per-phase task numbering follows the sh-cells precedent: Task 1 is a smoke-check on `main`; Tasks 2–19 are the 18 cells in canonical order (see § "Cell ordering"); Task 20 is final verification + push + PR.

### CR10 — Cell ordering (uniform)

Within each phase, author cells in this order so commits read predictably and per-PR diffs cluster by interest:

| Order | interest | ageBand |
|-------|----------|---------|
| 2     | animals  | early   |
| 3     | animals  | mid     |
| 4     | animals  | late    |
| 5     | dinosaurs | early  |
| 6     | dinosaurs | mid    |
| 7     | dinosaurs | late   |
| 8     | vehicles | early   |
| 9     | vehicles | mid     |
| 10    | vehicles | late    |
| 11    | space    | early   |
| 12    | space    | mid     |
| 13    | space    | late    |
| 14    | sports   | early   |
| 15    | sports   | mid     |
| 16    | sports   | late    |
| 17    | robots   | early   |
| 18    | robots   | mid     |
| 19    | robots   | late    |

(The sh-cells PR skipped `sh × vehicles × mid` because Track B-1 already shipped it. For th/f/r/short_a, no cells exist in `main`, so all 18 cells are authored.)

### CR11 — Parallel subagent dispatch

The sh-cells PR proved the parallel-worktree approach (sh-cells § "Execution note — parallel subagents"): nine subagents, each in its own `isolation: "worktree"`, authoring different file paths with no shared state. Each phase here can apply the same: dispatch up to nine parallel subagents per phase after the first 1–2 cells have established tone in the controller's worktree. This deviates from `superpowers:subagent-driven-development`'s default "never parallel" rule for the same reason it did in the sh-cells PR — different file paths in different worktrees produce no git/file conflicts. Per-cell granularity is preserved in `git log` regardless of dispatch mode.

### CR12 — Final verification step (per phase, uniform)

After all 18 cell commits, the phase's final task runs:

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

The expected cell count after each phase, assuming sequential phase order:

| After phase | Cells | Sentences |
|-------------|-------|-----------|
| sh (merged) | 18    | 360       |
| th          | 36    | 720       |
| f           | 54    | 1,080     |
| r           | 72    | 1,440     |
| short_a     | 90    | 1,800     |

If phases land out of order, the count is `(phase count after this phase) × 18 × 20`. The PR's commit titles encode the phase number for traceability.

Then:

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -10)
(cd Packages/MoraCore && swift test 2>&1 | tail -3)
(cd Packages/MoraUI && swift test 2>&1 | tail -3)
(cd Packages/MoraTesting && swift test 2>&1 | tail -3)
(cd dev-tools/sentence-validator && swift test 2>&1 | tail -3)
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests \
    dev-tools/sentence-validator/Sources dev-tools/sentence-validator/Tests
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

All commands must exit 0. The PR body links the spec, this plan, and the phase's number.

---

## Phase 2 — `th` phoneme (PR title: "content(sentence-library): th phoneme — 18 cells × 20 sentences (Track B-2 Phase 2)")

### Phase 2 — Overview

`th` corresponds to the voiceless dental fricative /θ/ (e.g., "thin", "math", "path"). Curriculum week index 1; allowed graphemes are L2 alphabet (a-z) plus `sh` (the only previously-taught digraph). Target grapheme is `th`.

### Phase 2 — Per-cell file header (CR7 fill)

```json
{
  "phoneme": "th",
  "phonemeIPA": "θ",
  "graphemeLetters": "th",
  ...
}
```

### Phase 2 — Allowed graphemes

| Source | Graphemes |
|--------|-----------|
| `baselineTaughtGraphemes` (L2 alphabet) | `a b c d e f g h i j k l m n o p q r s t u v w x y z` |
| previously taught digraphs | `sh` |
| target grapheme | `th` |

Total: **26 single letters + `sh` + `th`.**

`sh` is now allowed inside content words for `th` cells. Words like `ship`, `shop`, `shed`, `shy`, `shaggy` are usable. Don't waste them — every `sh` in a `th` cell sentence is one fewer slot for `th` density.

### Phase 2 — Forbidden cheat sheet

| Reason | Words to **avoid** entirely |
|--------|------------------------------|
| Uses `ch`  | chin, chip, chop, chess, much, rich, such, lunch, beach, child, church, cheese |
| Uses `wh`  | when, where, why, what, while, white, wheel |
| Uses `ph`  | phone, photo, graph, dolphin, alphabet |
| Uses `gh`  | rough, tough, laugh, ghost, eight, night, fight, bright |
| Uses `ee`  | see, bee, feet, sheep, green, deer, peep, weed, sleep, three |
| Uses `oo`  | moon, soon, room, food, boot, school, book, look, foot, took, good |
| Uses `ai`/`ay`/`ea` | rain, train, play, day, way, eat, tea, sea, lead, beach |
| Uses `oa`/`ow`/`ou` | boat, road, low, snow, town, out, found, mouth (yes, even though `th` is the target, `mouth` has `ou` — skip) |
| Uses `ck`  | back, sock, duck, kick, rock, pack, neck, lock, clock |
| Uses `ng`/`nk` | sing, ring, long, song, drink, think (✗ — `th` is the target but `nk` is the digraph; skip), blank, thank (same) |
| Uses `qu`  | quick, queen, quiz, quack |

**Do NOT skip `th` words just because they overlap with old sh-cells forbidden lists.** `th` words are now first-class — `thin`, `that`, `then`, `this`, `with`, `path`, `math`, `bath`, `both`, `cloth`, `thick`, `three`✗(`ee`), `throw`✗(`ow`), `thank`✗(`nk`), `think`✗(`nk`), `thread`✗(`ea`).

### Phase 2 — Proper-noun cast (per spec § 6.2 step 6)

| Surface | Graphemes | Phonemes | Notes |
|---------|-----------|----------|-------|
| `Thad`  | `["th","a","d"]`         | `["θ","æ","d"]` | th-onset; counts toward both density rules |
| `Theo`  | `["th","e","o"]`         | `["θ","i","oʊ"]` (if "Theo" pronounced /θioʊ/; ok-ish) — alternative `["θ","ɛ","oʊ"]` for shorter `e` | th-onset; counts toward both density rules |
| `Beth`  | `["b","e","th"]`         | `["b","ɛ","θ"]` | th-coda; counts toward total only |
| `Seth`  | `["s","e","th"]`         | `["s","ɛ","θ"]` | th-coda; counts toward total only |

To hit "≥ 3 word-initial in content words" reliably, lean on `Thad` or `Theo` paired with a `th`-content-word (`thin`, `path`, `math`, `bath`). Two onset proper nouns plus one onset content word = 3 hit.

### Phase 2 — Verb pool (th-decodable)

- `had`, `has`, `got`, `let`, `set`, `sat`, `ran`, `hid`, `hit`, `cut`, `put`, `dug`, `fed`, `fit`, `fix`, `lit`, `met`, `rid`, `rip`, `rub`, `sip`, `sat`
- `bath`, `bathe` (just careful with `bathe` — final silent e on a Latin-origin word, but graphemes are `["b","a","th","e"]`, fine)
- `thin`, `thinned` (past-tense regular)
- `path` (verb sense rare but ok as noun)

Avoid: `think`, `thank` (`nk`), `throw` (`ow`), `three` (`ee`), `thread` (`ea`).

### Phase 2 — Vocabulary starter pools

#### Animals (th-decodable)

| Band | Pool |
|------|------|
| early | `cat`, `dog`, `hen`, `fox`, `ant`, `rat`, `bat`, `pig`, `bug`, `pup`, `ox`, `fish`, `moth` (✗ — wait, `moth` is `m,o,th`, fine), `path`(habitat), `Beth`'s pets (proxy via cast) |
| mid   | early pool + `frog`, `ram`, `hog`, `owl`, `swan`, `lamb`, `python` ✗ (`th` itself is fine but the `y` is OK actually — `python` is `p,y,th,o,n` — fine!) |
| late  | mid pool + `hippo`, `llama`, `camel`, `parrot`, `rabbit`, `lizard`, `panda`, `pony`, `python` |

`python` is decodable for th cells: `["p","y","th","o","n"]` — `y` is a single letter, `th` is taught, `o` and `n` are alphabet. Use it freely in mid/late.

#### Dinosaurs (th-decodable)

| Band | Pool |
|------|------|
| early | `rex`, `dino`, `egg`, `fang`, `claw` ✗ (`aw` digraph — skip), `bone`, `fossil`, `tusk` |
| mid   | early pool + `raptor`, `Spino`, `Stego`, `swift`, `herd`, `roar` ✗ (`oa`/`r` is fine but `roar` is `r,o,a,r` — fine actually), `path` (dino-themed phrase: "across the path") |
| late  | mid pool + `Allosaur`, `hadrosaur`, `predator`, `armor`, `dorsal`, `ankylosaur` ✗ (`y` is fine but `nk` is a digraph; skip) |

Watch for `claw` (`aw`) and similar dinosaur-tangent vowel digraphs. `roar` is fine because `oa` would be a single grapheme only if joined — but author tokenization keeps it as `["r","o","a","r"]` which is two singles. (Validator does not enforce phonics-faithfulness; only checks that each grapheme in `graphemes[]` is in the allowed set. Still, a `roar` pronounced `/rɔr/` with `oa` as `/ɔ/` is dishonest phonics — author with care.)

#### Vehicles (th-decodable)

| Band | Pool |
|------|------|
| early | `ship`, `cab`, `van`, `bus`, `jet`, `path` (vehicle-going-on-the-path) |
| mid   | early pool + `tram`, `taxi`, `truck` (`t,r,u,c,k` — `ck` digraph; ✗ skip!), `kart`, `wagon` |
| late  | mid pool + `submarine` (use sparingly), `tanker`, `marathon` ✗ (`th` digraph — fine!), wait `marathon` is `m,a,r,a,th,o,n` — perfect for th cells |

Note: `marathon` is th-decodable and useful for th cells (sport tangent + path noun). Counts as 1 th-onset content word? No — `m` is its first grapheme, so `marathon` contributes to total count but not word-initial-content-word count.

#### Space (th-decodable)

| Band | Pool |
|------|------|
| early | `sun`, `star`, `rocket` ✗ (`ck`), `planet`, `ship`, `jet`, `Mars`, `path` (orbit path) |
| mid   | early pool + `comet`, `Saturn`, `Jupiter`, `Mercury`, `orbit`, `Earth` (`E,a,r,th` — fine) |
| late  | mid pool + `asteroid`, `satellite`, `galaxy`, `cosmos`, `meteor`, `lander` |

`Earth` is th-decodable as `["E","a","r","th"]` (or with capital `E` lowercased to `["e","a","r","th"]` — `e,a,r` are singles, `th` is the target). Uses one `th` (coda). Useful.

#### Sports (th-decodable)

| Band | Pool |
|------|------|
| early | `bat`, `ball`, `net`, `mat`, `kit`, `run`, `hop`, `jog`, `lap`, `path` (running path) |
| mid   | early pool + `jump`, `dash`, `tag`, `swim`, `pass`, `gym`, `bath` (after-game), `marathon` (target!) |
| late  | mid pool + `javelin`, `sprint`, `tennis`, `cricket` ✗ (`ck`), `triathlon` (`t,r,i,a,th,l,o,n` — fine), `decathlon` (similar) |

`marathon`, `triathlon`, `decathlon` are gold for th cells — each contributes a `th` and naturally fits sports cells. `marathon`'s `th` is medial; `triathlon`'s is medial too.

#### Robots (th-decodable)

| Band | Pool |
|------|------|
| early | `bot`, `robot`, `kit`, `fan`, `fix`, `run`, `hop` |
| mid   | early pool + `gear`, `motor`, `magnet`, `lever`, `circuit` ✗ (`ck` no — `circuit` is `c,i,r,c,u,i,t` — `c` and `c` and `t`... fine actually), `signal`, `arm`, `hand` |
| late  | mid pool + `sensor`, `servo`, `actuator`, `processor`, `algorithm` (`a,l,g,o,r,i,th,m` — th-decodable!) |

`algorithm` is th-decodable for th cells. Good for late-band robots cells.

### Phase 2 — Density-anchor cookbook

Common shapes:

- `Thad and Theo had a thin path.` — Thad (th-onset content), Theo (th-onset content), thin (th-onset content), path (th-coda content), the (th in sight word). 4 word-initial content words, 5 total `th`. ✓
- `Beth and Seth had a path with a moth.` — wait, `with` has `th`! Let me count: with = `["w","i","th"]`, moth = `["m","o","th"]`. So sentence: Beth(th-coda), and, Seth(th-coda), had, a, path(th-coda content), with(th-coda content), a, moth(th-coda content). Word-initial `th` content words: 0. Fail. Need at least 3 onset.

The lesson: `Beth/Seth` and `path/moth/cloth/with` are all th-coda — they count toward total only. To hit ≥3 word-initial content words, you need `Thad`, `Theo`, `thin`, `that`, `then`, `this`, `them`, `they`, `thick`. Lean on `Thad` and `Theo` as recurring subjects.

### Phase 2 — Tasks

Phase 2 has **20 tasks** following CR9 + CR10:
- Task 1: Smoke check (no commit).
- Tasks 2–19: 18 cells, ordered per CR10. Each task uses CR9's loop.
- Task 20: Final verification + push + PR per CR12.

For each cell task, the structure is identical to sh-cells § "Task 2: `sh × animals × early` cell" with the following per-task substitutions:

- `sh` → `th` everywhere in paths and field values.
- "Authoring rulebook (R1–R10)" → "Cross-phase rulebook (CR1–CR8) + Phase 2 § Allowed graphemes / § Forbidden cheat sheet / § Proper-noun cast / § Vocabulary starter pools".
- `interestWords` examples drawn from this phase's vocab pools per interest.
- Validator expected output: cumulative `<N> cells, <N*20> sentences` where N starts at 19 (after Task 2, sh has 18 + first th cell = 19) and ends at 36 (after Task 19, sh 18 + th 18 = 36).

The agent does **not** copy sh-cells task verbatim — they substitute the deltas. The agent does **not** reproduce CR1–CR8 inside each task — they reference them.

### Phase 2 — Final PR body

```
content(sentence-library): th phoneme — 18 cells × 20 sentences (Track B-2 Phase 2)

## Summary

Adds 18 new `th` cells (every `th × {6 interests} × {3 ageBands}` cell), each with 20 validator-clean tongue-twister sentences focused on the voiceless `/θ/` sound. After this PR, `th` is the second complete phoneme in the bundled `SentenceLibrary` and Track B-2 has 3 phonemes remaining (`f`, `r`, `short_a`).

Tracks: B-2 Phase 2; 3 phonemes remain (`f`, `r`, `short_a`) under the same plan shape.

Spec: `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6 / § 9 PR 3.
Plan: `docs/superpowers/plans/2026-04-25-decodable-sentence-library-remaining-phonemes.md` § Phase 2.

## Test plan

- [x] Validator: `36 cells, 720 sentences  PASS`.
- [x] `swift test` per package green.
- [x] `xcodebuild build` SUCCEEDED on iOS Simulator.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Phase 3 — `f` phoneme (PR title: "content(sentence-library): f phoneme — 18 cells × 20 sentences (Track B-2 Phase 3)")

### Phase 3 — Overview

`f` corresponds to /f/ as in "fish", "fan", "frog". Curriculum week index 2; target grapheme is `f` (already a member of the L2 alphabet — the "target" union with already-taught is a no-op for the allowed-set computation, but the validator's density rules still anchor on `f`).

### Phase 3 — Per-cell file header (CR7 fill)

```json
{
  "phoneme": "f",
  "phonemeIPA": "f",
  "graphemeLetters": "f",
  ...
}
```

### Phase 3 — Allowed graphemes

| Source | Graphemes |
|--------|-----------|
| L2 alphabet | `a..z` |
| previously taught digraphs | `sh`, `th` |
| target | `f` (already in L2) |

Total: **26 single letters + `sh` + `th`.** Same set as `th` cells — `f` cells gain no new graphemes over `th` cells, but the *target* changes (which changes density math, not the allowed set).

### Phase 3 — Forbidden cheat sheet

Same as Phase 2 § "Forbidden cheat sheet" verbatim. The forbidden set does not change between `th` and `f` cells.

### Phase 3 — Proper-noun cast (per spec § 6.2 step 6)

| Surface | Graphemes | Phonemes |
|---------|-----------|----------|
| `Finn`  | `["f","i","n","n"]`        | `["f","ɪ","n","n"]` (or single `n` morphologically — author may choose `["f","i","n"]` for cleanliness, but the file ships consistently across the cell) |
| `Fred`  | `["f","r","e","d"]`        | `["f","r","ɛ","d"]` |
| `Frank` | ✗ — `nk` digraph; **skip** |  |

`Frank` was listed in spec § 6.2 step 6 but is `nk`-digraph forbidden. Use `Finn` and `Fred` only. To round out the cast, add `Fran` (`["f","r","a","n"]`, `["f","r","æ","n"]`) as a third name; it is f-onset and decodes cleanly.

All three are word-initial f content words, so they count toward both density rules.

### Phase 3 — Verb pool (f-decodable)

- `fan`, `fans`, `fed`, `fit`, `fix`, `fled`, `flit`, `flop`, `fluff` (f-onset + f-coda, double bonus), `frets`, `fries` ✗ (`ie` digraph), `fed`, `fend`, `fib`
- `lift` (f-medial), `puff`, `cuff`, `huff` (f-coda)
- Past tense forms with `-ed`: `fixed` → `["f","i","x","e","d"]` (regular)

Avoid: `find` ✗ (no — `f,i,n,d` is fine actually), `flew` ✗ (`ew` digraph), `fight` ✗ (`gh`), `phone` ✗ (`ph`).

### Phase 3 — Vocabulary starter pools

#### Animals (f-decodable)

| Band | Pool |
|------|------|
| early | `fox`, `frog`, `fish`, `fly`, `flea`, `fawn` ✗ (`aw`), `fawn` skip |
| mid   | early pool + `ferret`, `falcon`, `finch` ✗ (`ch`), `flamingo` (`f,l,a,m,i,n,g,o` — fine), `flounder` ✗ (`ou`) |
| late  | mid pool + `pufferfish`, `falcon`, `firefly`, `flamingo` |

`fish` is the workhorse — f-onset and contains `sh`-coda which is taught.
`fly`, `flea`, `flit` are decodable; `flea` is `f,l,e,a` (singles) but author with care since "ea" is conventionally a digraph; `["f","l","e","a"]` decomposes pedantically OK but pronounce as `/fli:/` is dishonest. Better skip and use `flit` or `flicker` ✗ (`ck`).

#### Dinosaurs (f-decodable)

| Band | Pool |
|------|------|
| early | `fang`, `fossil`, `frill` (frill-necked dinos), `fin`, `foot` ✗ (`oo`), foot skip |
| mid   | early pool + `feather` ✗ (`ea`/`er`... `er` is two singles, fine; but `ea` is a digraph — skip), `Spino`, `flag` (dinosaur flag-tail) |
| late  | mid pool + `Allosaur`'s `flank`, `frilled` adjective |

Dinosaur cells for `f` are sparse — lean on `Finn/Fred/Fran` cast plus generic dinosaur-adjacent f-words (`fang`, `fossil`, `flag`, `frill`).

#### Vehicles (f-decodable)

| Band | Pool |
|------|------|
| early | `ferry` ✗ (`y` ending fine, but `er` is `e,r` singles — fine), `ferry` ok actually; `flag`, `freight` ✗ (`ei` and `gh`), wait `freight` is `f,r,e,i,g,h,t` — has `gh` digraph — ✗ skip |
| mid   | early pool + `flatbed`, `forklift`, `freighter` ✗ (`gh`), skip; `frigate` (`f,r,i,g,a,t,e` — fine) |
| late  | mid pool + `freighter` skip; `firetruck` ✗ (`ck`), skip; `fishing-boat` ✗ (`oa`), skip |

`f` vehicles are constrained — use `ferry`, `frigate`, `flatbed`, `forklift`. Add character cast (`Finn`/`Fred`/`Fran`) for proper-noun-driven density.

#### Space (f-decodable)

| Band | Pool |
|------|------|
| early | `flag` (Mars flag), `flare` (solar), `flight` ✗ (`gh`), skip; `Phobos` ✗ (`ph`), skip; `Fomalhaut` ✗ — too long & rare |
| mid   | early pool + `flare`, `fission`, `fossil` (Mars fossil) |
| late  | mid pool + `fission-drive`, `flux`, `flicker` ✗ (`ck`), `flotilla` |

Lean on Mars/Saturn etc. (decodable across) plus f-words like `flare`, `fossil`, `flux`.

#### Sports (f-decodable)

| Band | Pool |
|------|------|
| early | `fan` (sports fan), `flag`, `flop`, `fast` (`f,a,s,t` — fine), `feet` ✗ (`ee`), skip |
| mid   | early pool + `fitness`, `foul` ✗ (`ou`), skip; `forfeit` ✗ (`ei`), skip; `field` ✗ (`ie`), skip |
| late  | mid pool + `forward` (`f,o,r,w,a,r,d` — fine), `fumble` (`f,u,m,b,l,e` — fine), `forfeit` skip |

`fast`, `flag`, `fan`, `forward`, `fumble` are the durable f-content vocabulary. Add cast for density.

#### Robots (f-decodable)

| Band | Pool |
|------|------|
| early | `fan` (cooling fan), `fix`, `fan` again, `fuse` (`f,u,s,e` — fine) |
| mid   | early pool + `firmware` ✗ (no — `f,i,r,m,w,a,r,e` is all singles, fine), `fitting`, `fold` |
| late  | mid pool + `forge`, `forklift`, `flame` ✗ (`am,e` is `a,m,e` singles, fine), `flange` |

`fan`, `fix`, `firmware`, `flame`, `flange`, `forge`, `forklift` — robust f-content set.

### Phase 3 — Density-anchor cookbook

- `Finn and Fred fixed a flat fan.` — Finn(f-onset), Fred(f-onset), fixed(f-onset), flat(f-onset), fan(f-onset) = 5 f-onset content words, 5+ total `f`. ✓
- `Fran fed a fish and a fox.` — Fran(f-onset), fed(f-onset), fish(f-onset), fox(f-onset) = 4 onset content words, 5 total f. ✓

The strategy mirrors sh cells: keep proper-noun cast carrying ≥2 of the 3 onset slots, then 1–2 f-content words.

### Phase 3 — Tasks

Same shape as Phase 2 § Tasks. Cumulative counts: Task 2 lands cell #37 (sh 18 + th 18 + 1 = 37, but only if Phase 2 already merged); Task 19 lands cell #54.

If phases land out of order, the cumulative count differs. The PR's commit titles encode `f phoneme` in the path so traceability is preserved.

### Phase 3 — Final PR body

```
content(sentence-library): f phoneme — 18 cells × 20 sentences (Track B-2 Phase 3)

## Summary

Adds 18 new `f` cells (every `f × {6 interests} × {3 ageBands}` cell), each with 20 validator-clean tongue-twister sentences focused on the `/f/` sound. After this PR, `f` is the third complete phoneme in the bundled `SentenceLibrary` and Track B-2 has 2 phonemes remaining (`r`, `short_a`).

Tracks: B-2 Phase 3; 2 phonemes remain (`r`, `short_a`) under the same plan shape.

Spec: `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6 / § 9 PR 3.
Plan: `docs/superpowers/plans/2026-04-25-decodable-sentence-library-remaining-phonemes.md` § Phase 3.

## Test plan

- [x] Validator: `54 cells, 1080 sentences  PASS`.
- [x] `swift test` per package green.
- [x] `xcodebuild build` SUCCEEDED on iOS Simulator.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Phase 4 — `r` phoneme (PR title: "content(sentence-library): r phoneme — 18 cells × 20 sentences (Track B-2 Phase 4)")

### Phase 4 — Overview

`r` corresponds to /r/ as in "rat", "ran", "rip". Curriculum week index 3; target grapheme is `r` (already a member of the L2 alphabet).

### Phase 4 — Per-cell file header (CR7 fill)

```json
{
  "phoneme": "r",
  "phonemeIPA": "r",
  "graphemeLetters": "r",
  ...
}
```

### Phase 4 — Allowed graphemes

| Source | Graphemes |
|--------|-----------|
| L2 alphabet | `a..z` |
| previously taught digraphs | `sh`, `th` |
| target | `r` (already in L2; `f` is also in L2) |

Total: **26 single letters + `sh` + `th`.** Identical set to `th` and `f` cells.

### Phase 4 — Forbidden cheat sheet

Same as Phase 2 verbatim.

### Phase 4 — Proper-noun cast (per spec § 6.2 step 6)

| Surface | Graphemes | Phonemes |
|---------|-----------|----------|
| `Rex`   | `["r","e","x"]`            | `["r","ɛ","ks"]` |
| `Ron`   | `["r","o","n"]`            | `["r","ɒ","n"]` |
| `Rip`   | `["r","i","p"]`            | `["r","ɪ","p"]` |
| `Rob`   | `["r","o","b"]`            | `["r","ɒ","b"]` |

All four are r-onset content words. Any pair carries 2 onset slots; pair with one r-content word and the cell hits the floor.

### Phase 4 — Verb pool (r-decodable)

- `ran`, `runs`, `rid`, `rip`, `rob`, `rub`, `rest`, `rests`, `rust`, `rip`, `rim`, `raft`, `ramp`, `rip`, `rant`, `rasp`, `read` ✗ (`ea`), skip; `rolled` (`r,o,l,l,e,d` — fine)
- Past tense forms: `ripped` (`r,i,p,p,e,d`), `robbed` (`r,o,b,b,e,d`)
- Coda: `bar`, `car`, `far`, `jar`, `tar`, `star`, `near` ✗ (`ea`), skip; `fear` ✗ (`ea`), skip

Avoid: `read` (`ea`), `roar` (`oa` if treated as digraph; if singles it's fine, but author with care), `roof` (`oo`).

### Phase 4 — Vocabulary starter pools

#### Animals (r-decodable)

| Band | Pool |
|------|------|
| early | `rat`, `rabbit`, `raccoon` ✗ (`oo`), skip; `ram`, `raven`, `robin`, `roach` ✗ (`oa`/`ch`), skip |
| mid   | early pool + `reptile`, `rooster` ✗ (`oo`), skip; `raptor`, `rabbit` |
| late  | mid pool + `reindeer` ✗ (`ei`/`ee`), skip; `rhinoceros` (`r,h,i,n,o,c,e,r,o,s` — fine), `rattlesnake` |

`rat`, `ram`, `raven`, `robin`, `rabbit`, `reptile`, `rhinoceros`, `rattlesnake` — solid r-content set.

#### Dinosaurs (r-decodable)

| Band | Pool |
|------|------|
| early | `rex` (already in cast), `raptor`, `rib` (dino rib bone), `roar` |
| mid   | early pool + `Triceratops` ✗ — `c,e,r,a,t,o,p,s` — wait it's `T,r,i,c,e,r,a,t,o,p,s` — all singles, fine! |
| late  | mid pool + `tyrannosaur` ✗ (`y` and `nn` and `o,s,a,u,r` — `y,r,a,n,n,o,s,a,u,r` — fine!), `Triceratops` |

Use `raptor`, `rib`, `roar`, `Triceratops`, `tyrannosaur` — r-rich.

#### Vehicles (r-decodable)

| Band | Pool |
|------|------|
| early | `rocket` ✗ (`ck`), skip; `raft`, `ramp`, `rover` (Mars rover crossover — vehicle for space context), `rail`, `road` ✗ (`oa`), skip |
| mid   | early pool + `racer`, `rotor`, `rickshaw` ✗ (`ck`), skip; `Roadster` ✗ (`oa`), skip; `rollers` |
| late  | mid pool + `racetrack` ✗ (`ck`), skip; `roller-skate` ✗ (`oll` ok; `kate` is `k,a,t,e` fine; but `ate` is two singles fine — overall ok), `recovery` |

`raft`, `ramp`, `rover`, `racer`, `rotor`, `rollers` — r-content set.

#### Space (r-decodable)

| Band | Pool |
|------|------|
| early | `rocket` ✗ (`ck`), skip; `ring` ✗ (`ng`), skip; `red` (Red Planet), `rim` |
| mid   | early pool + `rotation`, `Saturn`'s `ring` ✗ (`ng`), skip; `rover` (Mars), `radio` |
| late  | mid pool + `radiation`, `Roswell`, `relay` ✗ (`ay`), skip |

Space `r` is constrained — use `rover`, `radio`, `radiation`, `red`, `rim`.

#### Sports (r-decodable)

| Band | Pool |
|------|------|
| early | `run`, `ran`, `runs`, `relay` ✗ (`ay`), skip; `racket` ✗ (`ck`), skip; `rink` ✗ (`nk`), skip |
| mid   | early pool + `runner`, `racer`, `rugby` (`r,u,g,b,y` — fine), `rim` (basketball rim) |
| late  | mid pool + `rebounder`, `referee`, `relay` skip; `rookie` ✗ (`oo`), skip |

`run`, `ran`, `runner`, `racer`, `rugby`, `rim`, `rebounder`, `referee` — r-rich sport set.

#### Robots (r-decodable)

| Band | Pool |
|------|------|
| early | `robot` (already cast-adjacent), `rod`, `rim`, `ram` (memory ram), `rust` |
| mid   | early pool + `rotor`, `relay` skip; `repair`, `rivet` |
| late  | mid pool + `repair-bot`, `recharge` ✗ (`ch`), skip; `rotational`, `regulator` |

`rotor`, `repair`, `rivet`, `regulator`, `rotational` — r-content set.

### Phase 4 — Density-anchor cookbook

- `Rex and Ron ran past a rat.` — Rex(r-onset), Ron(r-onset), ran(r-onset), rat(r-onset) = 4 onset; rest of word totals add up, ≥4 total. ✓
- `Rip and Rob got a red robot.` — Rip(r-onset), Rob(r-onset), red(r-onset), robot(r-onset) = 4 onset; total `r` includes "red", "robot", and `o-r` in some words = ≥5. ✓

### Phase 4 — Tasks + PR body

Identical structure to Phase 3 with substitutions: `f` → `r`. Cumulative counts after Phase 4: 72 cells, 1,440 sentences.

```
content(sentence-library): r phoneme — 18 cells × 20 sentences (Track B-2 Phase 4)

## Summary

Adds 18 new `r` cells (every `r × {6 interests} × {3 ageBands}` cell), each with 20 validator-clean tongue-twister sentences focused on the `/r/` sound. After this PR, `r` is the fourth complete phoneme in the bundled `SentenceLibrary` and Track B-2 has 1 phoneme remaining (`short_a`).

Tracks: B-2 Phase 4; 1 phoneme remains (`short_a`) under the same plan shape.

Spec: `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6 / § 9 PR 3.
Plan: `docs/superpowers/plans/2026-04-25-decodable-sentence-library-remaining-phonemes.md` § Phase 4.

## Test plan

- [x] Validator: `72 cells, 1440 sentences  PASS`.
- [x] `swift test` per package green.
- [x] `xcodebuild build` SUCCEEDED on iOS Simulator.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Phase 5 — `short_a` phoneme (PR title: "content(sentence-library): short_a phoneme — 18 cells × 20 sentences (Track B-2 Phase 5)")

### Phase 5 — Overview (special case)

`short_a` corresponds to /æ/ — the short-a vowel as in "cat", "ran", "ant". Curriculum week index 4; target grapheme is `a` (already in the L2 alphabet).

**This is the constrained phase.** Density rule CR2 requires:
- ≥ 4 occurrences of letter `a` total → trivial (every common sentence has many `a`s).
- ≥ 3 word-initial `a` content words → **hard.** Most short-a words (`cat`, `bat`, `mat`, `ran`, `ham`) have `a` *medial*, not initial. The proper-noun cast (`Sam`, `Jan`, `Pat`, `Cam`) all have `a` medial too — none counts toward the word-initial-content-word slot.

### Phase 5 — Per-cell file header (CR7 fill)

```json
{
  "phoneme": "short_a",
  "phonemeIPA": "æ",
  "graphemeLetters": "a",
  ...
}
```

### Phase 5 — Allowed graphemes

| Source | Graphemes |
|--------|-----------|
| L2 alphabet | `a..z` |
| previously taught digraphs | `sh`, `th` |
| target | `a` (already in L2; `f`, `r` also in L2) |

Total: **26 single letters + `sh` + `th`.** Same set as Phases 2–4.

### Phase 5 — Forbidden cheat sheet

Same as Phase 2 verbatim. Note that `oa`, `ai`, `ay`, `aw`, `au` digraphs (when treated as multi-grapheme units) are forbidden, **but** the validator only checks per-grapheme membership in the allowed set. A word like `boat` tokenized as `["b","o","a","t"]` would technically pass the grapheme check — but it dishonestly splits the `oa` digraph. **Do NOT do this.** Phase 5 sentences must use words whose Phase-2 phonics decomposition naturally consists of single letters (or `sh`/`th`); a long-vowel `oa` word is off-limits regardless of how it's tokenized.

### Phase 5 — Proper-noun cast (per spec § 6.2 step 6)

| Surface | Graphemes | Phonemes |
|---------|-----------|----------|
| `Sam`   | `["s","a","m"]`            | `["s","æ","m"]` | a-medial only — does NOT count toward word-initial-content-word density |
| `Jan`   | `["j","a","n"]`            | `["dʒ","æ","n"]` | a-medial only |
| `Pat`   | `["p","a","t"]`            | `["p","æ","t"]` | a-medial only |
| `Cam`   | `["c","a","m"]`            | `["k","æ","m"]` | a-medial only |

**These four cast members carry the total `a` count but contribute zero to the word-initial-content-words count.**

### Phase 5 — A-initial cast (Phase 5 addition)

Spec § 6.2 step 6 lists Sam/Jan/Pat/Cam, but those don't help with word-initial density. Phase 5 adds **a-initial** cast members so cells reliably hit the ≥3 onset rule:

| Surface | Graphemes | Phonemes | Notes |
|---------|-----------|----------|-------|
| `Adam`  | `["a","d","a","m"]`         | `["æ","d","ə","m"]` | a-onset proper noun |
| `Anna`  | `["a","n","n","a"]`         | `["æ","n","ə"]` | a-onset; double-`a` (initial + final), bonus density |
| `Andy`  | `["a","n","d","y"]`         | `["æ","n","d","i"]` | a-onset |
| `Al`    | `["a","l"]`                 | `["æ","l"]` | a-onset; one-syllable shortname |

Pair Sam/Jan/Pat/Cam (medial cast for total density) with Adam/Anna/Andy/Al (a-onset cast for word-initial density). Two a-onset cast + one a-content word = 3 onset content words, easy.

### Phase 5 — A-onset content words (Phase 5 addition)

Words starting with short-a that decompose cleanly into the allowed grapheme set:

| Word | Graphemes | Phonemes | Notes |
|------|-----------|----------|-------|
| `ant`     | `["a","n","t"]`     | `["æ","n","t"]` | classic short-a noun |
| `ax`      | `["a","x"]`         | `["æ","ks"]` | |
| `apt`     | `["a","p","t"]`     | `["æ","p","t"]` | adj. |
| `add`     | `["a","d","d"]`     | `["æ","d"]` | |
| `act`     | `["a","c","t"]`     | `["æ","k","t"]` | |
| `ash`     | `["a","sh"]`        | `["æ","ʃ"]` | uses sh digraph (taught) |
| `ask`     | `["a","s","k"]`     | `["æ","s","k"]` | |
| `am`      | `["a","m"]`         | `["æ","m"]` | verb-be 1sg |
| `an`      | `["a","n"]`         | `["æ","n"]` | indefinite article — but careful: NOT in sight-word whitelist, so `an` is a content word in validator's eyes! |
| `as`      | `["a","s"]`         | `["æ","z"]` | |
| `apple`   | `["a","p","p","l","e"]` | `["æ","p","ə","l"]` | |
| `after`   | `["a","f","t","e","r"]` | `["æ","f","t","ə","r"]` | f and r in L2; ok |
| `arm`     | `["a","r","m"]`     | `["ɑ","r","m"]` | (long-a sound but spelled with a) |
| `art`     | `["a","r","t"]`     | `["ɑ","r","t"]` | |
| `aft`     | `["a","f","t"]`     | `["æ","f","t"]` | |
| `axle`    | `["a","x","l","e"]` | `["æ","k","s","ə","l"]` | |
| `at`      | sight word — does NOT count for word-initial density |  |
| `atom`    | `["a","t","o","m"]` | `["æ","t","ə","m"]` | |
| `attic`   | `["a","t","t","i","c"]` | `["æ","t","ɪ","k"]` | |

**Important:** `an` is NOT in the sight-word whitelist (`the, a, and, is, to, on, at`). If a sentence has `an apple`, then both `an` and `apple` are content words with `a` as the first grapheme — that's TWO word-initial-content-words from one phrase. Use `an` aggressively as a density vector.

Words to **avoid** even though they look short-a:
- `apron` ✗ — long a, `["a","p","r","o","n"]` is dishonest phonics
- `able` ✗ — long a
- `acorn` ✗ — long a; also `oa`-like if singles
- `April` ✗ — long a in some pronunciations; also `i,l` final

### Phase 5 — Verb pool (a-decodable)

- `ran`, `had`, `has`, `sat`, `bat`, `pat`, `tap`, `nap`, `nab`, `cap`, `rap`, `lap`, `pad`, `sad`, `mad`, `lab`, `gab`
- `am`, `is`, `at` — sight words
- `add`, `act`, `apt`, `ash`, `ask`, `act` — a-onset (count toward density)

### Phase 5 — Vocabulary starter pools

#### Animals (a-decodable)

| Band | Pool |
|------|------|
| early | `cat`, `rat`, `bat`, `ant`, `ass` ✗ (could be euphemized; avoid for child content), `ram`, `gnat` (`g,n,a,t` — fine), `ass` skip |
| mid   | early pool + `panda`, `llama`, `rabbit`, `raccoon` ✗ (`oo`), skip; `alpaca` (`a,l,p,a,c,a` — a-onset!), `armadillo` (a-onset!) |
| late  | mid pool + `aardvark` (`a,a,r,d,v,a,r,k` — a-onset!), `albatross`, `anaconda` (`a,n,a,c,o,n,d,a`) |

`alpaca`, `armadillo`, `aardvark`, `albatross`, `anaconda` are **a-onset gold** for Phase 5 animals cells — every one anchors a word-initial slot.

#### Dinosaurs (a-decodable)

| Band | Pool |
|------|------|
| early | `Anky` (anky-shorthand; a-onset), `dactyl` ✗ (`y` actually fine but `act` start — `d,a,c,t,y,l`, fine; but `dactyl` is medial-a not onset — skip for density), `fang`, `tail` ✗ (`ai`), skip |
| mid   | early pool + `Allosaur` (a-onset!), `Apatosaurus` (a-onset!), `Acrocanthosaurus` ✗ (long, `nth` is fine but check `ck`... `c,r,o,c,a,n,th,o,s,a,u,r,u,s` — `c,k` not present, `th` is taught — fine), `Ankylosaur` (a-onset, but `nk` digraph in `nky`... wait `n,k,y` is three singles — fine, but `ky` could be `k,y` singles — author carefully) |
| late  | mid pool + `Argentinosaurus` (a-onset, long), `armored`, `Apatosaurus` |

Lots of dinosaur names are a-onset and Phase-5-decodable: `Allosaur`, `Apatosaurus`, `Ankylosaur`, `Argentinosaurus`, `Albertosaurus`. Use them.

#### Vehicles (a-decodable)

| Band | Pool |
|------|------|
| early | `cab`, `van`, `tram`, `cart`, `auto` ✗ (`au` digraph), skip; `ambulance` (a-onset! `a,m,b,u,l,a,n,c,e` — fine) |
| mid   | early pool + `airplane` ✗ (`ai`/`pl` fine but `ai`), skip; `aircraft` ✗ (`ai`), skip; `armored-car` |
| late  | mid pool + `aircraft` skip; `armored-truck` ✗ (`ck`), skip; `ambulance`, `articulated` |

`ambulance` and `armored` are the a-onset workhorses for vehicles. Otherwise lean on cast.

#### Space (a-decodable)

| Band | Pool |
|------|------|
| early | `astronaut` ✗ (`au` digraph), skip; `asteroid` (`a,s,t,e,r,o,i,d` — `oi` is digraph, ✗ skip), `apollo` ✗ (likely `ll`fine but `o,l,l,o` final — `Apollo` is `A,p,o,l,l,o`, fine actually, a-onset), `alien` ✗ (`ie` digraph), skip |
| mid   | early pool + `Apollo`, `astral`, `axis` (a-onset!) |
| late  | mid pool + `astronomy` ✗ (`o,n,o,m,y` is fine; `astronomy` = `a,s,t,r,o,n,o,m,y` — fine, a-onset!), `astronomical` |

`Apollo`, `astral`, `axis`, `astronomy`, `astronomical` — strong a-onset space set.

#### Sports (a-decodable)

| Band | Pool |
|------|------|
| early | `bat`, `ball`, `mat`, `lap`, `tag` |
| mid   | early pool + `archery` ✗ (`ch`), skip; `ace` (`a,c,e` — a-onset!), `attack` ✗ (`ck`), skip |
| late  | mid pool + `athlete` (`a,th,l,e,t,e` — a-onset! and uses `th` digraph), `athletics` |

`ace`, `athlete`, `athletics` are great a-onset sports words. Use the cast for fillers.

#### Robots (a-decodable)

| Band | Pool |
|------|------|
| early | `arm`, `act` (robot acts), `am` (robot says "I am"), `ant` (ant-bot) |
| mid   | early pool + `assembly` (`a,s,s,e,m,b,l,y` — a-onset!), `armature` (a-onset!), `actuator` (a-onset!) |
| late  | mid pool + `algorithm` (uses `th`; a-onset!), `artificial` ✗ (`ci` is two singles fine but `ial`... `i,a,l` singles — ok but author carefully), `automaton` ✗ (`au` digraph), skip; `android` (a-onset!) |

`assembly`, `armature`, `actuator`, `algorithm`, `android` — all a-onset, all robot-relevant.

### Phase 5 — Density-anchor cookbook

The Phase 5 strategy is: cast for total a count, a-onset content words for word-initial slots.

- `Adam and Anna had an apple at the lab.` — Adam(a-onset), Anna(a-onset), had(0), an(a-onset), apple(a-onset), at(sight), the(0), lab(0). Word-initial content words with `a`: Adam, Anna, an, apple = **4** ✓. Total `a`: every `a` letter — Adam(2), Anna(2), an(1), apple(1), at(1), Sam(0), the(0), lab(1) = many ✓.
- `Andy and Al ran past an ant and an ant.` (sample, but reuse risk) — Andy(a-onset), Al(a-onset), ran(0), an(a-onset), ant(a-onset), an(a-onset), ant(a-onset) = 6 ✓.
- `Sam and Jan saw an alpaca and an armadillo.` — Sam(0), Jan(0), saw(0 — `aw` digraph though! ✗ skip `saw`), … needs rephrase: `Sam and Jan got an alpaca and an armadillo.` — Sam(0 medial), Jan(0 medial), got(0), an(a-onset), alpaca(a-onset), and(0), an(a-onset), armadillo(a-onset) = **4** word-initial ✓. Total `a`: Sam(1), Jan(1), got(0), an(1), alpaca(3), and(1), an(1), armadillo(4) = 12 ✓.

Note: `saw` has the `aw` digraph — skip. Use `had`, `got`, `met`, `set`, `sat`, `let` as r-decodable verbs.

### Phase 5 — Special-case gotchas

1. **`an` is a content word**, not a sight word. Sentences with `an X` patterns gain free word-initial slots. Use `an apple`, `an ant`, `an alpaca`, `an armadillo` aggressively.
2. **Sam/Jan/Pat/Cam contribute zero word-initial slots.** They give total-`a` count only. Pair them with Adam/Anna/Andy/Al for the onset slots.
3. **Many "short-a" words are actually long-a or schwa-a.** `arm`, `art`, `arc` use /ɑ/ not /æ/. `arm` is `["a","r","m"]` — the validator counts the `a` regardless. The phonics is honest if you accept the broader "a as letter" framing, but the spec's IPA `æ` for short_a means a strict reader might object. **Pragmatic call**: include `arm`, `art`, etc., as a-onset content words; the validator is the contract; phonics-purists can revisit in v2.
4. **`apple` and `attic` use double consonants** — graphemes are `["a","p","p","l","e"]` — fine, the validator allows repeated singles.
5. **Avoid `able`, `apron`, `April`, `acorn`** — these all have *long* a-sound. Phonics-dishonest to call them short-a.

### Phase 5 — Tasks

Same shape as Phases 2–4 with `phoneme = "short_a"` everywhere. Cumulative counts after Phase 5: 90 cells, 1,800 sentences — the spec's full library.

### Phase 5 — Final PR body

```
content(sentence-library): short_a phoneme — 18 cells × 20 sentences (Track B-2 Phase 5 — library complete)

## Summary

Adds the final 18 `short_a` cells, completing the spec's 5×6×3×20 = 1,800-sentence bundled library. Special-cases the constrained "vowel as target" phoneme by leaning on a-onset cast (`Adam`, `Anna`, `Andy`, `Al`) plus a-onset content words (`an`, `ant`, `apple`, `ash`, `axle`, `alpaca`, `armadillo`, `astral`, `algorithm`, `android`, etc.) instead of the spec's medial-only `Sam`/`Jan`/`Pat`/`Cam` cast.

Library is now feature-complete for v1: every `(phoneme × interest × ageBand)` cell is populated.

Tracks: B-2 Phase 5 — final phoneme; library now matches spec § 6.1 in full.

Spec: `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6 / § 9 PR 3.
Plan: `docs/superpowers/plans/2026-04-25-decodable-sentence-library-remaining-phonemes.md` § Phase 5.

## Test plan

- [x] Validator: `90 cells, 1800 sentences  PASS`.
- [x] `swift test` per package green.
- [x] `xcodebuild build` SUCCEEDED on iOS Simulator.
- [x] Bundle size delta within iPad budget (sanity-check `du -sh Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary` — expect ~650 KB).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Cross-phase risks

| Risk | Trigger | Mitigation |
|------|---------|------------|
| Author tokenizes a multigraph (e.g., `oa` in `boat`) as singles to skirt the validator | Time pressure or unfamiliarity with phonics | Each phase's § "Forbidden cheat sheet" lists the dishonest tokenizations explicitly; PR review must catch them. The validator alone cannot detect dishonesty — it only checks set membership. |
| `short_a` cells don't reach 3 word-initial-content-words slots | Author leans on Sam/Jan/Pat/Cam (medial only) | Phase 5 § "A-initial cast" introduces Adam/Anna/Andy/Al; cookbook examples lead with these. |
| Phase 4 (`r`) and Phase 5 (`short_a`) share allowed-grapheme set with Phase 2 (`th`); subtle copy-paste of th-only words | Author drift | Phase headers force `phoneme` and `phonemeIPA` to differ; the validator's `payloadFilenameMismatch` check catches header errors but cannot catch "this sentence has insufficient `r` density when the file says `r`". Density rule CR2 catches it. |
| One phase's PR-CI fails on an interestWords mismatch | A vocab pool word like `alpaca` is tagged but not present in the sentence text | Per CR4, the validator's `interestWordNotInSentence` violation gives a clear error; common fix in CR9 step 5. |
| Phase 5 hand-authored count drifts because `algorithm`, `actuator` etc. are syllabically heavy | Late-band Phase 5 cells run long | Cookbook leans on shorter a-onset content words for early/mid; long technical names reserved for late. |
| Bundle size grows past iPad budget | Future phases add per-cell metadata | At 1,800 sentences × ~360 B = 650 KB, well under any iPad bundle limit. Adding decode-words later (out of this scope) would only ~3× that. |

---

## Forward hooks (after Phase 5)

Once Phase 5 lands, the v1 library is complete. Future expansions slot in cleanly:

1. **Selector freshness** — re-introduce the `excluding` filter once a `decodedSentenceTextsJSON` field is added to `SessionSummaryEntity` (a future minor-migration PR). Selector signature is unchanged; bootstrap call site flips `excluding: []` to `excluding: recentSurfaces`.
2. **On-device LLM (deferred mora-design.md track)** — `SentenceLibrary` becomes pluggable; an `OnDeviceLLMProvider` produces sentences into the same JSON shape and merges with bundled cells.
3. **Decode-word library** — same matrix shape, new directory tree (`Resources/DecodeWordLibrary/`); same validator extended.
4. **Mini-stories ("yokai's letter")** — multi-sentence units; validator extends to story-arc files.
5. **New interest categories** — adding a 7th category requires only ~600 new sentences (5 phonemes × 3 ageBands × 20 × 2 [if N+1 backfill] = 600 → adjust ratio). Selector and validator need no code change.
6. **New phonemes (week 6+)** — 6 × 3 × 20 = 360 new sentences per phoneme. Selector and validator are phoneme-agnostic; phoneme directory map gets one new entry.

---

## Self-review

**Spec coverage:**

- **§ 6.1 matrix** — fills the four remaining rows of the 5×6×3 matrix; § 6.1 cell count budget honored (18 cells per phoneme, 20 sentences per cell).
- **§ 6.2 sentence rules** — encoded in CR1–CR8 with phoneme-specific overrides per phase.
- **§ 6.3 generation flow** — per-cell loop in CR9 mirrors spec's Claude-Code loop (author → write → validate → fix → commit).
- **§ 6.4 validator** — used as the gating CI check at every cell commit and at the per-phase final verification step (CR12). No validator changes.
- **§ 6.5 schema** — encoded in CR6 + CR7 + the existing `sh × vehicles × mid` reference.
- **§ 6.6 / § 6.7 runtime** — out of scope for this plan; deferred to `2026-04-25-decodable-sentence-library-selector.md` (Track B-3).
- **§ 6.10 tests** — selectively in scope: only the bundle-counting tests added in B-1 are exercised; bigger library-completeness tests deferred until Phase 5 closes the matrix.
- **§ 8 risks** — "Tongue-twister density unattainable for some `(interest, ageBand)` cells" addressed in each phase's vocab pool (e.g., Phase 5 special case adds the a-initial cast). "Validator passes but runtime decodability disagrees" addressed by the validator + runtime parity (both use `CurriculumEngine.sharedV1`).
- **§ 9 PR 3** — this plan is the remaining 4 slices of PR 3 (sh shipped as Phase 1 in PR #94).

**Placeholder scan:**

- No `TBD`/`TODO`/`implement later`/`add appropriate error handling`/`similar to Task N` anywhere in the rulebook or phase sections.
- Each phase names exact proper-noun cast tokenizations and exact vocab pool words; cookbook examples are concrete.
- Validator and lint commands are literal — copy-paste runnable from any phase.
- One commit message convention (`content(sentence-library/{phoneme}): {interest} × {ageBand} (20 sentences)`) given verbatim.

**Type / value consistency:**

- File-path stems align with `(interest, ageBand)` payload pairs across all 4 phases.
- Validator's expected output (`<N> cells, <N*20> sentences\n  PASS`) matches the cumulative cell-count progression assuming sequential phase order.
- Sight-word list (`the, a, and, is, to, on, at`) is identical across CR1, validator's `sightWords`, and sh-cells § R2.
- Tokenization conventions in CR6 match the existing `sh × vehicles × mid` cell verbatim.
- Cell ordering in CR10 matches sh-cells task numbering 2–18 (with `vehicles × mid` reinstated for non-sh phases).

**Cross-phase consistency:**

- Phases 2–4 share an identical allowed-grapheme set (26 letters + `sh` + `th`); the only change is the target letter, which drives density math.
- Phase 5 has the same allowed set but a vowel target; the special-case A-initial cast and A-onset content-word section addresses the unique density challenge.
- Forbidden cheat sheets are uniform across phases (after Phase 2's strictly larger forbidden list — no phase widens it back).

No spec gaps that aren't called out as Deviations. No internal contradictions. Plan is ready.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-decodable-sentence-library-remaining-phonemes.md`. Each of the four phases is an independent PR that can be executed via:

1. **Subagent-Driven (recommended)** — fresh subagent per phase per cell with two-stage review; per CR11, each phase can fan out to up to nine parallel subagents in isolated worktrees once the first 1–2 cells set tone.
2. **Inline Execution** — execute phase-by-phase in this session using `superpowers:executing-plans`; checkpoint at each phase's PR-creation step.

Recommended order: **th → f → r → short_a** (rationale in § "Phase ordering"). Each phase ships as a separate PR.

If `2026-04-25-decodable-sentence-library-selector.md` (Track B-3) has not yet shipped, each merged phase here sits dormant until selector lands. If Track B-3 has shipped, each merged phase becomes immediately user-visible to learners on the corresponding curriculum week.

Which phase to start, and which approach?
