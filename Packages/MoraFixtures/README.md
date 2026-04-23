# MoraFixtures

Shared value types for fixture audio recording and bench ingestion.

- `FixtureMetadata`, `ExpectedLabel`, `SpeakerTag` — the sidecar-JSON schema the
  recorder writes and the bench reads.
- `FixturePattern`, `FixtureCatalog.v1Patterns` — the 12-entry canonical pattern
  list the recorder UI drives.
- `FixtureWriter`, `FilenameSlug` — pure-Swift 16-bit PCM WAV writer and the
  IPA-to-ASCII filename slug helper.

Consumed by:
- `recorder/MoraFixtureRecorder/` (the iPad recorder app)
- `dev-tools/pronunciation-bench/` (the Mac benchmarking CLI)

Not consumed by the shipped Mora app. Main `Mora.app` has no dependency edge
into this package.
