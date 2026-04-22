# mora

An iPad-first, on-device learning app for children with dyslexia learning English as a second language.

> **Status:** Early development. Scope, architecture, and APIs are expected to change.

## Requirements

- macOS with Xcode 15+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [swift-format](https://github.com/apple/swift-format) — `brew install swift-format`

## Getting started

```sh
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
