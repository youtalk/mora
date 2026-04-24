# tools/yokai-forge/scripts/synthesize_voices.py
"""Generate the 8 voice clips for one yokai.

Fish Speech S2 Pro handles the main clips (clean pronunciation).
Bark handles non-verbal tag mixing for greet / friday_acknowledge.

Inputs: refs/<yokai_id>_reference.wav — user-curated reference clip.
Outputs: outputs/voice/<yokai_id>/<clip_key>.wav (pre-mastering).

Usage:
    python scripts/synthesize_voices.py --yokai sh
"""
from __future__ import annotations
import sys
import pathlib as _pathlib
sys.path.insert(0, str(_pathlib.Path(__file__).resolve().parent))
import argparse
import pathlib
import subprocess

from compose_prompt import load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    args = ap.parse_args()
    spec = load_spec(ROOT / "prompts" / f"yokai_{args.yokai}.json")
    ref = ROOT / "refs" / f"{args.yokai}_reference.wav"
    if not ref.exists():
        raise SystemExit(f"reference missing: {ref}")
    out = ROOT / "outputs" / "voice" / args.yokai
    out.mkdir(parents=True, exist_ok=True)

    # Fish Speech (via fish-speech CLI — installed separately; see README).
    # We shell out so this script stays ABI-stable across Fish Speech releases.
    for key, text in spec["voice"]["clips"].items():
        wav = out / f"{key}.wav"
        cmd = [
            "fish-speech", "generate",
            "--ref-audio", str(ref),
            "--text", text,
            "--output", str(wav),
        ]
        subprocess.run(cmd, check=True)
        print(f"generated {wav}")

    # TODO-FOR-R4-USER: optional Bark head-tail mix for greet / friday_acknowledge.
    # The Bark command is tool-specific; see tools/yokai-forge/README.md.


if __name__ == "__main__":
    main()
