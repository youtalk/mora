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
    # Loudnorm to -16 LUFS, resample to 22050 Hz mono, encode AAC —
    # no silence trimming on either end. fish-speech output is used
    # verbatim in the time domain.
    #
    # An earlier revision ran `silenceremove ... start_duration=0.1
    # ... start_threshold=-50dB` at the head to drop leading silence.
    # The `start_duration` parameter in silenceremove means the
    # amount of non-silence that must be sustained before the filter
    # STOPS trimming — not the minimum silence window to trim. For
    # fricatives like /ʃ/, /f/, /θ/ whose onset ramps up gradually
    # through -50 dB, the filter kept trimming through the onset
    # because it never saw 100 ms of continuous non-silence at the
    # start. sh/example_3 "shell" lost ~100 ms of the /ʃ/ ramp and
    # became hard to recognize. Dropping the trim preserves the
    # natural fricative onset at the cost of whatever leading
    # silence fish-speech produced, which in practice is ≤ 50 ms of
    # low-level noise across all 40 clips and inaudible in playback.
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11",
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
