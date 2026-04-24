# tools/yokai-forge/scripts/compose_prompt.py
"""Compose a Flux prompt from a yokai JSON spec + the Layer-1 style lock."""
from __future__ import annotations
import json
import pathlib
import argparse

ROOT = pathlib.Path(__file__).resolve().parents[1]
STYLE = (ROOT / "prompts" / "style_layer.txt").read_text().strip()
NEG = (ROOT / "prompts" / "negative.txt").read_text().strip()


def compose_positive(spec: dict) -> str:
    decor = spec["word_decor"]
    palette = ", ".join(spec["palette"])
    return (
        f"{STYLE}, "
        f"a {spec['personality']}, "
        f"{spec['sound_gesture']}, "
        f"wearing {decor[0]}, with {decor[1]}, and {decor[2]}, "
        f"{palette} color scheme, {spec['expression']}"
    )


def compose_negative() -> str:
    return NEG


def load_spec(path: pathlib.Path) -> dict:
    return json.loads(path.read_text())


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True, help="id, e.g. sh / th / f / r / short_a")
    args = ap.parse_args()
    spec_path = ROOT / "prompts" / f"yokai_{args.yokai}.json"
    spec = load_spec(spec_path)
    print("POSITIVE:")
    print(compose_positive(spec))
    print("\nNEGATIVE:")
    print(compose_negative())
