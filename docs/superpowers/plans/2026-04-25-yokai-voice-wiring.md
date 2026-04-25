# Yokai Voice Wiring (PR 1, Track A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire all 8 bundled yokai voice clips per yokai into deterministic session-internal trigger points so a single A-day session audibly plays at least 6 distinct clips on Tue–Thu (no cutscene days).

**Architecture:** Introduce a `@MainActor` `YokaiClipRouter` in `MoraEngines` that owns the active yokai's clip catalog and serializes audio playback against an injected `silencer` closure (so it can drain Apple TTS before clip playback without taking a `SpeechController` dependency from `MoraUI`). `SessionContainerView.bootstrap` constructs the router per session and passes it to `WarmupView`, the decoding-phase `.task(id:)` hook, and `ShortSentencesView`. Streak (`encourage` after 3 consecutive correct) and throttle (`gentle_retry` ≤1 per 5 trials) live in the router; views are pure trigger sources.

**Tech Stack:** Swift 6 (language mode 5), SwiftUI, AVFoundation `AVAudioPlayer`, XCTest, swift-format.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` § 5 (Track A).

---

## Session Progress

Resume here at the start of any new session. Tasks 1–6 are committed and pushed on `feat/yokai-voice-wiring`. **Resume at Task 7.**

| Task | Status | Commits (oldest → fixups) |
|------|--------|----------------------------|
| T1 — `YokaiClipPlayer` protocol + `FakeYokaiClipPlayer` | done | `5384e0d` → `3d0465c` (drop `final`) |
| T2 — `AVFoundationYokaiClipPlayer` concrete            | done | `7c3cb7f` → `5a2bed5` (doc + `prepareToPlay()` + drop redundant `import Foundation` + rename `next`→`newPlayer`) |
| T3 — Router `play()` basic + first router test         | done | `8bf73de` → `90d7329` (swift-format `{ }` → `{}`) |
| T4 — Silencer ordering + missing-URL no-op tests       | done | `0c51a74` (also promoted `FakeYokaiClipPlayer` class + `play(url:)` to `open` for cross-module subclassing — `stop()` stays `public`) → `63d5b7d` (revert `stop()` over-promotion) |
| T5 — `recordCorrect` streak fires `.encourage`         | done | `c6403f4` |
| T6 — `recordIncorrect` throttles `.gentle_retry`       | done | `13f28e5` |
| T7 — `stop()` regression test                          | pending | — |
| T8 + T9 + T10 — View wiring (combined commit)          | pending | — |
| T11 — Six-clips coverage test                          | pending | — |
| T12 — Lint, full build, xcodegen, push (confirm first) | pending | — |

### Deviations from the plan as written

These are real changes that landed on the branch and that the next-session agent should be aware of when reading the plan code blocks below:

1. **`FakeYokaiClipPlayer` is `open class`, not `final` class.** Task 4 promoted the class + `play(url:) -> Bool` to `open` so `TracingYokaiClipPlayer` (in the test target, a different module) can subclass it. `stop()` stays `public`. Task 5 onward should rely on this access shape — there is nothing to do here, but do NOT add `final` back.
2. **`AVFoundationYokaiClipPlayer` has a doc comment, calls `prepareToPlay()` before `play()`, and uses `newPlayer` instead of `next`.** No semantic change vs. the plan's Task 2 code; pure code-review polish. The router's `play(_:)` contract is unchanged.
3. **The router's `play(_:)` already short-circuits before silencer on missing URL.** Task 4's tests pass without further changes to `YokaiClipRouter.swift`. Tasks 5–7 add fields and methods to the same router file but should not change `play(_:)`'s body; they only add new methods (`recordCorrect`, `recordIncorrect`) and private state.
4. **A `swift-format --strict` rule disallows `{ }` in favor of `{}`.** Empty closure literals must use `{}`. Apply this from the start in any new test code.
5. **`OrderRecorder` and `TracingYokaiClipPlayer` already exist** in `YokaiClipRouterTests.swift` (file scope, after the test class brace). T5–T7 tests reuse `FakeYokaiClipPlayer` directly without subclassing, so they don't need these helpers — but don't delete them either.
6. **T5/T6 follow the plan's code blocks verbatim** including the `consecutiveCorrect`/`trialIndex`/`lastGentleRetryTrialIndex: -100` field placement after `stop()`, and the `>= 3` / `>= 5` guards. A code-quality reviewer in the previous session suggested `== 3` and moving the fields up next to `yokaiID/store/player/silencer` — both were declined as plan-prescribed. Do NOT re-litigate; keep the layout and guards as written.
7. **SourceKit lag is loud during these edits.** After each subagent commit, the editor will surface stale "cannot find 'YokaiClipRouter'" / "no member 'recordCorrect'" diagnostics for several minutes. Trust `swift test` output, not the inline diagnostics — actual builds in the previous session were 0 failures across 8 tests at HEAD `13f28e5`.

### What the next-session agent should do

1. Read this section first.
2. Verify current state of the branch: `git log --oneline feat/yokai-voice-wiring --not origin/main` should show 10 task-related commits on top of the spec + plan commits (`dea5e2e`, `9113804`, `a7aeae8`).
3. Verify tests still pass: `(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests)` should report 8 tests, 0 failures (the 3 from T1–T4 plus 2 from T5 plus 3 from T6).
4. Resume at Task 7 below. Do NOT redo Tasks 1–6.
5. The user has confirmed they want subagent-driven execution (one fresh implementer per task + spec reviewer + code-quality reviewer); continue that pattern.
6. The final task (T12) requires user confirmation before pushing — do not push autonomously. (T5 and T6 commits are already pushed to `origin/feat/yokai-voice-wiring` as of the end of the previous session, so a `git push` after T7 will be a fast-forward.)

---

## File Structure

### Files to Create

| Path                                                                              | Responsibility                                                                                                  |
|-----------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipPlayer.swift`            | `@MainActor` protocol abstracting clip playback (`play(url:) -> Bool`, `stop()`).                              |
| `Packages/MoraEngines/Sources/MoraEngines/Yokai/AVFoundationYokaiClipPlayer.swift`| Concrete `YokaiClipPlayer` wrapping `AVAudioPlayer`. Default impl bundled with the package.                    |
| `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift`            | `@MainActor` class with `play(_:) -> Bool`, `recordCorrect()`, `recordIncorrect()`, `stop()`. Throttle + streak.|
| `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`          | XCTest unit tests for router routing, streak, throttle, stop.                                                  |
| `Packages/MoraTesting/Sources/MoraTesting/FakeYokaiClipPlayer.swift`              | Test double recording calls; lets router tests run without AVFoundation.                                       |

### Files to Modify

| Path                                                                                        | Change                                                                                                          |
|---------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`                         | Construct `YokaiClipRouter` in `bootstrap`; pass to `WarmupView` / `ShortSentencesView`; fire `example_N` via `.task(id: completedTrialCount)` in decoding phase; `clipRouter?.stop()` at phase change.|
| `Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift`                                   | After narrator preamble, call `clipRouter.play(.phoneme)`; fall back to existing `.phoneme(p, .slow)` if `play` returns `false`.|
| `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift`                           | In existing `onChange(of: feedback)`: `.correct` → `clipRouter?.recordCorrect()`; `.wrong` → `clipRouter?.recordIncorrect()`. Both fire-and-forget via `Task`.|

`DecodeBoardView` is **not** modified — example clip dispatch happens at the `SessionContainerView` level via `.task(id:)`, keeping the board view oblivious to the router.

---

## Task 1: YokaiClipPlayer protocol + FakeYokaiClipPlayer

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipPlayer.swift`
- Create: `Packages/MoraTesting/Sources/MoraTesting/FakeYokaiClipPlayer.swift`

- [ ] **Step 1: Create the protocol**

Write `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipPlayer.swift`:

```swift
import Foundation

/// Plays a yokai voice clip located at `url`. Returns `true` if playback was
/// initiated successfully (the audio file existed and the player accepted it),
/// `false` otherwise — callers fall back to a different audio path on `false`.
@MainActor
public protocol YokaiClipPlayer: AnyObject {
    func play(url: URL) -> Bool
    func stop()
}
```

- [ ] **Step 2: Create the fake**

Write `Packages/MoraTesting/Sources/MoraTesting/FakeYokaiClipPlayer.swift`:

```swift
import Foundation
import MoraEngines

/// Records every play / stop call. `playReturn` lets a test simulate a
/// player that fails to initialize (e.g., missing file).
@MainActor
public final class FakeYokaiClipPlayer: YokaiClipPlayer {
    public var playedURLs: [URL] = []
    public var stopCallCount: Int = 0
    public var playReturn: Bool = true

    public init() {}

    public func play(url: URL) -> Bool {
        playedURLs.append(url)
        return playReturn
    }

    public func stop() {
        stopCallCount += 1
    }
}
```

- [ ] **Step 3: Build to verify**

Run:
```sh
(cd Packages/MoraEngines && swift build) && (cd Packages/MoraTesting && swift build)
```

Expected: both succeed.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipPlayer.swift Packages/MoraTesting/Sources/MoraTesting/FakeYokaiClipPlayer.swift
git commit -m "engines(yokai): YokaiClipPlayer protocol + FakeYokaiClipPlayer

Protocol abstracts clip playback so YokaiClipRouter (next commit) can
serialize against any backend; fake records calls for unit tests.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: AVFoundationYokaiClipPlayer (concrete)

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/AVFoundationYokaiClipPlayer.swift`

- [ ] **Step 1: Create the concrete impl**

Write `Packages/MoraEngines/Sources/MoraEngines/Yokai/AVFoundationYokaiClipPlayer.swift`:

```swift
import AVFoundation
import Foundation

@MainActor
public final class AVFoundationYokaiClipPlayer: YokaiClipPlayer {
    private var player: AVAudioPlayer?

    public init() {}

    public func play(url: URL) -> Bool {
        player?.stop()
        guard let next = try? AVAudioPlayer(contentsOf: url) else {
            player = nil
            return false
        }
        player = next
        return next.play()
    }

    public func stop() {
        player?.stop()
        player = nil
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```sh
(cd Packages/MoraEngines && swift build)
```

Expected: success.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/AVFoundationYokaiClipPlayer.swift
git commit -m "engines(yokai): AVFoundationYokaiClipPlayer concrete

Wraps AVAudioPlayer behind YokaiClipPlayer; production default for the
router. No automated test — AVAudioPlayer needs the audio session and is
covered by manual on-device verification at end of PR.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: YokaiClipRouter — basic play() routes URL through player

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`

- [ ] **Step 1: Write the failing test**

Write `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`:

```swift
import XCTest
import MoraTesting
@testable import MoraCore
@testable import MoraEngines

@MainActor
final class YokaiClipRouterTests: XCTestCase {
    func test_play_resolvesURLAndCallsPlayer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-phoneme.m4a")
        store.clipURLs["sh"] = [.phoneme: url]

        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { }
        )

        let played = await router.play(.phoneme)

        XCTAssertTrue(played)
        XCTAssertEqual(player.playedURLs, [url])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_play_resolvesURLAndCallsPlayer)
```

Expected: build error — `cannot find 'YokaiClipRouter' in scope`.

- [ ] **Step 3: Implement the minimal router**

Write `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift`:

```swift
import Foundation
import MoraCore

/// Coordinates yokai voice-clip playback during an A-day session.
///
/// The router resolves a `YokaiClipKey` to a bundled URL via the injected
/// `YokaiStore`, drains any in-flight Apple TTS through the `silencer`
/// closure (so playback never overlaps), and dispatches to a `YokaiClipPlayer`.
/// Streak (`recordCorrect` → `.encourage` on 3rd consecutive correct) and
/// throttle (`recordIncorrect` → `.gentle_retry` ≤1 per 5 trials) live here so
/// view code stays purely declarative.
///
/// Construction lives in `SessionContainerView.bootstrap`; the router is
/// scoped to a single session and discarded with the view.
@MainActor
public final class YokaiClipRouter {
    private let yokaiID: String
    private let store: YokaiStore
    private let player: YokaiClipPlayer
    private let silencer: () async -> Void

    public init(
        yokaiID: String,
        store: YokaiStore,
        player: YokaiClipPlayer,
        silencer: @escaping () async -> Void
    ) {
        self.yokaiID = yokaiID
        self.store = store
        self.player = player
        self.silencer = silencer
    }

    /// Play a clip directly. Returns `true` if the clip URL resolved and the
    /// player started playback, `false` otherwise — callers fall back to a
    /// different audio path on `false`.
    @discardableResult
    public func play(_ clip: YokaiClipKey) async -> Bool {
        guard let url = store.voiceClipURL(for: yokaiID, clip: clip) else {
            return false
        }
        await silencer()
        return player.play(url: url)
    }

    public func stop() {
        player.stop()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_play_resolvesURLAndCallsPlayer)
```

Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift
git commit -m "engines(yokai): YokaiClipRouter routes clip-key to player URL

Initial cut: resolves YokaiClipKey through YokaiStore, drains Apple TTS
via injected silencer closure, dispatches to YokaiClipPlayer. Streak +
throttle land in subsequent commits.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Router play() — silencer awaited; missing-clip URL returns false

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `YokaiClipRouterTests`:

```swift
    func test_play_awaitsSilencerBeforePlayer() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.encourage: url]

        // Both the silencer and the player append into a shared MainActor
        // recorder; the test asserts the resulting order. The whole test class
        // is @MainActor so no concurrency safety wrapper is needed.
        let recorder = OrderRecorder()
        let player = TracingYokaiClipPlayer(recorder: recorder)
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { recorder.append("silencer") }
        )

        _ = await router.play(.encourage)

        XCTAssertEqual(recorder.events, ["silencer", "player"])
    }

    func test_play_returnsFalseWhenClipURLMissing() async {
        let store = FakeYokaiStore()  // no clip URLs seeded
        let player = FakeYokaiClipPlayer()
        var silenced = false
        let router = YokaiClipRouter(
            yokaiID: "sh",
            store: store,
            player: player,
            silencer: { silenced = true }
        )

        let played = await router.play(.phoneme)

        XCTAssertFalse(played)
        XCTAssertTrue(player.playedURLs.isEmpty)
        XCTAssertFalse(silenced, "silencer should not run when clip URL is missing")
    }
}

/// Test helper: ordered event log. Used only inside the @MainActor test class
/// so a plain reference type is safe — no cross-isolation appends.
@MainActor
final class OrderRecorder {
    private(set) var events: [String] = []
    func append(_ event: String) { events.append(event) }
}

/// Test player that logs `"player"` synchronously when `play(url:)` is called.
@MainActor
final class TracingYokaiClipPlayer: FakeYokaiClipPlayer {
    let recorder: OrderRecorder
    init(recorder: OrderRecorder) {
        self.recorder = recorder
        super.init()
    }
    override func play(url: URL) -> Bool {
        recorder.append("player")
        return super.play(url: url)
    }
}
```

- [ ] **Step 2: Run the tests — `test_play_returnsFalseWhenClipURLMissing` should already pass; the silencer ordering test should pass too**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests)
```

Expected: PASS for both new tests, since the router already awaits silencer and short-circuits on missing URL.

- [ ] **Step 3: If silencer-ordering test fails, the implementation must be corrected**

Inspect the existing `play(_:)`:

```swift
guard let url = store.voiceClipURL(for: yokaiID, clip: clip) else {
    return false
}
await silencer()
return player.play(url: url)
```

The `await silencer()` runs strictly before `player.play(url:)` because Swift `async` functions are linear. If the test fails, the order is reversed somewhere — fix and re-run.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift
git commit -m "engines(yokai): pin router silencer ordering + missing-URL no-op

Two tests: (1) silencer awaited before player.play, (2) play() returns
false and skips silencer when clip URL is missing (so the caller can
fall back to Apple TTS without silencing the very utterance it would
otherwise speak).

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Router recordCorrect — streak fires `.encourage` on 3rd

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `YokaiClipRouterTests` inside the class:

```swift
    func test_recordCorrect_firesEncourageOnThirdConsecutiveCorrect() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.encourage: url]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: { }
        )

        await router.recordCorrect()
        await router.recordCorrect()
        XCTAssertTrue(player.playedURLs.isEmpty, "no clip until 3rd correct")

        await router.recordCorrect()
        XCTAssertEqual(player.playedURLs, [url], "encourage on 3rd correct")
    }

    func test_recordCorrect_streakResetsAfterEncourage() async {
        let store = FakeYokaiStore()
        let url = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.encourage: url]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: { }
        )

        for _ in 0..<6 {
            await router.recordCorrect()
        }

        XCTAssertEqual(player.playedURLs.count, 2, "two encourage clips for 6-correct run (3rd and 6th)")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_recordCorrect)
```

Expected: build error — `cannot find 'recordCorrect'`.

- [ ] **Step 3: Implement `recordCorrect`**

Add to `YokaiClipRouter` (inside the class, after `stop()`):

```swift
    private var consecutiveCorrect: Int = 0

    /// Record a correct trial in `shortSentences`. Fires `.encourage` and
    /// resets the streak on every 3rd consecutive correct.
    public func recordCorrect() async {
        consecutiveCorrect += 1
        if consecutiveCorrect >= 3 {
            consecutiveCorrect = 0
            await play(.encourage)
        }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_recordCorrect)
```

Expected: PASS for both tests.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift
git commit -m "engines(yokai): router fires .encourage on every 3rd consecutive correct

recordCorrect() tracks streak, dispatches play(.encourage) on the 3rd,
6th, 9th, ... consecutive correct trial, resetting the counter each
time. View layer drives the calls from ShortSentencesView's existing
.correct feedback path.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Router recordIncorrect — streak resets, gentle_retry throttled to ≤1/5 trials

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `YokaiClipRouterTests`:

```swift
    func test_recordIncorrect_resetsStreakAndFiresGentleRetry() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: { }
        )

        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordIncorrect()  // resets streak, fires retry (first miss)
        await router.recordCorrect()
        await router.recordCorrect()
        // Two more correct trials; would have been the third in the original
        // streak. Encourage must NOT fire because the wrong answer reset the count.
        XCTAssertEqual(player.playedURLs, [retry])
    }

    func test_recordIncorrect_throttlesGentleRetryToAtMostOnePerFiveTrials() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: { }
        )

        // T1: first miss → fires.
        await router.recordIncorrect()
        XCTAssertEqual(player.playedURLs.count, 1)

        // T2 / T3 / T4 / T5: still inside the throttle window
        // (trialIndex - lastGentleRetryTrialIndex < 5). All suppressed.
        for _ in 0..<4 {
            await router.recordIncorrect()
        }
        XCTAssertEqual(
            player.playedURLs.count, 1,
            "trials 2–5 are within the 5-trial throttle window after T1"
        )

        // T6: trialIndex - lastGentleRetryTrialIndex == 5 → fires again.
        await router.recordIncorrect()
        XCTAssertEqual(
            player.playedURLs.count, 2,
            "fires on the 5th trial after the previous retry (T6)"
        )
    }

    func test_recordIncorrect_correctTrialsCountTowardThrottleWindow() async {
        let store = FakeYokaiStore()
        let retry = URL(fileURLWithPath: "/tmp/sh-retry.m4a")
        let encourage = URL(fileURLWithPath: "/tmp/sh-encourage.m4a")
        store.clipURLs["sh"] = [.gentleRetry: retry, .encourage: encourage]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: { }
        )

        await router.recordIncorrect()  // trial 1, retry fires
        await router.recordCorrect()    // trial 2
        await router.recordCorrect()    // trial 3
        await router.recordCorrect()    // trial 4 — encourage fires (3 consecutive)
        await router.recordIncorrect()  // trial 5 — within throttle, retry suppressed
        XCTAssertEqual(player.playedURLs, [retry, encourage])

        await router.recordIncorrect()  // trial 6 — 5 trials elapsed, retry fires
        XCTAssertEqual(player.playedURLs, [retry, encourage, retry])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_recordIncorrect)
```

Expected: build error — `cannot find 'recordIncorrect'`.

- [ ] **Step 3: Implement `recordIncorrect` and trial counter**

Modify `YokaiClipRouter`:

Replace the existing `recordCorrect` with the trial-counting version, and add `recordIncorrect`:

```swift
    private var consecutiveCorrect: Int = 0
    private var trialIndex: Int = 0
    private var lastGentleRetryTrialIndex: Int = -100

    /// Record a correct trial in `shortSentences`. Fires `.encourage` and
    /// resets the streak on every 3rd consecutive correct.
    public func recordCorrect() async {
        trialIndex += 1
        consecutiveCorrect += 1
        if consecutiveCorrect >= 3 {
            consecutiveCorrect = 0
            await play(.encourage)
        }
    }

    /// Record an incorrect trial in `shortSentences`. Resets the streak and
    /// fires `.gentle_retry` if at least 5 trials have passed since the last
    /// retry clip — protects the learner from a retry-clip storm during a
    /// rough run.
    public func recordIncorrect() async {
        trialIndex += 1
        consecutiveCorrect = 0
        if trialIndex - lastGentleRetryTrialIndex >= 5 {
            lastGentleRetryTrialIndex = trialIndex
            await play(.gentleRetry)
        }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests)
```

Expected: PASS for all router tests.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiClipRouter.swift Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift
git commit -m "engines(yokai): router throttles .gentle_retry to <=1 per 5 trials

recordIncorrect() resets the consecutive-correct streak (so the very
next missed answer cannot be the cause of an encourage clip), and only
plays gentle_retry when the running trial counter has advanced >=5 since
the last retry clip. Both correct and incorrect trials advance the
counter so a string of correct trials between two misses still counts
toward the throttle window.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Router stop() — cancels in-flight player

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `YokaiClipRouterTests`:

```swift
    func test_stop_callsPlayerStop() async {
        let store = FakeYokaiStore()
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: "sh", store: store, player: player, silencer: { }
        )

        router.stop()
        XCTAssertEqual(player.stopCallCount, 1)
    }
```

- [ ] **Step 2: Run the test to verify it passes**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_stop)
```

Expected: PASS — `stop()` already exists from Task 3 and forwards to `player.stop()`.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift
git commit -m "engines(yokai): pin router.stop() forwarding to player.stop()

Regression guard so a future refactor can't quietly swallow stop().
SessionContainerView calls this on phase boundaries.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: SessionContainerView — construct router in bootstrap, pass to phase views, stop on phase change

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Read the current bootstrap path**

Read `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` lines 130–250 to see the existing bootstrap, the phase switch, and the `onChange(of: phase)` hook.

- [ ] **Step 2: Add router state and construction**

Inside `SessionContainerView`, near the other `@State` declarations, add:

```swift
    @State private var clipRouter: YokaiClipRouter?
```

In the body of `bootstrap()`, after `speech` is initialized and the active encounter / skill have been resolved (find the existing block where `yokaiOrchestrator` is constructed), add:

```swift
        let yokaiClipStore: YokaiStore
        do {
            yokaiClipStore = try BundledYokaiStore()
        } catch {
            // Bundled catalog unavailable — proceed without clips. Existing
            // Apple TTS phoneme + no encourage/retry is the fallback experience.
            self.orchestrator = SessionOrchestrator( /* unchanged construction */ )
            return
        }

        let speechRef = speech
        clipRouter = YokaiClipRouter(
            yokaiID: encounter.yokaiID,
            store: yokaiClipStore,
            player: AVFoundationYokaiClipPlayer(),
            silencer: { [weak speechRef] in
                await speechRef?.stop()
            }
        )
```

(Adjust the placement so the original orchestrator construction is preserved; the goal is `clipRouter != nil` whenever bootstrap reaches the success path.)

- [ ] **Step 3: Pass router to phase views**

In the `content` ViewBuilder, find each phase case and pass the router as a new initializer argument. For now only declare the parameter at the call sites; the views will pick it up in Tasks 9–11. Sample edits:

```swift
            case .warmup:
                WarmupView(orchestrator: orchestrator, speech: speech, clipRouter: clipRouter)
            // ...
            case .shortSentences:
                ShortSentencesView(
                    orchestrator: orchestrator, uiMode: uiMode,
                    feedback: $feedback,
                    speechEngine: uiMode == .mic ? speechEngine : nil,
                    speech: speech,
                    clipRouter: clipRouter
                )
```

- [ ] **Step 4: Add example_N task at decoding case**

Inside the existing `case .decoding:` block of `content`, attach a `.task(id:)` to the outer `VStack` that fires the example clip after a 1.5s delay (giving Apple TTS time to speak the target word):

```swift
            case .decoding:
                VStack(spacing: MoraTheme.Space.md) {
                    if let engine = orchestrator.currentTileBoardEngine {
                        DecodeBoardView(
                            engine: engine,
                            chainPipStates: orchestrator.chainPipStates.map(ChainPipState.init),
                            incomingRole: orchestrator.currentChainRole,
                            speech: speech,
                            onTrialComplete: { result in
                                orchestrator.consumeTileBoardTrial(result)
                            }
                        )
                        .id(orchestrator.completedTrialCount)
                    } else {
                        Color.clear
                    }
                    #if DEBUG
                    Button("DEBUG: Skip to Short Sentences") {
                        orchestrator.debugSkipDecoding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .padding(.bottom, MoraTheme.Space.sm)
                    #endif
                }
                .task(id: orchestrator.completedTrialCount) {
                    let idx = orchestrator.completedTrialCount
                    let clip: YokaiClipKey?
                    switch idx {
                    case 0: clip = .example1
                    case 3: clip = .example2
                    case 7: clip = .example3
                    default: clip = nil
                    }
                    guard let clip else { return }
                    // Wait for the in-trial Apple TTS speakTarget() to finish
                    // before triggering the yokai exemplar; an explicit await on
                    // SpeechController completion would be more precise but the
                    // single-word utterance reliably finishes inside this window.
                    try? await Task.sleep(for: .milliseconds(1500))
                    await clipRouter?.play(clip)
                }
```

- [ ] **Step 5: Stop the router on phase change**

Find the existing `.onChange(of: orchestrator?.phase)` modifier on the outer ZStack:

```swift
        .onChange(of: orchestrator?.phase) { oldValue, _ in
            guard oldValue != nil, oldValue != .notStarted else { return }
            guard let speech else { return }
            Task { await speech.stop() }
        }
```

Extend it so the router is also stopped:

```swift
        .onChange(of: orchestrator?.phase) { oldValue, _ in
            guard oldValue != nil, oldValue != .notStarted else { return }
            clipRouter?.stop()
            guard let speech else { return }
            Task { await speech.stop() }
        }
```

- [ ] **Step 6: Build (will fail — phase views don't yet accept clipRouter)**

Run:
```sh
(cd Packages/MoraUI && swift build)
```

Expected: build error — `WarmupView` / `ShortSentencesView` initializers don't have `clipRouter:` parameters yet. This is expected; Tasks 9–11 add them.

- [ ] **Step 7: Defer the commit**

Do **not** commit yet. Tasks 9–11 introduce the matching initializer parameters; commit at end of Task 11 once the package builds clean. Continue to Task 9.

---

## Task 9: WarmupView — phoneme clip on appear with TTS fallback

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift`

- [ ] **Step 1: Add the `clipRouter` parameter and replace `playTargetPhoneme`**

Replace the entire `WarmupView` struct in `Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift` with:

```swift
import MoraCore
import MoraEngines
import SwiftUI

struct WarmupView: View {
    @Environment(\.moraStrings) private var strings
    let orchestrator: SessionOrchestrator
    let speech: SpeechController?
    let clipRouter: YokaiClipRouter?

    private static let promptPrefix = "Which one says"

    var body: some View {
        ScrollView {
            VStack(spacing: MoraTheme.Space.lg) {
                Text("\(Self.promptPrefix) /\(targetIPA)/?")
                    .font(MoraType.heading())
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)

                Text("Listen and tap.")
                    .font(MoraType.subtitle())
                    .foregroundStyle(MoraTheme.Ink.muted)
                    .minimumScaleFactor(0.5)

                HStack(spacing: MoraTheme.Space.lg) {
                    ForEach(orchestrator.warmupOptions, id: \.letters) { g in
                        Button(action: {
                            Task { await orchestrator.handle(.warmupTap(g)) }
                        }) {
                            Text(g.letters)
                                .font(MoraType.heroWord(120))
                                .foregroundStyle(MoraTheme.Ink.primary)
                                .frame(width: 180, height: 180)
                                .background(
                                    Color.white,
                                    in: .rect(cornerRadius: MoraTheme.Radius.card)
                                )
                                .minimumScaleFactor(0.5)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if orchestrator.warmupMissCount > 0 {
                    Text("Let's try again — listen.")
                        .font(MoraType.label())
                        .foregroundStyle(MoraTheme.Accent.orange)
                        .minimumScaleFactor(0.5)
                }

                Button(action: { Task { await playTargetPhoneme() } }) {
                    Text(strings.warmupListenAgain)
                        .font(MoraType.cta())
                        .foregroundStyle(MoraTheme.Accent.teal)
                        .padding(.vertical, MoraTheme.Space.md)
                        .padding(.horizontal, MoraTheme.Space.xl)
                        .background(MoraTheme.Background.mint, in: .capsule)
                        .minimumScaleFactor(0.5)
                }
                .buttonStyle(.plain)
                .disabled(speech == nil)
            }
            .padding(.vertical, MoraTheme.Space.xl)
            .frame(maxWidth: .infinity)
        }
        .task {
            await playTargetPhoneme()
        }
    }

    /// Speaks the warmup prompt and the target phoneme. Sequence:
    /// 1. Apple TTS narrator: "Which one says".
    /// 2. Yokai's `phoneme` clip if the active week has one bundled — gives
    ///    the target sound a character voice instead of generic SFSpeech IPA.
    /// 3. If no yokai clip is available, fall back to the original Apple TTS
    ///    `.phoneme` rendering so a missing-asset state still teaches the sound.
    private func playTargetPhoneme() async {
        guard let speech else { return }
        await speech.playAndAwait([.text(Self.promptPrefix, .normal)])
        let played = (await clipRouter?.play(.phoneme)) ?? false
        if !played, let phoneme = orchestrator.target.phoneme {
            await speech.playAndAwait([.phoneme(phoneme, .slow)])
        }
    }

    private var targetIPA: String {
        orchestrator.target.ipa ?? "?"
    }
}
```

- [ ] **Step 2: Verify `SpeechController` exposes `playAndAwait`**

Run:
```sh
grep -n "playAndAwait" Packages/MoraUI/Sources/MoraUI/Session/SpeechController.swift
```

Expected: at least one match. (Confirmed present from `ShortSentencesView`'s existing usage.) If absent, fall back to `play(...)` and rely on serial queue ordering — but the grep should succeed.

- [ ] **Step 3: Build the MoraUI package (will still fail — ShortSentencesView needs router param too)**

Run:
```sh
(cd Packages/MoraUI && swift build)
```

Expected: build error in `ShortSentencesView` only. WarmupView itself compiles. Continue to Task 10.

---

## Task 10: ShortSentencesView — encourage / gentle_retry on feedback transitions

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift`

- [ ] **Step 1: Read the current feedback handler**

Inspect `Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift` lines 80–110 — the `onChange(of: feedback)` modifier already runs side effects (haptics).

- [ ] **Step 2: Add the `clipRouter` parameter**

Locate the field declarations near the top of `ShortSentencesView` and add:

```swift
    let clipRouter: YokaiClipRouter?
```

Add `MoraEngines` import if not already present at the top of the file.

- [ ] **Step 3: Extend the `onChange(of: feedback)` handler**

Replace the existing block:

```swift
        .onChange(of: feedback) { _, new in
            if new == .wrong {
                shakeResetTask?.cancel()
                withAnimation(.linear(duration: 0.6)) { shakeAmount = 1 }
                shakeResetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    guard !Task.isCancelled else { return }
                    shakeAmount = 0
                }
            }
            #if canImport(UIKit)
            switch new {
            case .correct: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .wrong: UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .none: break
            }
            #endif
        }
```

with:

```swift
        .onChange(of: feedback) { _, new in
            if new == .wrong {
                shakeResetTask?.cancel()
                withAnimation(.linear(duration: 0.6)) { shakeAmount = 1 }
                shakeResetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    guard !Task.isCancelled else { return }
                    shakeAmount = 0
                }
            }
            #if canImport(UIKit)
            switch new {
            case .correct: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .wrong: UINotificationFeedbackGenerator().notificationOccurred(.error)
            case .none: break
            }
            #endif

            // Yokai voice routing — fire-and-forget. The router's @MainActor
            // isolation serializes calls so the streak math is never racy.
            switch new {
            case .correct:
                Task { @MainActor in await clipRouter?.recordCorrect() }
            case .wrong:
                Task { @MainActor in await clipRouter?.recordIncorrect() }
            case .none:
                break
            }
        }
```

- [ ] **Step 4: Build the MoraUI package**

Run:
```sh
(cd Packages/MoraUI && swift build)
```

Expected: success.

- [ ] **Step 5: Run the package test suites to confirm no existing test broke**

Run:
```sh
(cd Packages/MoraUI && swift test) && (cd Packages/MoraEngines && swift test) && (cd Packages/MoraCore && swift test)
```

Expected: PASS across all three. (`MoraTesting` has no test target.)

- [ ] **Step 6: Commit Tasks 8 + 9 + 10 together**

```sh
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift Packages/MoraUI/Sources/MoraUI/Session/WarmupView.swift Packages/MoraUI/Sources/MoraUI/Session/ShortSentencesView.swift
git commit -m "ui(session): wire YokaiClipRouter into warmup, decoding, sentences

SessionContainerView constructs YokaiClipRouter in bootstrap (with a
silencer closure that captures SpeechController so the dependency stays
inside MoraUI), passes it to WarmupView and ShortSentencesView, and
fires example_1/2/3 from a .task(id: completedTrialCount) hook on the
decoding case so DecodeBoardView itself stays oblivious to the router.

WarmupView's playTargetPhoneme awaits the narrator preamble, then plays
the yokai .phoneme clip; falls back to Apple TTS .phoneme rendering
when the clip URL is unavailable.

ShortSentencesView's existing onChange(feedback) handler now also
forwards .correct -> recordCorrect (streak / encourage) and .wrong ->
recordIncorrect (streak reset / throttled gentle_retry).

Phase changes call clipRouter?.stop() before the existing speech.stop()
so a clip that started on the previous phase doesn't bleed into the
next one.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 11: Verify all clip keys play across a full session

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift`

This task adds an integration-style coverage test that drives the router through the trigger sequence a single Tue–Thu session would produce, asserting that 6 distinct clip keys (`phoneme`, `example_1`, `example_2`, `example_3`, `encourage`, `gentle_retry`) all reach the player. The actual view-layer dispatch was wired in Task 8/9/10; this test covers the router's combined behavior.

- [ ] **Step 1: Write the failing test**

Append to `YokaiClipRouterTests`:

```swift
    func test_typicalTuesdaySessionFiresAllSixSessionInternalClips() async {
        let store = FakeYokaiStore()
        let yokai = "sh"
        store.clipURLs[yokai] = [
            .phoneme: URL(fileURLWithPath: "/tmp/sh-phoneme.m4a"),
            .example1: URL(fileURLWithPath: "/tmp/sh-ex1.m4a"),
            .example2: URL(fileURLWithPath: "/tmp/sh-ex2.m4a"),
            .example3: URL(fileURLWithPath: "/tmp/sh-ex3.m4a"),
            .encourage: URL(fileURLWithPath: "/tmp/sh-encourage.m4a"),
            .gentleRetry: URL(fileURLWithPath: "/tmp/sh-retry.m4a"),
        ]
        let player = FakeYokaiClipPlayer()
        let router = YokaiClipRouter(
            yokaiID: yokai, store: store, player: player, silencer: { }
        )

        // Warmup
        await router.play(.phoneme)
        // Decoding (10 trials, examples at indices 0/3/7)
        await router.play(.example1)
        await router.play(.example2)
        await router.play(.example3)
        // Short sentences: 3 correct → encourage; 1 wrong → retry
        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordCorrect()
        await router.recordIncorrect()

        let lastComponents = player.playedURLs.map { $0.lastPathComponent }
        XCTAssertEqual(
            Set(lastComponents),
            ["sh-phoneme.m4a", "sh-ex1.m4a", "sh-ex2.m4a", "sh-ex3.m4a", "sh-encourage.m4a", "sh-retry.m4a"]
        )
    }
```

- [ ] **Step 2: Run the test — it should pass**

Run:
```sh
(cd Packages/MoraEngines && swift test --filter YokaiClipRouterTests.test_typicalTuesdaySessionFiresAllSixSessionInternalClips)
```

Expected: PASS.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/YokaiClipRouterTests.swift
git commit -m "engines(yokai): assert a typical Tuesday session fires 6 distinct clips

Drives the router through the warmup -> decoding -> sentences trigger
sequence and asserts every session-internal clip key (phoneme, the three
examples, encourage on a 3-correct streak, gentle_retry on a miss)
reaches the player. Locks in the spec's C1 success criterion.

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 12: Lint, full build, regenerate Xcode project, push

**Files:** none modified — verification only.

- [ ] **Step 1: Run swift-format strict lint**

Run:
```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

Expected: clean exit. If any new file has a violation, `swift-format format --in-place` it and re-stage in a tiny follow-up commit.

- [ ] **Step 2: Run all package tests**

Run:
```sh
(cd Packages/MoraCore && swift test) && (cd Packages/MoraEngines && swift test) && (cd Packages/MoraUI && swift test) && (cd Packages/MoraTesting && swift test)
```

Expected: PASS across all four. (`MoraMLX` is build-only.)

- [ ] **Step 3: Regenerate Xcode project + run xcodebuild**

Per `CLAUDE.md`, inject `DEVELOPMENT_TEAM` then revert (memory: `feedback_mora_xcodegen_team_injection`). The mora-specific sequence:

```sh
# Inject team for local generation only
sed -i '' 's|^settings:|settings:\
  base:\
    DEVELOPMENT_TEAM: 7BT28X9TQ9|' project.yml

xcodegen generate

# Revert the injection so it never reaches git
git checkout -- project.yml

xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: clean build.

- [ ] **Step 4: Push the branch and open the PR**

If working on `main` directly per the existing commit cadence, push:

```sh
git push origin HEAD
```

Otherwise create a feature branch first:

```sh
git checkout -b feat/yokai-voice-wiring
git push -u origin feat/yokai-voice-wiring
gh pr create --title "engines+ui(yokai): wire all 8 voice clips into session triggers" --body "$(cat <<'EOF'
## Summary

Track A of the spec at `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md`.

Wires every bundled yokai voice clip into a session-internal trigger:

- `phoneme` — WarmupView, after the narrator preamble.
- `example_1/2/3` — decoding phase, on trial indices 0 / 3 / 7 via `.task(id: completedTrialCount)`.
- `encourage` — every 3rd consecutive correct in ShortSentences.
- `gentle_retry` — on a miss, throttled to <=1 per 5 trials.
- `greet` / `friday_acknowledge` — unchanged (cutscene path).

## Architecture

- New `YokaiClipRouter` (`@MainActor`) in MoraEngines owns the clip catalog for the active week's yokai. Throttle + streak math live there; views are pure trigger sources.
- `YokaiClipPlayer` protocol + `AVFoundationYokaiClipPlayer` concrete + `FakeYokaiClipPlayer` (in MoraTesting) for testability.
- Silencer is injected as a closure so MoraEngines does not depend on `SpeechController` in MoraUI.

## Test plan

- [x] `swift test` for MoraCore / MoraEngines / MoraUI / MoraTesting
- [x] `swift-format lint --strict` clean
- [x] `xcodebuild build` on generic iOS Simulator
- [ ] On-device: full Tue session — verify phoneme + 3 examples + encourage on a 3-correct streak + gentle_retry on a miss are all audible
- [ ] On-device: confirm Apple TTS does not race the clip (overlap)
- [ ] On-device: confirm phase change cancels any in-flight clip

EOF
)"
```

- [ ] **Step 5: No commit needed for this task**

Verification only. PR body is the deliverable.

---

## Self-Review

### Spec coverage

| Spec section          | Plan task                                  |
|-----------------------|--------------------------------------------|
| § 5.1 trigger map     | Tasks 8 (decoding), 9 (warmup), 10 (sentences); Task 11 asserts coverage |
| § 5.2 router shape    | Tasks 1 (protocol+fake), 2 (concrete), 3 (basic play), 5 (recordCorrect), 6 (recordIncorrect), 7 (stop) |
| § 5.3 wiring locations| Tasks 8, 9, 10                             |
| § 5.4 overlap avoidance | Task 4 (silencer ordering test); Task 8 (phase-change stop) |
| § 5.5 tests           | Tasks 3–7 (router unit tests); Task 11 (integration coverage) |

No spec gap. The "WarmupViewSnapshotTests" / "ShortSentencesViewIntegrationTests" mentioned in spec § 5.5 are deliberately omitted — SwiftUI snapshot infrastructure is not yet in the repo, and the router-level integration test in Task 11 covers the same surface (which clips fire when). If snapshot tests become valuable later, a follow-up plan can add `swift-snapshot-testing` and the two view tests in one PR.

### Type consistency

- `YokaiClipKey.example1` / `.example2` / `.example3` / `.gentleRetry` — match the existing enum in `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiClipKey.swift`.
- `YokaiStore.voiceClipURL(for:clip:)` — matches the protocol.
- `FakeYokaiStore.clipURLs` keyed `[String: [YokaiClipKey: URL]]` — matches the existing fake.
- `SpeechController.playAndAwait` — confirmed present (used elsewhere in `ShortSentencesView`).

### Placeholder scan

No "TBD", no "TODO", no "implement later". Every step has the exact code or shell command. Test names map to test bodies. No "similar to Task N" stubs.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-25-yokai-voice-wiring.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
