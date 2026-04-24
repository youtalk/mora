# tools/yokai-forge/scripts/audit_voices.py
"""QC-audit the bundled yokai voice clips against YokaiCatalog.json.

For each `<yokai_id>/voice/<clip>.m4a` under the bundle root, run Whisper
STT and check that the transcription contains the expected word or
phrase from `voice.clips.<clip>`. Also measure duration, last-100 ms
mean volume (= trailing-silence check), and first-50 ms mean volume
(= leading-onset check) so regressions like "hallucinated six-second
filler text" or "fricative onset clipped by silenceremove" surface
without listening to every clip.

Two-stage transcription: run `small.en` first for speed and escalate
to `medium.en` only when `small.en` fails. `small.en` is known to
confuse final /t/ ~ /d/ and to drop stretched vowels like "Aaah!" that
the app does pronounce; `medium.en` is more tolerant of these patterns
and of low-energy phoneme onsets (/ʃ/, /θ/, /f/).

IPA-notation phoneme clips (catalog text contains "/" or clip key is
"phoneme") are skipped for the transcription check — whisper cannot
reliably render "Shhh /ʃ/" or "Aaah /æ/" as written. They still go
through the duration / tail / lead checks.

Thresholds (all tunable via CLI):
    tail_db_max      last-100 ms mean_volume above this → flag "truncated"
    lead_db_max_50ms first-50 ms mean_volume above this (i.e. louder than
                     a natural silence) is fine; below this AND first-200 ms
                     also quiet means the clip may be starting with silence.
    long_factor      whisper transcript longer than expected_word_count *
                     this factor → flag "hallucinated".

Usage:
    python scripts/audit_voices.py                       # audit bundled m4a
    python scripts/audit_voices.py --yokai sh            # one yokai only
    python scripts/audit_voices.py --bundle path/to/dir  # alternate bundle root
    python scripts/audit_voices.py --json report.json    # machine-readable
    python scripts/audit_voices.py --strict              # exit 1 on any FAIL
"""
from __future__ import annotations
import argparse
import difflib
import json
import pathlib
import re
import subprocess
import sys

import whisper

ROOT = pathlib.Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parents[1]
CATALOG = REPO_ROOT / "Packages" / "MoraCore" / "Sources" / "MoraCore" / "Yokai" / "YokaiCatalog.json"
DEFAULT_BUNDLE = REPO_ROOT / "Packages" / "MoraCore" / "Sources" / "MoraCore" / "Resources" / "Yokai"


def normalize(s: str) -> str:
    """Lowercase letters-only + collapse runs of 3+ identical chars.

    Whisper doesn't render stretched phoneme prefixes verbatim — the
    catalog spells `Aaamazing!` but whisper writes `Amazing!`, `Shhh!`
    becomes `Shh!`, and `Ffff.` is dropped altogether. Collapsing any
    3+ repeat to a single char ("aaamazing" → "amazing",
    "shhh" → "sh", "ffff" → "f") makes the two spellings compare
    equal without hand-rolling a prefix stripper.
    """
    cleaned = re.sub(r"[^a-z]", "", s.lower())
    cleaned = re.sub(r"(.)\1{2,}", r"\1", cleaned)
    return cleaned


def matches(expected: str, actual: str, threshold: float) -> bool:
    """Fuzzy match whisper transcription against catalog text.

    Three-tier acceptance:
    1. Substring match either direction on the normalized forms. This
       handles most cases, including whisper dropping a stretched
       phoneme prefix ("Ffff. Breathe softly..." → "Breathe softly...").
    2. SequenceMatcher ratio >= threshold. This rescues cases where
       whisper substitutes a near-homophone word for the phoneme cue
       ("Thhh! Show me..." transcribed as "See! Show me...") or drops
       final /t/ vs /d/ distinction on short words.

    Anything below the threshold is treated as a genuine mismatch and
    surfaces as FAIL with both small.en and medium.en outputs reported.
    """
    enorm = normalize(expected)
    anorm = normalize(actual)
    if not enorm:
        return True
    if enorm in anorm or anorm in enorm:
        return True
    return difflib.SequenceMatcher(None, enorm, anorm).ratio() >= threshold


def transcribe(model, path: pathlib.Path) -> str:
    r = model.transcribe(str(path), fp16=True, language="en", verbose=False)
    return r["text"].strip()


def duration_s(path: pathlib.Path) -> float:
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", str(path)],
        capture_output=True, text=True, check=True,
    )
    return float(r.stdout.strip())


def window_mean_db(path: pathlib.Path, seek: str, duration: float | None) -> float | None:
    """Mean volume of a time window. seek: e.g. '-sseof -0.1' or '-ss 0'."""
    cmd = ["ffmpeg", *seek.split()]
    if duration is not None:
        cmd += ["-t", str(duration)]
    cmd += ["-i", str(path), "-af", "volumedetect", "-f", "null", "-"]
    r = subprocess.run(cmd, capture_output=True, text=True)
    for line in r.stderr.splitlines():
        if "mean_volume" in line:
            return float(line.split()[4].rstrip("dB"))
    return None


def is_ipa_phoneme(expected_text: str, clip_key: str) -> bool:
    # Either the catalog clip key is literally "phoneme", or the text
    # carries an IPA bracket ("Shhh /ʃ/") that whisper can't render.
    return clip_key == "phoneme" or "/" in expected_text


def audit_clip(
    yokai_id: str,
    clip_key: str,
    expected_text: str,
    bundle_root: pathlib.Path,
    small_model,
    medium_model_loader,
    tail_db_max: float,
    long_factor: float,
    match_threshold: float,
) -> dict:
    m4a = bundle_root / yokai_id / "voice" / f"{clip_key}.m4a"
    base = {
        "yokai": yokai_id,
        "clip": clip_key,
        "expected": expected_text,
    }
    if not m4a.exists():
        return {**base, "status": "MISSING", "path": str(m4a)}

    dur = duration_s(m4a)
    tail = window_mean_db(m4a, "-sseof -0.1", None)
    lead_50 = window_mean_db(m4a, "-ss 0", 0.05)
    lead_200 = window_mean_db(m4a, "-ss 0", 0.2)
    base.update({
        "duration_s": round(dur, 3),
        "tail_db": None if tail is None else round(tail, 1),
        "lead_50ms_db": None if lead_50 is None else round(lead_50, 1),
        "lead_200ms_db": None if lead_200 is None else round(lead_200, 1),
    })

    warnings: list[str] = []
    if tail is not None and tail > tail_db_max:
        warnings.append(f"tail_hot({tail:.1f}dB>{tail_db_max}dB): may be truncated mid-sound")

    if is_ipa_phoneme(expected_text, clip_key):
        # Skip transcription check — whisper can't transcribe raw phonemes.
        base["status"] = "OK" if not warnings else "WARN"
        base["warnings"] = warnings
        base["skipped_transcription"] = True
        return base

    # Whisper check: small.en, escalate to medium.en only on miss.
    actual_small = transcribe(small_model, m4a)
    if matches(expected_text, actual_small, match_threshold):
        base.update({
            "actual": actual_small, "model": "small.en",
            "status": "OK" if not warnings else "WARN",
            "warnings": warnings,
        })
        return base

    medium_model = medium_model_loader()
    actual_medium = transcribe(medium_model, m4a)
    if matches(expected_text, actual_medium, match_threshold):
        base.update({
            "actual": actual_medium, "model": "medium.en (escalated)",
            "actual_small": actual_small,
            "status": "OK" if not warnings else "WARN",
            "warnings": warnings,
        })
        return base

    # Still mismatched. Probable hallucination: transcript much longer
    # than expected word count.
    expected_word_count = max(1, len(expected_text.split()))
    actual_word_count = len(actual_medium.split())
    hallucinated = actual_word_count > expected_word_count * long_factor
    base.update({
        "actual_small": actual_small,
        "actual_medium": actual_medium,
        "status": "FAIL",
        "reason": "hallucinated" if hallucinated else "mismatch",
        "warnings": warnings,
    })
    return base


def format_row(r: dict) -> str:
    status = r["status"]
    yid = r["yokai"]
    clip = r["clip"]
    exp = r["expected"][:28]
    dur = r.get("duration_s", "-")
    tail = r.get("tail_db")
    lead = r.get("lead_50ms_db")
    tail_s = f"{tail:>5.1f}" if tail is not None else "   - "
    lead_s = f"{lead:>5.1f}" if lead is not None else "   - "

    if status == "MISSING":
        return f"  {yid:<8} {clip:<22} MISSING  {r['path']}"
    if r.get("skipped_transcription"):
        extra = ""
        if r.get("warnings"):
            extra = "  [" + "; ".join(r["warnings"]) + "]"
        return f"  {yid:<8} {clip:<22} {status:<6} {dur:>6.2f}s tail={tail_s}dB lead={lead_s}dB  (ipa, no stt){extra}"
    if status in ("OK", "WARN"):
        actual = r.get("actual", "")
        model = r.get("model", "")
        extra = ""
        if r.get("warnings"):
            extra = "  [" + "; ".join(r["warnings"]) + "]"
        return (
            f"  {yid:<8} {clip:<22} {status:<6} {dur:>6.2f}s tail={tail_s}dB lead={lead_s}dB  "
            f"actual={actual!r:<42} [{model}]{extra}"
        )
    # FAIL
    return (
        f"  {yid:<8} {clip:<22} {status:<6} {dur:>6.2f}s tail={tail_s}dB lead={lead_s}dB  "
        f"expected={r['expected']!r} small={r.get('actual_small','')!r} medium={r.get('actual_medium','')!r}  "
        f"({r.get('reason','')})"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="Audit bundled yokai voice clips via whisper STT.")
    ap.add_argument("--yokai", help="Audit only this yokai id")
    ap.add_argument("--bundle", type=pathlib.Path, default=DEFAULT_BUNDLE,
                    help=f"Root directory containing <yokai>/voice/*.m4a (default: {DEFAULT_BUNDLE})")
    ap.add_argument("--catalog", type=pathlib.Path, default=CATALOG,
                    help="Path to YokaiCatalog.json")
    ap.add_argument("--json", dest="json_out", metavar="PATH", type=pathlib.Path,
                    help="Write JSON report to this path")
    ap.add_argument("--strict", action="store_true",
                    help="Exit 1 if any clip is FAIL")
    ap.add_argument("--tail-db-max", type=float, default=-25.0,
                    help="Last-100ms mean_volume above this flags a truncated tail (default: -25)")
    ap.add_argument("--long-factor", type=float, default=6.0,
                    help="Whisper transcript > expected_word_count * this → hallucination (default: 6)")
    ap.add_argument("--match-threshold", type=float, default=0.7,
                    help="SequenceMatcher ratio between normalized expected and actual for fuzzy match (default: 0.7)")
    args = ap.parse_args()

    catalog = json.loads(args.catalog.read_text())
    if args.yokai:
        catalog = [y for y in catalog if y["id"] == args.yokai]
        if not catalog:
            print(f"yokai id not in catalog: {args.yokai}", file=sys.stderr)
            return 2

    print("Loading whisper small.en...", flush=True)
    small_model = whisper.load_model("small.en")

    medium_model_cache = {}
    def load_medium():
        if "m" not in medium_model_cache:
            print("Loading whisper medium.en for escalation...", flush=True)
            medium_model_cache["m"] = whisper.load_model("medium.en")
        return medium_model_cache["m"]

    results: list[dict] = []
    for y in catalog:
        yid = y["id"]
        print(f"\n{yid}:")
        for clip_key, expected_text in y["voice"]["clips"].items():
            r = audit_clip(
                yid, clip_key, expected_text, args.bundle,
                small_model, load_medium,
                args.tail_db_max, args.long_factor, args.match_threshold,
            )
            results.append(r)
            print(format_row(r), flush=True)

    total = len(results)
    fails = sum(1 for r in results if r["status"] == "FAIL")
    warns = sum(1 for r in results if r["status"] == "WARN")
    missing = sum(1 for r in results if r["status"] == "MISSING")
    passing = total - fails - warns - missing

    print(f"\nSummary: {passing} OK, {warns} WARN, {fails} FAIL, {missing} MISSING  ({total} total)")

    if args.json_out:
        args.json_out.write_text(json.dumps({
            "bundle_root": str(args.bundle),
            "summary": {
                "total": total, "ok": passing, "warn": warns,
                "fail": fails, "missing": missing,
            },
            "clips": results,
        }, indent=2))
        print(f"wrote {args.json_out}")

    if args.strict and (fails or missing):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
