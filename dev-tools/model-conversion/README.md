# dev-tools/model-conversion

Converts `facebook/wav2vec2-xlsr-53-espeak-cv-ft` from Hugging Face to a
CoreML package ready to ship in `Packages/MoraMLX`. Emits:

- `wav2vec2-phoneme.mlmodelc/` — compiled CoreML model, INT8-quantized.
- `phoneme-labels.json` — ordered espeak IPA label list matching the
  model's final classification head.

This tool runs on the developer's machine, never in CI. Output artifacts
are checked into the repo via Git LFS (see `.gitattributes` at repo root).

## Requirements

- macOS with Xcode Command Line Tools (`xcrun coremlcompiler` is required
  for the `.mlpackage` → `.mlmodelc` compile step, so Linux / Docker are
  not viable hosts).
- Python 3.11. `coremltools==7.2` + `torch==2.3.1` only publish wheels
  for 3.8–3.11; 3.12+ will fail to resolve the pinned dependency set.
- ~2 GB free disk: ~1.3 GB model download cache under `~/.cache/huggingface`
  plus a ~150 MB compiled artifact and a short-lived `.mlpackage`
  intermediate in a scratch tempdir.

The upstream model is public, so **no Hugging Face token is required**.

## Setup with `uv` (recommended)

[`uv`](https://github.com/astral-sh/uv) is an isolated Python package
manager — it fetches a project-local Python 3.11 under
`~/.local/share/uv/` without touching system or Homebrew Python.

    brew install uv

From this directory:

    uv venv --python 3.11
    uv pip install -r requirements.txt

## Setup with Homebrew Python 3.11 (alternative)

    brew install python@3.11
    /opt/homebrew/opt/python@3.11/bin/python3.11 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

## Running

    source .venv/bin/activate  # if using uv; Homebrew flow already sourced it
    python convert.py \
        --output-dir ../../Packages/MoraMLX/Sources/MoraMLX/Resources

The script downloads the model, quantizes to INT8, exports `.mlpackage`
into a tempdir, compiles it to `.mlmodelc`, and writes
`phoneme-labels.json`. Expected output size ~303 MB (weights ~317 MB
INT8-packed plus ~1 MB metadata; the base wav2vec2-xlsr-53 model has
~317 M parameters, which sets the INT8 floor). Runtime ~10 minutes on
an M2 MacBook Pro.

## Pinned model revision

`facebook/wav2vec2-xlsr-53-espeak-cv-ft` revision
`2c733782da5604684829819a5eb744c193fe9398` (the repo's sole commit, from
2021-12-10; SHA set in `convert.py`). Changing the revision requires
bumping the pin and re-running the conversion; any behavior change is a
product decision, not a tooling one.
