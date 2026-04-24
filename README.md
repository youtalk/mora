# Mora

An iPad-first, on-device learning app for children with dyslexia learning English as a second language.

> **Status:** Early development. Scope, architecture, and APIs are expected to change.

## Requirements

- macOS with Xcode 15+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [swift-format](https://github.com/apple/swift-format) — `brew install swift-format`

## First-time setup (clone-fresh)

The wav2vec2-phoneme CoreML model is hosted as a GitHub Release asset
(see `tools/models.manifest`), not in Git. After cloning:

```sh
bash tools/fetch-models.sh
```

This downloads + SHA-verifies the model into
`Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/`.
Re-runs are no-ops when nothing has changed. The Mora Xcode target also
runs `tools/fetch-models.sh` as a preBuildScript so manifest bumps are
picked up automatically.

CI does the same via `actions/cache` keyed on the manifest hash, so model
download bandwidth stays at zero on cache hits.

## Getting started

```sh
git clone git@github.com:youtalk/mora.git
cd mora
bash tools/fetch-models.sh     # see "First-time setup (clone-fresh)" above
xcodegen generate
open Mora.xcodeproj
```

Then build the `Mora` scheme against an iPad simulator.

## Repository layout

- `Mora/` — iOS app target (thin shell).
- `Packages/` — local Swift packages containing the actual logic (`MoraCore`, `MoraEngines`, `MoraUI`, `MoraTesting`, `MoraMLX`).
- `docs/` — design specs and implementation plans.

## License

[PolyForm Noncommercial License 1.0.0](./LICENSE). Source-available; not OSI-approved open source.

Note: the yokai asset forge under `tools/yokai-forge/` depends on **non-commercial** upstream models (FLUX.1-dev, Fish Speech S2 Pro). Any generated portrait or voice clip inherits that restriction, so a future commercial release would require regenerating those assets with commercially-cleared models. See `tools/yokai-forge/README.md` § "Licensing — commercial release requires swap-outs" and the project `CLAUDE.md` for the swap-out checklist.
