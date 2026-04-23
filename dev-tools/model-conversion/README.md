# dev-tools/model-conversion

Converts `facebook/wav2vec2-xlsr-53-espeak-cv-ft` from Hugging Face to a
CoreML package ready to ship in `Packages/MoraMLX`. Emits:

- `wav2vec2-phoneme.mlmodelc/` — compiled CoreML model, INT8-quantized.
- `phoneme-labels.json` — ordered espeak IPA label list matching the
  model's final classification head.

This tool runs on the developer's machine, never in CI. Output artifacts
are checked into the repo via Git LFS (see `.gitattributes` at repo root).

## Requirements

Python 3.11 is recommended (3.12 works but the pinned coremltools version
tracks 3.11). A Hugging Face access token with read access to the pinned
model revision is required.

Create a virtualenv and install the pinned requirements:

    python3.11 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

Copy `.env.example` to `.env` and fill in `HF_TOKEN`. The `.env` file is
gitignored.

## Running

From this directory:

    python convert.py \
        --output-dir ../../Packages/MoraMLX/Sources/MoraMLX/Resources

The script downloads the model, quantizes to INT8, exports `.mlpackage`,
compiles to `.mlmodelc`, and writes `phoneme-labels.json`. Expected output
size ~150 MB. Runtime ~10 minutes on an M2 MacBook Pro.

## Pinned model revision

`facebook/wav2vec2-xlsr-53-espeak-cv-ft` revision `3693e11` (SHA set in
`convert.py`). Changing the revision requires bumping the pin and
re-running the conversion; any behavior change is a product decision,
not a tooling one.
