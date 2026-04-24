# tools/yokai-forge/scripts/bootstrap_style.py
"""Generate ~100 style-bootstrap images before Style LoRA training.

Uses diffusers directly (no ComfyUI dependency) so the script runs
as a plain Python workload on the RTX 5090. Reads prompt variations
from the 5 per-yokai JSON specs to force variety in the bootstrap pool.

Usage:
    python scripts/bootstrap_style.py --count 100
"""
from __future__ import annotations
import argparse
import pathlib
import itertools
import random

import torch
from diffusers import FluxPipeline

from compose_prompt import compose_positive, compose_negative, load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs" / "style_bootstrap"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=100)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--guidance", type=float, default=3.5)
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-dev",
        torch_dtype=torch.bfloat16,
    ).to("cuda")

    specs = sorted((ROOT / "prompts").glob("yokai_*.json"))
    variants = list(itertools.cycle([load_spec(p) for p in specs]))

    for i in range(args.count):
        spec = variants[i]
        prompt = compose_positive(spec)
        neg = compose_negative()
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
        image.save(OUT / f"bootstrap_{i:03d}_{spec['id']}_{seed}.png")
        print(f"saved bootstrap_{i:03d}_{spec['id']}_{seed}.png")


if __name__ == "__main__":
    main()
