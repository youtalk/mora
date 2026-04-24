# RPG Shell Yokai — Voice + Catalog Follow-up (R4 Part B)

Follow-up to the portraits-only R4 PR (#63, "assets(yokai): bundle first
five yokai portraits (R4 part A)"). The original R4 plan at
`docs/superpowers/plans/2026-04-23-rpg-shell-yokai.md` scoped R4 as
"five portraits + forty voice clips + catalog finalization"; portraits
landed first as a self-contained PR and the voice/catalog tail moves
here so it can merge independently once reference audio is ready.

## Status at start of this plan

**Shipped in the portraits PR (R4 Part A):**

- 5 portraits committed as plain binary under
  `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/<id>/portrait.png`
  (no Git LFS — origin/main dropped `.gitattributes` in #62 before this
  branch landed, so binaries go in directly; ~3 MB total for all five).
- Forge tooling iteratively tuned: prompt pipeline converged on
  iteration-3 (`body_shape` field per yokai + front-loaded mouth pose
  + stripped "not X" negatives from the positive layer) plus a per-yokai
  sh fix (human-proportioned arm, fingertip beside the lips).
- `render_portraits.py` accepts `--all` and makes `--lora` optional
  (Style LoRA training was skipped — prompt-only quality hit the
  shipping bar).
- `synthesize_voices.py` migrated to fish-speech v2 HTTP API (the
  original `fish-speech generate ...` CLI was removed upstream in v2).

**Rejected during R4 Part A, do not revisit:**

- FLUX ControlNet-Canny conditioning on per-phoneme mouth sketches.
  Produces unmistakable "uncanny valley" composites even at low
  cn-scale (the mouth reads as a sticker forced onto the character).
  Scripts (`make_mouth_sketches.py`, `render_with_canny.py`) and the
  InstantX checkpoint download live in commit history but are not used
  for any shipped asset.

**Already staged on the youtalk-desktop Ubuntu workstation:**

- `~/fish-speech` — v2.0.0 clone, installed editable into
  `~/mora-forge-work/venv`.
- `~/fish-speech/checkpoints/s2-pro` — full Fish Speech S2 Pro
  checkpoint (~11 GB, all 13 files). `python tools/api_server.py`
  picks this up automatically via the upstream defaults.
- FLUX.1-dev weights cached (not needed for voice, but available for
  further portrait tweaks if something needs redoing).

## Tasks

### Task V1: Collect voice references (USER INPUT)

For each yokai in `{sh, th, f, r, short_a}`, drop two files into
`tools/yokai-forge/refs/` on the Ubuntu box:

- `<id>_reference.wav` — 5–30 s clean speech clip of the target voice
  timbre. Sources: an ElevenLabs v3 free-tier export prompted with the
  yokai's `voice.character_description` from `YokaiCatalog.json`, a
  recorded human voice, or any other cleared source. No background
  music, no overlapping speakers.
- `<id>_reference.txt` — verbatim transcription of that WAV. Required
  by Fish Speech v2's in-context voice cloning; audio alone degrades
  the cloned timbre substantially.

The 8 per-yokai clip **texts** are already authored in
`Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json` under
`voice.clips.{phoneme,example_1,example_2,example_3,greet,encourage,gentle_retry,friday_acknowledge}`
— nothing further to write.

### Task V2: Synthesize + master 8 clips × 5 yokai

```sh
cd ~/.config/superpowers/worktrees/mora/rpg-yokai-r4-assets/tools/yokai-forge
source ~/mora-forge-work/venv/bin/activate
for y in sh th f r short_a; do
  python scripts/synthesize_voices.py --yokai "$y"   # spins up api_server, hits /v1/tts per clip
  python scripts/master_audio.py --yokai "$y"        # loudnorm + 22050 Hz mono AAC
done
```

Expected outputs per yokai:

- `outputs/voice/<id>/<clip_key>.wav` — 8 raw WAVs from the API.
- `outputs/voice/<id>/mastered/<clip_key>.m4a` — 8 mastered clips
  (–16 LUFS, 22050 Hz, mono, AAC 96 kbps).

On the RTX 5090, model cold start through api_server is ~1–2 min per
yokai invocation; each /v1/tts call is a few seconds. 5 yokai × (~90 s
load + 8 × ~5 s synth + master) ≈ 12 min end-to-end.

### Task V3: Bundle mastered clips into Resources

```sh
cd ~/.config/superpowers/worktrees/mora/rpg-yokai-r4-assets
for y in sh th f r short_a; do
  mkdir -p "Packages/MoraCore/Sources/MoraCore/Resources/Yokai/$y/voice"
  cp "tools/yokai-forge/outputs/voice/$y/mastered/"*.m4a \
     "Packages/MoraCore/Sources/MoraCore/Resources/Yokai/$y/voice/"
done
```

Verify:

```sh
ls Packages/MoraCore/Sources/MoraCore/Resources/Yokai/*/voice/*.m4a | wc -l
# expect 40 (8 × 5)
```

All forty files commit as plain binary (no LFS — origin/main has no
`.gitattributes`). Combined size expected ~2–4 MB at 96 kbps AAC over
~1–3 s clips.

### Task V4: Finalize YokaiCatalog.json to match bundled portraits

**File:** `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json`

The R1 catalog was written against the original per-yokai JSON specs
and has drifted from the final picked portraits in a handful of
narrative-descriptor fields. Reconcile each record against what the
portrait actually depicts:

- `sh`
  - `word_decor` — replace "pointed seashell ears" with "curved
    seashell headpieces jutting like horns" (picked portrait has no
    cat-ear silhouette).
  - `expression` — swap in "kiss-pucker lips and winking eye,
    mischievous mood" to match the shushing pose.
- `th`
  - `word_decor` — replace "small lightning-bolt ear tufts" with
    "small lightning-bolt antennae on the head". Remove the stray
    "thumb-up paw held forward" decor entry (it duplicated
    `sound_gesture`).
- `f`
  - `word_decor` — move "soft feather" from "on one ear" to "tucked at
    the crown of the head" (matches picked portrait).
- `r`
  - `personality` — replace "tiger-cub rumble yokai" with "rumbling
    rock-spirit yokai" (picked portrait has a cracked boulder body, not
    a tiger cub).
- `short_a` — no changes; current values match the picked portrait.

Fields that drive engine behavior (`id`, `grapheme`, `ipa`,
`voice.clips.*`) stay untouched. `voice.character_description` stays
unchanged so users generating reference WAVs can keep using it as a
prompt for ElevenLabs or similar.

Run after editing:

```sh
(cd Packages/MoraCore && swift test)
```

Expect green; the `YokaiCatalogLoaderTests` accept any well-formed
schema, and no tests assert specific descriptor strings.

### Task V5: Xcode smoke on the Mac

```sh
git pull                        # pull the voice bundle commit
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expect BUILD SUCCEEDED. If `YokaiResourceAnchor` or the SwiftUI
bestiary view picks up a stale bundle, regenerate from
`project.yml` and re-run.

### Task V6: Open PR

Title: `assets(yokai): bundle voice clips + finalize catalog (R4 part B)`

Body:

```markdown
## Summary
- Adds 8 mastered voice clips (~96 kbps AAC, 22050 Hz mono) for each of
  sh / th / f / r / short_a under `Packages/MoraCore/.../Resources/Yokai/<id>/voice/`.
- Reconciles YokaiCatalog.json metadata to match the portraits shipped
  in the Part A PR.

## Test plan
- [ ] `ls Packages/MoraCore/Sources/MoraCore/Resources/Yokai/*/voice/*.m4a | wc -l` = 40
- [ ] `(cd Packages/MoraCore && swift test)` green
- [ ] `xcodebuild build` green
- [ ] Manual: run a session end-to-end; each yokai plays its greeting
      clip and the per-phoneme example clips on trial outcomes.
```

## Design decisions captured (for future sessions)

- **Phoneme articulation does not live in the portrait.** After three
  prompt iterations + a rejected ControlNet experiment, the portrait
  carries character personality / body silhouette / approximate mouth
  expression. Teaching the precise mouth shape for each phoneme (e.g.
  the /θ/ tongue-between-teeth articulation) is a problem for a
  future UI layer (SVG or Lottie mouth overlay), not a problem the
  still portrait can solve on its own. Out of scope for R4 Part B;
  track separately if taken up.
- **No Git LFS for this repo going forward.** #62 removed
  `.gitattributes` and moved wav2vec2 to GitHub Releases. Plain binary
  commits are the accepted pattern for the yokai asset set too.
- **Fish Speech v2 requires paired audio + transcription for voice
  cloning.** The plan Appendix A.6 only mentions the audio file;
  document the `.txt` companion when/if the appendix is updated.
- **FLUX CLIP truncation is expected.** Composed prompts run ~220–270
  tokens; CLIP sees only the first 77. The front-loading in
  `compose_prompt.py` (style → personality → body_shape → mouth_pose)
  keeps the critical silhouette + phoneme tokens inside the CLIP
  budget, while T5 reads the full sequence.

## Self-review checklist

After V1–V6 merge:

- [ ] 40 voice clips present under `Resources/Yokai/*/voice/*.m4a`.
- [ ] `YokaiCatalog.json` descriptors align with picked portraits.
- [ ] `swift test` in each package passes.
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests`
      clean.
- [ ] `xcodebuild build` succeeds on a clean checkout.
- [ ] Manual α: full week runs end-to-end with portraits + greetings
      playing per yokai.
