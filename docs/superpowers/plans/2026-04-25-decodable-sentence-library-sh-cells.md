# Decodable Sentence Library — sh Phoneme Cells (Track B-2 Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the 17 missing `sh`-phoneme cells (every `sh × {animals, dinosaurs, vehicles, space, sports, robots} × {early, mid, late}` cell except the already-shipped `sh × vehicles × mid`), each containing 20 validator-clean tongue-twister sentences, so `sh` is the first complete phoneme in the bundled `SentenceLibrary` and Track B-2 can continue with the four remaining phonemes in subsequent PRs of identical shape.

**Architecture:** Pure content. No new code, no schema changes, no test additions beyond the bundle-counting regression that closes the PR. Each cell is one `Resources/SentenceLibrary/sh/{interest}_{ageBand}.json` file conforming to the schema introduced in Track B-1 (`docs/superpowers/plans/2026-04-25-decodable-sentence-library-validator.md`). The `dev-tools/sentence-validator/` Swift CLI is the single source of truth for cell well-formedness; every commit must leave the validator green.

**Tech Stack:** JSON authoring, `dev-tools/sentence-validator` (`swift run`), `swift test` (`Packages/MoraEngines`), `swift-format`, `xcodegen`, `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 6 (Track B), § 9 PR 3.

---

## Deviations from spec (read first)

1. **PR scope is the `sh` phoneme only, not all 89 remaining cells.** Spec § 9 PR 3 packages the entire ~89-cell remainder under one heading but explicitly notes "Each cell committed individually or in small per-phoneme batches" so review is "incremental and bisectable." This plan implements one batch — the `sh` phoneme — so the next four phonemes (`th`, `f`, `r`, `short_a`) repeat the identical task shape with phoneme-specific grapheme sets. Doing all 89 cells in a single PR would be ~30 KB of JSON and 1,800 review-worthy sentences; one phoneme is ~5 KB, 340 sentences, and one weeks's worth of focused review.

2. **One commit per cell.** Spec § 9 leaves the granularity open ("individually or in small per-phoneme batches"). Per-cell commits maximize bisect granularity, keep authorial tone localized in a single change, and let each cell's validator run be a clean atomic step. The PR rolls 17 commits — one per cell — plus the final verification commit.

3. **No new Swift code in this PR.** Track B-1 shipped `SentenceLibrary` (loader, identity-mismatch checks) and the validator CLI; both already handle the 17 new files automatically. The `sentences(...)` selector body remains `fatalError("…Track B-3")`. No tests beyond the existing `SentenceLibraryTests` suite are added — adding "must contain 18 sh cells" as a runtime assertion now would be redundant with the validator's CI gate, and would have to be revisited on every subsequent phoneme PR.

4. **No interest-vocabulary table is added to source.** B-1 established that the validator only checks each `interestWords` entry's *presence* in the sentence text, not its membership in any per-interest vocabulary list. Per-cell vocabulary judgment lives in this plan (§ "Vocabulary starter pools" below) and in the authorial intent of each task; if alpha feedback later demands a centralized `(interest, ageBand) → vocab` table, that's a separate refactor PR.

5. **No README touch-up to claim "phoneme done".** Track B-2 is intentionally an incremental fill; surfacing partial progress in any user-visible README would create a maintenance pothole at every subsequent phoneme PR. The validator's own report (`N cells, M sentences`) is the running progress signal.

---

## Execution note — parallel subagents

Tasks 2–9 were executed sequentially with one implementer subagent per cell. **Tasks 10–18 were dispatched concurrently as nine parallel subagents**, each working in its own isolated git worktree (`isolation: "worktree"`). Each parallel subagent authored its cell, ran the validator inside its own worktree (which saw `vehicles_mid.json` plus its single new file), and committed on its own branch. The controller cherry-picked the nine resulting commits back into the main worktree in task order. Per-cell granularity is preserved in `git log` regardless of the dispatch mode.

This deviates from `superpowers:subagent-driven-development`'s default "never parallel" rule, but the rule's stated reason — git/file conflicts — does not apply when each subagent writes a different file path inside its own worktree. The wall-clock saving for nine ~5–10-minute authoring tasks is substantial.

---

## Authoring rulebook

> **Every cell task below follows this rulebook verbatim. Read it once at the top of the session; do not re-derive the rules from the spec on each task.**

### R1 — Allowed graphemes for `sh` cells

The validator computes `taughtGraphemes(beforeWeekIndex: 0) ∪ {sh}`. For the `sh` phoneme that resolves to:

| Source | Graphemes |
|--------|-----------|
| `baselineTaughtGraphemes` (the L2 alphabet) | `a b c d e f g h i j k l m n o p q r s t u v w x y z` (single letters, all 26) |
| `map.target` for `sh/` | `sh` |

That's the entire set: **26 single letters + the digraph `sh`.** Every grapheme of every non-sight word in every sentence must come from this set. In particular:

- `th`, `ch`, `wh`, `ph`, `gh` (consonant digraphs) are **not** allowed in `sh` cells.
- `ee`, `oo`, `ai`, `oa`, `ay`, `ow`, `ou`, `ie`, `ea` (vowel digraphs) are **not** allowed.
- `ck`, `ng`, `nk`, `qu` are **not** allowed as digraphs.

A word whose natural Phase 2 phonics decomposition uses any of the above is therefore **off-limits at sh week** — even though splitting the digraph into single letters would mechanically pass the validator, it produces dishonest phonics that breaks the spec's "Decodability is guaranteed by the template/content layer" invariant. Treat the validator as a necessary, not sufficient, check.

#### Concrete forbidden-vocabulary cheat sheet

| Reason | Words to **avoid** entirely (do not include even with creative tokenization) |
|--------|------------------------------------------------------------------------------|
| Uses `th`  | thin, this, that, them, they, with, math, path, both, cloth, thick, three, throw, throne, thank, think |
| Uses `ch`  | chin, chip, chop, chess, much, rich, such, lunch, beach, child, church, cheese |
| Uses `wh`  | when, where, why, what, while, white, wheel |
| Uses `ph`  | phone, photo, graph, dolphin, alphabet |
| Uses `ee`  | see, bee, feet, sheep, green, deer, peep, weed, sleep, three |
| Uses `oo`  | moon, soon, room, food, boot, school, book, look, foot, took, good (avoid for clean phonics — see R1a below) |
| Uses `ai`/`ay`/`ea` | rain, train, play, day, way, eat, tea, sea, lead, beach |
| Uses `oa`/`ow`/`ou` | boat, road, low, snow, town, out, found |
| Uses `ck`  | back, sock, duck, kick, rock, pack, neck, lock, clock |
| Uses `ng`/`nk` | sing, ring, long, song, drink, think, blank |
| Uses `qu`  | quick, queen, quiz, quack |

#### R1a — `oo` clarification

Spec § 6.5's example sentence is `"Shen and Sharon shop for a ship at the shed."` — no `oo`. The shipped `sh × vehicles × mid` cell uses `took = [t,o,o,k]` once, splitting `oo` into single `o + o`. **Do not follow that one example as a precedent.** Prefer `got` / `had` / `set` over `took` / `look` / `got the moon`. If you reach for an `oo` word and there is no equivalent monosyllabic substitute, treat the cell as constrained and choose a different sentence shape.

### R2 — Sight-word whitelist

The validator skips the grapheme check for any word whose lowercased surface is in:

```
the, a, and, is, to, on, at
```

These seven words may appear regardless of how they decompose. Tokenize them as the existing sample cell does:

| Surface | Graphemes | Phonemes |
|---------|-----------|----------|
| `the`   | `["th","e"]` | `["ð","ə"]` |
| `a`     | `["a"]` | `["ə"]` |
| `and`   | `["a","n","d"]` | `["æ","n","d"]` |
| `is`    | `["i","s"]` | `["ɪ","z"]` |
| `to`    | `["t","o"]` | `["t","u"]` |
| `on`    | `["o","n"]` | `["ɒ","n"]` |
| `at`    | `["a","t"]` | `["æ","t"]` |

(Yes, `the` uses the `th` digraph in its tokenization even though `th` isn't in the allowed set — that's fine because the validator skips grapheme checking for sight words; decomposing as `["th","e"]` matches the sample cell and the validator's existing tests.)

### R3 — Density rules

For every sentence:

- The target phoneme's letters (`"sh"`) must appear **≥4 times total** across all of the sentence's `words[*].graphemes` arrays. (The validator counts every `["sh"]`-equal entry across every word, including medial and coda occurrences.)
- The target phoneme's letters must appear **as the first grapheme of ≥3 content words.** "Content word" = any word whose lowercased surface is **not** in the sight-word whitelist (so proper nouns count as content words; `the/a/and/is/to/on/at` do not).

Practical author shortcut: if a sentence has 4 sh-onset content words, both rules are satisfied automatically. A common shape is `[Shen|Sharon|Shep] [verb] a [shy|shiny] X and a [sh-noun]` which carries 4 sh-onsets in 9 words.

### R4 — Sentence length

Word count (the JSON's `words.count`) must be in `[6, 10]` inclusive. Punctuation is not in `words`, so commas/periods/semicolons cost nothing.

### R5 — Interest tagging

`interestWords` must be **non-empty**, and **every entry must appear (case-insensitive) as the surface of at least one word in the sentence.** The validator's actual rule:

```swift
let surfaces = Set(sentence.words.map { $0.surface.lowercased() })
for tag in sentence.interestWords {
    if !surfaces.contains(tag.lowercased()) {
        violations.append(.interestWordNotInSentence(interestWord: tag))
    }
}
```

Practical advice: pick the 1–2 most "interest-y" content words from the sentence (e.g., `ship` for vehicles, `rex` for dinosaurs) and list those as `interestWords`. Don't tag sight words.

### R6 — Filename / payload identity

Every cell's JSON top-level fields **must** match the file's path:

| Field | Source | Example for `sh/animals_early.json` |
|-------|--------|-------------------------------------|
| `phoneme` | parent directory name | `"sh"` |
| `interest` | filename stem before the **last** `_` | `"animals"` |
| `ageBand` | filename stem after the **last** `_` | `"early"` |

The other two header fields (`phonemeIPA`, `graphemeLetters`) are constants for the `sh` phoneme:

```json
"phonemeIPA": "ʃ",
"graphemeLetters": "sh",
```

The loader (`SentenceLibrary.loadCells`) and the validator (`SentenceValidatorCLI`) both throw on any mismatch. Copy the header block verbatim across all 17 new cells and edit only `interest` + `ageBand`.

### R7 — Schema

Per-sentence JSON shape (one entry of the `sentences[]` array):

```json
{
  "text": "Shen had a fish and Sharon had a shrimp.",
  "targetCount": 4,
  "targetInitialContentWords": 3,
  "interestWords": ["fish", "shrimp"],
  "words": [
    { "surface": "Shen",   "graphemes": ["sh","e","n"],         "phonemes": ["ʃ","ɛ","n"] },
    { "surface": "had",    "graphemes": ["h","a","d"],          "phonemes": ["h","æ","d"] },
    { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
    { "surface": "fish",   "graphemes": ["f","i","sh"],         "phonemes": ["f","ɪ","ʃ"] },
    { "surface": "and",    "graphemes": ["a","n","d"],          "phonemes": ["æ","n","d"] },
    { "surface": "Sharon", "graphemes": ["sh","a","r","o","n"], "phonemes": ["ʃ","æ","r","ə","n"] },
    { "surface": "had",    "graphemes": ["h","a","d"],          "phonemes": ["h","æ","d"] },
    { "surface": "a",      "graphemes": ["a"],                  "phonemes": ["ə"] },
    { "surface": "shrimp", "graphemes": ["sh","r","i","m","p"], "phonemes": ["ʃ","r","ɪ","m","p"] }
  ]
}
```

Notes:

- `text` is the human-readable rendering with original capitalization and punctuation.
- `targetCount` and `targetInitialContentWords` are author-recorded counts. The validator does **not** read these fields against `words[]` (it computes its own); they exist for debug/PR-review legibility. Always fill them with the truthful count to keep authorial intent on record.
- `surface` preserves capitalization (proper nouns capitalized; sentence-initial `A`/`The` capitalized). The sight-word check normalizes via `.lowercased()`, so case does not affect validation.
- `graphemes[]` is split per Phase-2 phonics: `sh` is a single grapheme; everything else is a single letter. (See R1 — do not merge `ee`, `oo`, `ck`, etc. into multigraphs.)
- `phonemes[]` aligns 1:1 with `graphemes[]`; emit IPA. Vowel renderings: `æ` for short-a, `ɛ` for short-e (or `i` for unstressed `e` per `shiny → [ʃ,aɪ,n,i]`), `ɪ` for short-i, `ɒ` for short-o, `ʌ` for short-u, `ə` for schwa.

### R8 — Per-cell file shell

Every new cell file follows this exact shell. Replace `<INTEREST>`, `<AGEBAND>`, and the `sentences[]` body:

```json
{
  "phoneme": "sh",
  "phonemeIPA": "ʃ",
  "graphemeLetters": "sh",
  "interest": "<INTEREST>",
  "ageBand": "<AGEBAND>",
  "sentences": [
    /* 20 sentence objects per R7 */
  ]
}
```

### R9 — Age-band guidance

The validator caps length at 6–10 across all bands (R4). Use band to vary register, not length:

| Band | Target reading age | Sentence shape | Vocabulary register |
|------|---------------------|----------------|----------------------|
| `early` | 4–7 | Lower end of 6–10 (target ~7 words). Single clause; concrete subject + concrete action. | High-frequency monosyllabic content words; characters as subjects (Shen/Shep/Sharon); avoid abstract nouns. |
| `mid`   | 8–10 | Mid-range (target ~8–9 words). One conjunction allowed. | Adds disyllabic content words (`shiny`, `Sharon`, `shrimp`); more verbs (`dashed`, `rushed`, `washed`). |
| `late`  | 11+ | High end (target ~9–10 words). Two clauses, denser tongue-twister cadence. | Adds adjective+noun stacking (`shiny shy fish`); more `sh` per sentence; can use proper nouns + interest nouns simultaneously. |

These are heuristics for *register*, not validator rules. A 6-word late-band sentence and a 10-word early-band sentence both pass the validator; the band guidance exists so cells feel age-appropriate during PR review.

### R10 — `sh`-themed proper nouns

Spec § 6.2 step 6 lists `Shen`, `Sharon`, `Shep` for `sh` cells. Use these as the recurring cast across all 17 cells (the existing `sh × vehicles × mid` cell already does). Tokenizations:

| Surface | Graphemes | Phonemes |
|---------|-----------|----------|
| `Shen`   | `["sh","e","n"]`         | `["ʃ","ɛ","n"]` |
| `Sharon` | `["sh","a","r","o","n"]` | `["ʃ","æ","r","ə","n"]` |
| `Shep`   | `["sh","e","p"]`         | `["ʃ","ɛ","p"]` |

These count as content words (proper nouns are not in the sight-word whitelist), which means each name's `sh` onset contributes to *both* "total" and "word-initial in content words" counts.

### R11 — Verb pool (sh-decodable)

A small pool of verbs that decompose cleanly into the allowed grapheme set, useful across all cells:

- `had`, `has`, `got`, `let`, `set`, `sat`, `ran`, `hid`, `hit`, `cut`, `put`, `dug`, `fed`, `fit`, `fix`, `lit`, `met`, `rid`, `rip`, `rub`, `sip`
- `shut`, `dash`, `wash`, `rush`, `crush` (sh as final/coda)
- `dashed`, `washed`, `rushed`, `crushed` (`-ed` past) — note the past form decomposes as `[X, e, d]` (regular past tense, the `e` is kept distinct)
- `shop`, `shops`, `shops` — verb senses of sh-words

Avoid: `think`, `think`, `made`, `make`, `take`, `goes`, `went`, `come` (`th`/`ai`/`oa`/`ow`/`oo` digraphs).

---

## Vocabulary starter pools

The agent picks per-cell vocabulary at authoring time; these are starter pools to anchor the interest tagging and avoid drift into forbidden words.

### Animals (sh-decodable, sh-week)

| Band | Pool |
|------|------|
| early | `cat`, `dog`, `hen`, `fox`, `ant`, `rat`, `bat`, `pig`, `bug`, `pup`, `cub`, `kid`, `ox`, `fish`, `shrimp`, `shark` |
| mid   | early pool + `frog`, `ram`, `hog`, `owl`, `swan`, `lamb` (`l,a,m,b` — fine), `gosling` (`g,o,s,l,i,n,g`) |
| late  | mid pool + `hippo`, `llama`, `camel`, `parrot`, `rabbit`, `lizard`, `raven`, `panda`, `python` ✗ (no — `th` digraph; skip), `pony`, `donkey` (`d,o,n,k,e,y` — fine) |

### Dinosaurs (sh-decodable, sh-week)

| Band | Pool |
|------|------|
| early | `rex`, `dino`, `egg`, `fang`, `claw`, `tail`✗ (`ai` digraph; skip), `bone`, `fossil`, `tusk` (`t,u,s,k` — fine) |
| mid   | early pool + `raptor`, `Spino` (proper-noun shorthand for Spinosaurus; `S,p,i,n,o`), `Stego` (`S,t,e,g,o`), `swift`, `pack`✗ (`ck`), `herd`, `roar` |
| late  | mid pool + `Allosaur` (`A,l,l,o,s,a,u,r`), `hadrosaur` (`h,a,d,r,o,s,a,u,r`), `Triassic` ✗ (`a,i` and `c,c`; skip), `predator`, `armor`, `dorsal` |

Note: full Linnaean names (`Tyrannosaurus`, `Stegosaurus`) are too long for our 6–10 word window when combined with required `sh` density. Use short forms (`rex`, `Stego`, `Spino`).

### Vehicles (sh-decodable, sh-week)

The shipped `sh × vehicles × mid` cell uses: `ship`, `shop`, `shed`, `cab`, `van`, `tram`, `jet`. Reuse these for early/late, varying density.

| Band | Pool |
|------|------|
| early | `ship`, `cab`, `van`, `bus`, `jet` |
| late  | early pool + `tram`, `truck` (`t,r,u,c,k`), `taxi`, `submarine` (long; use sparingly), `tanker`, `wagon` (`w,a,g,o,n`), `kart` (`k,a,r,t`) |

(Mid is already shipped; this PR adds early + late only — 2 cells, not 3.)

### Space (sh-decodable, sh-week)

| Band | Pool |
|------|------|
| early | `sun`, `moon` ✗ (`oo`; **avoid** — see R1a), `star`, `rocket`, `planet`, `ship` (rocket ship), `jet` |
| mid   | early pool − `moon` + `comet`, `Mars`, `Saturn`, `Jupiter`, `Mercury`, `orbit` |
| late  | mid pool + `asteroid` (`a,s,t,e,r,o,i,d` — note `oi` is two singles, not a digraph in our tokenization here), `satellite`, `galaxy`, `cosmos`, `meteor`, `lander` |

`moon` is in the spec's spirit but uses the `oo` vowel digraph — skip it for sh cells per R1a. `Mars`, `Saturn`, `Jupiter`, etc., decompose cleanly as singles.

### Sports (sh-decodable, sh-week)

| Band | Pool |
|------|------|
| early | `bat`, `ball`, `net`, `mat`, `kit`, `run`, `hop`, `jog`, `lap` |
| mid   | early pool + `kick` ✗ (`ck`; **skip**), `jump`, `dash`, `tag`, `swim`, `goal`✗ (`oa`; skip), `pass`, `gym` |
| late  | mid pool + `marathon` ✗ (`th`; skip), `javelin`, `relay` ✗ (`ay`), `sprint`, `pitch` ✗ (`ch`), `tennis`, `cricket` ✗ (`ck`) |

Sports has the thinnest pool because so many sport names use forbidden digraphs (`pitch`, `kick`, `match`, `coach`, `relay`, `marathon`). Lean on `bat`, `ball`, `net`, `gym`, `jog`, `run`, `dash`, `swim`, `sprint` and let the proper nouns (Shen/Shep/Sharon) carry the sh-density.

### Robots (sh-decodable, sh-week)

| Band | Pool |
|------|------|
| early | `bot`, `robot`, `kit`, `fan`, `fix`, `run`, `hop` |
| mid   | early pool + `gear`, `motor`, `magnet`, `lever`, `circuit`, `signal`, `boss`, `arm`, `hand` |
| late  | mid pool + `sensor`, `servo`, `actuator`, `propeller`, `transistor` ✗ (`tr` is two letters; fine), `algorithm` ✗ (`th`; skip), `processor` |

---

## File structure

### Files to create (17)

| Path | Status |
|------|--------|
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_early.json` | new (Task 2) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_mid.json`   | new (Task 3) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_late.json`  | new (Task 4) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_early.json` | new (Task 5) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_mid.json` | new (Task 6) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_late.json` | new (Task 7) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_early.json` | new (Task 8) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_late.json`  | new (Task 9) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_early.json`    | new (Task 10) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_mid.json`      | new (Task 11) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_late.json`     | new (Task 12) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_early.json`   | new (Task 13) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_mid.json`     | new (Task 14) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_late.json`    | new (Task 15) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_early.json`   | new (Task 16) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_mid.json`     | new (Task 17) |
| `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_late.json`    | new (Task 18) |

### Files NOT modified

- No source code (`*.swift`) changes.
- No test additions.
- No CI workflow changes (the validator already runs on the bundle).
- No spec or other plan changes.

The shipped `sh × vehicles × mid` cell (`Resources/SentenceLibrary/sh/vehicles_mid.json`) is **untouched** by this PR.

---

## Task 1: Smoke check — confirm pre-existing state

**Goal:** Before authoring any cells, verify `main` is in the state Track B-1 left it: validator passes on the one shipped cell, MoraEngines tests pass.

**Files:** none modified.

- [ ] **Step 1: Run the validator on the existing bundle.**

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: exit 0, with output that includes:

```
sentence-validator: 1 cells, 20 sentences
  PASS
```

If the cell count is anything other than 1 or violations are reported, **STOP** — `main` is not in the expected pre-Track-B-2 state and authoring against it will produce confusing diffs. Fix the bundle first; then proceed.

- [ ] **Step 2: Run MoraEngines tests.**

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -20)
```

Expected: all tests pass, including `SentenceLibraryTests` (4 tests: load + sample-cell counts + nil for unpopulated + invalid-ageBand throws).

- [ ] **Step 3: No commit.** This task is verification-only. Move on to Task 2.

---

## Task 2: `sh × animals × early` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_early.json`

**Cell parameters:**

- `interest`: `animals`
- `ageBand`: `early` (4–7 yo register; 6–8 word sentences; concrete subject + verb + object cadence; high-frequency vocab.)
- Vocab focus (from Vocabulary starter pools § Animals/early): `cat`, `dog`, `hen`, `fox`, `ant`, `rat`, `bat`, `pig`, `bug`, `pup`, `cub`, `fish`, `shrimp`, `shark`.
- Recurring cast: `Shen`, `Sharon`, `Shep` (R10).
- Sh-density anchors: prefer `Shen`/`Sharon`/`Shep` as subjects; mix in `shrimp`/`shark`/`shy`/`shiny` for additional sh-onsets; allow `fish` and `dish` for medial/coda sh.
- `interestWords` examples: `["fish"]`, `["shrimp"]`, `["fish","shrimp"]`, `["shark"]`, `["cat"]`, `["dog","fox"]`.

- [ ] **Step 1: Author 20 sentences obeying the Authoring rulebook (R1–R10).**

Each sentence must:
- Have 6–10 words (R4).
- Use only graphemes from `{a..z, sh}` for non-sight-words; sight words from R2's whitelist may decompose freely.
- Include ≥4 total `sh` graphemes and ≥3 word-initial `sh` content words (R3).
- Include ≥1 word from the Animals interest pool, recorded in `interestWords`.
- Avoid every word in R1's "Concrete forbidden-vocabulary cheat sheet."
- Vary the proper-noun cast across the 20 entries (do not start every sentence with `Shen`).

Aim for thematic coherence across the 20 — these are read by an early-band learner, so concrete shopkeeper-and-pet imagery (Shen and Shep at the shop with shrimp / fish / shy cats) reads naturally.

- [ ] **Step 2: Write the JSON file.**

File path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_early.json`

Use the R8 file shell with `<INTEREST> = animals`, `<AGEBAND> = early`, and 20 sentence objects per R7. Match the formatting of the existing `Resources/SentenceLibrary/sh/vehicles_mid.json` (2-space indent; `surface`, `graphemes`, `phonemes` aligned in column form is encouraged but not required).

- [ ] **Step 3: Run the validator.**

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: exit 0, output:

```
sentence-validator: 2 cells, 40 sentences
  PASS
```

- [ ] **Step 4: If FAIL, fix violations and re-run.**

Common fixes:
- `.undecodableGrapheme(word: X, grapheme: Y)` → either drop the word or replace with a sh-decodable equivalent (consult R1's forbidden list).
- `.targetCountTooLow` → add another sh-onset content word or substitute a sh-word for a non-sh content word.
- `.targetInitialContentWordsTooLow` → swap a sh-coda word (`fish`, `dish`) for a sh-onset word (`shy`, `shiny`, `Shep`).
- `.interestWordsEmpty` → add an interest word to the sentence and tag it.
- `.interestWordNotInSentence(interestWord: X)` → either remove `X` from `interestWords` or add the word to the sentence.
- `.lengthOutOfRange` → trim or expand to 6–10 words.
- `.payloadFilenameMismatch` → fix the `phoneme`/`interest`/`ageBand` header value to match the file path.

Re-run the validator after each batch of fixes. Loop until PASS.

- [ ] **Step 5: Run `MoraEngines` tests to confirm the loader still loads the new cell.**

```sh
(cd Packages/MoraEngines && swift test --filter MoraEnginesTests.SentenceLibraryTests 2>&1 | tail -20)
```

Expected: 4/4 tests pass. The `cellCount` assertion (`>= 1`) is unchanged; `sh × vehicles × mid` is still loaded; `th × robots × late` is still nil. The new cell silently joins the loaded set.

- [ ] **Step 6: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_early.json
git commit -m "content(sentence-library/sh): animals × early (20 sentences)"
```

---

## Task 3: `sh × animals × mid` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_mid.json`

**Cell parameters:**

- `interest`: `animals`
- `ageBand`: `mid` (8–10 yo register; 7–9 word sentences; one conjunction allowed; disyllabic content words OK.)
- Vocab focus (from § Animals/mid): early pool + `frog`, `ram`, `hog`, `owl`, `swan`, `lamb`.
- Recurring cast: `Shen`, `Sharon`, `Shep`.
- Sh-density anchors: same as Task 2 plus `shaggy` (`sh,a,g,g,y`), `shadow` ✗ (skip — `o,w` digraph).
- `interestWords` examples: `["fish","shark"]`, `["shrimp"]`, `["frog"]`, `["owl"]`, `["lamb"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Mid-band: target 8 words, allow `Sharon and Shep` paired subjects, mix in `dashed`/`rushed`/`washed` action verbs for sh-coda density. Do not reuse any of Task 2's specific 20 sentences (some structural overlap is fine; verbatim duplication is not).

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_mid.json`. R8 shell + 20 sentences per R7.

- [ ] **Step 3: Run the validator.**

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: `3 cells, 60 sentences\n  PASS`.

- [ ] **Step 4: Fix violations and re-run.** See Task 2 Step 4 for the violation → fix mapping.

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_mid.json
git commit -m "content(sentence-library/sh): animals × mid (20 sentences)"
```

---

## Task 4: `sh × animals × late` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_late.json`

**Cell parameters:**

- `interest`: `animals`
- `ageBand`: `late` (11+ yo register; 9–10 word sentences; two clauses allowed; denser tongue-twisters.)
- Vocab focus (from § Animals/late): mid pool + `hippo`, `llama`, `camel`, `parrot`, `rabbit`, `lizard`, `raven`, `panda`, `pony`, `donkey`.
- Sh-density anchors: stack adjectives (`a shy shaggy fish`) for medial sh; combine multiple proper nouns (`Shen and Sharon`) for compound subjects.
- `interestWords` examples: `["hippo"]`, `["llama","camel"]`, `["lizard"]`, `["panda"]`, `["raven"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Late-band: target 9–10 words; structures like `Shep dashed past a shy fish and Sharon hid a hippo`. Two-clause "X did Y, and A did B" works well. Maintain interest tagging — at least one animal noun per sentence even when the cast is heavy.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_late.json`.

- [ ] **Step 3: Run the validator.** Expected `4 cells, 80 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/animals_late.json
git commit -m "content(sentence-library/sh): animals × late (20 sentences)"
```

---

## Task 5: `sh × dinosaurs × early` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_early.json`

**Cell parameters:**

- `interest`: `dinosaurs`
- `ageBand`: `early`
- Vocab focus (§ Dinosaurs/early): `rex`, `dino`, `egg`, `fang`, `claw`, `bone`, `fossil`, `tusk`.
- Sh-density anchors: dinosaurs vocab is sh-light (no dinosaur word starts with sh), so lean heavily on the proper-noun cast (`Shen`/`Sharon`/`Shep`) plus `shy`/`shiny`/`shed` modifiers.
- `interestWords` examples: `["rex"]`, `["dino"]`, `["fossil"]`, `["egg"]`, `["fang","claw"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Aim for shapes like `Shen had a shiny rex and Sharon had a fossil` — two proper nouns + 1 sh modifier easily clears 4 sh-onsets in 9 words. Recheck R1's forbidden list; `Tyrannosaurus`/`Stegosaurus` are out (length); `pterodactyl` ✗ (`pt`, `cy`); `triceratops` is fine grapheme-wise but at 11 letters and 4 syllables is mid/late material.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_early.json`.

- [ ] **Step 3: Run the validator.** Expected `5 cells, 100 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_early.json
git commit -m "content(sentence-library/sh): dinosaurs × early (20 sentences)"
```

---

## Task 6: `sh × dinosaurs × mid` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_mid.json`

**Cell parameters:**

- `interest`: `dinosaurs`
- `ageBand`: `mid`
- Vocab focus (§ Dinosaurs/mid): early pool + `raptor`, `Spino`, `Stego`, `swift`, `herd`, `roar`.
- Sh-density anchors: same as Task 5; the dinosaur subject is the sh-tag, the cast carries the sh-onsets.
- `interestWords` examples: `["raptor"]`, `["Stego"]`, `["Spino","rex"]`, `["herd"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Mid-band: 8 words; one verb of action (`Sharon and Shep saw a swift raptor at the shop`).

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_mid.json`.

- [ ] **Step 3: Run the validator.** Expected `6 cells, 120 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_mid.json
git commit -m "content(sentence-library/sh): dinosaurs × mid (20 sentences)"
```

---

## Task 7: `sh × dinosaurs × late` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_late.json`

**Cell parameters:**

- `interest`: `dinosaurs`
- `ageBand`: `late`
- Vocab focus (§ Dinosaurs/late): mid pool + `Allosaur`, `hadrosaur`, `predator`, `armor`, `dorsal`.
- Sh-density anchors: late tongue-twister density — pair `Shen and Shep` + `shiny shy raptor` + sh-coda verb (`dashed`/`rushed`).
- `interestWords` examples: `["raptor","predator"]`, `["hadrosaur"]`, `["Allosaur"]`, `["fossil","armor"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Late-band: 9–10 words; example shape: `Sharon and Shep dashed past a shy hadrosaur and a shiny rex`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_late.json`.

- [ ] **Step 3: Run the validator.** Expected `7 cells, 140 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/dinosaurs_late.json
git commit -m "content(sentence-library/sh): dinosaurs × late (20 sentences)"
```

---

## Task 8: `sh × vehicles × early` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_early.json`

**Cell parameters:**

- `interest`: `vehicles`
- `ageBand`: `early` (the existing `vehicles × mid` is the natural reference for tone; aim simpler.)
- Vocab focus (§ Vehicles/early): `ship`, `cab`, `van`, `bus`, `jet`.
- Sh-density anchors: `ship` itself is a sh-onset content word, so vehicles cells reach 4 sh easily — usually 2 proper nouns + 1 `ship` + 1 `shop`/`shed` carries it.
- `interestWords` examples: `["ship"]`, `["van","cab"]`, `["bus"]`, `["jet"]`.
- Reference cell: read `Resources/SentenceLibrary/sh/vehicles_mid.json` for tone before authoring; aim for shorter sentences and simpler vocab. Do not duplicate any sentence from the mid cell verbatim.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Early-band: 6–7 words; example: `Shen and Sharon got on a ship`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_early.json`.

- [ ] **Step 3: Run the validator.** Expected `8 cells, 160 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_early.json
git commit -m "content(sentence-library/sh): vehicles × early (20 sentences)"
```

---

## Task 9: `sh × vehicles × late` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_late.json`

**Cell parameters:**

- `interest`: `vehicles`
- `ageBand`: `late`
- Vocab focus (§ Vehicles/late): early pool + `tram`, `truck`, `taxi`, `tanker`, `wagon`, `kart`, `submarine`.
- Sh-density anchors: late-band can stack 2–3 vehicles in one sentence (`a ship and a tram and a kart`) with proper nouns providing sh-onset.
- `interestWords` examples: `["ship","tram"]`, `["truck"]`, `["submarine"]`, `["wagon"]`.
- Reference cell: again the existing mid cell for tone; aim for denser tongue-twister cadence.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Late-band: 9–10 words; example: `Sharon and Shep dashed past a shiny ship and a swift tram`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_late.json`.

- [ ] **Step 3: Run the validator.** Expected `9 cells, 180 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/vehicles_late.json
git commit -m "content(sentence-library/sh): vehicles × late (20 sentences)"
```

---

## Task 10: `sh × space × early` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_early.json`

**Cell parameters:**

- `interest`: `space`
- `ageBand`: `early`
- Vocab focus (§ Space/early): `sun`, `star`, `rocket`, `planet`, `ship` (rocket ship), `jet`. **Skip `moon` per R1a (`oo` digraph).**
- Sh-density anchors: `ship` (rocket ship) is the sh-onset workhorse; otherwise rely on cast.
- `interestWords` examples: `["rocket","ship"]`, `["sun"]`, `["star"]`, `["planet"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Early-band: example: `Shen had a shiny rocket ship and a star`. Watch for `moon` slipping in — drop it on sight.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_early.json`.

- [ ] **Step 3: Run the validator.** Expected `10 cells, 200 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_early.json
git commit -m "content(sentence-library/sh): space × early (20 sentences)"
```

---

## Task 11: `sh × space × mid` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_mid.json`

**Cell parameters:**

- `interest`: `space`
- `ageBand`: `mid`
- Vocab focus (§ Space/mid): early pool − `moon` + `comet`, `Mars`, `Saturn`, `Jupiter`, `Mercury`, `orbit`.
- Sh-density anchors: same as Task 10. `ship` (rocket ship) is the sh-onset workhorse.
- `interestWords` examples: `["Mars","comet"]`, `["Saturn"]`, `["Jupiter"]`, `["orbit"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Mid-band: example: `Shen and Shep had a ship and a comet to Mars`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_mid.json`.

- [ ] **Step 3: Run the validator.** Expected `11 cells, 220 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_mid.json
git commit -m "content(sentence-library/sh): space × mid (20 sentences)"
```

---

## Task 12: `sh × space × late` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_late.json`

**Cell parameters:**

- `interest`: `space`
- `ageBand`: `late`
- Vocab focus (§ Space/late): mid pool + `asteroid`, `satellite`, `galaxy`, `cosmos`, `meteor`, `lander`.
- Sh-density anchors: late-band can pair `Shen and Sharon` with `dashed`/`rushed` past `a comet` for both sh-onset and sh-coda density.
- `interestWords` examples: `["asteroid"]`, `["satellite","galaxy"]`, `["meteor"]`, `["cosmos","Mars"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Late-band: example: `Shen and Sharon dashed past a shiny satellite and a comet`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_late.json`.

- [ ] **Step 3: Run the validator.** Expected `12 cells, 240 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/space_late.json
git commit -m "content(sentence-library/sh): space × late (20 sentences)"
```

---

## Task 13: `sh × sports × early` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_early.json`

**Cell parameters:**

- `interest`: `sports`
- `ageBand`: `early`
- Vocab focus (§ Sports/early): `bat`, `ball`, `net`, `mat`, `kit`, `run`, `hop`, `jog`, `lap`.
- Sh-density anchors: sports vocab is sh-light; the proper-noun cast carries most of the density. `dash`/`dashed`/`rush` are sport-tangent and sh-coda useful.
- `interestWords` examples: `["bat"]`, `["ball","net"]`, `["mat"]`, `["jog"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Early-band: example: `Shep had a shiny bat and Sharon had a net`. Avoid `kick` (`ck`), `pitch` (`ch`), `coach` (`ch`/`oa`).

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_early.json`.

- [ ] **Step 3: Run the validator.** Expected `13 cells, 260 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_early.json
git commit -m "content(sentence-library/sh): sports × early (20 sentences)"
```

---

## Task 14: `sh × sports × mid` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_mid.json`

**Cell parameters:**

- `interest`: `sports`
- `ageBand`: `mid`
- Vocab focus (§ Sports/mid): early pool + `jump`, `dash`, `tag`, `swim`, `pass`, `gym`. **Skip `kick` (ck), `goal` (oa).**
- Sh-density anchors: `dash`/`dashed`/`crush`/`rush` for sh-coda; cast for sh-onset.
- `interestWords` examples: `["bat","ball"]`, `["jump"]`, `["dash"]`, `["gym"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Mid-band: example: `Sharon dashed past Shep to get a shiny bat`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_mid.json`.

- [ ] **Step 3: Run the validator.** Expected `14 cells, 280 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_mid.json
git commit -m "content(sentence-library/sh): sports × mid (20 sentences)"
```

---

## Task 15: `sh × sports × late` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_late.json`

**Cell parameters:**

- `interest`: `sports`
- `ageBand`: `late`
- Vocab focus (§ Sports/late): mid pool + `javelin`, `sprint`, `tennis`. **Skip `marathon` (th), `relay` (ay), `pitch` (ch), `cricket` (ck).**
- Sh-density anchors: stack `dashed past a` clauses; pair adjectives `shiny shy bat`.
- `interestWords` examples: `["javelin"]`, `["sprint","dash"]`, `["tennis","bat"]`, `["gym","ball"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Late-band: example: `Shep dashed past a shiny shy bat and Sharon ran a lap`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_late.json`.

- [ ] **Step 3: Run the validator.** Expected `15 cells, 300 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/sports_late.json
git commit -m "content(sentence-library/sh): sports × late (20 sentences)"
```

---

## Task 16: `sh × robots × early` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_early.json`

**Cell parameters:**

- `interest`: `robots`
- `ageBand`: `early`
- Vocab focus (§ Robots/early): `bot`, `robot`, `kit`, `fan`, `fix`, `run`, `hop`.
- Sh-density anchors: cast + `shiny`/`shy`/`shed` modifiers; `robot` is sh-light, so `Shen had a shiny robot` shape works well.
- `interestWords` examples: `["robot"]`, `["bot"]`, `["kit"]`, `["fan"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Early-band: example: `Shen had a shiny robot and a shy bot`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_early.json`.

- [ ] **Step 3: Run the validator.** Expected `16 cells, 320 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_early.json
git commit -m "content(sentence-library/sh): robots × early (20 sentences)"
```

---

## Task 17: `sh × robots × mid` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_mid.json`

**Cell parameters:**

- `interest`: `robots`
- `ageBand`: `mid`
- Vocab focus (§ Robots/mid): early pool + `gear`, `motor`, `magnet`, `lever`, `circuit`, `signal`, `arm`, `hand`.
- Sh-density anchors: same as Task 16; `Sharon and Shep had a shiny gear and a magnet` clears density easily.
- `interestWords` examples: `["robot","gear"]`, `["motor"]`, `["magnet","circuit"]`, `["arm","hand"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Mid-band: example: `Sharon and Shep had a shiny robot and a magnet`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_mid.json`.

- [ ] **Step 3: Run the validator.** Expected `17 cells, 340 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_mid.json
git commit -m "content(sentence-library/sh): robots × mid (20 sentences)"
```

---

## Task 18: `sh × robots × late` cell

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_late.json`

**Cell parameters:**

- `interest`: `robots`
- `ageBand`: `late`
- Vocab focus (§ Robots/late): mid pool + `sensor`, `servo`, `actuator`, `propeller`, `processor`. **Skip `algorithm` (th).**
- Sh-density anchors: late-band tongue-twister; `Shep dashed past a shiny sensor and Sharon hid a magnet`.
- `interestWords` examples: `["sensor","servo"]`, `["robot","processor"]`, `["actuator"]`, `["propeller"]`.

- [ ] **Step 1: Author 20 sentences per R1–R10.** Late-band: example: `Sharon and Shep dashed past a shiny sensor and a magnet`.

- [ ] **Step 2: Write the JSON file.** Path: `Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_late.json`.

- [ ] **Step 3: Run the validator.** Expected `18 cells, 360 sentences\n  PASS`.

- [ ] **Step 4: Fix violations.**

- [ ] **Step 5: Commit.**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/sh/robots_late.json
git commit -m "content(sentence-library/sh): robots × late (20 sentences)"
```

---

## Task 19: Final verification + push

**Goal:** Confirm the whole `sh` phoneme is bundled cleanly and the rest of the codebase still builds and tests; then push the branch.

**Files:** none modified.

- [ ] **Step 1: Confirm cell count via validator.**

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Expected: exit 0, output:

```
sentence-validator: 18 cells, 360 sentences
  PASS
```

If anything other than `18 cells, 360 sentences` is reported, identify which cell is missing or short and revisit the corresponding Task 2–18 step before pushing.

- [ ] **Step 2: Confirm `MoraEngines` tests still pass.**

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -20)
```

Expected: all tests pass. The test count is unchanged from `main`; the four `SentenceLibraryTests` cases keep working because:
- `cellCount >= 1` → still true (now 18).
- `sh × vehicles × mid` cell → still loads, still 20 sentences.
- `th × robots × late` → still nil (this PR only touches `sh/`).
- invalid-ageBand fixture → still throws.

- [ ] **Step 3: Confirm full SPM cross-package green.**

```sh
(cd Packages/MoraCore && swift test 2>&1 | tail -5)
(cd Packages/MoraUI && swift test 2>&1 | tail -5)
(cd Packages/MoraTesting && swift test 2>&1 | tail -5)
(cd dev-tools/sentence-validator && swift test 2>&1 | tail -5)
```

Expected: each subshell prints test success summary (no failures, no errors). Content-only PRs don't touch Swift code, but a sanity check guards against accidental dirty state.

- [ ] **Step 4: Run swift-format strict lint.**

```sh
swift-format lint --strict --recursive \
    Mora Packages/*/Sources Packages/*/Tests \
    dev-tools/sentence-validator/Sources dev-tools/sentence-validator/Tests
```

Expected: zero output, exit 0. Content JSON is not Swift; the lint pass is purely a sanity check that no surrounding Swift accidentally changed.

- [ ] **Step 5: Regenerate Xcode project and build.**

```sh
xcodegen generate
xcodebuild build \
    -project Mora.xcodeproj -scheme Mora \
    -destination 'generic/platform=iOS Simulator' \
    -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -15
```

Expected: `** BUILD SUCCEEDED **`. Per `CLAUDE.md`, run xcodegen any time `project.yml` changed — it didn't here, but the build still verifies that the new bundled JSON files are picked up under `Resources/SentenceLibrary/sh/` without the bundle copy phase choking.

- [ ] **Step 6: Push the branch.**

```sh
git push -u origin HEAD
```

- [ ] **Step 7: Open the PR.**

Use `gh pr create` with the title:

```
content(sentence-library): sh phoneme — 17 cells × 20 sentences (Track B-2 Phase 1)
```

Body (HEREDOC) including:
- One-paragraph summary referencing spec § 6 and § 9 PR 3.
- "Tracks: B-2 Phase 1 (sh phoneme); 4 phonemes remain (`th`, `f`, `r`, `short_a`) under the same plan shape."
- Validator report from Step 1: `18 cells, 360 sentences  PASS`.
- "No code or test changes; pure content."
- Link to the spec and to this plan: `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md`, `docs/superpowers/plans/2026-04-25-decodable-sentence-library-sh-cells.md`.
- Test plan checklist: validator green; `swift test` per package green; `xcodebuild build` SUCCEEDED.
- Per `CLAUDE.md`'s `Co-author / generated-by attribution` opt-in for this repo, end the body with:
  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

---

## Self-review

Spec coverage check:

- **Track B § 6.1 matrix** — this PR fills the `sh` row of the matrix (`sh × {6 interests} × {3 age bands} = 18 cells`, of which 17 are new and `vehicles × mid` exists). Other phonemes are explicitly out of scope per Deviation 1.
- **§ 6.2 sentence rules** — encoded in Authoring rulebook R1–R10; per-task instructions reference R1–R10 by number.
- **§ 6.3 generation flow** — the per-task step shape (author → write → validate → fix → commit) is the spec's loop: "Claude Code emits 20 candidate sentences" → "user runs the validator" → "Failures are reported" → "Claude Code regenerates only the failing entries; passing entries are preserved" → "Loop until all 20 pass" → "Cell file is committed."
- **§ 6.4 validator** — used as the gating CI check at every cell commit (Steps 3–4 in Tasks 2–18 and Step 1 in Task 19). No validator changes in this PR; the B-1-shipped CLI is the contract.
- **§ 6.5 schema** — encoded in R7 + R8 + the existing `sh × vehicles × mid` reference.
- **§ 6.6 / § 6.7 runtime** — out of scope for B-2; explicitly deferred to B-3 by the `fatalError` in `SentenceLibrary.sentences(...)`.
- **§ 6.10 tests** — selectively in scope: only the bundle-counting tests added in B-1 are exercised; bigger library-completeness tests (`90 cells × 20`) are deferred until all phonemes ship.
- **§ 8 risks** — "Tongue-twister density unattainable for some `(interest, ageBand)` cells" is acknowledged inline (sports cells are constrained by forbidden-digraph collisions; the rulebook + vocab pools steer authoring around it).
- **§ 9 PR 3** — this plan is the first slice of PR 3, scoped to the `sh` phoneme per the spec's "individually or in small per-phoneme batches" sentence.

Placeholder scan:

- No "TBD"/"TODO"/"implement later"/"add appropriate error handling"/"similar to Task N" anywhere in the cell tasks.
- Each cell task names exact `interestWords` examples and exact vocab pools by reference, not abstract description.
- The validator command, lint command, build command are all literal — copy-paste runnable.
- One commit message per task is given verbatim.

Type / value consistency:

- File-path stems align with `(interest, ageBand)` payload pairs across all 17 cells.
- Validator's expected output ("`N cells, M*20 sentences\n  PASS`") matches the actual cell-count progression: pre-existing 1 cell + i cells after Task `2+i-1` (Task 2 → 2 cells, Task 18 → 18 cells).
- Sight word list (`the, a, and, is, to, on, at`) is identical between R2 in this plan and the validator's `sightWords` constant in `SentenceValidatorCLI.swift:36`.
- Tokenization conventions in R7 match the existing `sh × vehicles × mid` cell verbatim.

No spec gaps. No internal contradictions. Plan is ready.
