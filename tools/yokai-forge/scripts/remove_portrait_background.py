#!/usr/bin/env python3
"""Convert bundled yokai portrait PNGs from opaque-white backgrounds to transparent.

The rendered portraits ship as 1024x1024 8-bit RGB PNGs with a pure-white
canvas. A naive "white -> alpha 0" swap would also erase internal white
regions (bellies, cat faces, highlights), so this script flood-fills from
the four corners across near-white pixels only, leaving interior whites
opaque. The alpha edge is feathered by one pixel to avoid aliased halos
when the portrait is composited onto colored backgrounds in MoraUI.

Usage:
    python scripts/remove_portrait_background.py \
        ../../Packages/MoraCore/Sources/MoraCore/Resources/Yokai

By default the script rewrites each `*/portrait.png` in-place as RGBA.
Pass `--output-root <dir>` to write transparent copies to a mirrored tree
(useful for eyeballing the alpha mask before committing the overwrite).
"""
from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

WHITE_THRESHOLD = 240  # pixels where min(R,G,B) >= this are treated as background
SHADOW_MIN = 135  # lower bound of neutral-grey shadow pixels (min RGB channel)
SHADOW_MAX = 248  # overlaps WHITE_THRESHOLD so the soft gradient rim is bridged
SHADOW_SAT_SPREAD = 22  # max(R,G,B) - min(R,G,B); small => near-neutral grey
FEATHER_RADIUS = 1  # pixels; smooth the alpha mask to avoid jaggies


def _flood_fill(eligible: np.ndarray, seed_mask: np.ndarray) -> np.ndarray:
    """4-connected flood fill restricted to `eligible`, seeded from `seed_mask`."""
    h, w = eligible.shape
    visited = seed_mask & eligible
    queue: deque[tuple[int, int]] = deque(
        (int(y), int(x)) for y, x in zip(*np.where(visited))
    )
    while queue:
        y, x = queue.popleft()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and eligible[ny, nx]:
                visited[ny, nx] = True
                queue.append((ny, nx))
    return visited


def _build_background_mask(rgb: np.ndarray) -> np.ndarray:
    """Return a boolean mask (H, W) where True = background.

    Pass 1 — flood fill from the four corners across near-white pixels. This
    removes the rendered canvas while leaving interior whites (bellies, the
    cat's body) intact.

    Pass 2 — expand the mask through neutral-grey pixels adjacent to the
    already-transparent region. This captures the soft drop-shadow ellipses
    under some characters without touching warm-cream bellies or the white
    cat body (those are either lighter than SHADOW_MAX or only reachable by
    crossing character edges).
    """
    h, w, _ = rgb.shape
    rgb_min = rgb.min(axis=2)
    rgb_max = rgb.max(axis=2)

    near_white = rgb_min >= WHITE_THRESHOLD
    corner_seeds = np.zeros((h, w), dtype=bool)
    corner_seeds[0, 0] = corner_seeds[0, -1] = True
    corner_seeds[-1, 0] = corner_seeds[-1, -1] = True
    background = _flood_fill(near_white, corner_seeds)

    shadow_like = (
        (rgb_min >= SHADOW_MIN)
        & (rgb_min <= SHADOW_MAX)
        & ((rgb_max - rgb_min) <= SHADOW_SAT_SPREAD)
    )
    # Seed the shadow pass with background pixels that already touch a
    # shadow-like neighbor. Using the full background as seed is fine: the
    # flood only advances through `shadow_like`, so unrelated neutral-grey
    # regions inside the character stay untouched unless reachable.
    eligible = shadow_like | background
    background = _flood_fill(eligible, background)
    return background


def _process(portrait_path: Path, output_path: Path) -> None:
    with Image.open(portrait_path) as img:
        rgb = np.asarray(img.convert("RGB"))
    background = _build_background_mask(rgb)
    alpha = np.where(background, 0, 255).astype(np.uint8)
    alpha_img = Image.fromarray(alpha, mode="L")
    if FEATHER_RADIUS > 0:
        alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=FEATHER_RADIUS))
    rgba = Image.fromarray(rgb, mode="RGB").convert("RGBA")
    rgba.putalpha(alpha_img)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    rgba.save(output_path, format="PNG", optimize=True)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "yokai_root",
        type=Path,
        help="Directory containing <slug>/portrait.png subdirectories.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=None,
        help=(
            "Optional output directory. When set, transparent portraits are "
            "written to <output-root>/<slug>/portrait.png instead of "
            "overwriting the input files."
        ),
    )
    args = parser.parse_args(argv)

    portraits = sorted(args.yokai_root.glob("*/portrait.png"))
    if not portraits:
        print(f"no portraits found under {args.yokai_root}", file=sys.stderr)
        return 1

    for src in portraits:
        if args.output_root is None:
            dst = src
        else:
            dst = args.output_root / src.parent.name / src.name
        _process(src, dst)
        print(f"transparent: {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
