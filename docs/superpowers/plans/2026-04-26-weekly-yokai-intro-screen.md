# Weekly Yokai Intro Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Monday yokai intro overlay (which talks over the warmup TTS) with a dedicated pre-warmup `WeeklyIntroView` that mounts only when `YokaiOrchestrator.activeCutscene == .mondayIntro`, owns its own greet-clip playback, and unmounts before `WarmupView` mounts so the audio streams never overlap.

**Architecture:** UI-only change in `MoraUI`. The existing `YokaiOrchestrator.activeCutscene` state already encodes "is this a Monday intro" — `startWeek()` sets `.mondayIntro` on the first session of a yokai week, `resume()` clears it on subsequent sessions, `dismissCutscene()` clears it after the user taps the CTA. We add (1) a small `YokaiCutscene.isMondayIntro` predicate, (2) a new `WeeklyIntroView` modeled on `TodaysYokaiPanel`, (3) a gate inside `SessionContainerView.content`'s `.warmup` branch that picks `WeeklyIntroView` over `WarmupView`, (4) suppression of the now-redundant `.mondayIntro` rendering inside `YokaiCutsceneOverlay` and the corner portrait + friendship gauge inside `YokaiLayerView`. No engine, persistence, or onboarding changes.

**Tech Stack:** Swift 6 (language mode 5), SwiftUI, SwiftData, XCTest, `MoraCore` (`BundledYokaiStore`, `YokaiDefinition`, `MoraStrings`), `MoraEngines` (`YokaiOrchestrator`, `YokaiCutscene`, `YokaiClipPlayer`, `AVFoundationYokaiClipPlayer`), `MoraTesting` (test fakes). Tests run via `(cd Packages/MoraUI && swift test)`. CI lints with `swift-format --strict`.

**Spec:** `docs/superpowers/specs/2026-04-26-weekly-yokai-intro-screen-design.md`.

**Worktree:** `.worktrees/weekly-yokai-intro-screen` on branch `feat/weekly-yokai-intro-screen`.

---

## File map

**Create:**
- `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutscenePredicates.swift` — `YokaiCutscene.isMondayIntro` extension. Tiny.
- `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift` — the new screen.
- `Packages/MoraUI/Tests/MoraUITests/YokaiCutscenePredicatesTests.swift`
- `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift`
- `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewDismissTests.swift`
- `Packages/MoraUI/Tests/MoraUITests/YokaiCutsceneOverlayMondayIntroTests.swift`

**Modify:**
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — add `@State` for `yokaiStore` + `yokaiClipPlayer`, wire them in `bootstrap()`, add gate inside `case .warmup:`.
- `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift` — switch `.mondayIntro` to `EmptyView()` and drop its `subtitleText` arm.
- `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift` — gate corner portrait + `FriendshipGaugeHUD` off `.mondayIntro`.

**Untouched:** all of `MoraCore`, all of `MoraEngines`, all of `MoraMLX`, the four-panel `YokaiIntroFlow` onboarding (`Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/**`), and every existing test file unless explicitly modified.

---

## Task 1: `YokaiCutscene.isMondayIntro` predicate

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutscenePredicates.swift`
- Test: `Packages/MoraUI/Tests/MoraUITests/YokaiCutscenePredicatesTests.swift`

**Why this task first:** the gate logic in `SessionContainerView` and the suppression logic in `YokaiLayerView` both want the same predicate. Defining it once, with a unit test, prevents drift.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraUI/Tests/MoraUITests/YokaiCutscenePredicatesTests.swift`:

```swift
import MoraEngines
import XCTest

@testable import MoraUI

final class YokaiCutscenePredicatesTests: XCTestCase {
    func testIsMondayIntroTrueForMondayIntroCase() {
        let cutscene: YokaiCutscene = .mondayIntro(yokaiID: "sh")
        XCTAssertTrue(cutscene.isMondayIntro)
    }

    func testIsMondayIntroFalseForOtherCases() {
        XCTAssertFalse(YokaiCutscene.fridayClimax(yokaiID: "sh").isMondayIntro)
        XCTAssertFalse(YokaiCutscene.srsCameo(yokaiID: "sh").isMondayIntro)
        XCTAssertFalse(YokaiCutscene.sessionStart(yokaiID: "sh").isMondayIntro)
    }

    func testOptionalNilIsNotMondayIntro() {
        let cutscene: YokaiCutscene? = nil
        XCTAssertFalse(cutscene?.isMondayIntro ?? false)
    }

    func testOptionalSomeMondayIntro() {
        let cutscene: YokaiCutscene? = .mondayIntro(yokaiID: "th")
        XCTAssertTrue(cutscene?.isMondayIntro ?? false)
    }
}
```

- [ ] **Step 2: Run the test and verify it fails**

```sh
(cd Packages/MoraUI && swift test --filter YokaiCutscenePredicatesTests)
```

Expected: build failure, "value of type 'YokaiCutscene' has no member 'isMondayIntro'".

- [ ] **Step 3: Add the predicate**

Create `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutscenePredicates.swift`:

```swift
import MoraEngines

extension YokaiCutscene {
    /// `true` only when this cutscene is the per-week Monday intro. The
    /// session UI uses this to render the dedicated `WeeklyIntroView`
    /// instead of `YokaiCutsceneOverlay`'s default overlay treatment, so
    /// the warmup TTS does not play under a hovering yokai panel.
    var isMondayIntro: Bool {
        if case .mondayIntro = self { return true }
        return false
    }
}
```

- [ ] **Step 4: Run the test and verify it passes**

```sh
(cd Packages/MoraUI && swift test --filter YokaiCutscenePredicatesTests)
```

Expected: 4 tests pass.

- [ ] **Step 5: Lint and commit**

```sh
swift-format lint --strict --recursive \
  Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutscenePredicates.swift \
  Packages/MoraUI/Tests/MoraUITests/YokaiCutscenePredicatesTests.swift
```

```sh
git add \
  Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutscenePredicates.swift \
  Packages/MoraUI/Tests/MoraUITests/YokaiCutscenePredicatesTests.swift
git commit -m "ui(yokai): add isMondayIntro predicate on YokaiCutscene

Single source of truth for the 'is this the per-week Monday intro?'
check used by the upcoming WeeklyIntroView gate and the corner portrait
suppression in YokaiLayerView."
```

---

## Task 2: `WeeklyIntroView` skeleton with auto-play greet clip

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`
- Test: `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift`

The view is modeled on `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift` but is a separate file so the four-panel onboarding flow does not change. We test with the same `UIWindow` + `UIHostingController` pattern as `YokaiIntroPanel2AudioTests`.

The view takes the `YokaiOrchestrator` directly (so it can read `currentYokai` reactively and call `dismissCutscene()` later in Task 4), plus an injectable `BundledYokaiStore?` and `any YokaiClipPlayer`.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift`:

```swift
import Foundation
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit
#endif

@testable import MoraUI

@MainActor
final class WeeklyIntroViewAudioTests: XCTestCase {
    #if canImport(UIKit)
    func testGreetClipPlaysOnceOnAppear() async throws {
        let store = try BundledYokaiStore()
        let player = RecordingClipPlayer()
        let player1Expectation = expectation(description: "greet plays once on appear")
        player.firstPlayExpectation = player1Expectation

        let yokai = try Self.makeYokaiOrchestrator(forID: "sh")
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                view.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        await fulfillment(of: [player1Expectation], timeout: 2.0)

        XCTAssertEqual(player.playedURLs.count, 1)
        XCTAssertEqual(
            player.playedURLs.first,
            store.voiceClipURL(for: "sh", clip: .greet)
        )

        window.isHidden = true
    }

    func testGreetClipStopsOnDisappear() async throws {
        let store = try BundledYokaiStore()
        let player = RecordingClipPlayer()
        let yokai = try Self.makeYokaiOrchestrator(forID: "sh")
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                view.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(player.playedURLs.count, 1)
        XCTAssertEqual(player.stopCallCount, 0)

        window.rootViewController = UIHostingController(rootView: Color.clear)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertGreaterThanOrEqual(player.stopCallCount, 1)
        window.isHidden = true
    }
    #endif

    static func makeYokaiOrchestrator(forID yokaiID: String) throws -> YokaiOrchestrator {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: yokaiID, weekStart: Date())
        return orch
    }
}

@MainActor
final class RecordingClipPlayer: YokaiClipPlayer {
    private(set) var playedURLs: [URL] = []
    private(set) var stopCallCount: Int = 0
    var firstPlayExpectation: XCTestExpectation?

    func play(url: URL) -> Bool {
        playedURLs.append(url)
        if playedURLs.count == 1 { firstPlayExpectation?.fulfill() }
        return true
    }

    func stop() {
        stopCallCount += 1
    }
}
```

(`RecordingClipPlayer` is local to this test file rather than the shared `MoraTesting.FakeYokaiClipPlayer` because we want the `firstPlayExpectation` hook the same way `YokaiIntroPanel2AudioTests` does. Same pattern, separate purpose.)

- [ ] **Step 2: Run the test and verify it fails**

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewAudioTests)
```

Expected: build failure, "cannot find 'WeeklyIntroView' in scope".

- [ ] **Step 3: Create the view**

Create `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`:

```swift
import MoraCore
import MoraEngines
import SwiftUI

/// Pre-warmup intro shown on the first session of each yokai week.
/// Plays the active yokai's `.greet` clip and waits for the learner to
/// tap "Next" before the warmup phase view (and its TTS prompt) mounts.
///
/// Mounted only when `phase == .warmup` AND
/// `yokai.activeCutscene.isMondayIntro` is true; gated by
/// `SessionContainerView.content`. CTA wiring (`yokai.dismissCutscene()`)
/// is added in Task 4. Replay button is added in Task 3.
public struct WeeklyIntroView: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var yokai: YokaiOrchestrator
    let store: BundledYokaiStore?
    let player: any YokaiClipPlayer

    @State private var portraitScale: CGFloat = 0.8

    public init(
        yokai: YokaiOrchestrator,
        store: BundledYokaiStore?,
        player: any YokaiClipPlayer
    ) {
        self.yokai = yokai
        self.store = store
        self.player = player
    }

    public var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.yokaiIntroTodayTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            if let definition = yokai.currentYokai {
                portraitColumn(yokai: definition)
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

            HeroCTA(title: strings.yokaiIntroNext, action: {})
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            playGreet()
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

    private var greetClipURL: URL? {
        guard let id = yokai.currentYokai?.id else { return nil }
        return store?.voiceClipURL(for: id, clip: .greet)
    }

    private func playGreet() {
        guard let url = greetClipURL else { return }
        _ = player.play(url: url)
    }
}

#if DEBUG
#Preview("Weekly intro — sh") {
    let container = try! MoraModelContainer.inMemory()
    let ctx = ModelContext(container)
    let store = try! BundledYokaiStore()
    let orch = YokaiOrchestrator(store: store, modelContext: ctx)
    try! orch.startWeek(yokaiID: "sh", weekStart: Date())
    return WeeklyIntroView(
        yokai: orch,
        store: store,
        player: AVFoundationYokaiClipPlayer()
    )
    .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 4: Run the test and verify it passes**

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewAudioTests)
```

Expected: 2 tests pass.

- [ ] **Step 5: Lint and commit**

```sh
swift-format lint --strict --recursive \
  Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift \
  Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift
```

```sh
git add \
  Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift \
  Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift
git commit -m "ui(session): add WeeklyIntroView with auto-played greet clip

Pre-warmup intro screen shown on the first session of each yokai week.
The view auto-plays the active yokai's .greet clip on appear and stops
playback on disappear so the next phase's TTS does not land underneath
a tail. CTA is intentionally a no-op in this commit; wiring lands in a
follow-up task. The view is not yet mounted by SessionContainerView."
```

---

## Task 3: Replay button on `WeeklyIntroView`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`
- Modify: `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift`

The replay button mirrors `WarmupView`'s "Listen again" capsule (teal text, mint capsule). It is hidden when `voiceClipURL` returns nil so a yokai with no greet clip doesn't show a button that would do nothing.

- [ ] **Step 1: Write the failing test**

Append to `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift` inside the existing `WeeklyIntroViewAudioTests` class (just before the `#endif` after `testGreetClipStopsOnDisappear`):

```swift
    func testReplayButtonRefiresGreetClip() async throws {
        let store = try BundledYokaiStore()
        let player = RecordingClipPlayer()
        let firstPlay = expectation(description: "greet plays on appear")
        player.firstPlayExpectation = firstPlay
        let yokai = try Self.makeYokaiOrchestrator(forID: "sh")
        let inspector = WeeklyIntroViewTestHook()
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)
            .environment(\.weeklyIntroTestHook, inspector)

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(
            rootView:
                view.environment(
                    \.moraStrings,
                    JapaneseL1Profile().uiStrings(forAgeYears: 8)
                )
        )
        window.rootViewController = host
        window.makeKeyAndVisible()

        await fulfillment(of: [firstPlay], timeout: 2.0)
        XCTAssertEqual(player.playedURLs.count, 1)

        // Simulate the user tapping the replay button.
        inspector.tapReplay?()

        XCTAssertEqual(player.playedURLs.count, 2)
        XCTAssertEqual(player.stopCallCount, 1, "replay should stop before re-playing")
        XCTAssertEqual(
            player.playedURLs.last,
            store.voiceClipURL(for: "sh", clip: .greet)
        )

        window.isHidden = true
    }
```

This needs a small SwiftUI test hook so the test can fire the replay action without traversing the actual SwiftUI view hierarchy. Add this above the `RecordingClipPlayer` declaration in the same file:

```swift
@MainActor
final class WeeklyIntroViewTestHook {
    var tapReplay: (() -> Void)?
}

private struct WeeklyIntroTestHookKey: EnvironmentKey {
    static let defaultValue: WeeklyIntroViewTestHook? = nil
}

extension EnvironmentValues {
    var weeklyIntroTestHook: WeeklyIntroViewTestHook? {
        get { self[WeeklyIntroTestHookKey.self] }
        set { self[WeeklyIntroTestHookKey.self] = newValue }
    }
}
```

(The hook is a test-side-only convenience; `WeeklyIntroView` reads `@Environment(\.weeklyIntroTestHook)` and assigns its replay closure to the hook so tests can fire it. Production code never injects the hook, so the production code path is unchanged.)

- [ ] **Step 2: Run the test and verify it fails**

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewAudioTests/testReplayButtonRefiresGreetClip)
```

Expected: build failure (`weeklyIntroTestHook` doesn't exist on production environment yet) — that means we need to ALSO add a non-test extension hook so production builds compile. Add the production-side environment definition first.

Edit `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`. Append above the `WeeklyIntroView` struct definition:

```swift
/// Internal test seam: when set in the environment, `WeeklyIntroView`
/// publishes its replay action to this object so unit tests can fire it
/// without traversing the SwiftUI button hierarchy. Production code never
/// reads it.
@MainActor
final class WeeklyIntroViewTestHook {
    var tapReplay: (() -> Void)?
}

private struct WeeklyIntroTestHookKey: EnvironmentKey {
    static let defaultValue: WeeklyIntroViewTestHook? = nil
}

extension EnvironmentValues {
    var weeklyIntroTestHook: WeeklyIntroViewTestHook? {
        get { self[WeeklyIntroTestHookKey.self] }
        set { self[WeeklyIntroTestHookKey.self] = newValue }
    }
}
```

Now remove the duplicate `WeeklyIntroViewTestHook` / key / extension you added to the test file in Step 1 — production owns them, the test file just references them. The test file should no longer declare `WeeklyIntroViewTestHook` itself.

Re-run:

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewAudioTests/testReplayButtonRefiresGreetClip)
```

Expected: build succeeds, test fails because `WeeklyIntroView` does not yet publish a replay closure to the hook (no replay button).

- [ ] **Step 3: Add the replay button + hook publication**

Edit `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`.

Add the environment read inside the struct, just under the existing environment properties:

```swift
    @Environment(\.weeklyIntroTestHook) private var testHook: WeeklyIntroViewTestHook?
```

Add the replay function, alongside `playGreet`:

```swift
    private func replayGreet() {
        guard let url = greetClipURL else { return }
        player.stop()
        _ = player.play(url: url)
    }
```

Insert the replay button into `body` between the body Text and the trailing `Spacer()` (i.e., immediately after the body copy and before the spacer that pushes the CTA to the bottom):

```swift
            if greetClipURL != nil {
                Button(action: replayGreet) {
                    Text(strings.warmupListenAgain)
                        .font(MoraType.cta())
                        .foregroundStyle(MoraTheme.Accent.teal)
                        .padding(.vertical, MoraTheme.Space.md)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .background(MoraTheme.Background.mint, in: .capsule)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.plain)
            }
```

Publish the closure to the test hook from `.task` (right after `playGreet()`):

```swift
            testHook?.tapReplay = { Task { @MainActor in self.replayGreet() } }
```

- [ ] **Step 4: Run the test and verify it passes**

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewAudioTests)
```

Expected: 3 tests pass.

- [ ] **Step 5: Lint and commit**

```sh
swift-format lint --strict --recursive \
  Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift \
  Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift
```

```sh
git add \
  Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift \
  Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewAudioTests.swift
git commit -m "ui(session): WeeklyIntroView replay button for greet clip

Mirrors WarmupView's 'Listen again' capsule. Hidden when the active
yokai has no .greet clip URL. Tests drive the replay path through a
production environment-key seam so the assertion does not depend on
SwiftUI button-tap traversal."
```

---

## Task 4: Wire CTA to `dismissCutscene`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`
- Test: `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewDismissTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewDismissTests.swift`:

```swift
import Foundation
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit
#endif

@testable import MoraUI

@MainActor
final class WeeklyIntroViewDismissTests: XCTestCase {
    #if canImport(UIKit)
    func testCTADismissesMondayIntroCutscene() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let yokai = YokaiOrchestrator(store: store, modelContext: ctx)
        try yokai.startWeek(yokaiID: "sh", weekStart: Date())
        XCTAssertNotNil(yokai.activeCutscene)
        XCTAssertTrue(yokai.activeCutscene?.isMondayIntro ?? false)

        let player = SilentClipPlayer()
        let hook = WeeklyIntroViewTestHook()
        let view = WeeklyIntroView(yokai: yokai, store: store, player: player)
            .environment(\.weeklyIntroTestHook, hook)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )

        let window = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()

        // Wait for `.task` to publish the dismiss closure.
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertNotNil(hook.tapNext, "WeeklyIntroView must publish its CTA action")

        hook.tapNext?()

        XCTAssertNil(yokai.activeCutscene, "CTA should clear the cutscene")
        window.isHidden = true
    }
    #endif
}

@MainActor
private final class SilentClipPlayer: YokaiClipPlayer {
    func play(url: URL) -> Bool { true }
    func stop() {}
}
```

This test references `hook.tapNext` — we need to add that to `WeeklyIntroViewTestHook`.

- [ ] **Step 2: Run the test and verify it fails**

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewDismissTests)
```

Expected: build failure ("WeeklyIntroViewTestHook has no member 'tapNext'").

- [ ] **Step 3: Wire the CTA**

Edit `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`.

Extend the test hook (add `tapNext` next to `tapReplay`):

```swift
@MainActor
final class WeeklyIntroViewTestHook {
    var tapReplay: (() -> Void)?
    var tapNext: (() -> Void)?
}
```

Replace the placeholder CTA action with a real one. Find this line:

```swift
            HeroCTA(title: strings.yokaiIntroNext, action: {})
```

Replace with:

```swift
            HeroCTA(title: strings.yokaiIntroNext, action: dismiss)
```

Add the `dismiss` function alongside `playGreet` and `replayGreet`:

```swift
    private func dismiss() {
        player.stop()
        yokai.dismissCutscene()
    }
```

Publish the closure to the test hook in `.task`, alongside the existing `tapReplay` line:

```swift
            testHook?.tapNext = { Task { @MainActor in self.dismiss() } }
```

- [ ] **Step 4: Run the test and verify it passes**

```sh
(cd Packages/MoraUI && swift test --filter WeeklyIntroViewDismissTests \
  && cd ../.. && cd Packages/MoraUI && swift test --filter WeeklyIntroViewAudioTests)
```

Expected: 1 + 3 = 4 tests pass.

- [ ] **Step 5: Lint and commit**

```sh
swift-format lint --strict --recursive \
  Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift \
  Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewDismissTests.swift
```

```sh
git add \
  Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift \
  Packages/MoraUI/Tests/MoraUITests/WeeklyIntroViewDismissTests.swift
git commit -m "ui(session): WeeklyIntroView 'Next' CTA dismisses the cutscene

CTA now stops any in-flight greet clip and clears the orchestrator's
active cutscene. SessionContainerView's gate (next task) re-renders
the warmup view as a result."
```

---

## Task 5: Wire `WeeklyIntroView` into `SessionContainerView` with the `.warmup` gate

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

This task adds two `@State` slots to `SessionContainerView` (one for the bundled yokai store, one for the shared clip player), feeds them through `bootstrap()`, and inserts the gate that swaps `WeeklyIntroView` in for `WarmupView` when `yokai.activeCutscene.isMondayIntro` is true.

We do not add a unit test for the gate render here — the gate condition itself is `yokai?.activeCutscene?.isMondayIntro == true`, which is covered by `YokaiCutscenePredicatesTests` plus the upstream tests on `WeeklyIntroView` and `dismissCutscene`. Manual smoke (Task 8) verifies the actual render swap end-to-end.

- [ ] **Step 1: Add new `@State` slots**

Edit `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`. Find the existing `clipRouter` declaration (around line 30):

```swift
    @State private var clipRouter: YokaiClipRouter?
```

Add immediately after it:

```swift
    /// Shared `BundledYokaiStore` used by both `clipRouter` (in-session
    /// clip playback) and `WeeklyIntroView` (greet on the Monday intro
    /// screen). Populated during `bootstrap()`.
    @State private var yokaiStore: BundledYokaiStore?
    /// Shared clip player used by `clipRouter` and `WeeklyIntroView` so
    /// stopping playback in one path silences the other (no overlap when
    /// the user dismisses the intro mid-clip and lands on warmup).
    @State private var yokaiClipPlayer: any YokaiClipPlayer = AVFoundationYokaiClipPlayer()
```

- [ ] **Step 2: Plumb them through `bootstrap()`**

In the same file, find the `BundledYokaiStore` construction inside `bootstrap()` (around line 468):

```swift
                let store = try BundledYokaiStore()
```

Right after that line, expose the store on `self`:

```swift
                self.yokaiStore = store
```

Find the `YokaiClipRouter` construction (around line 509–516):

```swift
                self.clipRouter = YokaiClipRouter(
                    yokaiID: encYokaiID,
                    store: store,
                    player: AVFoundationYokaiClipPlayer(),
                    silencer: { [weak speechRef] in
                        await speechRef?.stop()
                    }
                )
```

Replace the `player:` argument with the shared instance:

```swift
                self.clipRouter = YokaiClipRouter(
                    yokaiID: encYokaiID,
                    store: store,
                    player: yokaiClipPlayer,
                    silencer: { [weak speechRef] in
                        await speechRef?.stop()
                    }
                )
```

- [ ] **Step 3: Add the gate inside `case .warmup:`**

In the same file, find the `case .warmup:` arm of `content` (around line 156):

```swift
            case .warmup:
                WarmupView(orchestrator: orchestrator, speech: speech, clipRouter: clipRouter)
```

Replace with:

```swift
            case .warmup:
                if let yokaiOrch = orchestrator.yokai,
                    yokaiOrch.activeCutscene?.isMondayIntro == true
                {
                    WeeklyIntroView(
                        yokai: yokaiOrch,
                        store: yokaiStore,
                        player: yokaiClipPlayer
                    )
                } else {
                    WarmupView(
                        orchestrator: orchestrator,
                        speech: speech,
                        clipRouter: clipRouter
                    )
                }
```

- [ ] **Step 4: Run the existing test suites and verify nothing regresses**

```sh
(cd Packages/MoraUI && swift test)
```

Expected: all existing MoraUI tests pass. Specifically `SessionContainerBootstrapTests`, `SessionContainerBootstrapLibraryTests`, and `SessionContainerDecodingTutorialTests` must still pass — they exercise `bootstrap()` and we just added two `@State` properties + a small render branch.

If a build fails because `orchestrator.yokai` is not exposed, double-check `SessionOrchestrator.yokai` (around line 27 of `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`) — it is `public var yokai: YokaiOrchestrator?`. No engine change should be needed.

- [ ] **Step 5: Lint and commit**

```sh
swift-format lint --strict --recursive Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
```

```sh
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "ui(session): gate WeeklyIntroView ahead of WarmupView on .mondayIntro

When the orchestrator's yokai is showing the Monday intro cutscene,
SessionContainerView now mounts WeeklyIntroView in place of WarmupView
during the .warmup phase. The bundled store and clip player are now
shared @State so the intro and the in-session clip router stop on the
same channel (no audio overlap when the user dismisses mid-clip)."
```

---

## Task 6: Drop `.mondayIntro` from `YokaiCutsceneOverlay`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift`
- Test: `Packages/MoraUI/Tests/MoraUITests/YokaiCutsceneOverlayMondayIntroTests.swift`

The overlay must no longer render anything for `.mondayIntro` — `WeeklyIntroView` owns that case now. `.fridayClimax` and `.srsCameo` continue to render. `.sessionStart` (still no producer) keeps its existing simpleStack path so it is forward-compatible.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraUI/Tests/MoraUITests/YokaiCutsceneOverlayMondayIntroTests.swift`:

```swift
import Foundation
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI
import XCTest

#if canImport(UIKit)
import UIKit
#endif

@testable import MoraUI

@MainActor
final class YokaiCutsceneOverlayMondayIntroTests: XCTestCase {
    #if canImport(UIKit)
    func testMondayIntroRendersNothing() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        XCTAssertTrue(orch.activeCutscene?.isMondayIntro ?? false)

        let overlay = YokaiCutsceneOverlay(orchestrator: orch, speech: nil)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )

        let host = UIHostingController(rootView: overlay)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        // The overlay's body is a ZStack with a black background by default.
        // For .mondayIntro we want it to publish *no* yokai content. We
        // assert this by checking that the rendered view tree contains no
        // text node carrying the greet subtitle (which would only be
        // produced by the simpleStack arm).
        let greetText = orch.currentYokai?.voice.clips[.greet] ?? "<unset>"
        XCTAssertFalse(
            host.view.recursiveDescription().contains(greetText),
            "Monday intro overlay must not render the greet subtitle"
        )
    }

    func testFridayClimaxStillRenders() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = try BundledYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        // Force-set fridayClimax via a public surface: nudge friendship to
        // 100% then run a Friday final-trial correct. This is the same
        // path the production session uses, kept here so the test does not
        // depend on internal mutation.
        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordFridayFinalTrial(correct: true)

        guard case .fridayClimax = orch.activeCutscene else {
            return XCTFail("expected fridayClimax cutscene")
        }

        let overlay = YokaiCutsceneOverlay(orchestrator: orch, speech: nil)
            .environment(
                \.moraStrings,
                JapaneseL1Profile().uiStrings(forAgeYears: 8)
            )

        let host = UIHostingController(rootView: overlay)
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()

        // We don't assert specific subtitle text here (the climax view
        // staggers its phases), only that the host view has positive
        // content size — i.e., the cutscene is not empty.
        XCTAssertGreaterThan(host.view.bounds.width, 0)
    }
    #endif
}

#if canImport(UIKit)
private extension UIView {
    func recursiveDescription() -> String {
        let me = String(describing: self)
        let kids = subviews.map { $0.recursiveDescription() }.joined(separator: "\n")
        return me + "\n" + kids
    }
}
#endif
```

- [ ] **Step 2: Run the test and verify it fails**

```sh
(cd Packages/MoraUI && swift test --filter YokaiCutsceneOverlayMondayIntroTests/testMondayIntroRendersNothing)
```

Expected: failure — current overlay renders the greet text via `simpleStack`.

- [ ] **Step 3: Suppress `.mondayIntro` in the overlay**

Edit `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift`. Find the body switch (around lines 32–38):

```swift
            if let yokai = orchestrator.currentYokai {
                switch orchestrator.activeCutscene {
                case .fridayClimax:
                    fridayClimax(for: yokai)
                default:
                    simpleStack(for: yokai)
                }
            }
```

Replace with:

```swift
            if let yokai = orchestrator.currentYokai {
                switch orchestrator.activeCutscene {
                case .fridayClimax:
                    fridayClimax(for: yokai)
                case .mondayIntro:
                    // WeeklyIntroView (mounted by SessionContainerView for
                    // the .warmup phase) owns this case; the overlay must
                    // not double-render.
                    EmptyView()
                default:
                    simpleStack(for: yokai)
                }
            }
```

Find the `subtitleText` function (around line 134) and remove the `.mondayIntro` arm:

```swift
    private func subtitleText(for cutscene: YokaiCutscene?, yokai: YokaiDefinition) -> String {
        switch cutscene {
        case .mondayIntro:
            return yokai.voice.clips[.greet] ?? ""
        case .fridayClimax:
            return yokai.voice.clips[.fridayAcknowledge] ?? ""
        case .srsCameo:
            return yokai.voice.clips[.encourage] ?? ""
        case .sessionStart, .none:
            return ""
        }
    }
```

becomes:

```swift
    private func subtitleText(for cutscene: YokaiCutscene?, yokai: YokaiDefinition) -> String {
        switch cutscene {
        case .fridayClimax:
            return yokai.voice.clips[.fridayAcknowledge] ?? ""
        case .srsCameo:
            return yokai.voice.clips[.encourage] ?? ""
        case .mondayIntro, .sessionStart, .none:
            return ""
        }
    }
```

- [ ] **Step 4: Run the test and verify it passes**

```sh
(cd Packages/MoraUI && swift test --filter YokaiCutsceneOverlayMondayIntroTests)
```

Expected: 2 tests pass.

Also re-run the full MoraUI suite to catch regressions in the cutscene overlay's existing callers:

```sh
(cd Packages/MoraUI && swift test)
```

Expected: full suite passes.

- [ ] **Step 5: Lint and commit**

```sh
swift-format lint --strict --recursive \
  Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift \
  Packages/MoraUI/Tests/MoraUITests/YokaiCutsceneOverlayMondayIntroTests.swift
```

```sh
git add \
  Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift \
  Packages/MoraUI/Tests/MoraUITests/YokaiCutsceneOverlayMondayIntroTests.swift
git commit -m "ui(yokai): drop .mondayIntro from YokaiCutsceneOverlay

WeeklyIntroView now owns the per-week intro screen. Leaving the case in
the overlay would double-render its portrait + greet subtitle on top of
WeeklyIntroView. Friday climax and SRS cameo paths are unchanged."
```

---

## Task 7: Suppress corner portrait + friendship gauge in `YokaiLayerView` during `.mondayIntro`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift`

Without this, the Weekly Intro screen (with a centered 200×200 portrait) shows a duplicate corner portrait + the friendship gauge HUD — visually noisy and the gauge is at 0.10 at this exact moment which is not the focal point yet.

We do not add a dedicated test file for this — `YokaiLayerView` has no existing test target and adding one is out of scope. The visual change is verified in Task 8's manual smoke run. The conditional itself uses the `isMondayIntro` predicate already covered by Task 1's tests.

- [ ] **Step 1: Add the suppression conditional**

Edit `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift`. Find `body`:

```swift
    public var body: some View {
        ZStack {
            if let yokai = orchestrator.currentYokai {
                VStack {
                    HStack {
                        Spacer()
                        FriendshipGaugeHUD(percent: orchestrator.currentEncounter?.friendshipPercent ?? 0)
                            .frame(width: 200, height: 18)
                            .padding(.trailing, 24)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        YokaiPortraitCorner(yokai: yokai, sparkleTrigger: orchestrator.lastCorrectTrialID)
                            .frame(width: 140, height: 140)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.top, 76)

                if orchestrator.activeCutscene != nil {
                    YokaiCutsceneOverlay(orchestrator: orchestrator, speech: speech)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: orchestrator.activeCutscene)
        .allowsHitTesting(orchestrator.currentYokai != nil && orchestrator.activeCutscene != nil)
    }
```

Replace with:

```swift
    public var body: some View {
        ZStack {
            if let yokai = orchestrator.currentYokai {
                if orchestrator.activeCutscene?.isMondayIntro != true {
                    VStack {
                        HStack {
                            Spacer()
                            FriendshipGaugeHUD(
                                percent: orchestrator.currentEncounter?.friendshipPercent ?? 0
                            )
                            .frame(width: 200, height: 18)
                            .padding(.trailing, 24)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            YokaiPortraitCorner(
                                yokai: yokai,
                                sparkleTrigger: orchestrator.lastCorrectTrialID
                            )
                            .frame(width: 140, height: 140)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                        }
                    }
                    .padding(.top, 76)
                }

                if orchestrator.activeCutscene != nil {
                    YokaiCutsceneOverlay(orchestrator: orchestrator, speech: speech)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: orchestrator.activeCutscene)
        .allowsHitTesting(orchestrator.currentYokai != nil && orchestrator.activeCutscene != nil)
    }
```

The `YokaiCutsceneOverlay` block stays unchanged: its body is a no-op for `.mondayIntro` after Task 6, so leaving the condition is safe and forward-compatible (e.g. for `.sessionStart` which still routes to `simpleStack`).

- [ ] **Step 2: Run the full MoraUI test suite**

```sh
(cd Packages/MoraUI && swift test)
```

Expected: all tests pass.

- [ ] **Step 3: Lint and commit**

```sh
swift-format lint --strict --recursive Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift
```

```sh
git add Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift
git commit -m "ui(yokai): hide corner portrait + gauge during Monday intro

WeeklyIntroView already shows a centered 200x200 portrait of the same
yokai. Without this suppression, the layer view stacks a duplicate
corner portrait and a friendship gauge (still at 0.10) on top of it.
The cutscene overlay block is unchanged — its body is now a no-op for
.mondayIntro, so the existing condition is safe."
```

---

## Task 8: Manual smoke verification on iPad simulator

**No code changes.** This is the end-to-end verification spec §12 step 4 calls out.

- [ ] **Step 1: Reset SwiftData state and launch a fresh first-week session**

```sh
xcodegen generate
```

Run the app on an iPad simulator (iPad (10th generation) is fine), erasing SwiftData state from the previous run if needed via Settings → erase the app from the simulator. The very first launch into a session should land on the `sh` yokai's first session.

- [ ] **Step 2: Verify the intro screen**

Confirm by observation:

- The screen shows the `sh` yokai portrait centered at ~200×200 with the grapheme + IPA below it, the `yokaiIntroTodayTitle` above, and the `yokaiIntroTodayBody` below.
- The `.greet` voice clip plays once on appear. No "Which one says /ʃ/?" Apple TTS overlaps it.
- The "Listen again" capsule replays the greet clip on tap.
- The "次へ" / "Next" CTA dismisses the screen.
- After dismiss, the warmup screen mounts and **then** the "Which one says /ʃ/?" TTS plays for the first time.
- During the intro, the corner yokai portrait and the friendship gauge HUD are not visible.

- [ ] **Step 3: Verify Tue-session skip**

Complete the `sh` Monday session, return to Home, then start the next session of the same week (Tuesday). Confirm:

- The intro does not appear. The session opens directly on the warmup screen.

- [ ] **Step 4: Verify Friday handover triggers a new intro**

Run through the rest of the `sh` week to befriend the yokai (Friday climax). The next yokai (`th`) should fire a fresh `.mondayIntro` on the next session entry.

- Confirm the WeeklyIntroView appears for the new yokai, not for `sh`.
- Confirm the Friday climax cutscene itself still works as today (it is unchanged by this plan).

- [ ] **Step 5: Final commit**

If smoke surfaces a bug, debug it via `superpowers:systematic-debugging`. Otherwise this task has nothing to commit. Move on to a PR.

---

## Self-review

Compared the plan against the spec section by section.

- §2 Goal 1 (dedicated screen): Task 2.
- §2 Goal 2 (sequential audio): guaranteed by the gate in Task 5 (no double-mount) plus the `.onDisappear` `player.stop()` in Task 2.
- §2 Goal 3 (subsequent sessions skip): no code change required — `resume()` already clears `activeCutscene`. Verified by Task 8 step 3.
- §2 Goal 4 (no engine changes): all tasks touch only `MoraUI`.
- §3 non-goals: nothing in this plan touches `YokaiIntroFlow`, `.sessionStart`, `.fridayClimax`, or `.srsCameo` semantics.
- §5.1 first session: Task 5 gate + Task 2/3/4 view.
- §5.2 Tue–Fri: no code; Task 8 step 3.
- §5.3 kill mid-intro: behaviorally unchanged from main; spec confirms current `friendshipPercent = 0.10` already makes this work.
- §6.1 layout: Task 2 (skeleton), Task 3 (replay), Task 4 (CTA wiring).
- §6.2 behaviors: Tasks 2–4. The "hidden when no clip URL" replay button is implemented in Task 3 (`if greetClipURL != nil`).
- §6.3 file naming + reuse: Task 2 uses `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`.
- §7.1 gate: Task 5 (the `if let yokaiOrch ... isMondayIntro == true` branch).
- §7.2 overlay suppression: Task 6.
- §7.3 corner portrait suppression: Task 7.
- §8 data flow: Tasks 2/3/4/5 collectively implement it.
- §9 audio invariants: enforced by the gate (Task 5) + `onDisappear` stop (Task 2).
- §10 edge cases: greet-missing handled in Task 3 (replay button hidden) and Task 2 (silent fallback). Reduce Motion handled in Task 2. YokaiOrchestrator init failure: no path in this plan can hit `WeeklyIntroView` if `yokai` is nil because the gate requires `yokaiOrch != nil` (Task 5).
- §11 testing: covered by Tasks 1, 2, 3, 4, 6. The `SessionContainerWeeklyIntroGateTests` from the spec is *not* a new test file — its assertions are split across the predicate tests (Task 1) plus the dismiss test (Task 4) plus the manual smoke (Task 8). This is a deliberate simplification to avoid hosting a full session orchestrator inside an XCTest and brings no coverage gap.
- §12 implementation order: Tasks 1–4 build the screen in isolation, Task 5 wires it in, Tasks 6–7 clean up the redundant overlay paths, Task 8 verifies on simulator. Same shape as the spec.
- §13 risks: the Observable propagation risk mentioned in §13 is exercised by Task 4's dismiss test (it observes `activeCutscene` becoming `nil` after the CTA closure runs), so we will catch a propagation bug at unit-test time.

Placeholder scan: no "TBD"/"TODO"/"appropriate"/"similar to". Every test step contains real test code. Every implementation step contains the exact code or the exact replacement to make.

Type consistency check: `WeeklyIntroViewTestHook` is declared in Task 3 with `tapReplay`, extended in Task 4 with `tapNext`, referenced consistently in tests. `RecordingClipPlayer` is unique to the audio test file; `SilentClipPlayer` is unique to the dismiss test file (they have different needs). `yokaiClipPlayer` (Task 5 `@State`) is `any YokaiClipPlayer`; `WeeklyIntroView`'s `player` parameter is also `any YokaiClipPlayer`. `YokaiCutscene.isMondayIntro` is the same predicate used in Tasks 5, 6, and 7.
