# tools/yokai-forge/scripts/render_portraits.py
"""Render portrait candidates per yokai using FLUX.1-dev.

Pass --lora to mix in a trained Style LoRA (the long-lived R3 path), or omit
--lora to run pure prompt-only rendering against the base model (the fallback
path we ended up shipping with once ControlNet-Canny was rejected for
uncanny-valley results).

Usage:
    # Style-LoRA path
    python scripts/render_portraits.py --yokai sh --count 24 \
        --lora outputs/lora/moraforge_style_lora.safetensors
    # Prompt-only path (no LoRA trained yet, or LoRA not desired)
    python scripts/render_portraits.py --yokai sh --count 6
    # All five yokai in a single model load
    python scripts/render_portraits.py --all --count 6
"""
from __future__ import annotations
import sys
import pathlib as _pathlib
sys.path.insert(0, str(_pathlib.Path(__file__).resolve().parent))
import argparse
import pathlib
import random

import torch
from diffusers import FluxPipeline

from compose_prompt import compose_positive, compose_negative, load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]
ALL_IDS = ["sh", "th", "f", "r", "short_a"]


def main() -> None:
    ap = argparse.ArgumentParser()
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--yokai", help="yokai id (sh, th, f, r, short_a)")
    group.add_argument("--all", action="store_true", help="iterate over all five yokai in one model load")
    ap.add_argument("--count", type=int, default=24, help="candidates per yokai")
    ap.add_argument("--lora", help="path to trained Style LoRA .safetensors (omit for base-model-only rendering)")
    ap.add_argument("--lora_strength", type=float, default=0.8)
    ap.add_argument("--steps", type=int, default=32)
    ap.add_argument("--guidance", type=float, default=3.5)
    args = ap.parse_args()

    ids = ALL_IDS if args.all else [args.yokai]

    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-dev", torch_dtype=torch.bfloat16
    )
    style_tag = ""
    if args.lora:
        pipe.load_lora_weights(args.lora, adapter_name="style")
        pipe.set_adapters(["style"], adapter_weights=[args.lora_strength])
        style_tag = ", moraforge-kawaii-yokai-style"
    pipe.enable_model_cpu_offload()

    neg = compose_negative()
    for yokai_id in ids:
        spec = load_spec(ROOT / "prompts" / f"yokai_{yokai_id}.json")
        out = ROOT / "outputs" / "portraits" / yokai_id
        out.mkdir(parents=True, exist_ok=True)
        prompt = compose_positive(spec) + style_tag

        for i in range(args.count):
            seed = random.randint(0, 2**31 - 1)
            generator = torch.Generator(device="cuda").manual_seed(seed)
            image = pipe(
                prompt=prompt,
                negative_prompt=neg,
                num_inference_steps=args.steps,
                guidance_scale=args.guidance,
                generator=generator,
                height=1024, width=1024,
            ).images[0]
            path = out / f"{yokai_id}_candidate_{i:03d}_{seed}.png"
            image.save(path)
            print(f"saved {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
