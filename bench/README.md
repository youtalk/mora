# Mora Bench

Minimal iPadOS app that benchmarks on-device LLM inference to validate
Mora's ≤1.5s median turn-latency target on iPad Air class hardware.

This app is intentionally isolated from the main Mora target. It shares
the repo for co-evolution but builds as its own Xcode project
(`bench/Mora Bench.xcodeproj`) with its own bundle id
(`tech.reenable.MoraBench`) and its own external dependencies. The
main Mora app never links MLX.

## Prerequisites

- Xcode 16 or later
- `xcodegen` (`brew install xcodegen`)
- A paid Apple Developer account (required for the
  `increased-memory-limit` and `extended-virtual-addressing`
  entitlements on iPadOS — free Personal Team will build but crash
  under jetsam for >~3 GB models)
- An iPad Air 5 (M1, 8 GB) or later for meaningful numbers

## Build

```bash
cd bench
xcodegen generate
open "Mora Bench.xcodeproj"
```

In Xcode, select the `MoraBench` scheme and a connected iPad Air as the
destination. The first build will take 1-2 minutes to resolve the MLX
Swift package graph.

## First-launch model download

Models are downloaded from the Hugging Face Hub at runtime on first
use. Expect a 1.5-2.5 GB download per model on WiFi (5-15 min typical).
Downloaded weights are cached in the app's Application Support
directory and survive relaunches; they do **not** survive app deletion
or "Offload App".

## Running the benchmark

1. Launch the app on iPad Air.
2. Tap a model. If weights are missing, accept the download.
3. Pick a prompt shape (slot-fill short / with history / freeform /
   vocab-expansion).
4. Tap **Run once** to get a single-turn metrics report, or
   **20-min endurance** to loop the prompt and capture thermal /
   jetsam behaviour.
5. Tap **Export** to share the JSON results off-device via Share Sheet.

## Metrics captured

Per single run: cold/warm load time, TTFT, prefill tokens/sec, decode
tokens/sec, peak RSS, available-memory delta, thermal state.

Per endurance run: everything above plus turn-latency p50/p95, thermal
timeline, last-5-minute vs first-5-minute decode rate, Jetsam-fired
flag.

## Success thresholds

The Mora spec requires ≤1.5s median turn latency including STT and
TTS. For the LLM alone, we target:

- **Median 300-in / 40-out turn latency**: ≤ 1.2 s
- **Decode throughput**: ≥ 15 tokens/sec sustained
- **Peak RSS**: ≤ 3.5 GB
- **Last-5-min decode rate**: within 15% of first-5-min

If any threshold misses on the primary model, the bench app is the
place to evaluate fallbacks (smaller quantization, 2B model, or
deferring slot-fill to the next iPadOS release).
