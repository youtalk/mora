# pronunciation-bench

Local-only benchmark harness for mora's Engine A pronunciation evaluator.

**Not shipped.** This package is not referenced by `project.yml` or by any
`Package.swift` under `Packages/`. It exists at the repo root to stay
out of the production build graph.

## Usage

1. Copy `.env.example` to `.env` and fill in `SPEECHACE_API_KEY`. The
   CLI reads the key from `ProcessInfo.processInfo.environment`, not
   from `.env` directly, so the file has to be loaded into your shell
   before running the bench — e.g. `source .env`, or export the
   variable in your shell profile. (Pass `--no-speechace` to skip this
   step entirely and run Engine A only.)
2. Export fixtures (WAV + sidecar JSON) from an iPad running a DEBUG
   build of mora via the DEBUG fixture recorder — revealed by a hidden
   5-tap gesture on the HomeView header anchor.
3. Run:

```sh
cd dev-tools/pronunciation-bench
source .env   # or: export SPEECHACE_API_KEY=...
swift run bench ~/path/to/fixtures/ out.csv
```

Pass `--no-speechace` to skip the SpeechAce API call (offline mode).
