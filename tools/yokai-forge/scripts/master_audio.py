# tools/yokai-forge/scripts/master_audio.py
"""Master raw WAVs to -16 LUFS AAC m4a, 22050 Hz mono.

Usage:
    python scripts/master_audio.py --yokai sh
"""
from __future__ import annotations
import argparse
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def master(src: pathlib.Path, dst: pathlib.Path) -> None:
    # Trim leading + trailing silence on the raw signal, then loudnorm
    # to -16 LUFS, resample to 22050 Hz mono, encode AAC.
    #
    # Filter order matters. An earlier version ran loudnorm first and
    # then silenceremove with a -40 dB threshold, which dropped quiet
    # fricatives (notably the /ʃ/ in "ship") whose peaks sit near
    # -40 dB after loudnorm's gain — the fricative was classified as
    # silence and the word was cut to ~150 ms. Trimming before
    # loudnorm keeps the threshold on the known raw level, and the
    # -50 dB threshold leaves headroom for low-energy phonemes.
    #
    # The silenceremove chain uses the canonical "trim head, reverse,
    # trim head again, reverse back" idiom so only the true leading
    # and trailing silence is removed — inter-word pauses are kept.
    trim = (
        "silenceremove=start_periods=1:start_duration=0.1:start_threshold=-50dB"
    )
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-af", f"{trim},areverse,{trim},areverse,loudnorm=I=-16:TP=-1.5:LRA=11",
        "-ar", "22050", "-ac", "1",
        "-c:a", "aac", "-b:a", "96k",
        str(dst),
    ]
    subprocess.run(cmd, check=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    args = ap.parse_args()
    src_dir = ROOT / "outputs" / "voice" / args.yokai
    if not src_dir.is_dir():
        raise SystemExit(f"source dir missing: {src_dir}")
    wavs = sorted(src_dir.glob("*.wav"))
    if not wavs:
        raise SystemExit(f"no *.wav found in {src_dir}")
    dst_dir = src_dir / "mastered"
    dst_dir.mkdir(parents=True, exist_ok=True)
    for wav in wavs:
        dst = dst_dir / (wav.stem + ".m4a")
        master(wav, dst)
        print(f"mastered {dst}")


if __name__ == "__main__":
    main()
