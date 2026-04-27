# Mora

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)
[![Built with Opus 4.7](https://img.shields.io/badge/Built_with-Opus_4.7-orange.svg)](https://www.youtalk.jp/mora)
[![Hackathon Stage 1](https://img.shields.io/badge/Hackathon-Stage_1_2026--04--26-blue.svg)](https://www.youtalk.jp/mora)

> Submitted to Anthropic × Cerebral Valley **Built with Opus 4.7** hackathon (Apr 21–28, 2026). Demo video and full case study at <https://www.youtalk.jp/mora>.

An iPad-first, on-device learning app for children with dyslexia learning English as a second language.

## Demo video

<a href="https://youtu.be/zrsgP30Miqg"><img src="https://img.youtube.com/vi/zrsgP30Miqg/hqdefault.jpg" alt="Mora — 3-min demo (Built with Opus 4.7)" width="480"></a>

Three-minute walkthrough of one A-day session on a real iPad: <https://youtu.be/zrsgP30Miqg>

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

[Mozilla Public License 2.0](./LICENSE). OSI-approved, App Store-compatible,
file-level weak copyleft.

Note: the yokai asset forge under `tools/yokai-forge/` depends on
**non-commercial** upstream models (FLUX.1-dev, Fish Speech S2 Pro). Any
generated portrait or voice clip inherits that restriction, so a future
commercial release would require regenerating those assets with
commercially-cleared models. See `tools/yokai-forge/README.md` § "Licensing —
commercial release requires swap-outs" for the swap-out checklist.

The bundled `wav2vec2-phoneme.mlmodelc` is derived from
`facebook/wav2vec2-xlsr-53-espeak-cv-ft` (MIT-licensed); attribution preserved
in `Packages/MoraMLX/Sources/MoraMLX/Resources/`.
