# tools/yokai-forge/scripts/render_with_canny.py
"""Render yokai portrait candidates with FLUX ControlNet-Canny mouth conditioning.

Pure text prompting cannot force FLUX to draw phoneme-accurate mouth shapes
(/θ/ tongue-between-teeth, /ʃ/ pucker, /f/ teeth-on-lip). This script feeds
a per-phoneme line-art sketch (produced by `make_mouth_sketches.py`) as a
Canny condition so FLUX is forced to respect the mouth geometry while the
rest of the canvas — body, decor, palette — stays free for the text prompt
to drive.

Uses InstantX/FLUX.1-dev-Controlnet-Canny on top of FLUX.1-dev with CPU
offload (the combined weights overflow 32 GiB VRAM without it).

Usage:
    python scripts/render_with_canny.py --yokai sh --count 4
    python scripts/render_with_canny.py --yokai sh --count 4 --cn-scale 0.55
"""
from __future__ import annotations
import sys
import pathlib as _pathlib
sys.path.insert(0, str(_pathlib.Path(__file__).resolve().parent))
import argparse
import pathlib
import random

import torch
from diffusers import FluxControlNetModel, FluxControlNetPipeline
from diffusers.utils import load_image

from compose_prompt import compose_negative, compose_positive, load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]

CONTROLNET_REPO = "InstantX/FLUX.1-dev-Controlnet-Canny"
BASE_REPO = "black-forest-labs/FLUX.1-dev"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True, help="yokai id (sh, th, f, r, short_a)")
    ap.add_argument("--count", type=int, default=4)
    ap.add_argument(
        "--cn-scale",
        type=float,
        default=0.6,
        help="controlnet_conditioning_scale — higher (>0.7) locks mouth tightly "
        "but can freeze body composition; lower (<0.4) loosens mouth adherence.",
    )
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--guidance", type=float, default=3.5)
    args = ap.parse_args()

    spec = load_spec(ROOT / "prompts" / f"yokai_{args.yokai}.json")
    canny_path = ROOT / "refs" / "mouth_canny" / f"{args.yokai}.png"
    if not canny_path.exists():
        raise SystemExit(
            f"canny sketch missing: {canny_path} — run scripts/make_mouth_sketches.py"
        )
    out = ROOT / "outputs" / "canny_portraits" / args.yokai
    out.mkdir(parents=True, exist_ok=True)

    controlnet = FluxControlNetModel.from_pretrained(
        CONTROLNET_REPO, torch_dtype=torch.bfloat16
    )
    pipe = FluxControlNetPipeline.from_pretrained(
        BASE_REPO,
        controlnet=controlnet,
        torch_dtype=torch.bfloat16,
    )
    pipe.enable_model_cpu_offload()

    prompt = compose_positive(spec)
    negative = compose_negative()
    control_image = load_image(str(canny_path))

    for i in range(args.count):
        seed = random.randint(0, 2**31 - 1)
        generator = torch.Generator(device="cuda").manual_seed(seed)
        image = pipe(
            prompt=prompt,
            negative_prompt=negative,
            control_image=control_image,
            controlnet_conditioning_scale=args.cn_scale,
            num_inference_steps=args.steps,
            guidance_scale=args.guidance,
            generator=generator,
            height=1024,
            width=1024,
        ).images[0]
        path = out / f"{args.yokai}_cn{args.cn_scale:.2f}_{i:02d}_{seed}.png"
        image.save(path)
        print(f"saved {path.name}")


if __name__ == "__main__":
    main()
