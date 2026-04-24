# tools/yokai-forge/scripts/prepare_lora_dataset.py
"""Take a user-curated directory of ~50 style-bootstrap images and
emit a captioned dataset directory compatible with Ostris AI Toolkit.

Caption strategy: fixed style-token caption plus lightweight tag.
"""
from __future__ import annotations
import argparse
import pathlib
import shutil

STYLE_TAG = "moraforge-kawaii-yokai-style"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--curated", required=True, help="directory of hand-picked bootstrap images")
    ap.add_argument("--out", required=True, help="output dataset directory")
    args = ap.parse_args()
    src = pathlib.Path(args.curated)
    dst = pathlib.Path(args.out)
    dst.mkdir(parents=True, exist_ok=True)
    for i, img in enumerate(sorted(src.glob("*.png"))):
        stem = f"{STYLE_TAG}_{i:03d}"
        shutil.copy(img, dst / f"{stem}.png")
        (dst / f"{stem}.txt").write_text(
            f"{STYLE_TAG}, chibi kawaii yokai character, thick black outlines, flat pastel colors, 3/4 portrait, plain white background"
        )
    print(f"wrote {i+1} image+caption pairs to {dst}")


if __name__ == "__main__":
    main()
