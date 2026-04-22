# Mora Bench

Minimal iPadOS app that benchmarks on-device LLM inference to validate
Mora's ≤1.5s median turn-latency target on iPad Air class hardware.
The same target also builds for **Mac Catalyst** so the harness can be
smoke-tested on an Apple Silicon Mac before touching the iPad.

This app is intentionally isolated from the main Mora target. It shares
the repo for co-evolution but builds as its own Xcode project
(`bench/Mora Bench.xcodeproj`) with its own bundle id
(`tech.reenable.MoraBench`) and its own external dependencies. The
main Mora app never links MLX.

## Prerequisites

- Xcode 16 or later
- `xcodegen` (`brew install xcodegen`)
- A paid Apple Developer account (required on **iPadOS only** for the
  `increased-memory-limit` and `extended-virtual-addressing`
  entitlements — free Personal Team will build but crash under jetsam
  for >~3 GB models). Mac Catalyst ignores those entitlements, so an
  ad-hoc signature is enough for local smoke testing.
- An iPad Air 5 (M1, 8 GB) or later for the spec-relevant numbers.
- An Apple Silicon Mac (M1 or later) for Mac Catalyst verification.

## Build — iPad

```bash
cd bench
xcodegen generate
open "Mora Bench.xcodeproj"
```

In Xcode, select the `MoraBench` scheme and a connected iPad Air as the
destination. The first build will take 1-2 minutes to resolve the MLX
Swift package graph.

## Build — Mac Catalyst (local smoke test)

Mac Catalyst runs the whole app on macOS with UIKit-for-Mac, which lets
you validate the UI, prompt library, result store, and MLX inference
path without an iPad in the loop. Numbers from Mac Catalyst are **not**
comparable to iPad Air (different thermal envelope, no jetsam, unified
memory) — this destination is for functional verification, not spec
sign-off.

```bash
cd bench
xcodegen generate
xcodebuild build \
  -project "Mora Bench.xcodeproj" -scheme MoraBench \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO -skipMacroValidation
```

`-skipMacroValidation` is required because `mlx-swift-lm` ships Swift
macros (`#hubDownloader()` etc.) that Xcode normally prompts the user
to trust on first build. Opening the project in Xcode and approving
the macro once also works.

To launch the built app without a paid signing identity, ad-hoc sign
it first:

```bash
# Resolve the glob once (newest match) and capture into a single
# variable. `ls -td … | head -1` works in both bash and zsh and tolerates
# DerivedData paths that contain spaces; the plain `$APP` pattern would
# otherwise need either unquoted-to-glob or quoted-to-preserve-spaces
# and can't do both.
APP=$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/Mora_Bench-*/Build/Products/Debug-maccatalyst/MoraBench.app | head -1)
codesign -s - --force --deep --timestamp=none "$APP"
open -n "$APP"
```

Unit tests also run on Mac Catalyst (the jetsam-sensitive
`testAvailableMemoryIsPositive` is skipped because macOS doesn't
enforce iOS-style per-process memory limits):

```bash
xcodebuild test \
  -project "Mora Bench.xcodeproj" -scheme MoraBench \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO -skipMacroValidation
```

## First-launch model download

Models are downloaded from the Hugging Face Hub at runtime on first
use. Expect a 1.5-2.5 GB download per model on WiFi (5-15 min typical).
Downloaded weights are cached in the app's Application Support
directory and survive relaunches; they do **not** survive app deletion
or "Offload App".

## Running the benchmark

1. Launch the app on iPad Air.
2. Tap a model. If weights are missing, tap **Load** to accept the
   download.
3. Once loaded, tap **Run single** for a single-turn metrics report,
   or **Run 20-min endurance** to loop the prompt and capture thermal /
   jetsam behaviour.
4. On the single-run screen, pick a prompt shape (slot-fill short /
   with history / freeform / vocab-expansion) and tap **Run once**.
   On the endurance screen, pick a prompt shape, set the duration via
   the stepper, and tap **Start**.
5. Open **Results** (sidebar toolbar) and tap **Export** to share the
   JSON results off-device via the Share Sheet.

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

## Device verification checklist

Use this after each build that changes model loading, the metrics
harness, or the endurance loop.

### On Mac Catalyst (pre-iPad smoke test)

Use this as a functional gate before shipping the build to an iPad.
Numbers produced here are **not** the spec sign-off numbers — only
iPad Air numbers count for that.

1. Build, ad-hoc sign, launch (see the Mac Catalyst build section above).
2. Sidebar shows the four catalog entries; tapping each one opens
   the download screen in the detail column.
3. Pick **SmolLM 135M Instruct (smoke)**, tap **Load**, and confirm
   it downloads (~60-100 MB) without network errors.
4. Tap **Run single**, pick **Slot-fill (short)** in the picker, and
   tap **Run once** — confirm the live token counter climbs and the
   result summary renders with finite TTFT, prefill tok/s, and decode
   tok/s.
5. On the same single-run screen, change the prompt and tap **Run
   once** twice more — confirm entries accumulate in **Results**
   (sidebar toolbar) and **Export** produces a valid JSON file via
   the Share Sheet.
6. Relaunch — confirm cold load reuses the cached weights in
   `~/Library/Containers/tech.reenable.MoraBench/Data/Library/Application Support`.

Known Mac Catalyst limitations:

- `Peak RSS` and `Avail mem` come from `mach_task_basic_info` /
  `os_proc_available_memory()`. macOS doesn't enforce iOS-style
  jetsam limits, so `availableMemoryStartBytes` is typically `0`
  (i.e., no cap) — that's expected, not a bug.
- Thermal state reads through the same `ProcessInfo` API but Macs
  don't throttle the same way iPads do; drift numbers should be
  interpreted for functional correctness only.
- The 20-minute endurance loop runs to completion but won't trigger
  jetsam; the `JetsamMarker` breadcrumb still arms/disarms and can
  be tested by force-quitting during a run.

### On the iPad Air (manual, cannot run in CI)

1. Clean install: delete the app, reboot the device, leave WiFi on.
2. Launch and pick **Qwen 2.5 3B Instruct** (or the exact Qwen 3.5 4B
   entry once added), then tap **Load**.
3. Let the download complete — record: download time (min), final
   Application Support size (GB).
4. Tap **Run single**, pick **Slot-fill (short)** in the picker, and
   tap **Run once** — record: cold load time, TTFT, prefill tok/s,
   decode tok/s, peak RSS, thermal.
5. Tap **Run once** again on the same screen — record the same
   metrics as **warm**.
6. Run three more single prompts (**Slot-fill with history**,
   **Freeform decodable**, **Vocab expansion**) by changing the
   picker and tapping **Run once** each time — record their
   per-prompt metrics.
7. Back out to the download screen and tap **Run 20-min endurance**.
   Select **Slot-fill with history** (the closest to Mora's real
   load), leave the duration at 20 minutes, and tap **Start**. Let
   it run the full 20 minutes. Plug the iPad in to AC only if the
   spec's 20-minute claim assumes plugged-in usage; otherwise leave
   on battery.
8. After completion, open **Results** → **Export** → AirDrop or Mail
   the JSON off-device.
9. Relaunch the app; if a "previous run was killed" banner appears,
   note that the endurance run was jetsam-terminated.

### Go / no-go

The Mora spec's ≤1.5s median-turn-latency target is viable if, for
the selected model:

- Slot-fill with history **p50 turn latency** ≤ **1.2 s**
- Sustained **decode** ≥ **15 tokens/sec**
- **Peak RSS** ≤ **3.5 GB**
- **Decode drift** (last-5-min vs first-5-min) within ±15%
- **No jetsam** during the full 20-minute run

If the primary model misses on any of these, rerun with **Llama 3.2
3B Instruct** or a smaller quantization before concluding infeasibility.
