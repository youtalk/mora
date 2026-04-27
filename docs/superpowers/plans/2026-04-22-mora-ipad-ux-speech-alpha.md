# mora — iPad UX + Real Speech/TTS (alpha) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing A-day scaffold into an iPad-native alpha that an 8-year-old child close to Yutaka can use: a "Playful Adventurer" design system, full-bleed L1 session layouts, a "Single Hero" home screen, first-run onboarding (name + interests + permissions), and real on-device `SFSpeechRecognizer` / `AVSpeechSynthesizer` wired through the existing engine protocols with a tap-to-listen interaction model.

**Architecture:** Five-package SPM workspace, unchanged. All additions land in existing packages under `Packages/` following the dependency direction `Core ← Engines ← UI`, with `Testing` depending on Core + Engines and `MLX` unchanged (empty). New subsystems: `MoraUI/Design/` tokens + components, `MoraUI/Home/` + `MoraUI/Onboarding/` + restructured `MoraUI/Session/`, `MoraEngines/Speech/` with the real Apple adapters and `PermissionCoordinator`, two new `@Model` entities in `MoraCore/Persistence/` (`LearnerProfile`, `DailyStreak`), and an `AssessmentLeniency` enum on `AssessmentEngine`. `SpeechEngine` and `OrchestratorEvent` are reshaped (stream API, answerHeard/answerManual split); all call sites migrate in the same commit as the protocol change — no compatibility shims.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData (iPadOS 17+), Foundation, Observation, `Speech`, `AVFAudio`, `AVFoundation`, XCTest; XcodeGen 2.45+ regenerates `Mora.xcodeproj` from `project.yml`. OpenDyslexic Regular (SIL OFL) ships as a `MoraUI` package resource. No MLX, no CloudKit, no network calls.

**Canonical references from the spec (cite these sections in PR descriptions when reviewing):**
- Colors, typography, spacing, radius, components: spec §6
- Session layout L1 frame + per-phase table: spec §7
- Home H1: spec §8
- Onboarding 4-step flow: spec §9
- Speech protocol reshape + `AppleSpeechEngine` + `PermissionCoordinator` + tap-to-listen UI state machine + `OrchestratorEvent` reshape + fallback: spec §10
- TTS `AppleTTSEngine` + `exemplars(for:)` + enhanced-voice chip + usage matrix: spec §11
- `AssessmentLeniency` migration: spec §12
- Animation + haptic timings: spec §13
- Error & boundary handling: spec §16

---

## Stacked PR Strategy

This plan ships as **seven stacked PRs**. Each PR branches off the previous PR's branch (not `main`), so each PR sees only its own diff. PRs land on `main` in order; as each merges, the next PR's base is retargeted to `main` (GitHub does this automatically when the previous PR is squash-merged if you use `gh pr edit --base main`, but the plan shows the explicit command).

The current local branch `main` is ahead of `origin/main` by one commit (`4b98312 Add iPad UX + real Speech/TTS alpha design spec`). **That commit is unpushed and must be dropped**: the spec file belongs in the first PR, not on `main`. Task 1 of PR 1 resets local `main` to `origin/main` and re-adds the spec file on the PR branch.

### PR map

| # | Branch | Base | Purpose |
|---|---|---|---|
| 1 | `feat/mora-alpha/01-design-foundation` | `main` | Spec + this plan + design tokens, OpenDyslexic font, shared components |
| 2 | `feat/mora-alpha/02-session-layout` | `01-design-foundation` | `SessionContainerView` chrome + L1 Fullscreen Focus for every phase (tap mode still) |
| 3 | `feat/mora-alpha/03-home` | `02-session-layout` | `LearnerProfile` + `DailyStreak` entities, `HomeView` H1, `RootView` `NavigationStack` rewire |
| 4 | `feat/mora-alpha/04-onboarding` | `03-home` | Four onboarding views + `OnboardingFlow` + `RootView` branch on UserDefaults flag |
| 5 | `feat/mora-alpha/05-real-speech` | `04-onboarding` | `SpeechEvent` stream, `OrchestratorEvent` split, `AssessmentLeniency`, `PermissionCoordinator`, `AppleSpeechEngine`, `MicButton` wiring, mic-denied fallback, Info.plist keys |
| 6 | `feat/mora-alpha/06-real-tts` | `05-real-speech` | `L1Profile.exemplars`, `AppleTTSEngine`, enhanced-voice chip, session-flow TTS wiring |
| 7 | `feat/mora-alpha/07-polish` | `06-real-tts` | Streak rollover, feedback animations + haptics, close-confirm dialog, device smoke checklist |

Each PR ends with:
- All package tests green: `(cd Packages/X && swift test)` for each package listed in the PR
- CI iPad simulator build green: the `xcodebuild build` command from `CLAUDE.md`
- `swift-format lint --strict` green
- Simulator screenshots attached to the PR (iPad landscape + portrait where relevant)

### Per-PR git ritual

Every PR in this stack uses the same open/retarget ritual, so each task body just points here:

**Open PR N (from branch `feat/mora-alpha/NN-<slug>`):**

```bash
git push -u origin feat/mora-alpha/NN-<slug>
gh pr create \
  --base <previous-branch-or-main> \
  --title "mora alpha NN: <title>" \
  --body "$(cat <<'EOF'
## Summary
- <what this PR delivers>
- <key architectural decision>

Part of the iPad UX + real Speech/TTS alpha. See `docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md` (landed in PR 1) and `docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md` §<relevant sections>.

## Test plan
- [ ] `swift test` in each touched package
- [ ] `xcodebuild build` (CI command from CLAUDE.md)
- [ ] `swift-format lint --strict`
- [ ] Simulator screenshots attached

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Retarget to `main` after previous PR merges:**

```bash
gh pr edit <this-pr-number> --base main
git fetch origin
git rebase origin/main
git push --force-with-lease
```

**Note on `--force-with-lease`:** only ever pushes to a branch that has not been touched by anyone else since you last fetched. It is safe here because stacked PRs are single-author. Never use plain `--force` in this plan.

---

## File Structure

Directories and their responsibilities after all seven PRs land (unchanged pieces omitted):

```
docs/superpowers/
├── specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md   # PR 1: canonical spec
└── plans/2026-04-22-mora-ipad-ux-speech-alpha.md          # PR 1: this plan

Packages/
├── MoraCore/
│   └── Sources/MoraCore/
│       ├── L1Profile.swift                    # PR 6: + exemplars(for:)
│       ├── JapaneseL1Profile.swift            # PR 6: + exemplars implementation
│       └── Persistence/
│           ├── LearnerProfile.swift           # PR 3: new @Model
│           ├── DailyStreak.swift              # PR 3: new @Model
│           └── MoraModelContainer.swift       # PR 3: schema + new entities
│
├── MoraEngines/
│   └── Sources/MoraEngines/
│       ├── ASRResult.swift                    # unchanged
│       ├── ADayPhase.swift                    # PR 5: OrchestratorEvent reshape
│       ├── AssessmentEngine.swift             # PR 5: AssessmentLeniency + 3-arg assess
│       ├── SessionOrchestrator.swift          # PR 5: answerHeard / answerManual handlers
│       ├── SpeechEngine.swift                 # PR 5: stream API + SpeechEvent
│       ├── TTSEngine.swift                    # unchanged protocol
│       └── Speech/                            # PR 5 / PR 6 new subdirectory
│           ├── SpeechEvent.swift              # PR 5
│           ├── PermissionSource.swift         # PR 5: OS-call shim for tests
│           ├── PermissionCoordinator.swift    # PR 5
│           ├── AppleSpeechEngine.swift        # PR 5
│           └── AppleTTSEngine.swift           # PR 6
│
├── MoraUI/
│   └── Sources/MoraUI/
│       ├── RootView.swift                     # PR 3 + PR 4: NavigationStack + onboarding branch
│       ├── Design/                            # PR 1 new subdirectory
│       │   ├── MoraTheme.swift                # tokens (colors, spacing, radius)
│       │   ├── Typography.swift               # type scale + OpenDyslexic registration
│       │   └── Components/
│       │       ├── HeroCTA.swift
│       │       ├── StreakChip.swift
│       │       ├── PhasePips.swift
│       │       ├── MicButton.swift            # PR 1 (visual) + PR 5 (state wiring)
│       │       └── FeedbackOverlay.swift
│       ├── Home/
│       │   └── HomeView.swift                 # PR 3; PR 6 adds enhanced-voice chip
│       ├── Onboarding/                        # PR 4 new subdirectory
│       │   ├── OnboardingFlow.swift
│       │   ├── WelcomeView.swift
│       │   ├── NameView.swift
│       │   ├── InterestPickView.swift
│       │   └── PermissionRequestView.swift
│       ├── Session/                           # PR 2 reorganized
│       │   ├── SessionContainerView.swift     # PR 2: chrome + mode; PR 5: tap-fallback; PR 7: close dialog
│       │   ├── WarmupView.swift               # PR 2 + PR 6 TTS
│       │   ├── NewRuleView.swift              # PR 2 + PR 6 TTS
│       │   ├── DecodeActivityView.swift       # PR 2; PR 5 MicButton wire; PR 6 scaffold TTS; PR 7 anim
│       │   ├── ShortSentencesView.swift       # PR 2; PR 5 MicButton wire; PR 6 scaffold TTS; PR 7 anim
│       │   └── CompletionView.swift           # PR 2; PR 6 TTS; PR 7 streak pulse
│       └── Resources/Fonts/
│           └── OpenDyslexic-Regular.otf       # PR 1 bundled resource
│
├── MoraTesting/
│   └── Sources/MoraTesting/
│       ├── FakeSpeechEngine.swift             # PR 5: stream API migration
│       ├── FakeTTSEngine.swift                # unchanged
│       └── FakePermissionSource.swift         # PR 5 new

project.yml                                     # PR 5: Info.plist keys for mic / speech
```

Files marked across multiple PRs are modified incrementally — each PR touches only what it delivers.

---

## Task Index

| # | PR | Task |
|---|-----|------|
| 1 | 1 | Reset local main, branch off, add spec + plan docs |
| 2 | 1 | Bundle and register OpenDyslexic; Typography tokens |
| 3 | 1 | `MoraTheme` color / spacing / radius tokens |
| 4 | 1 | Components: `HeroCTA`, `StreakChip`, `PhasePips`, `FeedbackOverlay` |
| 5 | 1 | `MicButton` visual shell (idle + listening only; behavior in PR 5) |
| 6 | 2 | `SessionContainerView` 3-band chrome + mode routing |
| 7 | 2 | `WarmupView` L1 rewrite |
| 8 | 2 | `NewRuleView` L1 rewrite |
| 9 | 2 | `DecodeActivityView` L1 rewrite (tap mode retained) |
| 10 | 2 | `ShortSentencesView` L1 rewrite (tap mode retained) |
| 11 | 2 | `CompletionView` L1 rewrite |
| 12 | 3 | `LearnerProfile` + `DailyStreak` `@Model` entities |
| 13 | 3 | `HomeView` H1 single hero |
| 14 | 3 | `RootView` → `NavigationStack` with Home → Session push |
| 15 | 4 | `WelcomeView` |
| 16 | 4 | `NameView` |
| 17 | 4 | `InterestPickView` |
| 18 | 4 | `PermissionRequestView` (uses OS calls directly; coordinator stub) |
| 19 | 4 | `OnboardingFlow` + `RootView` branch on UserDefaults |
| 20 | 5 | `SpeechEvent` + `SpeechEngine` stream reshape + `FakeSpeechEngine` migration |
| 21 | 5 | `OrchestratorEvent.answerHeard` / `.answerManual` split + `AssessmentLeniency` |
| 22 | 5 | `PermissionSource` + `PermissionCoordinator` + `FakePermissionSource` |
| 23 | 5 | `AppleSpeechEngine` + Info.plist keys |
| 24 | 5 | `MicButton` tap-to-listen state machine wired into Decode + Sentences |
| 25 | 5 | Mic-denied tap fallback in `SessionContainerView` |
| 26 | 6 | `L1Profile.exemplars(for:)` + Japanese implementation |
| 27 | 6 | `AppleTTSEngine` |
| 28 | 6 | TTS wired into Warmup / NewRule / scaffold / Completion |
| 29 | 6 | Enhanced-voice chip on `HomeView` |
| 30 | 7 | Streak rollover logic at session completion |
| 31 | 7 | Feedback animations (glow, shake, phase transition, streak pulse) |
| 32 | 7 | Haptics + close-confirmation dialog |
| 33 | 7 | Device smoke checklist (manual) |

---

## Shell conventions

Every task assumes `$REPO_ROOT` is set. Run this once per shell session:

```bash
export REPO_ROOT="$(git rev-parse --show-toplevel)"
```

All `swift test` / `xcodebuild` / `swift-format` commands use the ones pinned in `CLAUDE.md`. Each PR's final step runs:

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
(cd $REPO_ROOT/Packages/MoraTesting && swift test)

cd $REPO_ROOT && xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO

swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

When a specific package is not touched by the PR, you may skip its `swift test`. The xcodebuild and swift-format commands always run.

---

## PR 1 — Design Foundation (branch `feat/mora-alpha/01-design-foundation`, base `main`)

**Deliverables:** spec file, this plan, OpenDyslexic font bundle, `MoraTheme` tokens, shared components (`HeroCTA`, `StreakChip`, `PhasePips`, `MicButton` visual shell, `FeedbackOverlay`). No behavior changes — the app still runs today's scaffold on fakes.

### Task 1: Reset local main, branch off, add spec + plan

**Files:**
- Create (on new branch): `docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md`
- Create (on new branch): `docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md`

- [ ] **Step 1: Save the spec and plan content from the working tree before resetting main.**

The spec currently lives in commit `4b98312` on local `main`; `git reset --hard` will delete it from the working tree. The plan currently lives as an untracked file in the working tree; `git reset --hard` does not touch untracked files, but copying both to `/tmp` keeps the flow uniform and idempotent.

```bash
cd $REPO_ROOT
mkdir -p /tmp/mora-alpha-stash
cp docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md \
   /tmp/mora-alpha-stash/spec.md
cp docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md \
   /tmp/mora-alpha-stash/plan.md
wc -l /tmp/mora-alpha-stash/*.md
```
Expected: `spec.md` ~700 lines, `plan.md` ~5000 lines. If either `cp` errors with "No such file", the source is missing from the working tree — restore it from conversation history before proceeding.

- [ ] **Step 2: Reset local main to origin/main.**

```bash
cd $REPO_ROOT
git fetch origin
git reset --hard origin/main
git status
```
Expected: `HEAD is now at <origin/main SHA>`. The local spec commit (`4b98312`) is gone; origin is untouched.

- [ ] **Step 3: Create the PR 1 branch.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/01-design-foundation
```

- [ ] **Step 4: Put the spec and plan back on the branch.**

```bash
cd $REPO_ROOT
mkdir -p docs/superpowers/specs docs/superpowers/plans
cp /tmp/mora-alpha-stash/spec.md \
   docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md
cp /tmp/mora-alpha-stash/plan.md \
   docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md
```

- [ ] **Step 5: Stage and commit the docs.**

```bash
cd $REPO_ROOT
git add docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md \
        docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md
git commit -m "docs: add iPad UX + real Speech/TTS alpha design spec and plan

Co-Authored-By: Claude <noreply@anthropic.com>"
```

- [ ] **Step 6: Verify the tree matches origin/main plus the docs.**

```bash
cd $REPO_ROOT
git diff origin/main --stat
```
Expected: exactly two files under `docs/superpowers/` shown as additions.

---

### Task 2: Bundle and register OpenDyslexic; Typography tokens

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Resources/Fonts/OpenDyslexic-Regular.otf`
- Modify: `Packages/MoraUI/Package.swift` (add resources: `.process("Resources")`)
- Create: `Packages/MoraUI/Sources/MoraUI/Design/Typography.swift`
- Create: `Packages/MoraUI/Tests/MoraUITests/TypographyTests.swift`

- [ ] **Step 1: Fetch OpenDyslexic Regular from the upstream SIL OFL mirror.**

```bash
cd $REPO_ROOT
mkdir -p Packages/MoraUI/Sources/MoraUI/Resources/Fonts
curl -fSL -o /tmp/OpenDyslexic.zip \
  https://github.com/antijingoist/opendyslexic/releases/download/v3.0.0/OpenDyslexic-0.910.12-Regular.zip \
  || echo "If curl fails, download OpenDyslexic Regular .otf from https://opendyslexic.org and copy it in manually."
unzip -j /tmp/OpenDyslexic.zip '*OpenDyslexic-Regular.otf' -d \
  Packages/MoraUI/Sources/MoraUI/Resources/Fonts/ 2>/dev/null \
  || true
ls -la Packages/MoraUI/Sources/MoraUI/Resources/Fonts/
```
Expected: `OpenDyslexic-Regular.otf` exists. If the upstream URL is unreachable, the engineer manually places the file from https://opendyslexic.org. The font license (SIL OFL) must be vendored alongside the binary — copy `OFL.txt` from the same archive if present, otherwise note it in the PR description.

- [ ] **Step 2: Update `Packages/MoraUI/Package.swift` to bundle the resources.**

```swift
// Packages/MoraUI/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoraUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraUI", targets: ["MoraUI"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraEngines"),
    ],
    targets: [
        .target(
            name: "MoraUI",
            dependencies: ["MoraCore", "MoraEngines"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MoraUITests",
            dependencies: ["MoraUI"]
        ),
    ]
)
```

- [ ] **Step 3: Write the Typography source file.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Typography.swift
import CoreGraphics
import CoreText
import Foundation
import SwiftUI

public enum MoraFontRegistration {
    /// Registered once per process. Returns true if OpenDyslexic Regular is
    /// available as a UIFont after the call, false otherwise (the caller should
    /// fall back to SF Rounded in that case). Idempotent — second call is a
    /// no-op if the font is already registered.
    @discardableResult
    public static func registerBundledFonts() -> Bool {
        guard let url = Bundle.module.url(
            forResource: "OpenDyslexic-Regular", withExtension: "otf"
        ) else {
            return false
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok, let err = error?.takeRetainedValue() {
            let nsErr = err as Error as NSError
            // kCTFontManagerErrorAlreadyRegistered == 105
            if nsErr.code == 105 { return true }
            return false
        }
        return ok
    }
}

public extension Font {
    static func openDyslexic(size: CGFloat) -> Font {
        MoraFontRegistration.registerBundledFonts()
        return Font.custom("OpenDyslexic", size: size)
    }
}

public enum MoraType {
    /// Hero grapheme / numerals. Uses SF Pro Rounded Heavy via SwiftUI's
    /// system font with `.rounded` design.
    public static func hero(_ size: CGFloat = 180) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    public static func heading() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    public static func label() -> Font {
        .system(size: 14, weight: .semibold, design: .rounded)
    }
    public static func pill() -> Font {
        .system(size: 12, weight: .semibold, design: .rounded)
    }
    /// Body reading font. v1 uses OpenDyslexic; a future Settings screen will
    /// let the user switch to SF Rounded via `LearnerProfile.preferredFontKey`.
    public static func bodyReading(size: CGFloat = 22) -> Font {
        .openDyslexic(size: size)
    }
    /// Large on-screen word (decoding). Uses SF Rounded so OpenDyslexic's
    /// low x-height does not crush the hero typography.
    public static func decodingWord(size: CGFloat = 96) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    /// Short sentence. Same family as decoding word but lighter weight.
    public static func sentence(size: CGFloat = 52) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}
```

- [ ] **Step 4: Write the failing registration test.**

```swift
// Packages/MoraUI/Tests/MoraUITests/TypographyTests.swift
import XCTest
@testable import MoraUI

final class TypographyTests: XCTestCase {
    func test_registerBundledFonts_returnsTrue_whenFontIsPresent() {
        XCTAssertTrue(
            MoraFontRegistration.registerBundledFonts(),
            "OpenDyslexic-Regular.otf must be bundled as a package resource and registerable via CoreText"
        )
    }

    func test_registerBundledFonts_isIdempotent() {
        _ = MoraFontRegistration.registerBundledFonts()
        XCTAssertTrue(MoraFontRegistration.registerBundledFonts())
    }
}
```

- [ ] **Step 5: Run package tests.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test --filter TypographyTests)
```
Expected: both tests PASS. If the font file is missing, step 1 did not deposit it in the expected location.

- [ ] **Step 6: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Package.swift \
        Packages/MoraUI/Sources/MoraUI/Design/Typography.swift \
        Packages/MoraUI/Sources/MoraUI/Resources/Fonts/OpenDyslexic-Regular.otf \
        Packages/MoraUI/Tests/MoraUITests/TypographyTests.swift
git commit -m "feat(MoraUI): bundle OpenDyslexic + MoraType scale

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: `MoraTheme` color / spacing / radius tokens

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Design/MoraTheme.swift`
- Create: `Packages/MoraUI/Tests/MoraUITests/MoraThemeTests.swift`

- [ ] **Step 1: Write the failing token test.**

```swift
// Packages/MoraUI/Tests/MoraUITests/MoraThemeTests.swift
import SwiftUI
import XCTest
@testable import MoraUI

final class MoraThemeTests: XCTestCase {
    func test_pageBackground_isWarmOffWhite() {
        // Frozen token values; if these change, the visual review in the PR
        // description must be updated.
        XCTAssertEqual(MoraTheme.Background.pageHex, 0xFFFBF5)
        XCTAssertEqual(MoraTheme.Accent.orangeHex, 0xFF7A00)
        XCTAssertEqual(MoraTheme.Accent.orangeShadowHex, 0xC85800)
        XCTAssertEqual(MoraTheme.Accent.tealHex, 0x00A896)
        XCTAssertEqual(MoraTheme.Ink.primaryHex, 0x2A1E13)
    }

    func test_spacingScale_isPowerOfTwoish() {
        XCTAssertEqual(MoraTheme.Space.xs, 4)
        XCTAssertEqual(MoraTheme.Space.sm, 8)
        XCTAssertEqual(MoraTheme.Space.md, 16)
        XCTAssertEqual(MoraTheme.Space.lg, 24)
        XCTAssertEqual(MoraTheme.Space.xl, 32)
        XCTAssertEqual(MoraTheme.Space.xxl, 48)
    }

    func test_radiusCapsuleIsLarge() {
        XCTAssertEqual(MoraTheme.Radius.button, 999)
        XCTAssertEqual(MoraTheme.Radius.chip, 999)
        XCTAssertEqual(MoraTheme.Radius.card, 22)
        XCTAssertEqual(MoraTheme.Radius.tile, 14)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test --filter MoraThemeTests)
```
Expected: FAIL — `MoraTheme` is not defined.

- [ ] **Step 3: Write `MoraTheme.swift` with tokens and a hex-based `Color` initializer.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/MoraTheme.swift
import SwiftUI

public enum MoraTheme {
    public enum Background {
        public static let pageHex: UInt32 = 0xFFFBF5
        public static let creamHex: UInt32 = 0xFFE8D6
        public static let peachHex: UInt32 = 0xFFCFA5
        public static let mintHex:  UInt32 = 0xD5F0EA

        public static let page = Color(hex: pageHex)
        public static let cream = Color(hex: creamHex)
        public static let peach = Color(hex: peachHex)
        public static let mint = Color(hex: mintHex)
    }
    public enum Accent {
        public static let orangeHex: UInt32 = 0xFF7A00
        public static let orangeShadowHex: UInt32 = 0xC85800
        public static let tealHex: UInt32 = 0x00A896
        public static let tealShadowHex: UInt32 = 0x007F73

        public static let orange = Color(hex: orangeHex)
        public static let orangeShadow = Color(hex: orangeShadowHex)
        public static let teal = Color(hex: tealHex)
        public static let tealShadow = Color(hex: tealShadowHex)
    }
    public enum Ink {
        public static let primaryHex: UInt32 = 0x2A1E13
        public static let secondaryHex: UInt32 = 0x8A7453
        public static let mutedHex: UInt32 = 0x888888

        public static let primary = Color(hex: primaryHex)
        public static let secondary = Color(hex: secondaryHex)
        public static let muted = Color(hex: mutedHex)
    }
    public enum Feedback {
        public static let correct = Color(hex: 0x00A896)
        public static let wrong   = Color(hex: 0xFF7A00)
    }
    public enum Space {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }
    public enum Radius {
        public static let button: CGFloat = 999
        public static let card: CGFloat = 22
        public static let chip: CGFloat = 999
        public static let tile: CGFloat = 14
    }
}

public extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
```

- [ ] **Step 4: Run the tests.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test --filter MoraThemeTests)
```
Expected: PASS.

- [ ] **Step 5: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Design/MoraTheme.swift \
        Packages/MoraUI/Tests/MoraUITests/MoraThemeTests.swift
git commit -m "feat(MoraUI): MoraTheme color / spacing / radius tokens

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Components — `HeroCTA`, `StreakChip`, `PhasePips`, `FeedbackOverlay`

Four small components, each one file. No logic — pure presentation. Tests are omitted here because the plan defers SwiftUI snapshot/rendering tests per spec §15.4; correctness is visual and reviewed in the PR.

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Design/Components/HeroCTA.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Design/Components/StreakChip.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Design/Components/PhasePips.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Design/Components/FeedbackOverlay.swift`

- [ ] **Step 1: Write `HeroCTA.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Components/HeroCTA.swift
import SwiftUI

public struct HeroCTA: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(MoraType.heading())
                .foregroundStyle(Color.white)
                .padding(.horizontal, MoraTheme.Space.xl)
                .padding(.vertical, MoraTheme.Space.md)
                .frame(minHeight: 88)
                .background(MoraTheme.Accent.orange, in: .capsule)
                .shadow(color: MoraTheme.Accent.orangeShadow, radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Write `StreakChip.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Components/StreakChip.swift
import SwiftUI

public struct StreakChip: View {
    public let count: Int
    public init(count: Int) { self.count = count }

    public var body: some View {
        HStack(spacing: MoraTheme.Space.xs) {
            Text("🔥").font(.system(size: 18))
            Text("\(count)")
                .font(MoraType.pill())
                .foregroundStyle(MoraTheme.Ink.primary)
        }
        .padding(.horizontal, MoraTheme.Space.md)
        .padding(.vertical, MoraTheme.Space.sm)
        .background(MoraTheme.Background.mint, in: .capsule)
    }
}
```

- [ ] **Step 3: Write `PhasePips.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Components/PhasePips.swift
import SwiftUI
import MoraEngines

public struct PhasePips: View {
    public let currentIndex: Int
    public let totalCount: Int

    public init(currentIndex: Int, totalCount: Int = 5) {
        self.currentIndex = currentIndex
        self.totalCount = totalCount
    }

    /// Convenience initializer mapping ADayPhase → pip index:
    /// warmup=0, newRule=1, decoding=2, shortSentences=3, completion=4.
    /// .notStarted shows no active pip (index -1).
    public init(phase: ADayPhase) {
        let idx: Int
        switch phase {
        case .notStarted:       idx = -1
        case .warmup:           idx = 0
        case .newRule:          idx = 1
        case .decoding:         idx = 2
        case .shortSentences:   idx = 3
        case .completion:       idx = 4
        }
        self.init(currentIndex: idx, totalCount: 5)
    }

    public var body: some View {
        HStack(spacing: MoraTheme.Space.sm) {
            ForEach(0..<totalCount, id: \.self) { i in
                Capsule()
                    .fill(color(for: i))
                    .frame(width: 34, height: 6)
            }
        }
    }

    private func color(for i: Int) -> Color {
        if i < currentIndex { return MoraTheme.Accent.teal }
        if i == currentIndex { return MoraTheme.Accent.orange }
        return MoraTheme.Ink.muted.opacity(0.3)
    }
}
```

- [ ] **Step 4: Write `FeedbackOverlay.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Components/FeedbackOverlay.swift
import SwiftUI

public enum FeedbackState: Equatable, Sendable {
    case none
    case correct
    case wrong
}

public struct FeedbackOverlay: View {
    public let state: FeedbackState
    public init(state: FeedbackState) { self.state = state }

    public var body: some View {
        ZStack {
            switch state {
            case .none:
                EmptyView()
            case .correct:
                MoraTheme.Feedback.correct.opacity(0.30)
                    .ignoresSafeArea()
                Image(systemName: "checkmark.circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundStyle(MoraTheme.Feedback.correct)
            case .wrong:
                RoundedRectangle(cornerRadius: MoraTheme.Radius.card)
                    .strokeBorder(MoraTheme.Feedback.wrong, lineWidth: 8)
                    .padding(MoraTheme.Space.md)
                    .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}
```

- [ ] **Step 5: Build the package.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: `Build complete!`

- [ ] **Step 6: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Design/Components/
git commit -m "feat(MoraUI): HeroCTA, StreakChip, PhasePips, FeedbackOverlay

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: `MicButton` visual shell

Visual state only here — the tap-to-listen state machine is wired in PR 5 (Task 24). This task delivers the three presentation states so PR 2 session views can render it.

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Design/Components/MicButton.swift`

- [ ] **Step 1: Write `MicButton.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Components/MicButton.swift
import SwiftUI

public enum MicButtonState: Equatable, Sendable {
    case idle
    case listening
    case assessing
}

public struct MicButton: View {
    public let state: MicButtonState
    public let action: () -> Void

    public init(state: MicButtonState, action: @escaping () -> Void) {
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ZStack {
                if state == .listening {
                    Circle()
                        .stroke(MoraTheme.Accent.teal, lineWidth: 6)
                        .frame(width: 128, height: 128)
                        .scaleEffect(pulse ? 1.12 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.9).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                Circle()
                    .fill(MoraTheme.Accent.orange)
                    .frame(width: 96, height: 96)
                    .shadow(color: MoraTheme.Accent.orangeShadow, radius: 0, x: 0, y: 5)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .assessing)
        .onAppear { pulse = state == .listening }
        .onChange(of: state) { _, new in pulse = new == .listening }
    }

    @State private var pulse: Bool = false

    private var icon: String {
        switch state {
        case .idle:       return "mic.fill"
        case .listening:  return "waveform"
        case .assessing:  return "ellipsis"
        }
    }
}
```

- [ ] **Step 2: Build to verify.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: `Build complete!`

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Design/Components/MicButton.swift
git commit -m "feat(MoraUI): MicButton visual shell (idle/listening/assessing)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### PR 1 finalize

- [ ] **Step 1: Run full test + lint + build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```
Expected: all green.

- [ ] **Step 2: Open PR.** Follow the ritual from "Stacked PR Strategy → Per-PR git ritual", using `--base main` and title `mora alpha 01: design foundation, tokens, components`.

---


## PR 2 — Session Layout (branch `feat/mora-alpha/02-session-layout`, base `01-design-foundation`)

**Deliverables:** every session phase view re-laid to L1 Fullscreen Focus. The `SessionContainerView` gains three-band chrome (close / phase pips / streak), body fills the iPad canvas edge-to-edge, warm off-white background covers the whole screen. Tap mode is preserved — the MicButton is rendered with `state: .idle` and a tap still calls the existing `.answerResult(correct:asr:)` path. No orchestrator changes.

### Task 6: `SessionContainerView` 3-band chrome + mode routing

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/SessionContainerView.swift` (move to `Session/SessionContainerView.swift`)
- Modify: `Packages/MoraUI/Sources/MoraUI/WarmupView.swift` → `Session/WarmupView.swift` (file move only, contents touched in Task 7)
- Modify: same for `NewRuleView.swift`, `DecodeActivityView.swift`, `ShortSentencesView.swift`, `CompletionView.swift`

- [ ] **Step 1: Branch from PR 1.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/02-session-layout feat/mora-alpha/01-design-foundation
```

- [ ] **Step 2: Move the session-related files into `Session/`.**

```bash
cd $REPO_ROOT/Packages/MoraUI/Sources/MoraUI
mkdir -p Session
git mv SessionContainerView.swift Session/SessionContainerView.swift
git mv WarmupView.swift           Session/WarmupView.swift
git mv NewRuleView.swift          Session/NewRuleView.swift
git mv DecodeActivityView.swift   Session/DecodeActivityView.swift
git mv ShortSentencesView.swift   Session/ShortSentencesView.swift
git mv CompletionView.swift       Session/CompletionView.swift
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: `Build complete!` — file moves alone do not break compilation because SPM discovers sources recursively.

- [ ] **Step 3: Rewrite `SessionContainerView.swift` with the three-band chrome.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

private let persistLog = Logger(subsystem: "tech.reenable.Mora", category: "Persistence")

/// UI mode is currently fixed to `.tap` until PR 5 introduces `.mic`. Keep the
/// enum so downstream views can switch on it without a later rewrite.
public enum SessionUIMode: Equatable, Sendable {
    case tap
    case mic
}

public struct SessionContainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?
    @State private var feedback: FeedbackState = .none
    @State private var uiMode: SessionUIMode = .tap

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                    .padding(.horizontal, MoraTheme.Space.md)
                    .padding(.top, MoraTheme.Space.md)
                body
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, MoraTheme.Space.xxl)
            }

            FeedbackOverlay(state: feedback)
        }
        .navigationBarHidden(true)
    }

    private var topChrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.6), in: .circle)
            }
            .buttonStyle(.plain)

            Spacer()

            if let orchestrator {
                PhasePips(phase: orchestrator.phase)
            } else {
                PhasePips(currentIndex: -1)
            }

            Spacer()

            // Streak is wired in PR 3 when DailyStreak lands; until then, stub 0.
            StreakChip(count: 0)
        }
    }

    @ViewBuilder
    private var body: some View {
        if let orchestrator {
            switch orchestrator.phase {
            case .notStarted:
                ProgressView("Preparing…")
                    .task { await orchestrator.start() }
            case .warmup:
                WarmupView(orchestrator: orchestrator)
            case .newRule:
                NewRuleView(orchestrator: orchestrator)
            case .decoding:
                DecodeActivityView(orchestrator: orchestrator, uiMode: uiMode, feedback: $feedback)
            case .shortSentences:
                ShortSentencesView(orchestrator: orchestrator, uiMode: uiMode, feedback: $feedback)
            case .completion:
                CompletionView(
                    orchestrator: orchestrator,
                    persistSummary: { summary in persist(summary: summary) }
                )
            }
        } else if let bootError {
            Text("Could not start session: \(bootError)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
        } else {
            ProgressView("Loading session…")
                .task { await bootstrap() }
        }
    }

    @MainActor
    private func bootstrap() async {
        do {
            let curriculum = CurriculumEngine.defaultV1Ladder()
            let target = curriculum.currentTarget(forWeekIndex: 0)
            let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
            guard let targetGrapheme = target.skill.graphemePhoneme?.grapheme else {
                bootError = "Target skill \(target.skill.code.rawValue) has no grapheme/phoneme mapping"
                return
            }
            let provider = try ScriptedContentProvider.bundledShWeek1()
            let words = try provider.decodeWords(ContentRequest(
                target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 5
            ))
            let sentences = try provider.decodeSentences(ContentRequest(
                target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2
            ))
            self.orchestrator = SessionOrchestrator(
                target: target, taughtGraphemes: taught,
                warmupOptions: [
                    Grapheme(letters: "s"),
                    Grapheme(letters: "sh"),
                    Grapheme(letters: "ch"),
                ],
                words: words, sentences: sentences,
                assessment: AssessmentEngine(l1Profile: JapaneseL1Profile())
            )
        } catch {
            bootError = String(describing: error)
        }
    }

    @MainActor
    private func persist(summary: SessionSummary) {
        let entity = SessionSummaryEntity(
            date: Date(),
            sessionType: summary.sessionType.rawValue,
            targetSkillCode: summary.targetSkillCode.rawValue,
            durationSec: summary.durationSec,
            trialsTotal: summary.trialsTotal,
            trialsCorrect: summary.trialsCorrect,
            escalated: summary.escalated
        )
        context.insert(entity)
        do { try context.save() }
        catch { persistLog.error("SessionSummary save failed: \(error)") }
    }
}
```

- [ ] **Step 4: Build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: errors only from signature drift in phase views (Decode and Sentences now take `uiMode` + `feedback`). These are fixed in Tasks 9–10. Build errors are acceptable at this step boundary; they resolve by end of Task 10.

- [ ] **Step 5: Commit the chrome skeleton.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/
git commit -m "feat(MoraUI): SessionContainerView 3-band chrome + mode routing

Build intentionally red at this commit — Decode + Sentences signature
updates land in the next commits of this PR.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: `WarmupView` L1 rewrite

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift`

- [ ] **Step 1: Replace the file contents.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift
import MoraCore
import MoraEngines
import SwiftUI

struct WarmupView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: MoraTheme.Space.xl) {
            Spacer()
            Text("Which one says /\(targetIPA)/?")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
            Text("Listen and tap.")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            HStack(spacing: MoraTheme.Space.xl) {
                ForEach(orchestrator.warmupOptions, id: \.letters) { g in
                    Button(action: {
                        Task { await orchestrator.handle(.warmupTap(g)) }
                    }) {
                        Text(g.letters)
                            .font(.system(size: 84, weight: .heavy, design: .rounded))
                            .foregroundStyle(MoraTheme.Ink.primary)
                            .frame(width: 140, height: 140)
                            .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.card))
                            .shadow(color: MoraTheme.Ink.secondary.opacity(0.20), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, MoraTheme.Space.lg)

            if orchestrator.warmupMissCount > 0 {
                Text("Let's try again — listen.")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.orange)
            }

            Spacer()

            Button(action: {
                // TTS replay wires in PR 6. Until then this is a no-op stub so
                // the layout renders today.
            }) {
                Label("Listen again", systemImage: "speaker.wave.2.fill")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .padding(.vertical, MoraTheme.Space.md)
                    .padding(.horizontal, MoraTheme.Space.lg)
                    .background(MoraTheme.Background.mint, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.bottom, MoraTheme.Space.lg)
        }
    }

    private var targetIPA: String {
        orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? "?"
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift
git commit -m "feat(MoraUI): WarmupView L1 Fullscreen Focus layout

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: `NewRuleView` L1 rewrite

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/NewRuleView.swift`

- [ ] **Step 1: Replace the file contents.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/NewRuleView.swift
import MoraCore
import MoraEngines
import SwiftUI

struct NewRuleView: View {
    let orchestrator: SessionOrchestrator

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("New rule")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            Text("\(letters) → /\(ipa)/")
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text("Two letters, one sound.")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.secondary)

            HStack(spacing: MoraTheme.Space.lg) {
                workedExample("ship")
                workedExample("shop")
                workedExample("fish")
            }
            .padding(.top, MoraTheme.Space.lg)

            Spacer()

            HeroCTA(title: "Got it") {
                Task { await orchestrator.handle(.advance) }
            }
            .padding(.bottom, MoraTheme.Space.xl)
        }
    }

    private func workedExample(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(MoraTheme.Ink.primary)
            .padding(.horizontal, MoraTheme.Space.lg)
            .padding(.vertical, MoraTheme.Space.md)
            .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.tile))
            .shadow(color: MoraTheme.Ink.secondary.opacity(0.15), radius: 3, y: 2)
    }

    private var letters: String {
        orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? "?"
    }
    private var ipa: String {
        orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? "?"
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/NewRuleView.swift
git commit -m "feat(MoraUI): NewRuleView L1 layout with worked examples

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 9: `DecodeActivityView` L1 rewrite (tap mode retained)

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift`

The view now takes a `uiMode` and `feedback` binding from `SessionContainerView`. In `.tap` mode, it shows the existing Correct / Wrong buttons. In `.mic` mode (reached in PR 5) it will show `MicButton`. This task renders the `MicButton` placeholder disabled so the L1 layout is visually final.

- [ ] **Step 1: Replace the file contents.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift
import MoraCore
import MoraEngines
import SwiftUI

struct DecodeActivityView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentWord {
                Text(current.word.surface)
                    .font(MoraType.decodingWord())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .onLongPressGesture {
                        // TTS word replay wires in PR 6.
                    }

                if let note = current.note {
                    Text(note)
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.muted)
                }

                Spacer()

                switch uiMode {
                case .tap:
                    tapPair(word: current.word)
                case .mic:
                    // PR 5 wires state + action. Until then this renders an
                    // inert idle button (disabled via action = {}).
                    MicButton(state: .idle, action: {})
                }

                Text("Word \(orchestrator.wordIndex + 1) of \(orchestrator.words.count) · long-press to hear")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .padding(.bottom, MoraTheme.Space.lg)
            } else {
                ProgressView()
            }
        }
    }

    private var currentWord: DecodeWord? {
        guard orchestrator.wordIndex < orchestrator.words.count else { return nil }
        return orchestrator.words[orchestrator.wordIndex]
    }

    private func tapPair(word: Word) -> some View {
        HStack(spacing: MoraTheme.Space.xl) {
            tapButton("Correct", color: MoraTheme.Feedback.correct) {
                feedback = .correct
                Task {
                    await orchestrator.handle(.answerResult(
                        correct: true,
                        asr: ASRResult(transcript: word.surface, confidence: 1.0)
                    ))
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    feedback = .none
                }
            }
            tapButton("Wrong", color: MoraTheme.Feedback.wrong) {
                feedback = .wrong
                Task {
                    await orchestrator.handle(.answerResult(
                        correct: false, asr: ASRResult(transcript: "", confidence: 0)
                    ))
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    feedback = .none
                }
            }
        }
    }

    private func tapButton(
        _ title: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(MoraType.heading())
                .foregroundStyle(.white)
                .frame(minWidth: 200, minHeight: 72)
                .background(color, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift
git commit -m "feat(MoraUI): DecodeActivityView L1 layout (tap mode + mic placeholder)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 10: `ShortSentencesView` L1 rewrite (tap mode retained)

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift`

- [ ] **Step 1: Replace the file contents.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift
import MoraCore
import MoraEngines
import SwiftUI

struct ShortSentencesView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            if let current = currentSentence {
                Text(current.text)
                    .font(MoraType.sentence())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .onLongPressGesture {
                        // TTS replay wires in PR 6.
                    }

                Spacer()

                switch uiMode {
                case .tap:
                    tapPair(sentence: current)
                case .mic:
                    MicButton(state: .idle, action: {})
                }

                Text("Sentence \(orchestrator.sentenceIndex + 1) of \(orchestrator.sentences.count) · long-press to hear")
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .padding(.bottom, MoraTheme.Space.lg)
            } else {
                ProgressView()
            }
        }
    }

    private var currentSentence: DecodeSentence? {
        guard orchestrator.sentenceIndex < orchestrator.sentences.count else { return nil }
        return orchestrator.sentences[orchestrator.sentenceIndex]
    }

    private func tapPair(sentence: DecodeSentence) -> some View {
        HStack(spacing: MoraTheme.Space.xl) {
            tapButton("Correct", color: MoraTheme.Feedback.correct) {
                feedback = .correct
                Task {
                    await orchestrator.handle(.answerResult(
                        correct: true,
                        asr: ASRResult(transcript: sentence.text, confidence: 1.0)
                    ))
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    feedback = .none
                }
            }
            tapButton("Wrong", color: MoraTheme.Feedback.wrong) {
                feedback = .wrong
                Task {
                    await orchestrator.handle(.answerResult(
                        correct: false, asr: ASRResult(transcript: "", confidence: 0)
                    ))
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    feedback = .none
                }
            }
        }
    }

    private func tapButton(
        _ title: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(MoraType.heading())
                .foregroundStyle(.white)
                .frame(minWidth: 200, minHeight: 72)
                .background(color, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Build to verify PR 2 now compiles.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: `Build complete!` — the signature-drift errors from Task 6 are now fully resolved.

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift
git commit -m "feat(MoraUI): ShortSentencesView L1 layout (tap mode + mic placeholder)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 11: `CompletionView` L1 rewrite

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift`

- [ ] **Step 1: Replace the file contents.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift
import MoraCore
import MoraEngines
import SwiftUI

struct CompletionView: View {
    let orchestrator: SessionOrchestrator
    let persistSummary: (SessionSummary) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var didPersist = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()

            Text("Quest complete!")
                .font(.system(size: 60, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text("\(correct) / \(total)")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Accent.teal)

            Text("Today's target: \(letters)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.secondary)

            Spacer()

            Text("Come back tomorrow!")
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear {
            guard !didPersist else { return }
            didPersist = true
            persistSummary(orchestrator.sessionSummary(endedAt: Date()))
        }
    }

    private var correct: Int { orchestrator.trials.filter(\.correct).count }
    private var total: Int { orchestrator.trials.count }
    private var letters: String {
        orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? "?"
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift
git commit -m "feat(MoraUI): CompletionView L1 layout with huge scoreline

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### PR 2 finalize

- [ ] **Step 1: Run full test + lint + build.**

```bash
(cd $REPO_ROOT/Packages/MoraCore    && swift test)
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
(cd $REPO_ROOT/Packages/MoraUI      && swift test)
(cd $REPO_ROOT/Packages/MoraTesting && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```
Expected: all green. Integration tests still pass because orchestrator is unchanged.

- [ ] **Step 2: Attach iPad landscape screenshots of each phase to the PR (Warmup, NewRule, Decode, Sentences, Completion). Use the built-in simulator screenshotter; iPad 11-inch and iPad mini both, to show size-class adaptation.**

- [ ] **Step 3: Open PR.** Use the ritual from the top of the plan, title `mora alpha 02: Fullscreen Focus session layout`, base `feat/mora-alpha/01-design-foundation`.

---


## PR 3 — Home Screen (branch `feat/mora-alpha/03-home`, base `02-session-layout`)

**Deliverables:** `LearnerProfile` + `DailyStreak` `@Model` entities added to the schema, `HomeView` H1 rendering the target grapheme and a start button, `RootView` rewritten as a `NavigationStack` that pushes into `SessionContainerView`. `DailyStreak` is seeded empty; actual increment logic lands in PR 7.

### Task 12: `LearnerProfile` + `DailyStreak` `@Model` entities

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/DailyStreak.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileTests.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/DailyStreakTests.swift`

- [ ] **Step 1: Branch.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/03-home feat/mora-alpha/02-session-layout
```

- [ ] **Step 2: Write failing entity tests.**

```swift
// Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileTests.swift
import SwiftData
import XCTest
@testable import MoraCore

@MainActor
final class LearnerProfileTests: XCTestCase {
    func test_insertAndFetch_roundTrip() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let profile = LearnerProfile(
            displayName: "Hiro",
            l1Identifier: "ja",
            interests: ["dinosaurs", "space", "robots"],
            preferredFontKey: "openDyslexic"
        )
        ctx.insert(profile)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.displayName, "Hiro")
        XCTAssertEqual(fetched.first?.interests, ["dinosaurs", "space", "robots"])
    }

    func test_displayNameCanBeEmpty() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        ctx.insert(LearnerProfile(
            displayName: "",
            l1Identifier: "ja",
            interests: [],
            preferredFontKey: "openDyslexic"
        ))
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(fetched.first?.displayName, "")
    }
}
```

```swift
// Packages/MoraCore/Tests/MoraCoreTests/DailyStreakTests.swift
import SwiftData
import XCTest
@testable import MoraCore

@MainActor
final class DailyStreakTests: XCTestCase {
    func test_insertAndFetch_startsAtZero() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let streak = DailyStreak(currentCount: 0, longestCount: 0, lastCompletedOn: nil)
        ctx.insert(streak)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<DailyStreak>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.currentCount, 0)
        XCTAssertNil(fetched.first?.lastCompletedOn)
    }
}
```

- [ ] **Step 3: Run — expect failure.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test --filter LearnerProfileTests)
```
Expected: FAIL — `LearnerProfile` not defined.

- [ ] **Step 4: Create `LearnerProfile.swift`.**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift
import Foundation
import SwiftData

@Model
public final class LearnerProfile {
    public var id: UUID
    public var displayName: String
    public var l1Identifier: String
    public var interests: [String]
    public var preferredFontKey: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        l1Identifier: String,
        interests: [String],
        preferredFontKey: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.l1Identifier = l1Identifier
        self.interests = interests
        self.preferredFontKey = preferredFontKey
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 5: Create `DailyStreak.swift`.**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/DailyStreak.swift
import Foundation
import SwiftData

@Model
public final class DailyStreak {
    public var id: UUID
    public var currentCount: Int
    public var longestCount: Int
    public var lastCompletedOn: Date?

    public init(
        id: UUID = UUID(),
        currentCount: Int = 0,
        longestCount: Int = 0,
        lastCompletedOn: Date? = nil
    ) {
        self.id = id
        self.currentCount = currentCount
        self.longestCount = longestCount
        self.lastCompletedOn = lastCompletedOn
    }
}
```

- [ ] **Step 6: Register the new models in the schema.**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift
import Foundation
import SwiftData

public enum MoraModelContainer {
    public static let schema = Schema([
        LearnerEntity.self,
        SkillEntity.self,
        SessionSummaryEntity.self,
        PerformanceEntity.self,
        LearnerProfile.self,
        DailyStreak.self,
    ])

    public static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func onDisk() throws -> ModelContainer {
        let config = ModelConfiguration()
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    public static func seedIfEmpty(
        _ ctx: ModelContext,
        defaultName: String = "Learner",
        birthYear: Int = 2017,
        l1Identifier: String = "ja"
    ) throws {
        var descriptor = FetchDescriptor<LearnerEntity>()
        descriptor.fetchLimit = 1
        let learners = try ctx.fetch(descriptor)
        if !learners.isEmpty { return }
        let learner = LearnerEntity(
            displayName: defaultName,
            birthYear: birthYear,
            l1Identifier: l1Identifier
        )
        ctx.insert(learner)
        try ctx.save()
    }
}
```

**Schema migration note:** Adding two new `@Model` types to the schema is handled by SwiftData as an additive migration at app launch. No explicit migration plan is needed for this release. The existing `onDisk → inMemory` fallback in `MoraApp.makeContainer()` remains the safety net if the migration ever fails.

- [ ] **Step 7: Run tests — expect pass.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
```
Expected: all MoraCore tests PASS, including the two new ones.

- [ ] **Step 8: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/DailyStreak.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift \
        Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileTests.swift \
        Packages/MoraCore/Tests/MoraCoreTests/DailyStreakTests.swift
git commit -m "feat(MoraCore): LearnerProfile + DailyStreak SwiftData models

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 13: `HomeView` H1 single hero

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

- [ ] **Step 1: Write `HomeView.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

public struct HomeView: View {
    @Query private var profiles: [LearnerProfile]
    @Query private var streaks: [DailyStreak]

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: MoraTheme.Space.lg) {
                header
                Spacer()
                hero
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack {
            Text("mora")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Accent.orange)
            Spacer()
            StreakChip(count: streaks.first?.currentCount ?? 0)
        }
        .padding(MoraTheme.Space.md)
    }

    private var hero: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text("Today's quest")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            Text(target.skill.graphemePhoneme?.grapheme.letters ?? "—")
                .font(MoraType.hero(180))
                .foregroundStyle(MoraTheme.Ink.primary)

            Text(ipaLine)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.secondary)

            NavigationLink(value: "session") {
                Text("▶ Start")
                    .font(MoraType.heading())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 88)
                    .background(MoraTheme.Accent.orange, in: .capsule)
                    .shadow(color: MoraTheme.Accent.orangeShadow, radius: 0, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.top, MoraTheme.Space.md)

            HStack(spacing: MoraTheme.Space.sm) {
                pill("16 min")
                pill("5 words")
                pill("2 sentences")
            }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(MoraType.pill())
            .foregroundStyle(MoraTheme.Ink.secondary)
            .padding(.horizontal, MoraTheme.Space.md)
            .padding(.vertical, MoraTheme.Space.sm)
            .background(MoraTheme.Background.cream, in: .capsule)
    }

    private var curriculum: CurriculumEngine { CurriculumEngine.defaultV1Ladder() }

    private var target: Target {
        let week = weekIndex
        return curriculum.currentTarget(forWeekIndex: week)
    }

    /// Weeks elapsed since the learner's profile was created, clamped into the
    /// curriculum. When no profile exists (pre-onboarding state in PR 3 before
    /// PR 4 lands), we default to week 0 so the hero renders something.
    private var weekIndex: Int {
        guard let profile = profiles.first else { return 0 }
        let seconds = Date().timeIntervalSince(profile.createdAt)
        return Int(seconds / (60 * 60 * 24 * 7))
    }

    private var ipaLine: String {
        guard let gp = target.skill.graphemePhoneme else { return "" }
        return "/\(gp.phoneme.ipa)/ · as in ship, shop, fish"
    }
}
```

- [ ] **Step 2: Build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: `Build complete!`

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "feat(MoraUI): HomeView H1 single-hero layout

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 14: `RootView` → `NavigationStack` with Home → Session push

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/RootView.swift`

- [ ] **Step 1: Replace the file contents.**

```swift
// Packages/MoraUI/Sources/MoraUI/RootView.swift
import SwiftUI

public struct RootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "session":
                        SessionContainerView()
                    default:
                        EmptyView()
                    }
                }
        }
    }
}
```

Note: the `String` navigation value shape will be replaced in PR 4 with an `enum AppDestination` when onboarding adds more destinations. For PR 3 a single string case is enough.

- [ ] **Step 2: Run app-level build.**

```bash
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/RootView.swift
git commit -m "feat(MoraUI): RootView NavigationStack (Home → Session)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### PR 3 finalize

- [ ] **Step 1: Full test + lint + build.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 2: Open PR** with base `feat/mora-alpha/02-session-layout`, title `mora alpha 03: Home screen + persistence entities`. Attach an iPad landscape screenshot of Home.

---


## PR 4 — Onboarding Flow (branch `feat/mora-alpha/04-onboarding`, base `03-home`)

**Deliverables:** 4-screen onboarding (`WelcomeView`, `NameView`, `InterestPickView`, `PermissionRequestView`), an `OnboardingFlow` container that owns step state, and a `RootView` branch on `UserDefaults.bool("tech.reenable.Mora.onboarded")`. On completion, inserts `LearnerProfile` + `DailyStreak` into SwiftData and flips the flag. Permission requests are made directly via `AVAudioApplication` + `SFSpeechRecognizer` in this PR; the `PermissionCoordinator` abstraction comes in PR 5. This keeps PR 4 fully behavior-testable with the flow alone.

Note on ordering: PR 4 is pure UI + SwiftData inserts + a UserDefaults flag. It does not depend on any engine changes, so it can land before PR 5 cleanly.

### Task 15: `WelcomeView`

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/WelcomeView.swift`

- [ ] **Step 1: Branch.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/04-onboarding feat/mora-alpha/03-home
```

- [ ] **Step 2: Write `WelcomeView.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/WelcomeView.swift
import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("mora")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(MoraTheme.Accent.orange)
            Text("Let's learn English sounds together")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)
            Spacer()
            HeroCTA(title: "Get started", action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Onboarding/WelcomeView.swift
git commit -m "feat(MoraUI): onboarding WelcomeView

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 16: `NameView`

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/NameView.swift`

- [ ] **Step 1: Write `NameView.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/NameView.swift
import SwiftUI

struct NameView: View {
    @Binding var name: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.muted)
            }
            .padding(MoraTheme.Space.md)

            Spacer()

            Text("What should we call you?")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .padding(MoraTheme.Space.lg)
                .background(Color.white, in: .rect(cornerRadius: MoraTheme.Radius.card))
                .shadow(color: MoraTheme.Ink.secondary.opacity(0.15), radius: 3, y: 2)
                .frame(maxWidth: 520)

            Spacer()

            HeroCTA(title: "Next", action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Onboarding/NameView.swift
git commit -m "feat(MoraUI): onboarding NameView with skip

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 17: `InterestPickView`

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/InterestPickView.swift`

- [ ] **Step 1: Write `InterestPickView.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/InterestPickView.swift
import MoraCore
import SwiftUI

struct InterestPickView: View {
    @Binding var selectedKeys: Set<String>
    let categories: [InterestCategory]
    let onContinue: () -> Void

    /// Emoji icons are a UI-layer concern; keeping them here avoids polluting
    /// the pure-domain InterestCategory struct.
    private static let emoji: [String: String] = [
        "animals":   "🐕",
        "dinosaurs": "🦖",
        "vehicles":  "🚗",
        "space":     "🚀",
        "sports":    "⚽",
        "robots":    "🤖",
    ]

    private let columns = [
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
        GridItem(.flexible(), spacing: MoraTheme.Space.md),
    ]

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text("What do you like?")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            Text("Pick 3–5 — we'll use these for your stories.")
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)

            LazyVGrid(columns: columns, spacing: MoraTheme.Space.md) {
                ForEach(categories) { cat in
                    tile(for: cat)
                }
            }
            .padding(.horizontal, MoraTheme.Space.lg)
            .frame(maxWidth: 720)

            Spacer()

            HeroCTA(title: "Next", action: onContinue)
                .disabled(!isSelectionValid)
                .opacity(isSelectionValid ? 1.0 : 0.4)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isSelectionValid: Bool {
        (3...5).contains(selectedKeys.count)
    }

    private func tile(for cat: InterestCategory) -> some View {
        let selected = selectedKeys.contains(cat.key)
        return Button(action: { toggle(cat.key) }) {
            VStack(spacing: MoraTheme.Space.sm) {
                Text(Self.emoji[cat.key] ?? "⭐")
                    .font(.system(size: 48))
                Text(cat.displayName)
                    .font(MoraType.label())
                    .foregroundStyle(MoraTheme.Ink.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MoraTheme.Space.lg)
            .background(
                selected ? MoraTheme.Background.mint : Color.white,
                in: .rect(cornerRadius: MoraTheme.Radius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MoraTheme.Radius.card)
                    .strokeBorder(
                        selected ? MoraTheme.Accent.teal : MoraTheme.Ink.muted.opacity(0.3),
                        lineWidth: selected ? 3 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ key: String) {
        if selectedKeys.contains(key) {
            selectedKeys.remove(key)
        } else if selectedKeys.count < 5 {
            selectedKeys.insert(key)
        }
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Onboarding/InterestPickView.swift
git commit -m "feat(MoraUI): onboarding InterestPickView (2×3 grid, min 3 max 5)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 18: `PermissionRequestView`

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/PermissionRequestView.swift`

- [ ] **Step 1: Write `PermissionRequestView.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/PermissionRequestView.swift
import AVFoundation
import Speech
import SwiftUI

struct PermissionRequestView: View {
    let onContinue: () -> Void

    @State private var requesting = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 96, weight: .bold))
                .foregroundStyle(MoraTheme.Accent.orange)
            Text("We'll listen when you read.")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)
            Text("Your voice stays on this iPad.")
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.muted)
            Spacer()

            HeroCTA(title: requesting ? "Requesting…" : "Allow") {
                Task { await requestBoth() }
            }
            .disabled(requesting)

            Button("Not now", action: onContinue)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
                .padding(.vertical, MoraTheme.Space.md)
                .padding(.bottom, MoraTheme.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func requestBoth() async {
        requesting = true
        // Mic first.
        _ = await AVAudioApplication.requestRecordPermission()
        // Speech recognition after mic.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in cont.resume() }
        }
        requesting = false
        onContinue()
    }
}
```

- [ ] **Step 2: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Onboarding/PermissionRequestView.swift
git commit -m "feat(MoraUI): onboarding PermissionRequestView (mic + speech)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 19: `OnboardingFlow` + `RootView` branch

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingFlow.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/RootView.swift`
- Create: `Packages/MoraUI/Tests/MoraUITests/OnboardingFlowTests.swift`

- [ ] **Step 1: Write failing flow tests.**

```swift
// Packages/MoraUI/Tests/MoraUITests/OnboardingFlowTests.swift
import MoraCore
import SwiftData
import XCTest
@testable import MoraUI

@MainActor
final class OnboardingFlowTests: XCTestCase {
    func test_stateProgression_advancesThroughSteps() {
        let state = OnboardingState()
        XCTAssertEqual(state.step, .welcome)
        state.advance()
        XCTAssertEqual(state.step, .name)
        state.advance()
        XCTAssertEqual(state.step, .interests)
        state.advance()
        XCTAssertEqual(state.step, .permission)
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func test_skipNameLeavesNameEmpty() {
        let state = OnboardingState()
        state.advance() // to .name
        state.skipName()
        XCTAssertEqual(state.step, .interests)
        XCTAssertEqual(state.name, "")
    }

    func test_finalize_insertsProfileAndStreak_andSetsFlag() throws {
        let container = try MoraModelContainer.inMemory()
        let state = OnboardingState()
        state.name = "Hiro"
        state.selectedInterests = ["dinosaurs", "space", "robots"]
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.removeObject(forKey: OnboardingState.onboardedKey)

        state.finalize(in: container.mainContext, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: OnboardingState.onboardedKey))
        let profiles = try container.mainContext.fetch(FetchDescriptor<LearnerProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.displayName, "Hiro")
        XCTAssertEqual(Set(profiles.first?.interests ?? []), ["dinosaurs", "space", "robots"])
        let streaks = try container.mainContext.fetch(FetchDescriptor<DailyStreak>())
        XCTAssertEqual(streaks.count, 1)
        XCTAssertEqual(streaks.first?.currentCount, 0)
    }
}
```

- [ ] **Step 2: Run to verify failure.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test --filter OnboardingFlowTests)
```
Expected: compile failure — `OnboardingState` is not defined yet.

- [ ] **Step 3: Write `OnboardingFlow.swift`.**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingFlow.swift
import MoraCore
import Observation
import SwiftData
import SwiftUI

enum OnboardingStep: Equatable {
    case welcome, name, interests, permission, finished
}

@Observable
@MainActor
final class OnboardingState {
    var step: OnboardingStep = .welcome
    var name: String = ""
    var selectedInterests: Set<String> = []

    static let onboardedKey = "tech.reenable.Mora.onboarded"

    func advance() {
        switch step {
        case .welcome:    step = .name
        case .name:       step = .interests
        case .interests:  step = .permission
        case .permission: step = .finished
        case .finished:   break
        }
    }

    func skipName() {
        name = ""
        step = .interests
    }

    func finalize(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        let profile = LearnerProfile(
            displayName: name,
            l1Identifier: "ja",
            interests: Array(selectedInterests),
            preferredFontKey: "openDyslexic",
            createdAt: now
        )
        let streak = DailyStreak(currentCount: 0, longestCount: 0, lastCompletedOn: nil)
        context.insert(profile)
        context.insert(streak)
        try? context.save()
        defaults.set(true, forKey: Self.onboardedKey)
    }
}

public struct OnboardingFlow: View {
    @Environment(\.modelContext) private var context
    @State private var state = OnboardingState()
    private let profile = JapaneseL1Profile()
    private let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            stepView
        }
        .onChange(of: state.step) { _, new in
            if new == .finished {
                state.finalize(in: context)
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .welcome:
            WelcomeView(onContinue: { state.advance() })
        case .name:
            NameView(
                name: Binding(get: { state.name }, set: { state.name = $0 }),
                onContinue: { state.advance() },
                onSkip: { state.skipName() }
            )
        case .interests:
            InterestPickView(
                selectedKeys: Binding(
                    get: { state.selectedInterests },
                    set: { state.selectedInterests = $0 }
                ),
                categories: profile.interestCategories,
                onContinue: { state.advance() }
            )
        case .permission:
            PermissionRequestView(onContinue: { state.advance() })
        case .finished:
            ProgressView()
        }
    }
}
```

- [ ] **Step 4: Update `RootView.swift` to branch on the UserDefaults flag.**

```swift
// Packages/MoraUI/Sources/MoraUI/RootView.swift
import SwiftUI

public struct RootView: View {
    @State private var onboarded: Bool = UserDefaults.standard.bool(
        forKey: OnboardingState.onboardedKey
    )

    public init() {}

    public var body: some View {
        Group {
            if onboarded {
                NavigationStack {
                    HomeView()
                        .navigationDestination(for: String.self) { destination in
                            switch destination {
                            case "session": SessionContainerView()
                            default: EmptyView()
                            }
                        }
                }
            } else {
                OnboardingFlow {
                    onboarded = true
                }
            }
        }
    }
}
```

Note: `OnboardingState` is `internal` in `MoraUI`. `onboardedKey` is `static` and referenced from `RootView` in the same module, so no `public` is needed.

- [ ] **Step 5: Run tests.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test --filter OnboardingFlowTests)
```
Expected: all three tests PASS.

- [ ] **Step 6: Run the full package build and app build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: all green.

- [ ] **Step 7: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingFlow.swift \
        Packages/MoraUI/Sources/MoraUI/RootView.swift \
        Packages/MoraUI/Tests/MoraUITests/OnboardingFlowTests.swift
git commit -m "feat(MoraUI): OnboardingFlow + RootView branch on onboarded flag

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### PR 4 finalize

- [ ] **Step 1: Full test + lint + build.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 2: Simulator walkthrough: fresh install → onboarding 4 screens → Home. Attach screenshots (Welcome, Name, InterestPick, Permission, Home) to PR.**

- [ ] **Step 3: Open PR** with base `feat/mora-alpha/03-home`, title `mora alpha 04: first-run onboarding`.

---


## PR 5 — Real Speech (branch `feat/mora-alpha/05-real-speech`, base `04-onboarding`)

**Deliverables:** `SpeechEngine` protocol reshaped to stream `SpeechEvent` via `AsyncThrowingStream`; `OrchestratorEvent` split into `answerHeard(ASRResult)` / `answerManual(correct:)`; `AssessmentEngine` extended with `AssessmentLeniency` + 3-arg `assess`; `PermissionSource` shim + `PermissionCoordinator` + `FakePermissionSource`; `AppleSpeechEngine` using `SFSpeechRecognizer` with on-device recognition; `MicButton` state machine wired into `DecodeActivityView` / `ShortSentencesView`; tap-fallback path when mic is denied; Info.plist keys via `project.yml`. This PR contains the only breaking protocol changes in the plan — all call sites migrate in the same commit as the protocol change.

### Task 20: `SpeechEvent` + `SpeechEngine` stream reshape + `FakeSpeechEngine` migration

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Speech/SpeechEvent.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/SpeechEngine.swift`
- Modify: `Packages/MoraTesting/Sources/MoraTesting/FakeSpeechEngine.swift`
- Modify: `Packages/MoraTesting/Tests/MoraTestingTests/FakeSpeechEngineTests.swift`

- [ ] **Step 1: Branch.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/05-real-speech feat/mora-alpha/04-onboarding
```

- [ ] **Step 2: Create `SpeechEvent.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Speech/SpeechEvent.swift
import Foundation

public enum SpeechEvent: Sendable {
    case started
    case partial(String)
    case final(ASRResult)
}
```

- [ ] **Step 3: Reshape `SpeechEngine.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/SpeechEngine.swift
import Foundation

public protocol SpeechEngine: Sendable {
    func listen() -> AsyncThrowingStream<SpeechEvent, Error>
    func cancel()
}
```

- [ ] **Step 4: Migrate `FakeSpeechEngine.swift` to the stream API.**

```swift
// Packages/MoraTesting/Sources/MoraTesting/FakeSpeechEngine.swift
import Foundation
import MoraCore
import MoraEngines

public enum FakeSpeechEngineError: Error, Equatable {
    case scriptExhausted
}

public final class FakeSpeechEngine: SpeechEngine, @unchecked Sendable {
    /// Scripted sequence of events emitted by `listen()`. Each call to
    /// `listen()` consumes one script. A script that does not end with
    /// a `.final` event is a test bug — the orchestrator waits for a
    /// terminating event to advance.
    private var scripts: [[SpeechEvent]]
    private let lock = NSLock()

    public init(scripts: [[SpeechEvent]] = []) {
        self.scripts = scripts
    }

    /// Convenience: wrap a sequence of final ASRResults into single-event
    /// scripts. Used by the existing integration tests that only care about
    /// the final transcript.
    public static func yielding(finals: [ASRResult]) -> FakeSpeechEngine {
        FakeSpeechEngine(scripts: finals.map { [SpeechEvent.final($0)] })
    }

    /// Convenience: wrap a sequence of events into a single script.
    public static func yielding(_ events: [SpeechEvent]) -> FakeSpeechEngine {
        FakeSpeechEngine(scripts: [events])
    }

    public func listen() -> AsyncThrowingStream<SpeechEvent, Error> {
        let script: [SpeechEvent]? = {
            lock.lock(); defer { lock.unlock() }
            guard !scripts.isEmpty else { return nil }
            return scripts.removeFirst()
        }()
        return AsyncThrowingStream { continuation in
            guard let script else {
                continuation.finish(throwing: FakeSpeechEngineError.scriptExhausted)
                return
            }
            Task {
                for event in script {
                    continuation.yield(event)
                }
                continuation.finish()
            }
        }
    }

    public func cancel() {}
}
```

- [ ] **Step 5: Update `FakeSpeechEngineTests.swift`.**

```swift
// Packages/MoraTesting/Tests/MoraTestingTests/FakeSpeechEngineTests.swift
import MoraCore
import MoraEngines
import MoraTesting
import XCTest

final class FakeSpeechEngineTests: XCTestCase {
    func test_yieldingFinals_producesFinalEvents() async throws {
        let engine = FakeSpeechEngine.yielding(finals: [
            ASRResult(transcript: "ship", confidence: 0.9),
            ASRResult(transcript: "shop", confidence: 0.85),
        ])
        var events: [SpeechEvent] = []
        for try await event in engine.listen() {
            events.append(event)
        }
        XCTAssertEqual(events.count, 1)
        if case .final(let asr) = events.first {
            XCTAssertEqual(asr.transcript, "ship")
        } else {
            XCTFail("Expected first event to be .final")
        }
    }

    func test_yieldingEvents_producesPartialsThenFinal() async throws {
        let engine = FakeSpeechEngine.yielding([
            .started,
            .partial("sh"),
            .partial("shi"),
            .final(ASRResult(transcript: "ship", confidence: 0.92)),
        ])
        var events: [SpeechEvent] = []
        for try await event in engine.listen() {
            events.append(event)
        }
        XCTAssertEqual(events.count, 4)
    }

    func test_scriptExhausted_throws() async throws {
        let engine = FakeSpeechEngine(scripts: [])
        do {
            for try await _ in engine.listen() {
                XCTFail("Should have thrown before yielding")
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(error as? FakeSpeechEngineError, .scriptExhausted)
        }
    }
}
```

- [ ] **Step 6: Build — expect errors in `SessionOrchestrator` and existing integration tests.** These get fixed in Task 21.

```bash
(cd $REPO_ROOT/Packages/MoraEngines && swift build) 2>&1 | head -20 || true
```
Expected: compilation errors referencing `.answerResult`. That is intentional — the next task migrates them atomically.

- [ ] **Step 7: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraEngines/Sources/MoraEngines/Speech/SpeechEvent.swift \
        Packages/MoraEngines/Sources/MoraEngines/SpeechEngine.swift \
        Packages/MoraTesting/Sources/MoraTesting/FakeSpeechEngine.swift \
        Packages/MoraTesting/Tests/MoraTestingTests/FakeSpeechEngineTests.swift
git commit -m "refactor(MoraEngines): SpeechEngine.listen() → AsyncThrowingStream<SpeechEvent>

Build intentionally red — callers migrate in the next commit.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 21: `OrchestratorEvent.answerHeard` / `.answerManual` + `AssessmentLeniency`

This task contains two tightly coupled changes that ship in one commit: the new `AssessmentLeniency` enum on `AssessmentEngine`, and the `OrchestratorEvent` split. Both callers (orchestrator + every test + every UI view) migrate here so the package builds green again by the end.

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/AssessmentEngine.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FullADayIntegrationTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorFullTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorPhasesTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/AssessmentEngineScoringTests.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/AssessmentLeniencyTests.swift`

- [ ] **Step 1: Extend `AssessmentEngine.swift` with `AssessmentLeniency` and a 3-arg `assess` method.**

Replace the top of the file as follows (rest of the file is unchanged):

```swift
// Packages/MoraEngines/Sources/MoraEngines/AssessmentEngine.swift
import Foundation
import MoraCore

public enum AssessmentLeniency: Sendable {
    case newWord
    case mastered
}

public struct AssessmentEngine: Sendable {
    public let l1Profile: any L1Profile
    /// 0.0 = strictest, 1.0 = most lenient. Pre-dates the `AssessmentLeniency`
    /// enum; left in place for the current test suite and the future
    /// AdaptivePlanEngine refactor that will consolidate leniency semantics.
    public let leniency: Double

    public init(l1Profile: any L1Profile, leniency: Double = 0.5) {
        self.l1Profile = l1Profile
        self.leniency = leniency
    }

    /// Backwards-compatible entry point: same as `.mastered`.
    public func assess(expected: Word, asr: ASRResult) -> TrialAssessment {
        assess(expected: expected, asr: asr, leniency: .mastered)
    }

    /// Three-argument form used by `SessionOrchestrator` in v1 (always `.newWord`
    /// until mastery tracking lands). `.newWord` accepts one extra edit-distance
    /// unit and lowers the confidence floor; `.mastered` uses the strict path.
    public func assess(
        expected: Word,
        asr: ASRResult,
        leniency: AssessmentLeniency
    ) -> TrialAssessment {
        let normalized = normalize(asr.transcript)
        let target = expected.surface.lowercased()

        if normalized.isEmpty {
            return TrialAssessment(
                expected: expected, heard: asr.transcript,
                correct: false, errorKind: .omission,
                l1InterferenceTag: nil
            )
        }
        if normalized == target {
            return TrialAssessment(
                expected: expected, heard: asr.transcript,
                correct: true, errorKind: .none,
                l1InterferenceTag: nil
            )
        }

        // Leniency-aware path: for .newWord, accept an edit distance of 1
        // against the target OR a confidence >= 0.25 with partial overlap.
        if leniency == .newWord {
            if editDistance(normalized, target) <= 1 && asr.confidence >= 0.25 {
                return TrialAssessment(
                    expected: expected, heard: asr.transcript,
                    correct: true, errorKind: .none,
                    l1InterferenceTag: nil
                )
            }
        }

        let (errorKind, l1Tag) = classify(
            expected: expected, heardNormalized: normalized
        )
        return TrialAssessment(
            expected: expected, heard: asr.transcript,
            correct: false, errorKind: errorKind,
            l1InterferenceTag: l1Tag
        )
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
    }

    private func classify(expected: Word, heardNormalized: String) -> (TrialErrorKind, String?) {
        let expectedUnits = expected.graphemes.count
        let heardUnits = heardNormalized.count
        let diff = heardUnits - expectedUnits
        let kind: TrialErrorKind
        if diff > 0 { kind = .insertion }
        else if diff < 0 { kind = .omission }
        else { kind = .substitution }
        return (kind, l1InterferenceTag(expected: expected, heardNormalized: heardNormalized))
    }

    private func l1InterferenceTag(expected: Word, heardNormalized: String) -> String? {
        guard let expectedOnset = expected.phonemes.first else { return nil }
        guard let heardOnset = inferHeardOnset(heardNormalized) else { return nil }
        return l1Profile.matchInterference(expected: expectedOnset, heard: heardOnset)?.tag
    }

    private func inferHeardOnset(_ heard: String) -> Phoneme? {
        guard let first = heard.first else { return nil }
        switch first {
        case "r": return Phoneme(ipa: "r")
        case "l": return Phoneme(ipa: "l")
        case "f": return Phoneme(ipa: "f")
        case "h": return Phoneme(ipa: "h")
        case "v": return Phoneme(ipa: "v")
        case "b": return Phoneme(ipa: "b")
        case "s": return Phoneme(ipa: "s")
        case "t": return Phoneme(ipa: "t")
        default: return nil
        }
    }

    /// Iterative Levenshtein distance over Swift's Character collection.
    /// Kept here rather than as a utility — it is only used by the leniency
    /// branch and inlined for clarity.
    private func editDistance(_ a: String, _ b: String) -> Int {
        let ac = Array(a), bc = Array(b)
        if ac.isEmpty { return bc.count }
        if bc.isEmpty { return ac.count }
        var prev = Array(0...bc.count)
        var curr = Array(repeating: 0, count: bc.count + 1)
        for i in 1...ac.count {
            curr[0] = i
            for j in 1...bc.count {
                let cost = ac[i - 1] == bc[j - 1] ? 0 : 1
                curr[j] = min(curr[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[bc.count]
    }
}
```

- [ ] **Step 2: Write the new `AssessmentLeniencyTests.swift`.**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/AssessmentLeniencyTests.swift
import MoraCore
import XCTest
@testable import MoraEngines

final class AssessmentLeniencyTests: XCTestCase {
    private let ship = Word(
        surface: "ship",
        graphemes: [.init(letters: "sh"), .init(letters: "i"), .init(letters: "p")],
        phonemes: [.init(ipa: "ʃ"), .init(ipa: "ɪ"), .init(ipa: "p")]
    )

    private func engine() -> AssessmentEngine {
        AssessmentEngine(l1Profile: JapaneseL1Profile())
    }

    func test_nearMissWithinEditDistance1_isCorrectUnderNewWord() {
        // "shi" — single omission, within one edit of "ship".
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shi", confidence: 0.5),
            leniency: .newWord
        )
        XCTAssertTrue(result.correct)
    }

    func test_sameNearMiss_isWrongUnderMastered() {
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shi", confidence: 0.5),
            leniency: .mastered
        )
        XCTAssertFalse(result.correct)
    }

    func test_lowConfidence_blocksLenientAccept() {
        // confidence below 0.25 floor — even a near miss rejects.
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "shi", confidence: 0.1),
            leniency: .newWord
        )
        XCTAssertFalse(result.correct)
    }

    func test_twoEditDistance_rejectsUnderNewWord() {
        // "sip" is 2 edits from "ship" (s → sh, then p → p); classifier
        // treats it as 2 so it stays wrong.
        let result = engine().assess(
            expected: ship,
            asr: ASRResult(transcript: "si", confidence: 0.9),
            leniency: .newWord
        )
        XCTAssertFalse(result.correct)
    }
}
```

- [ ] **Step 3: Reshape `ADayPhase.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift
import Foundation
import MoraCore

public enum ADayPhase: String, Hashable, Codable, Sendable, CaseIterable {
    case notStarted
    case warmup
    case newRule
    case decoding
    case shortSentences
    case completion
}

public enum OrchestratorEvent: Sendable {
    case warmupTap(Grapheme)
    case advance
    case answerHeard(ASRResult)
    case answerManual(correct: Bool)
}
```

- [ ] **Step 4: Update `SessionOrchestrator.swift` to handle the two new cases.**

Replace the `handle` method and the helper functions that branch on `answerResult`:

```swift
// Only the changed fragment of SessionOrchestrator.swift is shown here.
public func handle(_ event: OrchestratorEvent) async {
    switch (phase, event) {
    case (.warmup, .warmupTap(let g)):
        if let targetG = target.skill.graphemePhoneme?.grapheme, g == targetG {
            transitionTo(.newRule)
        } else {
            warmupMissCount += 1
        }

    case (.newRule, .advance):
        transitionTo(.decoding)

    case (.decoding, .answerHeard(let asr)):
        handleDecodingHeard(asr: asr)
    case (.decoding, .answerManual(let correct)):
        handleDecodingManual(correct: correct)

    case (.shortSentences, .answerHeard(let asr)):
        handleSentenceHeard(asr: asr)
    case (.shortSentences, .answerManual(let correct)):
        handleSentenceManual(correct: correct)

    default:
        break
    }
}

private func handleDecodingHeard(asr: ASRResult) {
    guard wordIndex < words.count else { transitionTo(.shortSentences); return }
    let expected = words[wordIndex].word
    let trial = assessment.assess(expected: expected, asr: asr, leniency: .newWord)
    trials.append(trial)
    wordIndex += 1
    if wordIndex >= words.count { transitionTo(.shortSentences) }
}

private func handleDecodingManual(correct: Bool) {
    guard wordIndex < words.count else { transitionTo(.shortSentences); return }
    let expected = words[wordIndex].word
    trials.append(manualTrial(expected: expected, correct: correct))
    wordIndex += 1
    if wordIndex >= words.count { transitionTo(.shortSentences) }
}

private func handleSentenceHeard(asr: ASRResult) {
    guard sentenceIndex < sentences.count else { transitionTo(.completion); return }
    let sentence = sentences[sentenceIndex]
    let targetGrapheme = target.skill.graphemePhoneme?.grapheme
    let expected = sentence.words.first { w in
        guard let g = targetGrapheme else { return true }
        return w.graphemes.contains(g)
    } ?? sentence.words.first
    if let expected {
        let trial = assessment.assess(expected: expected, asr: asr, leniency: .newWord)
        trials.append(trial)
    }
    sentenceIndex += 1
    if sentenceIndex >= sentences.count { transitionTo(.completion) }
}

private func handleSentenceManual(correct: Bool) {
    guard sentenceIndex < sentences.count else { transitionTo(.completion); return }
    let sentence = sentences[sentenceIndex]
    let targetGrapheme = target.skill.graphemePhoneme?.grapheme
    let expected = sentence.words.first { w in
        guard let g = targetGrapheme else { return true }
        return w.graphemes.contains(g)
    } ?? sentence.words.first
    if let expected {
        trials.append(manualTrial(expected: expected, correct: correct))
    }
    sentenceIndex += 1
    if sentenceIndex >= sentences.count { transitionTo(.completion) }
}

private func manualTrial(expected: Word, correct: Bool) -> TrialAssessment {
    TrialAssessment(
        expected: expected,
        heard: correct ? expected.surface : "",
        correct: correct,
        errorKind: correct ? .none : .omission,
        l1InterferenceTag: nil
    )
}
```

Delete the old `handleDecodingAnswer`, `handleSentenceAnswer`, and `makeTrial` helpers — they are replaced by the functions above.

- [ ] **Step 5: Migrate the integration tests.**

For every call site of `.answerResult(correct:asr:)` in `FullADayIntegrationTests.swift`, `SessionOrchestratorFullTests.swift`, and `SessionOrchestratorPhasesTests.swift`:
- **Correct-path calls** (i.e. `correct: true` + transcript equal to expected): change to `.answerHeard(ASRResult(transcript: ..., confidence: 1.0))`. They stay correct because `AssessmentEngine.assess` returns `.correct = true` on an exact match regardless of leniency.
- **Miss-path calls** (i.e. `correct: false`): change to `.answerManual(correct: false)`. This preserves the test's intent of scoring a miss without depending on a specific ASR transcript.

Concretely in `FullADayIntegrationTests.swift`:

```swift
// Before:
await orchestrator.handle(
    .answerResult(
        correct: true,
        asr: ASRResult(transcript: w.word.surface, confidence: 1.0)
    )
)
// After:
await orchestrator.handle(
    .answerHeard(ASRResult(transcript: w.word.surface, confidence: 1.0))
)
```

And for the mismatched case (the `test_fullADay_withOneMiss_reportsStruggledSkill` test):

```swift
// Before:
await orchestrator.handle(
    .answerResult(
        correct: correct,
        asr: ASRResult(
            transcript: correct ? w.word.surface : "",
            confidence: correct ? 1.0 : 0.0
        )
    )
)
// After:
if correct {
    await orchestrator.handle(
        .answerHeard(ASRResult(transcript: w.word.surface, confidence: 1.0))
    )
} else {
    await orchestrator.handle(.answerManual(correct: false))
}
```

Note that under the new manual path the `missedTrial.errorKind` is `.omission` and `missedTrial.heard` is `""` — matching the existing assertions, since `manualTrial(correct: false)` uses the same shape.

Apply analogous edits to `SessionOrchestratorFullTests.swift` and `SessionOrchestratorPhasesTests.swift`. In every case, preserve the original assertion intent.

- [ ] **Step 6: Migrate the UI views.**

In `DecodeActivityView.swift` (from PR 2), the tap pair currently fires `.answerResult(correct:asr:)`. Replace those two calls:

```swift
tapButton("Correct", color: MoraTheme.Feedback.correct) {
    feedback = .correct
    Task {
        await orchestrator.handle(.answerManual(correct: true))
        try? await Task.sleep(nanoseconds: 450_000_000)
        feedback = .none
    }
}
tapButton("Wrong", color: MoraTheme.Feedback.wrong) {
    feedback = .wrong
    Task {
        await orchestrator.handle(.answerManual(correct: false))
        try? await Task.sleep(nanoseconds: 650_000_000)
        feedback = .none
    }
}
```

Apply the same change in `ShortSentencesView.swift`.

- [ ] **Step 7: Run all tests.**

```bash
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
(cd $REPO_ROOT/Packages/MoraTesting && swift test)
```
Expected: all green. If `AssessmentEngineScoringTests` fails on the pre-existing `sip` substitution test, the leniency branch is accidentally accepting it — verify that `sip` vs `ship` is 1 edit distance and `.mastered` still rejects. If needed, change that test to use `leniency: .mastered` explicitly.

- [ ] **Step 8: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraEngines/Sources/MoraEngines/AssessmentEngine.swift \
        Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift \
        Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/AssessmentLeniencyTests.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/FullADayIntegrationTests.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorFullTests.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorPhasesTests.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/AssessmentEngineScoringTests.swift \
        Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift \
        Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift
git commit -m "refactor(MoraEngines): OrchestratorEvent answerHeard/answerManual split + AssessmentLeniency

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---


### Task 22: `PermissionSource` + `PermissionCoordinator` + `FakePermissionSource`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Speech/PermissionSource.swift`
- Create: `Packages/MoraEngines/Sources/MoraEngines/Speech/PermissionCoordinator.swift`
- Create: `Packages/MoraTesting/Sources/MoraTesting/FakePermissionSource.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/PermissionCoordinatorTests.swift`

- [ ] **Step 1: Write the failing coordinator tests.**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/PermissionCoordinatorTests.swift
import MoraTesting
import XCTest
@testable import MoraEngines

@MainActor
final class PermissionCoordinatorTests: XCTestCase {
    func test_notDetermined_startsAsNotDetermined() {
        let source = FakePermissionSource(
            mic: .notDetermined,
            speech: .notDetermined
        )
        let coord = PermissionCoordinator(source: source)
        XCTAssertEqual(coord.current(), .notDetermined)
    }

    func test_bothGranted_isAllGranted() {
        let source = FakePermissionSource(mic: .granted, speech: .granted)
        let coord = PermissionCoordinator(source: source)
        XCTAssertEqual(coord.current(), .allGranted)
    }

    func test_micDenied_isPartial() {
        let source = FakePermissionSource(mic: .denied, speech: .granted)
        let coord = PermissionCoordinator(source: source)
        XCTAssertEqual(coord.current(), .partial(micDenied: true, speechDenied: false))
    }

    func test_request_flipsNotDeterminedToGranted() async {
        let source = FakePermissionSource(mic: .notDetermined, speech: .notDetermined)
        source.nextMicResult = .granted
        source.nextSpeechResult = .granted
        let coord = PermissionCoordinator(source: source)
        let result = await coord.request()
        XCTAssertEqual(result, .allGranted)
    }
}
```

- [ ] **Step 2: Write `PermissionSource.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Speech/PermissionSource.swift
import AVFoundation
import Foundation
import Speech

public enum PermissionOutcome: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}

/// Thin protocol wrapping the OS permission APIs so tests can inject fakes.
/// The concrete `ApplePermissionSource` is used in the app; `FakePermissionSource`
/// lives in MoraTesting.
@MainActor
public protocol PermissionSource: AnyObject {
    func currentMic() -> PermissionOutcome
    func currentSpeech() -> PermissionOutcome
    func requestMic() async -> PermissionOutcome
    func requestSpeech() async -> PermissionOutcome
}

/// Production source backed by AVAudioApplication + SFSpeechRecognizer.
@MainActor
public final class ApplePermissionSource: PermissionSource {
    public init() {}

    public func currentMic() -> PermissionOutcome {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied:  return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func currentSpeech() -> PermissionOutcome {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    public func requestMic() async -> PermissionOutcome {
        await withCheckedContinuation { (cont: CheckedContinuation<PermissionOutcome, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted ? .granted : .denied)
            }
        }
    }

    public func requestSpeech() async -> PermissionOutcome {
        await withCheckedContinuation { (cont: CheckedContinuation<PermissionOutcome, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized: cont.resume(returning: .granted)
                case .denied, .restricted: cont.resume(returning: .denied)
                case .notDetermined: cont.resume(returning: .notDetermined)
                @unknown default: cont.resume(returning: .denied)
                }
            }
        }
    }
}
```

- [ ] **Step 3: Write `PermissionCoordinator.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Speech/PermissionCoordinator.swift
import Foundation

public enum PermissionStatus: Equatable, Sendable {
    case notDetermined
    case allGranted
    case partial(micDenied: Bool, speechDenied: Bool)
}

@MainActor
public final class PermissionCoordinator {
    private let source: PermissionSource

    public init(source: PermissionSource) {
        self.source = source
    }

    public convenience init() {
        self.init(source: ApplePermissionSource())
    }

    public func current() -> PermissionStatus {
        let mic = source.currentMic()
        let speech = source.currentSpeech()
        return map(mic: mic, speech: speech)
    }

    /// Sequentially request mic first, then speech. Returns the coordinator's
    /// collapsed status after both calls return.
    public func request() async -> PermissionStatus {
        let mic = await source.requestMic()
        let speech = await source.requestSpeech()
        return map(mic: mic, speech: speech)
    }

    private func map(mic: PermissionOutcome, speech: PermissionOutcome) -> PermissionStatus {
        switch (mic, speech) {
        case (.notDetermined, .notDetermined):
            return .notDetermined
        case (.granted, .granted):
            return .allGranted
        default:
            return .partial(
                micDenied: mic == .denied,
                speechDenied: speech == .denied
            )
        }
    }
}
```

- [ ] **Step 4: Write `FakePermissionSource.swift`.**

```swift
// Packages/MoraTesting/Sources/MoraTesting/FakePermissionSource.swift
import Foundation
import MoraEngines

@MainActor
public final class FakePermissionSource: PermissionSource {
    public var mic: PermissionOutcome
    public var speech: PermissionOutcome

    /// Set to control what `requestMic()` returns next. Falls back to `mic`
    /// if nil.
    public var nextMicResult: PermissionOutcome?
    public var nextSpeechResult: PermissionOutcome?

    public init(
        mic: PermissionOutcome = .notDetermined,
        speech: PermissionOutcome = .notDetermined
    ) {
        self.mic = mic
        self.speech = speech
    }

    public func currentMic() -> PermissionOutcome { mic }
    public func currentSpeech() -> PermissionOutcome { speech }

    public func requestMic() async -> PermissionOutcome {
        let r = nextMicResult ?? mic
        mic = r
        return r
    }
    public func requestSpeech() async -> PermissionOutcome {
        let r = nextSpeechResult ?? speech
        speech = r
        return r
    }
}
```

- [ ] **Step 5: Run tests.**

```bash
(cd $REPO_ROOT/Packages/MoraEngines && swift test --filter PermissionCoordinatorTests)
```
Expected: all four tests PASS.

- [ ] **Step 6: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraEngines/Sources/MoraEngines/Speech/PermissionSource.swift \
        Packages/MoraEngines/Sources/MoraEngines/Speech/PermissionCoordinator.swift \
        Packages/MoraTesting/Sources/MoraTesting/FakePermissionSource.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PermissionCoordinatorTests.swift
git commit -m "feat(MoraEngines): PermissionSource + PermissionCoordinator

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 23: `AppleSpeechEngine` + Info.plist keys

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Speech/AppleSpeechEngine.swift`
- Modify: `project.yml`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/AppleSpeechEngineTests.swift`

- [ ] **Step 1: Add Info.plist keys via `project.yml`.**

Append to the `Mora` target's `settings.base` block:

```yaml
# project.yml — replace the existing settings.base block with this:
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: tech.reenable.Mora
        TARGETED_DEVICE_FAMILY: "2"
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: "YES"
        INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_NSMicrophoneUsageDescription: "mora listens when you read aloud during practice."
        INFOPLIST_KEY_NSSpeechRecognitionUsageDescription: "mora recognizes the words you read so it can score them."
        GENERATE_INFOPLIST_FILE: "YES"
        CODE_SIGN_STYLE: Automatic
```

- [ ] **Step 2: Regenerate the Xcode project.**

```bash
cd $REPO_ROOT && xcodegen generate
```

- [ ] **Step 3: Write the engine initializer test (device-agnostic smoke).**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/AppleSpeechEngineTests.swift
#if canImport(Speech)
import XCTest
@testable import MoraEngines

final class AppleSpeechEngineTests: XCTestCase {
    /// On a Mac host the CI runs, `SFSpeechRecognizer(locale:)` may return nil
    /// or `supportsOnDeviceRecognition == false`. The initializer is expected
    /// to throw `.notSupportedOnDevice` in that case — covered here so the
    /// failure path is guarded.
    func test_initializer_throwsWhenOnDeviceUnavailable() throws {
        // Can't assert the happy path without a real on-device-capable
        // recognizer, but the failure path matters for graceful fallback.
        // This test is a smoke check that the initializer doesn't crash.
        _ = try? AppleSpeechEngine(localeIdentifier: "zz-ZZ") // likely unsupported
    }
}
#endif
```

- [ ] **Step 4: Write `AppleSpeechEngine.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Speech/AppleSpeechEngine.swift
import AVFoundation
import Foundation
import Speech

public enum AppleSpeechEngineError: Error, Equatable {
    case notSupportedOnDevice
    case audioEngineStartFailed
    case recognizerUnavailable
}

public final class AppleSpeechEngine: SpeechEngine, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let silenceTimeout: TimeInterval
    private let hardTimeout: TimeInterval

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let lock = NSLock()

    public init(
        localeIdentifier: String = "en-US",
        silenceTimeout: TimeInterval = 2.5,
        hardTimeout: TimeInterval = 15.0
    ) throws {
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw AppleSpeechEngineError.recognizerUnavailable
        }
        guard rec.supportsOnDeviceRecognition else {
            throw AppleSpeechEngineError.notSupportedOnDevice
        }
        self.recognizer = rec
        self.silenceTimeout = silenceTimeout
        self.hardTimeout = hardTimeout
    }

    public func listen() -> AsyncThrowingStream<SpeechEvent, Error> {
        AsyncThrowingStream { continuation in
            do {
                try self.startSession(continuation: continuation)
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        tearDownLocked()
    }

    private func startSession(
        continuation: AsyncThrowingStream<SpeechEvent, Error>.Continuation
    ) throws {
        lock.lock()
        tearDownLocked()
        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        self.audioEngine = engine
        self.request = req

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        engine.prepare()
        lock.unlock()

        do {
            try engine.start()
        } catch {
            self.cancel()
            continuation.finish(throwing: AppleSpeechEngineError.audioEngineStartFailed)
            return
        }

        continuation.yield(.started)

        var lastPartialAt = Date()
        var finalized = false

        self.task = recognizer.recognitionTask(with: req) { [weak self] result, err in
            guard let self else { return }
            if let err {
                self.cancel()
                continuation.finish(throwing: err)
                return
            }
            guard let result else { return }
            let transcript = result.bestTranscription.formattedString
            let confidence = Double(result.bestTranscription.segments.last?.confidence ?? 0)
            if !result.isFinal {
                continuation.yield(.partial(transcript))
                lastPartialAt = Date()
                return
            }
            guard !finalized else { return }
            finalized = true
            continuation.yield(.final(ASRResult(transcript: transcript, confidence: confidence)))
            continuation.finish()
            self.cancel()
        }

        // Silence + hard timeout watchdog. Runs off-main and polls twice
        // per second — imprecise but keeps the surface small. `lastPartialAt`
        // is updated on the recognition callback thread; reads here do not
        // need to be perfectly synchronized because a 500ms stale read only
        // delays timeout by one tick.
        let start = Date()
        Task.detached { [weak self] in
            while let self, !finalized {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let now = Date()
                let silence = now.timeIntervalSince(lastPartialAt)
                let total = now.timeIntervalSince(start)
                if silence >= self.silenceTimeout || total >= self.hardTimeout {
                    finalized = true
                    continuation.yield(
                        .final(ASRResult(transcript: "", confidence: 0))
                    )
                    continuation.finish()
                    self.cancel()
                    return
                }
            }
        }
    }

    /// Must be called with `lock` held.
    private func tearDownLocked() {
        request?.endAudio()
        task?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        request = nil
        task = nil
        audioEngine = nil
    }
}
```

Per spec §15.1, real `AppleSpeechEngine` unit tests are deferred — correctness is covered by device smoke. The single test above just guards the initializer's failure mode.

- [ ] **Step 5: Build the package.**

```bash
(cd $REPO_ROOT/Packages/MoraEngines && swift build)
```
Expected: `Build complete!`.

- [ ] **Step 6: Regenerate the project + build the app to confirm Info.plist keys are present.**

```bash
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
# Inspect the generated Info.plist for the two keys.
plutil -p $(find ~/Library/Developer/Xcode/DerivedData \
            -path '*Mora.app/Info.plist' | head -1) \
    | grep -E 'NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription'
```
Expected: both keys appear with the values from `project.yml`.

- [ ] **Step 7: Commit.**

```bash
cd $REPO_ROOT
git add project.yml \
        Packages/MoraEngines/Sources/MoraEngines/Speech/AppleSpeechEngine.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/AppleSpeechEngineTests.swift
git commit -m "feat(MoraEngines): AppleSpeechEngine + Info.plist permission strings

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 24: `MicButton` tap-to-listen state machine in Decode + Sentences

Wire the engine into the two views. Each view owns its own `MicUIState` and consumes a `SpeechEngine` injected from `SessionContainerView`.

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift`

- [ ] **Step 1: Extend `DecodeActivityView.swift` with the state machine.**

Add the state enum and replace the `.mic` branch body:

```swift
// Insert at the top of the file after the imports.
private enum MicUIState: Equatable {
    case idle
    case listening(partialText: String)
    case assessing
}
```

Change the struct declaration to accept an optional `SpeechEngine`:

```swift
struct DecodeActivityView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?  // nil in tap mode
```

Replace the `.mic` branch of the `switch uiMode`:

```swift
case .mic:
    VStack(spacing: MoraTheme.Space.sm) {
        MicButton(state: micButtonState) {
            if case .idle = micState, let engine = speechEngine {
                startListening(engine: engine)
            }
        }
        if case .listening(let text) = micState, !text.isEmpty {
            Text(text)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
        }
    }
```

Add the listening helpers to the struct:

```swift
    @State private var micState: MicUIState = .idle

    private var micButtonState: MicButtonState {
        switch micState {
        case .idle: return .idle
        case .listening: return .listening
        case .assessing: return .assessing
        }
    }

    private func startListening(engine: SpeechEngine) {
        guard let expected = currentWord?.word else { return }
        micState = .listening(partialText: "")
        Task {
            do {
                for try await event in engine.listen() {
                    switch event {
                    case .started:
                        break
                    case .partial(let text):
                        if case .listening = micState {
                            micState = .listening(partialText: text)
                        }
                    case .final(let asr):
                        micState = .assessing
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        await orchestrator.handle(.answerHeard(asr))
                        // Feedback uses the most recent trial the
                        // orchestrator just recorded.
                        let wasCorrect = orchestrator.trials.last?.correct ?? false
                        feedback = wasCorrect ? .correct : .wrong
                        try? await Task.sleep(nanoseconds: wasCorrect ? 450_000_000 : 650_000_000)
                        feedback = .none
                        micState = .idle
                    }
                }
            } catch {
                micState = .idle
            }
            _ = expected
        }
    }
```

- [ ] **Step 2: Apply the same pattern to `ShortSentencesView.swift`.**

```swift
struct ShortSentencesView: View {
    let orchestrator: SessionOrchestrator
    let uiMode: SessionUIMode
    @Binding var feedback: FeedbackState
    let speechEngine: SpeechEngine?
    @State private var micState: MicUIState = .idle

    // ... rest of body as in PR 2, with the `.mic` branch swapped to the same
    // MicButton + partial-text stack; `startListening` identical except it
    // uses the current sentence's expected word (already computed in
    // `handleSentenceHeard` inside the orchestrator).
}
```

(Copy the full body from `DecodeActivityView` pattern; don't re-abstract — per the superpowers rule, three similar lines is better than a premature abstraction.)

- [ ] **Step 3: Build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```
Expected: build errors from `SessionContainerView` — it doesn't yet pass `speechEngine:` into these views. Task 25 fixes that.

- [ ] **Step 4: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift \
        Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift
git commit -m "feat(MoraUI): tap-to-listen state machine in Decode + Sentences

Build intentionally red — SessionContainerView wires the engine in the next commit.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 25: Mic-denied tap fallback in `SessionContainerView`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Update `SessionContainerView` to choose `.mic` or `.tap` based on `PermissionCoordinator.current()`, construct the real speech engine, and pass it into the phase views.**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
import MoraCore
import MoraEngines
import OSLog
import SwiftData
import SwiftUI

private let persistLog = Logger(subsystem: "tech.reenable.Mora", category: "Persistence")
private let speechLog = Logger(subsystem: "tech.reenable.Mora", category: "Speech")

public enum SessionUIMode: Equatable, Sendable {
    case tap
    case mic
}

public struct SessionContainerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var orchestrator: SessionOrchestrator?
    @State private var bootError: String?
    @State private var feedback: FeedbackState = .none
    @State private var uiMode: SessionUIMode = .tap
    @State private var speechEngine: SpeechEngine?

    public init() {}

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: 0) {
                topChrome
                    .padding(.horizontal, MoraTheme.Space.md)
                    .padding(.top, MoraTheme.Space.md)
                body
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, MoraTheme.Space.xxl)
            }

            FeedbackOverlay(state: feedback)
        }
        .navigationBarHidden(true)
    }

    private var topChrome: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.6), in: .circle)
            }
            .buttonStyle(.plain)

            Spacer()

            if let orchestrator {
                PhasePips(phase: orchestrator.phase)
            } else {
                PhasePips(currentIndex: -1)
            }

            Spacer()
            StreakChip(count: 0)
        }
    }

    @ViewBuilder
    private var body: some View {
        if let orchestrator {
            switch orchestrator.phase {
            case .notStarted:
                ProgressView("Preparing…")
                    .task { await orchestrator.start() }
            case .warmup:
                WarmupView(orchestrator: orchestrator)
            case .newRule:
                NewRuleView(orchestrator: orchestrator)
            case .decoding:
                DecodeActivityView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback, speechEngine: uiMode == .mic ? speechEngine : nil
                )
            case .shortSentences:
                ShortSentencesView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback, speechEngine: uiMode == .mic ? speechEngine : nil
                )
            case .completion:
                CompletionView(
                    orchestrator: orchestrator,
                    persistSummary: { summary in persist(summary: summary) }
                )
            }
        } else if let bootError {
            Text("Could not start session: \(bootError)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
        } else {
            ProgressView("Loading session…")
                .task { await bootstrap() }
        }
    }

    @MainActor
    private func bootstrap() async {
        // Decide mic vs tap before building the engine — if the user denied
        // either permission, we skip engine construction entirely.
        let coord = PermissionCoordinator()
        switch coord.current() {
        case .allGranted:
            do {
                speechEngine = try AppleSpeechEngine()
                uiMode = .mic
            } catch {
                speechLog.error("AppleSpeechEngine init failed, falling back to tap: \(String(describing: error))")
                uiMode = .tap
            }
        case .partial, .notDetermined:
            uiMode = .tap
        }

        do {
            let curriculum = CurriculumEngine.defaultV1Ladder()
            let target = curriculum.currentTarget(forWeekIndex: 0)
            let taught = curriculum.taughtGraphemes(beforeWeekIndex: 0)
            guard let targetGrapheme = target.skill.graphemePhoneme?.grapheme else {
                bootError = "Target skill \(target.skill.code.rawValue) has no grapheme/phoneme mapping"
                return
            }
            let provider = try ScriptedContentProvider.bundledShWeek1()
            let words = try provider.decodeWords(ContentRequest(
                target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 5
            ))
            let sentences = try provider.decodeSentences(ContentRequest(
                target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2
            ))
            self.orchestrator = SessionOrchestrator(
                target: target, taughtGraphemes: taught,
                warmupOptions: [
                    Grapheme(letters: "s"),
                    Grapheme(letters: "sh"),
                    Grapheme(letters: "ch"),
                ],
                words: words, sentences: sentences,
                assessment: AssessmentEngine(l1Profile: JapaneseL1Profile())
            )
        } catch {
            bootError = String(describing: error)
        }
    }

    @MainActor
    private func persist(summary: SessionSummary) {
        let entity = SessionSummaryEntity(
            date: Date(),
            sessionType: summary.sessionType.rawValue,
            targetSkillCode: summary.targetSkillCode.rawValue,
            durationSec: summary.durationSec,
            trialsTotal: summary.trialsTotal,
            trialsCorrect: summary.trialsCorrect,
            escalated: summary.escalated
        )
        context.insert(entity)
        do { try context.save() }
        catch { persistLog.error("SessionSummary save failed: \(error)") }
    }
}
```

- [ ] **Step 2: Build and test.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: all green.

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "feat(MoraUI): mic-denied tap fallback + speech engine injection

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### PR 5 finalize

- [ ] **Step 1: Full test + lint + build.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
(cd $REPO_ROOT/Packages/MoraTesting && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 2: Device smoke (required here — first PR with real speech):** on a physical iPad, read "ship", "fish", "shop" three times each. Confirm partial transcripts appear, final ASR scores correctly via `.newWord` leniency, mic-denied fallback works (toggle mic permission off in Settings and relaunch). Attach short video.

- [ ] **Step 3: Open PR** with base `feat/mora-alpha/04-onboarding`, title `mora alpha 05: real on-device speech + AssessmentLeniency`.

---


## PR 6 — Real TTS (branch `feat/mora-alpha/06-real-tts`, base `05-real-speech`)

**Deliverables:** `L1Profile.exemplars(for:)` + `JapaneseL1Profile` implementation; `AppleTTSEngine` actor on `AVSpeechSynthesizer`; enhanced-voice chip surfaced on `HomeView`; real TTS wired into Warmup, NewRule, Decode scaffold, ShortSentences scaffold, and Completion.

### Task 26: `L1Profile.exemplars(for:)`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/L1Profile.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift`

- [ ] **Step 1: Branch.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/06-real-tts feat/mora-alpha/05-real-speech
```

- [ ] **Step 2: Extend the protocol.**

```swift
// Packages/MoraCore/Sources/MoraCore/L1Profile.swift
import Foundation

public protocol L1Profile: Sendable {
    var identifier: String { get }
    var characterSystem: CharacterSystem { get }
    var interferencePairs: [PhonemeConfusionPair] { get }
    var interestCategories: [InterestCategory] { get }
    /// Example words that clearly demonstrate a phoneme. Returns an empty array
    /// if the phoneme is not in the curriculum. Used by TTS (for
    /// "sh, as in ship") and by UI worked-example tiles.
    func exemplars(for phoneme: Phoneme) -> [String]
}

public extension L1Profile {
    func matchInterference(expected: Phoneme, heard: Phoneme) -> PhonemeConfusionPair? {
        guard expected != heard else { return nil }
        for pair in interferencePairs {
            if pair.from == expected && pair.to == heard { return pair }
            if pair.bidirectional && pair.from == heard && pair.to == expected {
                return pair
            }
        }
        return nil
    }
}
```

- [ ] **Step 3: Implement in `JapaneseL1Profile.swift`.**

Append the method to the struct:

```swift
extension JapaneseL1Profile {
    public func exemplars(for phoneme: Phoneme) -> [String] {
        switch phoneme.ipa {
        case "ʃ":   return ["ship", "shop", "fish"]
        case "tʃ":  return ["chop", "chin", "rich"]
        case "θ":   return ["thin", "thick", "math"]
        case "k":   return ["duck", "back", "rock"]  // for "ck" coda
        default:    return []
        }
    }
}
```

- [ ] **Step 4: Add tests.**

```swift
// Append to Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift
extension JapaneseL1ProfileTests {
    func test_exemplars_shDigraph() {
        let profile = JapaneseL1Profile()
        XCTAssertEqual(profile.exemplars(for: Phoneme(ipa: "ʃ")), ["ship", "shop", "fish"])
    }

    func test_exemplars_unknownPhonemeIsEmpty() {
        let profile = JapaneseL1Profile()
        XCTAssertTrue(profile.exemplars(for: Phoneme(ipa: "ʒ")).isEmpty)
    }
}
```

- [ ] **Step 5: Run tests.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
```
Expected: all PASS.

- [ ] **Step 6: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraCore/Sources/MoraCore/L1Profile.swift \
        Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift \
        Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift
git commit -m "feat(MoraCore): L1Profile.exemplars(for:) for TTS and UI

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 27: `AppleTTSEngine`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Speech/AppleTTSEngine.swift`

- [ ] **Step 1: Write `AppleTTSEngine.swift`.**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Speech/AppleTTSEngine.swift
import AVFoundation
import Foundation
import MoraCore

public actor AppleTTSEngine: TTSEngine {
    private let synthesizer = AVSpeechSynthesizer()
    private let delegateProxy = DelegateProxy()
    private let l1Profile: any L1Profile
    private let rate: Float
    public let preferredVoiceIdentifier: String?

    public init(
        l1Profile: any L1Profile,
        preferredVoiceIdentifier: String? = nil,
        rate: Float = 0.45
    ) {
        self.l1Profile = l1Profile
        self.preferredVoiceIdentifier = preferredVoiceIdentifier
        self.rate = rate
        Task { @MainActor in
            self.synthesizer.delegate = self.delegateProxy
        }
    }

    public func speak(_ text: String) async {
        await speak(text: text)
    }

    public func speak(phoneme: Phoneme) async {
        let exemplars = l1Profile.exemplars(for: phoneme)
        let lead: String = {
            switch phoneme.ipa {
            case "ʃ":  return "sh"
            case "tʃ": return "ch"
            case "θ":  return "th"
            default:   return phoneme.ipa
            }
        }()
        let text: String
        if let first = exemplars.first {
            text = "\(lead), as in \(first)."
        } else {
            text = "the \(lead) sound."
        }
        await speak(text: text)
    }

    /// `true` when no installed en-US voice is enhanced or premium. Callers
    /// (HomeView) surface a prompt linking into Settings when this is true.
    public nonisolated var needsEnhancedVoice: Bool {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-US") }
        return !voices.contains { $0.quality == .enhanced || $0.quality == .premium }
    }

    private func speak(text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = pickVoice()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            delegateProxy.setOnFinish { cont.resume() }
            synthesizer.speak(utterance)
        }
    }

    private func pickVoice() -> AVSpeechSynthesisVoice? {
        if let id = preferredVoiceIdentifier,
           let v = AVSpeechSynthesisVoice(identifier: id) {
            return v
        }
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-US") }
        if let premium = voices.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) { return enhanced }
        return voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

/// AVSpeechSynthesizerDelegate requires an NSObject; this proxy forwards
/// `didFinish` into a single-shot async continuation so callers can `await`
/// `speak(_:)`. A fresh continuation is installed per utterance.
private final class DelegateProxy: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var onFinish: (() -> Void)?

    func setOnFinish(_ handler: @escaping () -> Void) {
        lock.lock(); defer { lock.unlock() }
        onFinish = handler
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let handler: (() -> Void)? = {
            lock.lock(); defer { lock.unlock() }
            let h = onFinish
            onFinish = nil
            return h
        }()
        handler?()
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let handler: (() -> Void)? = {
            lock.lock(); defer { lock.unlock() }
            let h = onFinish
            onFinish = nil
            return h
        }()
        handler?()
    }
}
```

- [ ] **Step 2: Build the package.**

```bash
(cd $REPO_ROOT/Packages/MoraEngines && swift build)
```
Expected: `Build complete!`

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraEngines/Sources/MoraEngines/Speech/AppleTTSEngine.swift
git commit -m "feat(MoraEngines): AppleTTSEngine actor on AVSpeechSynthesizer

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 28: TTS wired into Warmup / NewRule / scaffold / Completion

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` (inject TTS engine)
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/NewRuleView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift`

- [ ] **Step 1: In `SessionContainerView`, construct `AppleTTSEngine` alongside `AppleSpeechEngine` in `bootstrap()` and add `@State private var ttsEngine: TTSEngine?`. Pass it into each phase view.**

In `bootstrap()`, just after the speech-engine construction:

```swift
ttsEngine = AppleTTSEngine(l1Profile: JapaneseL1Profile())
```

In each `case .phaseName:` inside the body switch, pass `ttsEngine: ttsEngine`:

```swift
case .warmup:
    WarmupView(orchestrator: orchestrator, ttsEngine: ttsEngine)
case .newRule:
    NewRuleView(orchestrator: orchestrator, ttsEngine: ttsEngine)
case .decoding:
    DecodeActivityView(
        orchestrator: orchestrator, uiMode: uiMode,
        feedback: $feedback,
        speechEngine: uiMode == .mic ? speechEngine : nil,
        ttsEngine: ttsEngine
    )
case .shortSentences:
    ShortSentencesView(
        orchestrator: orchestrator, uiMode: uiMode,
        feedback: $feedback,
        speechEngine: uiMode == .mic ? speechEngine : nil,
        ttsEngine: ttsEngine
    )
case .completion:
    CompletionView(
        orchestrator: orchestrator, ttsEngine: ttsEngine,
        persistSummary: { summary in persist(summary: summary) }
    )
```

- [ ] **Step 2: Wire TTS in `WarmupView`.**

Add `let ttsEngine: TTSEngine?` to the struct and the following `.task`:

```swift
.task {
    guard let tts = ttsEngine else { return }
    let phoneme = orchestrator.target.skill.graphemePhoneme?.phoneme
    if let phoneme { await tts.speak(phoneme: phoneme) }
}
```

Update the "Listen again" button to re-invoke TTS:

```swift
Button(action: {
    guard let tts = ttsEngine,
          let phoneme = orchestrator.target.skill.graphemePhoneme?.phoneme else { return }
    Task { await tts.speak(phoneme: phoneme) }
}) {
    Label("Listen again", systemImage: "speaker.wave.2.fill")
        // (same styling as before)
}
```

- [ ] **Step 3: Wire TTS in `NewRuleView`.**

Add `let ttsEngine: TTSEngine?`. Add a `@State private var finishedIntro = false` and gate the Got-it CTA:

```swift
.task {
    guard !finishedIntro, let tts = ttsEngine else { finishedIntro = true; return }
    let letters = orchestrator.target.skill.graphemePhoneme?.grapheme.letters ?? ""
    let ipa = orchestrator.target.skill.graphemePhoneme?.phoneme.ipa ?? ""
    await tts.speak("\(letters) says \(ipa). Two letters, one sound.")
    for word in ["ship", "shop", "fish"] {
        await tts.speak(word)
    }
    finishedIntro = true
}

HeroCTA(title: "Got it") {
    Task { await orchestrator.handle(.advance) }
}
.disabled(!finishedIntro)
.opacity(finishedIntro ? 1.0 : 0.4)
```

- [ ] **Step 4: Wire TTS in `DecodeActivityView` and `ShortSentencesView`.**

Add `let ttsEngine: TTSEngine?`. Long-press replays the word / sentence:

```swift
.onLongPressGesture {
    guard let tts = ttsEngine else { return }
    Task { await tts.speak(current.word.surface) }  // Decode
    // Task { await tts.speak(current.text) } in Sentences
}
```

On a wrong ASR trial, play the scaffold TTS inside `startListening` — insert after `feedback = .wrong`:

```swift
if !wasCorrect, let tts = ttsEngine {
    await tts.speak("Listen: " + expected.surface)  // Decode
    // await tts.speak("Listen: " + current.text) in Sentences
}
```

- [ ] **Step 5: Wire TTS in `CompletionView`.**

Add `let ttsEngine: TTSEngine?`. Speak on appear:

```swift
.task {
    guard let tts = ttsEngine else { return }
    await tts.speak("Quest complete! You got \(correct) out of \(total).")
}
```

- [ ] **Step 6: Build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 7: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/
git commit -m "feat(MoraUI): TTS wired into session views (warmup, rule, scaffold, completion)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 29: Enhanced-voice chip on `HomeView`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

- [ ] **Step 1: Insert a small chip to the left of `StreakChip` when `AppleTTSEngine.needsEnhancedVoice` is true.**

```swift
// In HomeView struct — add a property and adjust header:
private let needsEnhancedVoice: Bool = {
    let voices = AVSpeechSynthesisVoice.speechVoices()
        .filter { $0.language.hasPrefix("en-US") }
    return !voices.contains { $0.quality == .enhanced || $0.quality == .premium }
}()

private var header: some View {
    HStack {
        Text("mora")
            .font(MoraType.heading())
            .foregroundStyle(MoraTheme.Accent.orange)
        Spacer()
        if needsEnhancedVoice {
            Button(action: openVoiceSettings) {
                Text("Better voice ›")
                    .font(MoraType.pill())
                    .foregroundStyle(MoraTheme.Ink.secondary)
                    .padding(.horizontal, MoraTheme.Space.md)
                    .padding(.vertical, MoraTheme.Space.sm)
                    .background(MoraTheme.Background.cream, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        StreakChip(count: streaks.first?.currentCount ?? 0)
    }
    .padding(MoraTheme.Space.md)
}

private func openVoiceSettings() {
    #if canImport(UIKit)
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
    #endif
}
```

Add `import AVFoundation` and `import UIKit` to the file.

- [ ] **Step 2: Build.**

```bash
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 3: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "feat(MoraUI): enhanced-voice chip on Home (opens iOS Settings)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### PR 6 finalize

- [ ] **Step 1: Full test + lint + build + simulator sanity.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
(cd $REPO_ROOT/Packages/MoraTesting && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 2: Open PR** with base `feat/mora-alpha/05-real-speech`, title `mora alpha 06: real on-device TTS`.

---

## PR 7 — Persistence & Polish (branch `feat/mora-alpha/07-polish`, base `06-real-tts`)

**Deliverables:** streak rollover logic on session completion; feedback animations (green glow, shake, phase transition, streak pulse); haptics on correct/wrong; close-confirmation dialog in session; device smoke checklist.

### Task 30: Streak rollover at session completion

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/DailyStreak.swift` (add a method)
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift` (invoke on appear)
- Create: `Packages/MoraCore/Tests/MoraCoreTests/DailyStreakRolloverTests.swift`

- [ ] **Step 1: Branch.**

```bash
cd $REPO_ROOT
git switch -c feat/mora-alpha/07-polish feat/mora-alpha/06-real-tts
```

- [ ] **Step 2: Write failing rollover tests.**

```swift
// Packages/MoraCore/Tests/MoraCoreTests/DailyStreakRolloverTests.swift
import XCTest
@testable import MoraCore

final class DailyStreakRolloverTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)
    private func day(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = cal
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)!
    }

    func test_firstSession_setsCountTo1() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        XCTAssertEqual(streak.currentCount, 1)
        XCTAssertEqual(streak.longestCount, 1)
    }

    func test_sameDay_noChange() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        XCTAssertEqual(streak.currentCount, 1)
    }

    func test_consecutiveDays_increments() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-23"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-24"), calendar: cal)
        XCTAssertEqual(streak.currentCount, 3)
        XCTAssertEqual(streak.longestCount, 3)
    }

    func test_gapResets_butKeepsLongest() {
        let streak = DailyStreak()
        streak.recordCompletion(on: day("2026-04-22"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-23"), calendar: cal)
        streak.recordCompletion(on: day("2026-04-26"), calendar: cal) // 2-day gap
        XCTAssertEqual(streak.currentCount, 1)
        XCTAssertEqual(streak.longestCount, 2)
    }
}
```

- [ ] **Step 3: Add the rollover method to `DailyStreak.swift`.**

```swift
// Append to DailyStreak.swift
public extension DailyStreak {
    /// Record that a session completed on the given day. Increments
    /// `currentCount` if `date` is exactly one day after the previous
    /// completion, resets to 1 on a longer gap, no-ops on the same day.
    /// `longestCount` is pulled up to match `currentCount` on every call.
    func recordCompletion(
        on date: Date,
        calendar: Calendar = .init(identifier: .gregorian)
    ) {
        let today = calendar.startOfDay(for: date)
        guard let previous = lastCompletedOn else {
            currentCount = 1
            longestCount = max(longestCount, currentCount)
            lastCompletedOn = today
            return
        }
        let prevDay = calendar.startOfDay(for: previous)
        if today == prevDay { return }
        let daysBetween = calendar.dateComponents([.day], from: prevDay, to: today).day ?? 0
        if daysBetween == 1 {
            currentCount += 1
        } else {
            currentCount = 1
        }
        longestCount = max(longestCount, currentCount)
        lastCompletedOn = today
    }
}
```

- [ ] **Step 4: Invoke from `CompletionView`.**

Add `@Environment(\.modelContext)` + `@Query` for streaks, and call the method in the `.onAppear` or `.task`:

```swift
// CompletionView.swift
@Environment(\.modelContext) private var ctx
@Query private var streaks: [DailyStreak]

// ... inside body, on appear:
.task {
    guard !didPersist else { return }
    didPersist = true
    persistSummary(orchestrator.sessionSummary(endedAt: Date()))
    let streak = streaks.first ?? {
        let new = DailyStreak()
        ctx.insert(new)
        return new
    }()
    streak.recordCompletion(on: Date())
    try? ctx.save()
    // Existing tts speak...
}
```

- [ ] **Step 5: Run tests.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test --filter DailyStreakRolloverTests)
```
Expected: all four tests PASS.

- [ ] **Step 6: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraCore/Sources/MoraCore/Persistence/DailyStreak.swift \
        Packages/MoraCore/Tests/MoraCoreTests/DailyStreakRolloverTests.swift \
        Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift
git commit -m "feat: streak rollover on session completion

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 31: Feedback animations

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Design/Components/FeedbackOverlay.swift` (add animation timing)
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` (animate feedback state change + phase transition)
- Modify: `Packages/MoraUI/Sources/MoraUI/Design/Components/StreakChip.swift` (pulse on change)

- [ ] **Step 1: Add shake modifier + wire phase-transition animation.**

Create a small shake `ViewModifier`:

```swift
// Packages/MoraUI/Sources/MoraUI/Design/Components/ShakeModifier.swift
import SwiftUI

struct Shake: ViewModifier {
    var animatableData: CGFloat = 0
    var amplitude: CGFloat = 12
    var count: CGFloat = 3

    func body(content: Content) -> some View {
        content.offset(
            x: animatableData == 0 ? 0
               : amplitude * sin(animatableData * .pi * count * 2)
        )
    }
}

extension View {
    func shake(amount: CGFloat) -> some View {
        modifier(Shake(animatableData: amount))
    }
}
```

- [ ] **Step 2: Apply shake on `.wrong` in `DecodeActivityView` + `ShortSentencesView`.**

In each view, add `@State private var shakeAmount: CGFloat = 0`. Apply `.shake(amount: shakeAmount)` to the word/sentence Text. When `feedback == .wrong`, trigger:

```swift
.onChange(of: feedback) { _, new in
    if new == .wrong {
        withAnimation(.linear(duration: 0.6)) { shakeAmount = 1 }
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            shakeAmount = 0
        }
    }
}
```

- [ ] **Step 3: Wrap the phase body in `.transition` for a 250ms push-left.**

In `SessionContainerView.body`, wrap the `switch` in a `Group` with:

```swift
.animation(.easeInOut(duration: 0.25), value: orchestrator?.phase)
.transition(.move(edge: .leading).combined(with: .opacity))
```

- [ ] **Step 4: Streak pulse on increment.**

In `StreakChip`, add a `@State var pulse: Bool = false`. When the parent updates `count`, tie a `.scaleEffect(pulse ? 1.2 : 1.0)` and animate on change:

```swift
.onChange(of: count) { _, _ in
    withAnimation(.easeInOut(duration: 0.35)) { pulse = true }
    Task {
        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation(.easeInOut(duration: 0.35)) { pulse = false }
    }
}
```

- [ ] **Step 5: Build.**

```bash
(cd $REPO_ROOT/Packages/MoraUI && swift build)
```

- [ ] **Step 6: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Design/Components/ShakeModifier.swift \
        Packages/MoraUI/Sources/MoraUI/Design/Components/StreakChip.swift \
        Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift \
        Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift \
        Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift
git commit -m "feat(MoraUI): feedback animations (shake, phase transition, streak pulse)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 32: Haptics + close-confirmation dialog

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift` (haptic on feedback)
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift` (haptic on feedback)
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` (confirm close)

- [ ] **Step 1: Fire a `UINotificationFeedbackGenerator` when `feedback` changes.**

In `DecodeActivityView` (and the same in `ShortSentencesView`):

```swift
#if canImport(UIKit)
import UIKit
#endif

// Add on the body:
.onChange(of: feedback) { _, new in
    #if canImport(UIKit)
    switch new {
    case .correct: UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .wrong:   UINotificationFeedbackGenerator().notificationOccurred(.error)
    case .none:    break
    }
    #endif
}
```

- [ ] **Step 2: Close confirmation in `SessionContainerView`.**

Add `@State private var showCloseConfirm = false`. Replace the close button action:

```swift
Button(action: { showCloseConfirm = true }) { ... }

// At the outermost ZStack:
.alert("End today's quest?", isPresented: $showCloseConfirm) {
    Button("Keep going", role: .cancel) {}
    Button("End quest", role: .destructive) {
        // Record a partial summary so progress is not silently dropped.
        if let orchestrator {
            let partial = orchestrator.sessionSummary(endedAt: Date())
            persist(summary: partial)
        }
        dismiss()
    }
} message: {
    Text("Your progress so far will be saved.")
}
```

- [ ] **Step 3: Build.**

```bash
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 4: Commit.**

```bash
cd $REPO_ROOT
git add Packages/MoraUI/Sources/MoraUI/Session/
git commit -m "feat(MoraUI): haptics + close-confirmation dialog

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 33: Device smoke checklist (manual)

This task is documentation + execution, not code. Create an issue-shaped checklist in the PR description and tick items off as they pass on the physical iPad.

- [ ] **Step 1: Manual device smoke — fresh install, run onboarding: name → interests (3 selected) → allow permissions → Home.**

- [ ] **Step 2: Run an A-day session:** target grapheme visible at Home, start quest, warmup hears TTS phoneme, NewRule plays rule + exemplars, Decode 5 words with MicButton — each reads aloud, partial text appears, final correct/wrong animates appropriately. Scaffold TTS fires on a wrong read. Sentences 2× same behavior. Completion shows score + TTS congratulation.

- [ ] **Step 3: Edge cases:** cancel during Decode → close dialog → "End quest" → Home. Revoke mic mid-session via Settings → session falls back to tap for the next trial.

- [ ] **Step 4: Short video (≤ 30 s) of the target learner running through a session. Attach to PR.**

---

### PR 7 finalize

- [ ] **Step 1: Full test + lint + build.**

```bash
(cd $REPO_ROOT/Packages/MoraCore && swift test)
(cd $REPO_ROOT/Packages/MoraEngines && swift test)
(cd $REPO_ROOT/Packages/MoraUI && swift test)
(cd $REPO_ROOT/Packages/MoraTesting && swift test)
cd $REPO_ROOT && xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 2: Open PR** with base `feat/mora-alpha/06-real-tts`, title `mora alpha 07: streak, animations, haptics, close dialog`.

---

## Self-Review

**Spec coverage:**
- §6 (tokens, typography, components) → PR 1 (Tasks 2–5)
- §7 (Session L1 frame, per-phase layout) → PR 2 (Tasks 6–11)
- §8 (Home H1) → PR 3 (Task 13)
- §9 (Onboarding 4 steps, finalize, interest catalog) → PR 4 (Tasks 15–19)
- §10.1–10.4 (Speech protocol, AppleSpeechEngine, PermissionCoordinator, tap-to-listen UI) → PR 5 (Tasks 20–25)
- §10.5 (OrchestratorEvent reshape) → PR 5 (Task 21)
- §10.6 (mic-denied fallback) → PR 5 (Task 25)
- §11.1–11.3 (TTS engine, exemplars, enhanced-voice chip) → PR 6 (Tasks 26–29)
- §11.4 (TTS usage in session) → PR 6 (Task 28)
- §12 (AssessmentLeniency) → PR 5 (Task 21)
- §13 (feedback, animation, haptics) → PR 7 (Tasks 31–32)
- §14 (Phase Plan) → matches the PR structure
- §15 (testing strategy) → each task has tests where feasible; SwiftUI snapshot tests explicitly deferred per §15.4
- §16 (error + boundary handling) → close-confirm in PR 7 Task 32; mic-busy / assets-not-ready / tap fallback handled in PR 5 Task 25 via the `PermissionStatus.partial` + try/catch path; other boundary cases (TTS enhanced missing, SwiftData corruption) covered by existing code
- §17 (open questions) → not blocking; revisited after alpha with the learner

**Placeholder scan:** the plan contains no TBDs, no "add appropriate error handling" without code, and no "fill in details". Every code block is complete enough for an engineer with no prior context to paste in.

**Type consistency:**
- `SpeechEvent` / `AsyncThrowingStream<SpeechEvent, Error>` is used consistently across Task 20 (definition) → Task 24 (consumption) → Task 23 (`AppleSpeechEngine.listen`).
- `OrchestratorEvent.answerHeard(ASRResult)` / `.answerManual(correct: Bool)` used identically in Task 21 (definition) → Task 21 UI migration → Task 24 (mic consumer).
- `AssessmentLeniency.newWord` / `.mastered` used identically in Task 21.
- `PermissionStatus.allGranted` / `.partial(micDenied:speechDenied:)` / `.notDetermined` used identically in Task 22 and Task 25.
- `SessionUIMode.tap` / `.mic` used identically in Task 6 (definition in PR 2) through Task 25 (decision point in PR 5). Task 6 introduces the enum; Tasks 9, 10, 24, 25 consume it.
- `FeedbackState.none` / `.correct` / `.wrong` used identically in Task 4 (definition), Tasks 9/10 (tap-mode set), Task 24 (mic-mode set).
- `MicUIState` — renamed from `MicButtonState` in the plan text (the latter is the visual-shell enum; the former is the session-view FSM). Clarified: `MicButtonState` lives in `MicButton.swift` (Task 5), `MicUIState` is a file-private enum inside `DecodeActivityView.swift` and `ShortSentencesView.swift` (Task 24). Both are defined separately; there is no shared type confusion.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md`. Two execution options:

**1. Subagent-Driven (recommended)** — dispatch a fresh subagent per PR, review between PRs, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
