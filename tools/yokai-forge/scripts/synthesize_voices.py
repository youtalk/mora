# tools/yokai-forge/scripts/synthesize_voices.py
"""Generate the 8 voice clips for one yokai using Fish Speech S2 Pro.

Starts the Fish Speech HTTP server as a subprocess, waits for
/v1/health, then POSTs each clip's text to /v1/tts with the yokai's
reference audio + transcription attached. Saves one WAV per clip
under outputs/voice/<yokai_id>/. The server is torn down before
the script exits so running this per-yokai doesn't leak processes.

Inputs:
    refs/<yokai_id>_reference.wav — user-curated reference clip, ~5-30s clean speech.
    refs/<yokai_id>_reference.txt — verbatim transcription of the reference clip.

Outputs:
    outputs/voice/<yokai_id>/<clip_key>.wav (pre-mastering).

Env:
    FISH_SPEECH_ROOT — path to the fish-speech checkout (default: ~/fish-speech).

Usage:
    python scripts/synthesize_voices.py --yokai sh
"""
from __future__ import annotations
import sys
import pathlib as _pathlib
sys.path.insert(0, str(_pathlib.Path(__file__).resolve().parent))
import argparse
import base64
import json
import os
import pathlib
import signal
import subprocess
import time
import urllib.error
import urllib.request

from compose_prompt import load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]
FISH_SPEECH = pathlib.Path(
    os.environ.get("FISH_SPEECH_ROOT", pathlib.Path.home() / "fish-speech")
)
HEALTH_URL = "http://127.0.0.1:8080/v1/health"
TTS_URL = "http://127.0.0.1:8080/v1/tts"
SERVER_STARTUP_TIMEOUT_SEC = 300.0


def wait_for_server(deadline_sec: float) -> None:
    start = time.monotonic()
    last_err: Exception | None = None
    while time.monotonic() - start < deadline_sec:
        try:
            with urllib.request.urlopen(HEALTH_URL, timeout=2) as r:
                if r.status == 200:
                    return
        except Exception as exc:
            last_err = exc
        time.sleep(2)
    raise SystemExit(
        f"fish-speech api_server not ready after {deadline_sec:.0f}s; last error: {last_err!r}"
    )


def synth_clip(text: str, ref_audio_b64: str, ref_text: str, out_path: pathlib.Path) -> None:
    body = {
        "text": text,
        "format": "wav",
        "references": [{"audio": ref_audio_b64, "text": ref_text}],
        "use_memory_cache": "on",
    }
    req = urllib.request.Request(
        TTS_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            out_path.write_bytes(r.read())
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"/v1/tts failed for {out_path.name}: {exc.code} {exc.read()[:500]!r}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    args = ap.parse_args()

    spec = load_spec(ROOT / "prompts" / f"yokai_{args.yokai}.json")
    ref_wav = ROOT / "refs" / f"{args.yokai}_reference.wav"
    ref_txt = ROOT / "refs" / f"{args.yokai}_reference.txt"
    if not ref_wav.exists():
        raise SystemExit(f"reference audio missing: {ref_wav}")
    if not ref_txt.exists():
        raise SystemExit(f"reference transcription missing: {ref_txt}")
    if not (FISH_SPEECH / "tools" / "api_server.py").exists():
        raise SystemExit(f"fish-speech not found at {FISH_SPEECH}")

    out = ROOT / "outputs" / "voice" / args.yokai
    out.mkdir(parents=True, exist_ok=True)

    ref_audio_b64 = base64.b64encode(ref_wav.read_bytes()).decode("ascii")
    ref_transcription = ref_txt.read_text().strip()

    server = subprocess.Popen(
        [sys.executable, "tools/api_server.py"],
        cwd=str(FISH_SPEECH),
        start_new_session=True,
    )
    try:
        wait_for_server(SERVER_STARTUP_TIMEOUT_SEC)
        for key, text in spec["voice"]["clips"].items():
            wav = out / f"{key}.wav"
            synth_clip(text, ref_audio_b64, ref_transcription, wav)
            print(f"generated {wav}")
    finally:
        if server.poll() is None:
            os.killpg(os.getpgid(server.pid), signal.SIGTERM)
            try:
                server.wait(timeout=15)
            except subprocess.TimeoutExpired:
                os.killpg(os.getpgid(server.pid), signal.SIGKILL)


if __name__ == "__main__":
    main()
