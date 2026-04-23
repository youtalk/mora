"""Convert facebook/wav2vec2-xlsr-53-espeak-cv-ft to CoreML.

Outputs:
    <output-dir>/wav2vec2-phoneme.mlmodelc/   (compiled CoreML model)
    <output-dir>/phoneme-labels.json          (ordered espeak IPA labels)

Runs locally, never in CI. Reads HF_TOKEN from .env (python-dotenv).
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys

import numpy as np
import torch
from dotenv import load_dotenv
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

import coremltools as ct
from coremltools.optimize.coreml import (
    OptimizationConfig,
    OpLinearQuantizerConfig,
    linear_quantize_weights,
)

MODEL_ID = "facebook/wav2vec2-xlsr-53-espeak-cv-ft"
MODEL_REVISION = "3693e11"  # pin; see dev-tools/model-conversion/README.md
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


def load_model(token: str) -> tuple[Wav2Vec2ForCTC, Wav2Vec2Processor]:
    processor = Wav2Vec2Processor.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, token=token
    )
    model = Wav2Vec2ForCTC.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, token=token
    )
    # Switch to inference mode; see README for why we use .train(False)
    # instead of the more idiomatic alternative.
    model.train(False)
    return model, processor


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
    traced: torch.jit.ScriptModule, output_dir: pathlib.Path
) -> pathlib.Path:
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
    out_package = output_dir / "wav2vec2-phoneme.mlpackage"
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


def dump_phoneme_labels(
    processor: Wav2Vec2Processor, output_dir: pathlib.Path
) -> pathlib.Path:
    vocab = processor.tokenizer.get_vocab()
    ordered = [label for label, _ in sorted(vocab.items(), key=lambda kv: kv[1])]
    path = output_dir / "phoneme-labels.json"
    path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2))
    return path


def main() -> int:
    args = parse_args()
    load_dotenv()
    token = os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN is not set. Copy .env.example to .env and fill it in.", file=sys.stderr)
        return 1
    args.output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading {MODEL_ID}@{MODEL_REVISION}...")
    model, processor = load_model(token)
    print("Tracing model...")
    traced = trace(model)
    print("Exporting to mlprogram + INT8 quantizing...")
    pkg = export_mlprogram(traced, args.output_dir)
    print(f"Compiling .mlmodelc from {pkg.name}...")
    compiled = compile_mlmodelc(pkg, args.output_dir)
    print("Writing phoneme-labels.json...")
    labels_path = dump_phoneme_labels(processor, args.output_dir)
    print("Done:")
    print(f"  {compiled}")
    print(f"  {labels_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
