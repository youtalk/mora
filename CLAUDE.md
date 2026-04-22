# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language policy

All content that lands in this repository must be written in **English only**. This applies to:

- Markdown files (README, docs, design notes, this file)
- Source code identifiers (variable / function / type / file names)
- Code comments and docstrings
- Commit messages, PR titles and bodies, GitHub issues
- Any other artifact checked into the repo

Conversations with the user may continue in Japanese, but nothing Japanese should be committed.

## Co-author / generated-by attribution

This repository **opts out** of the global rule in `~/.claude/CLAUDE.md` that strips Anthropic co-author / generated-by attribution.

- Commit messages may end with `Co-Authored-By: Claude <noreply@anthropic.com>`
- PR descriptions may end with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`
- GitHub issues filed by Claude may include similar attribution

Rationale: mora is a personal project and the user wants the Claude Code collaboration history preserved.

## Build & test commands

The Xcode project is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) and is **not** checked in. **After any edit to `project.yml`** (or when `Mora.xcodeproj` is missing) you MUST run `xcodegen generate` to refresh `Mora.xcodeproj`, then run `xcodebuild build` to verify the regenerated project actually picked up the change. Skipping the regenerate step produces a stale `Mora.xcodeproj` that builds cleanly but silently drops new `INFOPLIST_KEY_*` and other build-setting changes — the failure only surfaces at runtime (e.g. a TCC crash because a usage-description key never made it into `Info.plist`).

```sh
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

The `xcodebuild` invocation above also matches CI (no code signing, generic simulator destination) and is the standalone command for a plain rebuild when `project.yml` has not changed.

Run package tests (each SPM package is tested independently; the app target has no test bundle):

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```

Run a single test:

```sh
(cd Packages/MoraEngines && swift test --filter SessionOrchestratorTests.testWarmupAdvancesOnTap)
```

`MoraMLX` is a placeholder package (no test target); verify with `swift build` only.

Lint with swift-format (CI runs `--strict`; `Package.swift` files are excluded because swift-format's `TrailingComma` rule conflicts with the repo convention of trailing commas on every element):

```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
swift-format format --in-place --recursive Mora Packages/*/Sources Packages/*/Tests
```

## Architecture

mora is an iPad-first, **fully on-device** dyslexia + ESL learning app. The thin iOS app target under `Mora/` wires SwiftData and presents `RootView`; all real logic lives in five local SPM packages under `Packages/`, layered strictly:

- **MoraCore** — Domain model + SwiftData persistence. Value types (`Grapheme`, `Phoneme`, `Word`, `Target`, `Skill`, `SessionType`), `L1Profile` protocol with `JapaneseL1Profile` as the v1 implementation, and `@Model` entities under `Persistence/`. `MoraModelContainer` exposes `onDisk()` / `inMemory()` / `seedIfEmpty()` — `MoraApp` falls back from disk → memory on container init failure so the app always launches. No dependencies on other Mora packages.
- **MoraEngines** — All learning-loop logic. Depends on MoraCore. Key pieces:
  - `SessionOrchestrator` (`@Observable @MainActor`) — state machine driving an A-day session through `ADayPhase` (warmup → decode → sentences → summary), consumes `OrchestratorEvent`s.
  - `AssessmentEngine`, `SpeechEngine`/`TTSEngine` protocols (Apple `Speech` / `AVFoundation` adapters live here; fakes live in MoraTesting).
  - `CurriculumEngine`, `ContentProvider` / `ScriptedContentProvider`, `TemplateEngine` — content is generated from a template engine + pre-authored library (bundled as package `Resources`). No network calls.
- **MoraUI** — SwiftUI only. Depends on Core + Engines. `RootView` → `SessionContainerView` drives the per-phase views (`WarmupView`, `DecodeActivityView`, `ShortSentencesView`, `CompletionView`). Views observe the orchestrator; they never own business logic.
- **MoraTesting** — Test doubles (`FakeSpeechEngine`, `FakeTTSEngine`) shared by the other packages' test targets. Keep fakes here, not inline in tests.
- **MoraMLX** — Placeholder for the v1.5 on-device LLM path (MLX + Gemma / Apple Intelligence Foundation Models). Currently empty; do not add runtime dependencies on it from other packages.

Dependency direction is one-way: `Core ← Engines ← UI`, with `Testing` depending on Core+Engines and `MLX` standalone. Do not introduce upward or cyclic edges.

### Key invariants

- **On-device only.** No raw audio, transcripts, or per-trial details may leave the device. The only cloud dependency planned is CloudKit private DB for Parent Mode sync — do not add network calls to engines or UI.
- **L1-aware from day one.** Even though v1 ships only `JapaneseL1Profile`, code must go through the `L1Profile` protocol. Do not hardcode Japanese-specific behavior into engines.
- **Decodability is guaranteed by the template/content layer**, not by UI. Any new content source must filter against the learner's mastered grapheme set plus the current `Target`.
- **Schema changes require a SwiftData migration path.** The on-disk-→in-memory fallback in `MoraApp` is a safety net, not a substitute for migration.

### Design docs

Product specs live under `docs/superpowers/specs/` and implementation plans under `docs/superpowers/plans/`. Check the directory for the current set before starting design or implementation work — filenames are dated and the canonical spec may change over time.

## License

The project is licensed under **PolyForm Noncommercial 1.0.0** (source-available, not OSI-approved). New dependencies must be compatible with noncommercial redistribution; avoid copyleft licenses (GPL family) that would conflict with App Store distribution.
