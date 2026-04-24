# yokai-forge

Offline asset pipeline for mora's yokai portraits and voice clips.

## Ubuntu bootstrap (RTX 5090)

Host: `youtalk-desktop.local`. Python 3.12 system. See Appendix A of
`docs/superpowers/plans/2026-04-23-rpg-shell-yokai.md` for the exact
commands (run manually on the workstation).

## Inputs

- `prompts/style_layer.txt` — Layer-1 constant prompt, feeds every portrait.
- `prompts/yokai_*.json` — Per-yokai JSON spec following the schema in design spec §7.

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

Binary assets ship via Git LFS.
