# mora

An iPad-first, on-device learning app for children with dyslexia learning English as a second language.

> **Status:** Early development. Scope, architecture, and APIs are expected to change.

## Requirements

- macOS with Xcode 15+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [swift-format](https://github.com/apple/swift-format) — `brew install swift-format`
- [Git LFS](https://git-lfs.com/) — `brew install git-lfs`. Required to fetch the bundled wav2vec2 CoreML model under `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/`. Without it the working tree checks out LFS pointer files instead of the ~300 MB weights, and Engine B silently falls back to Engine A at runtime (the app still launches — see `MoraApp.makeShadowFactory`).

## Getting started

First-time clone — enable Git LFS once per machine, then ensure the model weights are actually materialized:

```sh
git lfs install            # one-time, repo-agnostic hook install
git clone git@github.com:youtalk/mora.git
cd mora
git lfs pull               # only needed if LFS was installed AFTER cloning
```

Generate the Xcode project and open it:

```sh
xcodegen generate
open Mora.xcodeproj
```

Then build the `Mora` scheme against an iPad simulator.

To confirm the LFS artifacts came through, check that the on-disk `weight.bin` is ~300 MB rather than a ~100-byte pointer file:

```sh
du -h Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/weights/weight.bin
```

## Repository layout

- `Mora/` — iOS app target (thin shell).
- `Packages/` — local Swift packages containing the actual logic (`MoraCore`, `MoraEngines`, `MoraUI`, `MoraTesting`, `MoraMLX`).
- `docs/` — design specs and implementation plans.

## License

[PolyForm Noncommercial License 1.0.0](./LICENSE). Source-available; not OSI-approved open source.

Note: the yokai asset forge under `tools/yokai-forge/` depends on **non-commercial** upstream models (FLUX.1-dev, Fish Speech S2 Pro). Any generated portrait or voice clip inherits that restriction, so a future commercial release would require regenerating those assets with commercially-cleared models. See `tools/yokai-forge/README.md` § "Licensing — commercial release requires swap-outs" and the project `CLAUDE.md` for the swap-out checklist.
