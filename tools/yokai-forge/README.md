# yokai-forge

Offline asset pipeline for mora's yokai portraits and voice clips.

## Ubuntu bootstrap (RTX 5090)

Host: `youtalk-desktop.local`. Python 3.12 system. See Appendix A of
`docs/superpowers/plans/2026-04-23-rpg-shell-yokai.md` for the exact
commands (run manually on the workstation).

## Inputs

- `prompts/style_layer.txt` — Layer-1 constant prompt, feeds every portrait.
- `prompts/yokai_*.json` — Per-yokai JSON spec following the schema in design spec §7.
- `refs/<yokai_id>_reference.wav` — user-curated 5–30 s reference clip of the
  voice timbre (e.g. ElevenLabs v3 free-tier export of the yokai's
  `voice.character_description`).
- `refs/<yokai_id>_reference.txt` — verbatim transcription of the reference clip.
  Fish Speech S2 Pro requires paired audio + text for voice cloning.

## Outputs

- `outputs/portraits/<yokai_id>/candidate_*.png` — batch generations.
- `outputs/voice/<yokai_id>/<clip>.m4a` — mastered audio.

## Workflow

1. Run `scripts/bootstrap_style.py` once to seed the Style LoRA training set.
2. Train Style LoRA via `scripts/train_style_lora.sh`.
3. Run `scripts/render_portraits.py --yokai sh` to generate 20–30 candidates.
4. Curate; copy the chosen PNG into mora repo at `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/<id>/portrait.png`.
5. Run `scripts/synthesize_voices.py --yokai sh` for voice clips.
6. Master via `scripts/master_audio.py`; copy outputs into mora repo.
7. QC-audit the bundled m4a via `scripts/audit_voices.py`. It transcribes
   every clip with Whisper (`small.en` first, escalating to `medium.en`
   on miss), fuzzy-matches against `voice.clips.*` in `YokaiCatalog.json`,
   and surfaces truncated tails / hallucinated filler text / dropped
   phonemes without listening to every clip by hand. `--strict` exits
   non-zero on any FAIL so it can gate CI or pre-merge checks.

Binary assets ship as plain Git blobs (LFS was removed from the repo in
PR #62).

## Licensing — commercial release requires swap-outs

This pipeline is **non-commercial only** as wired up in the MVP. Every generated
portrait / voice clip inherits the most restrictive license in the chain that
produced it. Before any commercial release (paid App Store tier, in-app
purchase, or ad-supported distribution) the following dependencies must be
replaced or re-licensed:

| Dependency | License | Commercial use? |
|---|---|---|
| Flux.1 dev (`black-forest-labs/FLUX.1-dev`) | FLUX.1 [dev] Non-Commercial License | ❌ — swap to FLUX.1 [schnell] (Apache 2.0) or FLUX.1 [pro] (paid commercial API) |
| Fish Speech S2 Pro | CC-BY-NC-SA-4.0 for model weights | ❌ — swap to a commercially-licensed TTS (e.g. ElevenLabs commercial tier, or record real voice actors) |
| Bark (Suno) | MIT (weights + code) | ✅ |
| Ostris AI Toolkit | Apache 2.0 | ✅ — training wrapper only; LoRA output inherits the base model's license |
| diffusers / transformers / accelerate | Apache 2.0 | ✅ |

The repo-level license (`PolyForm Noncommercial 1.0.0`) already blocks
commercial distribution, so there is no immediate license conflict; the
constraint is that *even if* the repo license changes later, the bundled
portraits and voice clips under `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/`
would still be NC-only unless they are **regenerated from commercially-cleared
models** with the same prompts/refs. Re-running the whole forge with
schnell + a cleared TTS is the cleanest path.

See design spec §10 for the rationale and the planned commercial-swap
checklist.
