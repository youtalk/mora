# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language policy

All **governance and authoring artifacts** in this repository are written in **English only**:

- Markdown files used as repo governance / architecture docs (README, CLAUDE.md, most design notes)
- Source code identifiers (variable / function / type / file names)
- Code comments and docstrings
- Commit messages, PR titles and bodies, GitHub issues
- Any other discussion artifact checked into the repo

**Exception — localized product content.** Because the product itself ships localized UI (Japanese-first for the alpha), these are explicitly allowed to contain non-English text:

- `MoraStrings` catalog values and any per-locale string literals embedded in `L1Profile` implementations (e.g. `JapaneseL1Profile.stringsMid`)
- Locale-specific registries of linguistic data (e.g. `JPKanjiLevel`, which holds sets of kanji characters by MEXT grade)
- Sections of design specs and implementation plans that **quote** those strings or describe the locale-specific constraints around them (e.g. the per-string authoring table in `docs/superpowers/specs/2026-04-22-native-language-and-age-selection-design.md §7.2`)
- Inline test expectations that compare against the above values

Surrounding prose, file-level doc comments, git commit messages, and PR bodies stay English even inside files that carry localized strings.

Conversations with the user may continue in Japanese.

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
- **MoraMLX** — Host for on-device ML models used at runtime. Depends on `MoraCore` and `MoraEngines`. Exports `MoraMLXModelCatalog` (lazy model loader with in-process cache) and `CoreMLPhonemePosteriorProvider` (conforms to `MoraEngines.PhonemePosteriorProvider`). As of v1.5 it bundles the INT8-quantized wav2vec2-phoneme CoreML model for Engine B pronunciation scoring; later v1.5 work will also host the on-device LLM (Apple Intelligence Foundation Models or MLX + Gemma). Domain packages consume models only through narrow protocols defined in `MoraEngines`; `MoraUI` does not depend on `MoraMLX`.

Dependency direction is one-way: `Core ← Engines ← UI`, with `Testing` and `MLX` both depending on `Core` + `Engines`. `MoraUI` does not depend on `MoraMLX`. Do not introduce upward or cyclic edges.

### Key invariants

- **On-device only.** No raw audio, transcripts, or per-trial details may leave the device. The only cloud dependency planned is CloudKit private DB for Parent Mode sync — do not add network calls to engines or UI.
- **L1-aware from day one.** Even though v1 ships only `JapaneseL1Profile`, code must go through the `L1Profile` protocol. Do not hardcode Japanese-specific behavior into engines.
- **Decodability is guaranteed by the template/content layer**, not by UI. Any new content source must filter against the learner's mastered grapheme set plus the current `Target`.
- **Schema changes require a SwiftData migration path.** The on-disk-→in-memory fallback in `MoraApp` is a safety net, not a substitute for migration.

### Design docs

Product specs live under `docs/superpowers/specs/` and implementation plans under `docs/superpowers/plans/`. Check the directory for the current set before starting design or implementation work — filenames are dated and the canonical spec may change over time.

## License

The project is licensed under **PolyForm Noncommercial 1.0.0** (source-available, not OSI-approved). New dependencies must be compatible with noncommercial redistribution; avoid copyleft licenses (GPL family) that would conflict with App Store distribution.

### Asset-pipeline NC contamination (yokai-forge)

The offline asset forge under `tools/yokai-forge/` uses **non-commercial**
upstream models — notably **FLUX.1-dev** (FLUX.1 [dev] Non-Commercial License)
for portraits and **Fish Speech S2 Pro** (CC-BY-NC-SA-4.0 model weights) for
voice. Any bundled yokai PNG or `.m4a` produced by this chain is
NC-encumbered regardless of what license the repo ships under.

Before any commercial release:

1. Re-render portraits with a commercially-cleared base (FLUX.1 [schnell]
   under Apache 2.0, FLUX.1 [pro] via paid API, or another commercial
   T2I model). The Style LoRA trained on NC bootstrap pools must also be
   retrained on cleared inputs.
2. Re-synthesize voice clips with a commercially-cleared TTS (ElevenLabs
   commercial tier, real voice actors, or similar). Bark (MIT) is OK but
   its output quality is below Fish Speech — plan accordingly.
3. Audit `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/**` for any
   stale NC-derived files and replace before flipping the repo license.

See `tools/yokai-forge/README.md` § "Licensing — commercial release requires
swap-outs" for the per-dependency table.
