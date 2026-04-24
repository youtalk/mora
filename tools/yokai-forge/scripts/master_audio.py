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
    # ffmpeg loudnorm + resample + AAC encode.
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11,silenceremove=start_periods=1:start_silence=0.05:start_threshold=-40dB:stop_periods=1:stop_silence=0.05:stop_threshold=-40dB",
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
    dst_dir = ROOT / "outputs" / "voice" / args.yokai / "mastered"
    dst_dir.mkdir(parents=True, exist_ok=True)
    for wav in sorted(src_dir.glob("*.wav")):
        dst = dst_dir / (wav.stem + ".m4a")
        master(wav, dst)
        print(f"mastered {dst}")


if __name__ == "__main__":
    main()
