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
    # Trim leading silence only, then loudnorm to -16 LUFS, resample
    # to 22050 Hz mono, encode AAC. The trailing region is kept
    # verbatim so the natural decay of the last phoneme and whatever
    # tail silence fish-speech produced both survive.
    #
    # An earlier revision trimmed trailing silence too via the
    # `silenceremove, areverse, silenceremove, areverse` idiom at a
    # -50 dB threshold. That cut into the decay of low-energy
    # phonemes (fricatives /f/ /ʃ/, short vowels fading into
    # creaky-voice) — 39 of 40 clips ended mid-sound with the last
    # 100 ms sitting at -15 to -35 dB instead of a silent tail. For
    # short voice cues in the app we'd rather keep ~100-300 ms of
    # fish-speech's natural tail than clip the final consonant.
    #
    # Leading silence trim stays: playback still wants to start
    # immediately on the first phoneme, not after a padded gap.
    trim_leading = (
        "silenceremove=start_periods=1:start_duration=0.1:start_threshold=-50dB"
    )
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-af", f"{trim_leading},loudnorm=I=-16:TP=-1.5:LRA=11",
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
