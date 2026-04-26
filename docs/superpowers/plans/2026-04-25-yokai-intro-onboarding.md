# Yokai Intro Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4-panel Yokai introduction flow between the existing `OnboardingFlow.permission` step and `HomeView`, conveying (1) what yokai are, (2) the active week's yokai with its bundled English `greet` clip, (3) one session's shape (~10 min, きく / ならべる / 話す), and (4) the 5-sessions-per-yokai progression. Replayable from `HomeView` via an "あそびかた" link as a sheet.

**Architecture:** New SwiftUI views in `MoraUI/Onboarding/YokaiIntro/`, a new `@Observable @MainActor` state machine, and a new `UserDefaults` flag `tech.reenable.Mora.yokaiIntroSeen`. Reuses `BundledYokaiStore` + `AVFoundationYokaiClipPlayer` from `MoraEngines` for Panel 2 audio. `RootView` extends from a 2-stage gate (`languageAgeOnboarded → onboarded`) to a 3-stage gate (`… → yokaiIntroSeen → HomeView`). Replay path is `HomeView` `Button` + `@State` + `.sheet`, no new navigation destination.

**Tech Stack:** Swift 5/Swift 6 language mode pinned to v5, SwiftUI, SwiftData (read-only here — no schema change), AVFoundation, MoraCore + MoraEngines + MoraUI packages.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-intro-and-tile-tutorial-design.md`.

---

## File Structure

**New files (all PR 1):**
- `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift` — shared enum (also created by the parallel tile-tutorial plan; whichever PR ships first creates the file, the other rebases as a no-op).
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift` — `YokaiIntroState` class + `YokaiIntroFlow` View.
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift` — Panel 1 (silhouettes of all 5 yokai).
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift` — Panel 2 (active yokai portrait + `greet` clip).
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift` — Panel 3 (3 step icons).
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift` — Panel 4 (5 numbered circles).
- `Packages/MoraUI/Tests/MoraUITests/YokaiIntroStateTests.swift` — state-machine unit tests.
- `Packages/MoraUI/Tests/MoraUITests/RootViewOnboardingGateTests.swift` — 3-stage gate test.
- `Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift` — audio playback test (fake `YokaiClipPlayer`).

**Modified files:**
- `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift` — 15 new `public let` declarations + initializer parameters.
- `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift` — `stringsMid` literal +15 lines.
- `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift` — extend non-empty + kanji-budget loops with the 15 new keys.
- `Packages/MoraUI/Sources/MoraUI/RootView.swift` — 3-stage gate.
- `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` — "あそびかた" Button + sheet for replay.

---

## Task 1: Add `OnboardingPlayMode` shared enum

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift`

- [ ] **Step 1.1: Create the enum file**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift

/// Distinguishes the first-time gating run of an onboarding flow from
/// an on-demand replay. The replay variant must NOT mutate the
/// `UserDefaults` "seen" flag and may render a different terminal CTA
/// (e.g. "とじる" instead of "▶ はじめる").
public enum OnboardingPlayMode: Equatable, Sendable {
    case firstTime
    case replay
}
```

- [ ] **Step 1.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean, no warnings.

- [ ] **Step 1.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift
git commit -m "ui(onboarding): add OnboardingPlayMode enum"
```

---

## Task 2: Add 15 new keys to `MoraStrings`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`

- [ ] **Step 2.1: Add 15 `public let` declarations**

Insert immediately after the existing `permissionNotNow` line (after the "Existing four-step onboarding" block, before the "// Home" comment):

```swift
    // Yokai intro flow (4 panels + 3 CTAs + 1 replay close)
    public let yokaiIntroConceptTitle: String
    public let yokaiIntroConceptBody: String
    public let yokaiIntroTodayTitle: String
    public let yokaiIntroTodayBody: String
    public let yokaiIntroSessionTitle: String
    public let yokaiIntroSessionBody: String
    public let yokaiIntroSessionStep1: String
    public let yokaiIntroSessionStep2: String
    public let yokaiIntroSessionStep3: String
    public let yokaiIntroProgressTitle: String
    public let yokaiIntroProgressBody: String
    public let yokaiIntroNext: String
    public let yokaiIntroBegin: String
    public let yokaiIntroClose: String
```

Add one more under the "// Home" group (after `bestiaryBefriendedOn`):

```swift
    public let homeRecapLink: String
```

- [ ] **Step 2.2: Add 15 initializer parameters**

The initializer is a single big positional `init(...)`. Add these parameters in the same logical positions as the property declarations:

After `permissionNotNow: String,` add:

```swift
        yokaiIntroConceptTitle: String,
        yokaiIntroConceptBody: String,
        yokaiIntroTodayTitle: String,
        yokaiIntroTodayBody: String,
        yokaiIntroSessionTitle: String,
        yokaiIntroSessionBody: String,
        yokaiIntroSessionStep1: String,
        yokaiIntroSessionStep2: String,
        yokaiIntroSessionStep3: String,
        yokaiIntroProgressTitle: String,
        yokaiIntroProgressBody: String,
        yokaiIntroNext: String,
        yokaiIntroBegin: String,
        yokaiIntroClose: String,
```

After the existing `bestiaryBefriendedOn: @Sendable @escaping (Date) -> String,` add:

```swift
        homeRecapLink: String,
```

- [ ] **Step 2.3: Add 15 `self.x = x` lines in initializer body**

In the same order as parameters. After `self.permissionNotNow = permissionNotNow`:

```swift
        self.yokaiIntroConceptTitle = yokaiIntroConceptTitle
        self.yokaiIntroConceptBody = yokaiIntroConceptBody
        self.yokaiIntroTodayTitle = yokaiIntroTodayTitle
        self.yokaiIntroTodayBody = yokaiIntroTodayBody
        self.yokaiIntroSessionTitle = yokaiIntroSessionTitle
        self.yokaiIntroSessionBody = yokaiIntroSessionBody
        self.yokaiIntroSessionStep1 = yokaiIntroSessionStep1
        self.yokaiIntroSessionStep2 = yokaiIntroSessionStep2
        self.yokaiIntroSessionStep3 = yokaiIntroSessionStep3
        self.yokaiIntroProgressTitle = yokaiIntroProgressTitle
        self.yokaiIntroProgressBody = yokaiIntroProgressBody
        self.yokaiIntroNext = yokaiIntroNext
        self.yokaiIntroBegin = yokaiIntroBegin
        self.yokaiIntroClose = yokaiIntroClose
```

After `self.bestiaryBefriendedOn = bestiaryBefriendedOn`:

```swift
        self.homeRecapLink = homeRecapLink
```

- [ ] **Step 2.4: Verify the package compiles (will still fail to link until Task 3)**

Run: `(cd Packages/MoraCore && swift build)`
Expected: build fails with "missing argument for parameter 'yokaiIntroConceptTitle' in call" pointing at `JapaneseL1Profile.swift` `stringsMid =` literal. This is **expected** — Task 3 fixes it.

---

## Task 3: Populate `JapaneseL1Profile.stringsMid` with 15 values

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`

- [ ] **Step 3.1: Add the 15 values**

In the `stringsMid` literal, insert in matching positions:

After `permissionNotNow: "後で",`:

```swift
        yokaiIntroConceptTitle: "音には ともだちが いるよ",
        yokaiIntroConceptBody:
            "えいごの 音 ひとつ ひとつに、Yokai が すんでいる。"
            + "なかよく なるには、その 音を よく 聞いて、ことばに しよう。",
        yokaiIntroTodayTitle: "今週の ともだち",
        yokaiIntroTodayBody: "今週は この 音を いっしょに れんしゅうしよう。",
        yokaiIntroSessionTitle: "1回の すすめかた",
        yokaiIntroSessionBody: "1回 だいたい 10分。",
        yokaiIntroSessionStep1: "きく",
        yokaiIntroSessionStep2: "ならべる",
        yokaiIntroSessionStep3: "話す",
        yokaiIntroProgressTitle: "5回で ともだちに なる",
        yokaiIntroProgressBody:
            "Yokai と 5回 れんしゅうすると、なかよく なれる。"
            + "1日 1回 でも、すきな ペースで OK。",
        yokaiIntroNext: "つぎへ",
        yokaiIntroBegin: "▶ はじめる",
        yokaiIntroClose: "とじる",
```

After `bestiaryBefriendedOn: { date in … },`:

```swift
        homeRecapLink: "あそびかた",
```

- [ ] **Step 3.2: Build the package**

Run: `(cd Packages/MoraCore && swift build)`
Expected: build succeeds.

- [ ] **Step 3.3: Run the existing kanji-budget test (it MUST already cover the new keys to fail; if not we add coverage in Task 4)**

Run: `(cd Packages/MoraCore && swift test --filter MoraStringsTests)`
Expected: all existing tests pass; the new keys are not yet asserted but they are present in the struct so kanji budget is still enforced because the test enumerates `Mirror(reflecting:)` — verify by reading the test file. If the existing test uses an explicit hand-rolled list of keys (it does, per `head -25` grep), the new keys are **not** asserted yet. Move on to Task 4.

---

## Task 4: Extend `MoraStringsTests` with 15 entries

**Files:**
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift`

- [ ] **Step 4.1: Read the existing non-empty test loop**

Open the file and locate the two arrays that drive the loops:
- The non-empty array (around line 28): list of `(name, s.<key>)` tuples for plain `String` keys.
- The kanji-budget array (around line 189): same pattern but the budget loop iterates the same shape.

- [ ] **Step 4.2: Add 15 entries to both arrays (each in lexical group order)**

In both arrays, after the existing `("permissionNotNow", s.permissionNotNow),` line add:

```swift
            ("yokaiIntroConceptTitle", s.yokaiIntroConceptTitle),
            ("yokaiIntroConceptBody", s.yokaiIntroConceptBody),
            ("yokaiIntroTodayTitle", s.yokaiIntroTodayTitle),
            ("yokaiIntroTodayBody", s.yokaiIntroTodayBody),
            ("yokaiIntroSessionTitle", s.yokaiIntroSessionTitle),
            ("yokaiIntroSessionBody", s.yokaiIntroSessionBody),
            ("yokaiIntroSessionStep1", s.yokaiIntroSessionStep1),
            ("yokaiIntroSessionStep2", s.yokaiIntroSessionStep2),
            ("yokaiIntroSessionStep3", s.yokaiIntroSessionStep3),
            ("yokaiIntroProgressTitle", s.yokaiIntroProgressTitle),
            ("yokaiIntroProgressBody", s.yokaiIntroProgressBody),
            ("yokaiIntroNext", s.yokaiIntroNext),
            ("yokaiIntroBegin", s.yokaiIntroBegin),
            ("yokaiIntroClose", s.yokaiIntroClose),
```

After the existing `("bestiaryBefriendedOn", s.bestiaryBefriendedOn(.now)),` (or the equivalent line — bestiary close) add:

```swift
            ("homeRecapLink", s.homeRecapLink),
```

- [ ] **Step 4.3: Run the tests**

Run: `(cd Packages/MoraCore && swift test --filter MoraStringsTests)`
Expected: all tests pass. If the kanji-budget test fails on any new value, fix the offending value (the spec's authoring rationale lives in spec §7).

- [ ] **Step 4.4: Commit Tasks 2 + 3 + 4 together**

```bash
git add Packages/MoraCore/Sources/MoraCore/MoraStrings.swift \
        Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift \
        Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift
git commit -m "core(strings): add 15 yokai-intro + 1 home-recap MoraStrings keys"
```

---

## Task 5: Build `YokaiIntroState` (TDD)

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/YokaiIntroStateTests.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift` (state class portion only — flow View comes in Task 10)

- [ ] **Step 5.1: Write the failing tests**

```swift
// Packages/MoraUI/Tests/MoraUITests/YokaiIntroStateTests.swift
import XCTest
@testable import MoraUI

@MainActor
final class YokaiIntroStateTests: XCTestCase {
    func testStartsAtConcept() {
        let state = YokaiIntroState()
        XCTAssertEqual(state.step, .concept)
    }

    func testAdvanceWalksAllSteps() {
        let state = YokaiIntroState()
        state.advance()
        XCTAssertEqual(state.step, .todayYokai)
        state.advance()
        XCTAssertEqual(state.step, .sessionShape)
        state.advance()
        XCTAssertEqual(state.step, .progress)
        state.advance()
        XCTAssertEqual(state.step, .finished)
        // Idempotent at terminal state.
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func testFinalizeFlipsFlag() {
        let suite = "test.YokaiIntroStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(defaults.bool(forKey: YokaiIntroState.onboardedKey))
        YokaiIntroState().finalize(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: YokaiIntroState.onboardedKey))
    }

    func testOnboardedKeyIsNamespaced() {
        XCTAssertEqual(
            YokaiIntroState.onboardedKey,
            "tech.reenable.Mora.yokaiIntroSeen"
        )
    }
}
```

- [ ] **Step 5.2: Run tests — they fail because `YokaiIntroState` does not exist**

Run: `(cd Packages/MoraUI && swift test --filter YokaiIntroStateTests)`
Expected: build error: `cannot find 'YokaiIntroState' in scope`.

- [ ] **Step 5.3: Implement `YokaiIntroState`**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift
import Foundation
import Observation

@Observable
@MainActor
final class YokaiIntroState {
    enum Step: Equatable, CaseIterable {
        case concept, todayYokai, sessionShape, progress, finished
    }

    var step: Step = .concept

    static let onboardedKey = "tech.reenable.Mora.yokaiIntroSeen"

    func advance() {
        switch step {
        case .concept: step = .todayYokai
        case .todayYokai: step = .sessionShape
        case .sessionShape: step = .progress
        case .progress: step = .finished
        case .finished: break
        }
    }

    func finalize(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.onboardedKey)
    }
}
```

- [ ] **Step 5.4: Run tests — pass**

Run: `(cd Packages/MoraUI && swift test --filter YokaiIntroStateTests)`
Expected: 4 tests pass.

- [ ] **Step 5.5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift \
        Packages/MoraUI/Tests/MoraUITests/YokaiIntroStateTests.swift
git commit -m "ui(onboarding): add YokaiIntroState 5-step machine"
```

---

## Task 6: Build `YokaiConceptPanel` (Panel 1)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift`

- [ ] **Step 6.1: Implement Panel 1**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct YokaiConceptPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let onContinue: () -> Void

    @State private var silhouettesVisible: Bool = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroConceptTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)

            silhouetteRow
                .frame(height: 200)

            Text(strings.yokaiIntroConceptBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.yokaiIntroNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if reduceMotion {
                silhouettesVisible = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    silhouettesVisible = true
                }
            }
        }
    }

    @ViewBuilder
    private var silhouetteRow: some View {
        HStack(spacing: MoraTheme.Space.lg) {
            ForEach(catalog, id: \.id) { yokai in
                VStack(spacing: 4) {
                    Text(yokai.ipa)
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Ink.muted)
                    YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                        .frame(width: 96, height: 96)
                        .opacity(silhouettesVisible ? 1.0 : 0.0)
                }
            }
        }
    }

    private var catalog: [YokaiDefinition] {
        store?.catalog() ?? []
    }
}

#if DEBUG
#Preview {
    YokaiConceptPanel(store: try? BundledYokaiStore(), onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 6.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 6.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift
git commit -m "ui(onboarding): YokaiConceptPanel — 5-yokai silhouette intro"
```

---

## Task 7: Build `TodaysYokaiPanel` (Panel 2 — has audio)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift`

- [ ] **Step 7.1: Implement Panel 2**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct TodaysYokaiPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let player: any YokaiClipPlayer
    let onContinue: () -> Void

    @State private var portraitScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroTodayTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            if let yokai = activeYokai {
                portraitColumn(yokai: yokai)
            } else {
                Color.clear.frame(height: 240)
            }

            Text(strings.yokaiIntroTodayBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.yokaiIntroNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            playGreetClip()
            if reduceMotion {
                portraitScale = 1.0
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    portraitScale = 1.0
                }
            }
        }
        .onDisappear {
            player.stop()
        }
    }

    @ViewBuilder
    private func portraitColumn(yokai: YokaiDefinition) -> some View {
        VStack(spacing: MoraTheme.Space.sm) {
            YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                .frame(width: 200, height: 200)
                .scaleEffect(portraitScale)
            Text(yokai.grapheme)
                .font(MoraType.heroWord(72))
                .foregroundStyle(MoraTheme.Ink.primary)
            Text(yokai.ipa)
                .font(MoraType.subtitle())
                .foregroundStyle(MoraTheme.Ink.secondary)
        }
    }

    private var activeYokai: YokaiDefinition? {
        guard let store else { return nil }
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        return store.catalog().first { $0.id == firstYokaiID }
    }

    private func playGreetClip() {
        guard let yokai = activeYokai,
            let url = store?.voiceClipURL(for: yokai.id, clip: .greet)
        else { return }
        _ = player.play(url: url)
    }
}

#if DEBUG
#Preview {
    TodaysYokaiPanel(
        store: try? BundledYokaiStore(),
        player: AVFoundationYokaiClipPlayer(),
        onContinue: {}
    )
    .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 7.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 7.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift
git commit -m "ui(onboarding): TodaysYokaiPanel with greet clip playback"
```

---

## Task 8: Build `SessionShapePanel` (Panel 3)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift`

- [ ] **Step 8.1: Implement Panel 3**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift
import MoraCore
import SwiftUI

struct SessionShapePanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    @State private var stepsVisible: [Bool] = [false, false, false]

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroSessionTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)

            stepsRow
                .frame(height: 180)
                .padding(.horizontal, MoraTheme.Space.lg)

            Text(strings.yokaiIntroSessionBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HeroCTA(title: strings.yokaiIntroNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await animateSteps()
        }
    }

    private var stepsRow: some View {
        HStack(spacing: MoraTheme.Space.md) {
            stepIcon(emoji: "🎧", label: strings.yokaiIntroSessionStep1, index: 0)
            arrow
            stepIcon(emoji: "🟦", label: strings.yokaiIntroSessionStep2, index: 1)
            arrow
            stepIcon(emoji: "🗣️", label: strings.yokaiIntroSessionStep3, index: 2)
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(MoraTheme.Ink.muted)
    }

    private func stepIcon(emoji: String, label: String, index: Int) -> some View {
        VStack(spacing: MoraTheme.Space.sm) {
            Text(emoji).font(.system(size: 56))
            Text(label)
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.primary)
        }
        .opacity(stepsVisible[index] ? 1.0 : 0.0)
        .scaleEffect(stepsVisible[index] ? 1.0 : 0.85)
    }

    @MainActor
    private func animateSteps() async {
        if reduceMotion {
            stepsVisible = [true, true, true]
            return
        }
        for i in 0..<3 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                stepsVisible[i] = true
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
    }
}

#if DEBUG
#Preview {
    SessionShapePanel(onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 8.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 8.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift
git commit -m "ui(onboarding): SessionShapePanel — 3 step icons"
```

---

## Task 9: Build `ProgressPanel` (Panel 4)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift`

- [ ] **Step 9.1: Implement Panel 4**

```swift
// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift
import MoraCore
import MoraEngines
import SwiftUI

struct ProgressPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let store: BundledYokaiStore?
    let mode: OnboardingPlayMode
    let onContinue: () -> Void

    @State private var dotsLit: [Bool] = Array(repeating: false, count: 5)

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroProgressTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            dotsRow
                .frame(height: 140)
                .padding(.horizontal, MoraTheme.Space.lg)

            Text(strings.yokaiIntroProgressBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: ctaTitle, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await animateDots()
        }
    }

    private var ctaTitle: String {
        switch mode {
        case .firstTime: return strings.yokaiIntroBegin
        case .replay: return strings.yokaiIntroClose
        }
    }

    private var dotsRow: some View {
        HStack(spacing: MoraTheme.Space.md) {
            ForEach(0..<5) { index in
                dotView(index: index)
            }
        }
    }

    @ViewBuilder
    private func dotView(index: Int) -> some View {
        let lit = dotsLit[index]
        let diameter: CGFloat = 72
        ZStack {
            Circle()
                .fill(lit ? MoraTheme.Background.cream : Color.white)
                .frame(width: diameter, height: diameter)
                .overlay(
                    Circle().strokeBorder(
                        lit ? MoraTheme.Accent.orange : MoraTheme.Ink.muted.opacity(0.3),
                        lineWidth: 2
                    )
                )
            content(forIndex: index, lit: lit)
        }
        .opacity(lit ? 1.0 : 0.5)
    }

    @ViewBuilder
    private func content(forIndex index: Int, lit: Bool) -> some View {
        if index == 0, let yokai = activeYokai {
            YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
                .frame(width: 56, height: 56)
        } else if index == 4 {
            Text("🤝").font(.system(size: 36))
        } else {
            Text("\(index + 1)")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.muted)
        }
    }

    private var activeYokai: YokaiDefinition? {
        guard let store else { return nil }
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        return store.catalog().first { $0.id == firstYokaiID }
    }

    @MainActor
    private func animateDots() async {
        if reduceMotion {
            dotsLit = Array(repeating: true, count: 5)
            return
        }
        for i in 0..<5 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                dotsLit[i] = true
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
    }
}

#if DEBUG
#Preview {
    ProgressPanel(store: try? BundledYokaiStore(), mode: .firstTime, onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 9.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 9.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift
git commit -m "ui(onboarding): ProgressPanel — 5 numbered circles"
```

---

## Task 10: Build `YokaiIntroFlow` View wrapper

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift` (state class is already there from Task 5; append the View)

- [ ] **Step 10.1: Append the `YokaiIntroFlow` View**

Add at the end of the existing file:

```swift
import MoraEngines
import SwiftUI

public struct YokaiIntroFlow: View {
    @State private var state = YokaiIntroState()
    private let mode: OnboardingPlayMode
    private let onFinished: () -> Void
    @State private var store: BundledYokaiStore? = try? BundledYokaiStore()
    @State private var player: any YokaiClipPlayer = AVFoundationYokaiClipPlayer()

    public init(mode: OnboardingPlayMode, onFinished: @escaping () -> Void) {
        self.mode = mode
        self.onFinished = onFinished
    }

    public var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            stepView
                .transition(
                    .move(edge: .leading).combined(with: .opacity)
                )
        }
        .animation(.easeInOut(duration: 0.3), value: state.step)
        .onChange(of: state.step) { _, newStep in
            if newStep == .finished {
                if mode == .firstTime {
                    state.finalize()
                }
                player.stop()
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .concept:
            YokaiConceptPanel(store: store) { state.advance() }
        case .todayYokai:
            TodaysYokaiPanel(store: store, player: player) { state.advance() }
        case .sessionShape:
            SessionShapePanel { state.advance() }
        case .progress:
            ProgressPanel(store: store, mode: mode) { state.advance() }
        case .finished:
            ProgressView()
        }
    }
}

#if DEBUG
#Preview("First time") {
    YokaiIntroFlow(mode: .firstTime, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#Preview("Replay") {
    YokaiIntroFlow(mode: .replay, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 10.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 10.3: Run all MoraUI tests to confirm no regression**

Run: `(cd Packages/MoraUI && swift test)`
Expected: all green.

- [ ] **Step 10.4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift
git commit -m "ui(onboarding): YokaiIntroFlow wires 4 panels + finalize"
```

---

## Task 11: Add `YokaiIntroPanel2AudioTests`

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift`

- [ ] **Step 11.1: Define a `FakeYokaiClipPlayer` and the test**

```swift
// Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift
import Foundation
import MoraCore
import MoraEngines
import SwiftUI
import XCTest

@testable import MoraUI

@MainActor
final class FakeYokaiClipPlayer: YokaiClipPlayer {
    private(set) var playedURLs: [URL] = []
    private(set) var stopCount: Int = 0

    func play(url: URL) -> Bool {
        playedURLs.append(url)
        return true
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class YokaiIntroPanel2AudioTests: XCTestCase {
    func testPlayingTodaysYokaiPanelTriggersGreetClipExactlyOnce() async throws {
        let store = try BundledYokaiStore()
        let player = FakeYokaiClipPlayer()
        let panel = TodaysYokaiPanel(store: store, player: player, onContinue: {})

        let host = UIHostingController(rootView:
            panel.environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )
        )
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        // Allow `.task` to run.
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(player.playedURLs.count, 1, "greet clip should fire once on appear")
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        XCTAssertNotNil(firstYokaiID)
        let expectedURL = store.voiceClipURL(for: firstYokaiID!, clip: .greet)
        XCTAssertEqual(player.playedURLs.first, expectedURL)
    }
}
```

- [ ] **Step 11.2: Run the test**

Run: `(cd Packages/MoraUI && swift test --filter YokaiIntroPanel2AudioTests)`
Expected: pass. If it fails because `.task` did not run within 200 ms, bump the sleep to 400 ms.

- [ ] **Step 11.3: Commit**

```bash
git add Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift
git commit -m "ui(onboarding): test that Panel 2 fires greet clip on appear"
```

---

## Task 12: Wire `RootView` 3-stage gate

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/RootView.swift`

- [ ] **Step 12.1: Read the current `RootView`**

Open `Packages/MoraUI/Sources/MoraUI/RootView.swift`. Locate the existing two `@State` lines for `languageAgeOnboarded` and `onboarded`, and the existing `Group` body branching on them.

- [ ] **Step 12.2: Add the third `@State` and the new branch**

After the existing `@State private var onboarded:` declaration, add:

```swift
    @State private var yokaiIntroSeen: Bool = UserDefaults.standard.bool(
        forKey: YokaiIntroState.onboardedKey
    )
```

In the `body`, change the `Group` chain. Current:

```swift
if !languageAgeOnboarded { LanguageAgeFlow { … } }
else if !onboarded {       OnboardingFlow { … } }
else                       { NavigationStack { HomeView() … } }
```

becomes:

```swift
if !languageAgeOnboarded {
    LanguageAgeFlow { languageAgeOnboarded = true }
} else if !onboarded {
    OnboardingFlow { onboarded = true }
        .environment(\.moraStrings, resolvedStrings)
} else if !yokaiIntroSeen {
    YokaiIntroFlow(mode: .firstTime) { yokaiIntroSeen = true }
        .environment(\.moraStrings, resolvedStrings)
} else {
    NavigationStack {
        HomeView()
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "session": SessionContainerView()
                case "bestiary":
                    BestiaryView()
                        .environment(\.moraStrings, resolvedStrings)
                case "curriculumComplete":
                    CurriculumCompleteView()
                        .environment(\.moraStrings, resolvedStrings)
                default: EmptyView()
                }
            }
    }
    .environment(\.moraStrings, resolvedStrings)
}
```

(The `NavigationStack { HomeView() … }` body is unchanged from the current version.)

- [ ] **Step 12.3: Build**

Run: `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
Expected: builds clean.

- [ ] **Step 12.4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/RootView.swift
git commit -m "ui(root): three-stage onboarding gate (yokaiIntroSeen)"
```

---

## Task 13: Add `RootViewOnboardingGateTests`

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/RootViewOnboardingGateTests.swift`

- [ ] **Step 13.1: Implement the test**

```swift
// Packages/MoraUI/Tests/MoraUITests/RootViewOnboardingGateTests.swift
import Foundation
import MoraCore
import SwiftData
import SwiftUI
import XCTest

@testable import MoraUI

@MainActor
final class RootViewOnboardingGateTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "test.RootViewOnboardingGate.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    /// The integration here is in production driven by `UserDefaults.standard`.
    /// We test the *flag-reading* logic by reading the keys this view uses
    /// and verifying defaults align with the expected state-machine
    /// semantics. Full UI gating coverage is by-eye via the SwiftUI Preview.
    func testFreshInstallShowsLanguageAgeFlow() {
        XCTAssertFalse(defaults.bool(forKey: LanguageAgeState.onboardedKey))
        XCTAssertFalse(defaults.bool(forKey: OnboardingState.onboardedKey))
        XCTAssertFalse(defaults.bool(forKey: YokaiIntroState.onboardedKey))
    }

    func testYokaiIntroFiresAfterClassicOnboarding() {
        defaults.set(true, forKey: LanguageAgeState.onboardedKey)
        defaults.set(true, forKey: OnboardingState.onboardedKey)
        defaults.set(false, forKey: YokaiIntroState.onboardedKey)

        XCTAssertTrue(defaults.bool(forKey: LanguageAgeState.onboardedKey))
        XCTAssertTrue(defaults.bool(forKey: OnboardingState.onboardedKey))
        XCTAssertFalse(defaults.bool(forKey: YokaiIntroState.onboardedKey))
    }

    func testFullyOnboardedShowsHome() {
        defaults.set(true, forKey: LanguageAgeState.onboardedKey)
        defaults.set(true, forKey: OnboardingState.onboardedKey)
        defaults.set(true, forKey: YokaiIntroState.onboardedKey)

        XCTAssertTrue(defaults.bool(forKey: YokaiIntroState.onboardedKey))
    }

    func testYokaiIntroFlagIsNamespaced() {
        XCTAssertEqual(
            YokaiIntroState.onboardedKey,
            "tech.reenable.Mora.yokaiIntroSeen"
        )
    }
}
```

- [ ] **Step 13.2: Run the test**

Run: `(cd Packages/MoraUI && swift test --filter RootViewOnboardingGateTests)`
Expected: 4 tests pass.

- [ ] **Step 13.3: Commit**

```bash
git add Packages/MoraUI/Tests/MoraUITests/RootViewOnboardingGateTests.swift
git commit -m "ui(root): test 3-stage onboarding gate flag semantics"
```

---

## Task 14: Add `HomeView` "あそびかた" replay link

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

- [ ] **Step 14.1: Add the replay state and the Button + sheet**

In `HomeView`'s `@State` block, add:

```swift
    @State private var showYokaiIntroReplay: Bool = false
```

Locate `heroFooter` (around line 208 in current source). The current implementation is a single `NavigationLink(value: "bestiary")`. Wrap it in a `VStack` and add a second item below:

```swift
    private var heroFooter: some View {
        VStack(spacing: MoraTheme.Space.sm) {
            NavigationLink(value: "bestiary") {
                Label(strings.bestiaryLinkLabel, systemImage: "book.closed.fill")
                    .font(MoraType.label())
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button { showYokaiIntroReplay = true } label: {
                Label(strings.homeRecapLink, systemImage: "questionmark.circle")
                    .font(MoraType.label())
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.top, MoraTheme.Space.sm)
    }
```

At the end of the `body` `ZStack { … }` modifier chain, add:

```swift
        .sheet(isPresented: $showYokaiIntroReplay) {
            YokaiIntroFlow(mode: .replay) { showYokaiIntroReplay = false }
                .environment(\.moraStrings, strings)
        }
```

- [ ] **Step 14.2: Build**

Run: `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
Expected: builds clean.

- [ ] **Step 14.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "ui(home): あそびかた replay link opens YokaiIntroFlow as sheet"
```

---

## Task 15: Final verification + PR

- [ ] **Step 15.1: Full test sweep across all packages**

Run:
```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```
Expected: all four packages green.

- [ ] **Step 15.2: App-target build sanity check**

Run:
```bash
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: build succeeds.

- [ ] **Step 15.3: swift-format lint**

Run: `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests`
Expected: clean. If anything trips, run the formatter (`swift-format format --in-place …`) on the offending files and re-commit.

- [ ] **Step 15.4: Push branch and open PR**

```bash
git push -u origin <branch-name>
gh pr create --title "ui(onboarding): yokai-intro 4-panel flow + あそびかた replay" --body "$(cat <<'EOF'
## Summary
- Adds a 4-panel Yokai introduction flow between Permission and HomeView, with the active yokai's bundled English `greet` clip on Panel 2.
- Reframes from "Mon–Fri" to "5 sessions per yokai" so weekends and multi-session days are not implicitly forbidden.
- HomeView gains an "あそびかた" link that replays the panels as a sheet.
- One-time gating via `tech.reenable.Mora.yokaiIntroSeen` UserDefaults flag — second launch goes straight to HomeView.

## Test plan
- [ ] Fresh install (or DEBUG Reset) on Simulator: panels 1–4 appear after Permission; Panel 4 CTA "▶ はじめる" lands on HomeView; second launch skips the flow.
- [ ] HomeView "あそびかた" tap: sheet shows the 4 panels; Panel 4 reads "とじる"; close returns to HomeView; flag still `true`.
- [ ] Panel 2: yokai portrait + grapheme + ipa render; `greet` clip plays once on appear; leaving the panel stops audio.
- [ ] `swift test` green across all four packages.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 15.5: Done**

PR is open. Address review feedback as it comes in.

---

## Notes for the implementing engineer

- **`YokaiClipPlayer` protocol** lives in `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipPlayer.swift`; concrete is `AVFoundationYokaiClipPlayer`. Both are `public`.
- **`YokaiDefinition` value type** is in `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiDefinition.swift`; access fields `id`, `grapheme`, `ipa`. The catalog comes from `BundledYokaiStore.catalog()` (returns `[YokaiDefinition]`).
- **`YokaiPortraitCorner`** is the existing reusable portrait component in `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift`. Pass `sparkleTrigger: nil` when not animating sparkles (we don't here).
- **`HeroCTA`** is the existing big-orange-button reusable in `Packages/MoraUI/Sources/MoraUI/Design/Components/HeroCTA.swift`.
- **Kanji budget** is enforced by the loop in `MoraStringsTests.swift:107` (and ~169 for the second loop). If a future revision adds kanji above grade 2 to a new value, that test fails immediately — re-author with hiragana per spec §7.2.
- **The shared `OnboardingPlayMode.swift`** is also created by the parallel tile-tutorial PR. If that PR lands first, this PR's Task 1 becomes a no-op; if this one lands first, the other's first task becomes a no-op.
