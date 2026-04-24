# tools/yokai-forge/scripts/render_portraits.py
"""Render 20–30 portrait candidates per yokai using Flux.1 dev + trained Style LoRA.

Usage:
    python scripts/render_portraits.py --yokai sh --count 24 --lora outputs/lora/moraforge_style_lora.safetensors
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


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    ap.add_argument("--count", type=int, default=24)
    ap.add_argument("--lora", required=True)
    ap.add_argument("--lora_strength", type=float, default=0.8)
    ap.add_argument("--steps", type=int, default=32)
    ap.add_argument("--guidance", type=float, default=3.5)
    args = ap.parse_args()

    spec = load_spec(ROOT / "prompts" / f"yokai_{args.yokai}.json")
    out = ROOT / "outputs" / "portraits" / args.yokai
    out.mkdir(parents=True, exist_ok=True)

    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-dev", torch_dtype=torch.bfloat16
    ).to("cuda")
    pipe.load_lora_weights(args.lora, adapter_name="style")
    pipe.set_adapters(["style"], adapter_weights=[args.lora_strength])

    prompt = compose_positive(spec) + ", moraforge-kawaii-yokai-style"
    neg = compose_negative()

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
        image.save(out / f"{args.yokai}_candidate_{i:03d}_{seed}.png")
        print(f"saved {args.yokai}_candidate_{i:03d}_{seed}.png")


if __name__ == "__main__":
    main()
