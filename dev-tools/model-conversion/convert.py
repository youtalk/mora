"""Convert facebook/wav2vec2-xlsr-53-espeak-cv-ft to CoreML.

Outputs:
    <output-dir>/wav2vec2-phoneme.mlmodelc/   (compiled CoreML model)
    <output-dir>/phoneme-labels.json          (ordered espeak IPA labels)

Runs locally, never in CI. The upstream model is public, so no
Hugging Face token is required.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile

import numpy as np
import torch
from huggingface_hub import hf_hub_download
from transformers import Wav2Vec2ForCTC

import coremltools as ct
from coremltools.optimize.coreml import (
    OptimizationConfig,
    OpLinearQuantizerConfig,
    linear_quantize_weights,
)

MODEL_ID = "facebook/wav2vec2-xlsr-53-espeak-cv-ft"
# Main-branch SHA as of 2021-12-10; the repo has had no further commits.
# See dev-tools/model-conversion/README.md for the rationale behind pinning.
MODEL_REVISION = "2c733782da5604684829819a5eb744c193fe9398"
EXPECTED_SAMPLE_RATE = 16_000
EXPORT_DURATION_SECONDS = 2.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        required=True,
        help="Destination for wav2vec2-phoneme.mlmodelc and phoneme-labels.json",
    )
    return parser.parse_args()


def load_model() -> Wav2Vec2ForCTC:
    model = Wav2Vec2ForCTC.from_pretrained(MODEL_ID, revision=MODEL_REVISION)
    # Switch to inference mode; see README for why we use .train(False)
    # instead of the more idiomatic alternative.
    model.train(False)
    return model


def trace(model: Wav2Vec2ForCTC) -> torch.jit.ScriptModule:
    sample_len = int(EXPORT_DURATION_SECONDS * EXPECTED_SAMPLE_RATE)
    dummy = torch.zeros(1, sample_len, dtype=torch.float32)

    class Wrapper(torch.nn.Module):
        def __init__(self, m: Wav2Vec2ForCTC) -> None:
            super().__init__()
            self.m = m

        def forward(self, x: torch.Tensor) -> torch.Tensor:
            logits = self.m(x).logits
            return torch.nn.functional.log_softmax(logits, dim=-1).squeeze(0)

    wrapped = Wrapper(model)
    traced = torch.jit.trace(wrapped, dummy)
    return traced


def export_mlprogram(
    traced: torch.jit.ScriptModule, staging_dir: pathlib.Path
) -> pathlib.Path:
    """Export + INT8-quantize the traced model into ``staging_dir``.

    The ``.mlpackage`` is the CoreML intermediate; we compile it into
    ``.mlmodelc`` in :func:`compile_mlmodelc` and discard the intermediate.
    Writing it to a caller-owned staging directory (typically a tempdir
    from :mod:`tempfile`) keeps it from leaking into the bundled
    ``Resources/`` tree.
    """
    sample_len = int(EXPORT_DURATION_SECONDS * EXPECTED_SAMPLE_RATE)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[
            ct.TensorType(
                name="audio",
                shape=(1, ct.RangeDim(lower_bound=sample_len // 4, upper_bound=sample_len * 4)),
                dtype=np.float32,
            )
        ],
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )
    config = OptimizationConfig(
        global_config=OpLinearQuantizerConfig(mode="linear_symmetric", weight_threshold=512)
    )
    mlmodel = linear_quantize_weights(mlmodel, config=config)
    out_package = staging_dir / "wav2vec2-phoneme.mlpackage"
    if out_package.exists():
        subprocess.run(["rm", "-rf", str(out_package)], check=True)
    mlmodel.save(str(out_package))
    return out_package


def compile_mlmodelc(mlpackage: pathlib.Path, output_dir: pathlib.Path) -> pathlib.Path:
    target = output_dir / "wav2vec2-phoneme.mlmodelc"
    if target.exists():
        subprocess.run(["rm", "-rf", str(target)], check=True)
    subprocess.run(
        ["xcrun", "coremlcompiler", "compile", str(mlpackage), str(output_dir)],
        check=True,
    )
    return target


def dump_phoneme_labels(output_dir: pathlib.Path) -> pathlib.Path:
    # Fetch the tokenizer's vocab.json directly instead of instantiating
    # Wav2Vec2PhonemeCTCTokenizer, which eagerly initializes a phonemizer
    # backend (espeak-ng) that we never actually use — we only need the
    # ordered label list.
    vocab_path = hf_hub_download(
        repo_id=MODEL_ID, filename="vocab.json", revision=MODEL_REVISION
    )
    with open(vocab_path, encoding="utf-8") as fh:
        vocab: dict[str, int] = json.load(fh)
    ordered = [label for label, _ in sorted(vocab.items(), key=lambda kv: kv[1])]
    path = output_dir / "phoneme-labels.json"
    path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2))
    return path


def main() -> int:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading {MODEL_ID}@{MODEL_REVISION}...")
    model = load_model()
    print("Tracing model...")
    traced = trace(model)
    # Write the `.mlpackage` intermediate to a scratch directory so it
    # cannot leak into `Resources/` (or into the output-dir at all) and
    # accidentally get committed. The compiled `.mlmodelc` is the only
    # artifact we want to keep. `tempfile.mkdtemp()` is cleaned up
    # unconditionally via the `subprocess.run(["rm", "-rf", ...])` in
    # the `finally` block below.
    staging_dir = pathlib.Path(tempfile.mkdtemp(prefix="mora-mlpackage-"))
    try:
        print(f"Exporting to mlprogram + INT8 quantizing (staging in {staging_dir})...")
        pkg = export_mlprogram(traced, staging_dir)
        print(f"Compiling .mlmodelc from {pkg.name}...")
        compiled = compile_mlmodelc(pkg, args.output_dir)
        print("Writing phoneme-labels.json...")
        labels_path = dump_phoneme_labels(args.output_dir)
    finally:
        print(f"Cleaning up staging dir {staging_dir}...")
        subprocess.run(["rm", "-rf", str(staging_dir)], check=True)
    print("Done:")
    print(f"  {compiled}")
    print(f"  {labels_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
