# Weekly Yokai Intro Screen — Design

**Status:** Draft
**Date:** 2026-04-26
**Owner:** Yutaka

## 1. Problem

The Monday Yokai intro is currently shown as a `YokaiCutsceneOverlay` that
overlays the warmup screen. The underlying `WarmupView`'s `.task` fires the
"Which one says /sound/?" Apple TTS prompt at the same moment the overlay
appears. Two unrelated audio streams talk over each other and a young
dyslexic learner cannot parse either of them.

The intent of the Monday cutscene is preserved (introduce this week's yokai
once per week). The bug is purely in *how* it is presented: an overlay on
top of a phase that has its own audio loop is the wrong container.

## 2. Goals

1. The first session of each yokai week opens on a dedicated **Weekly Intro
   screen** that owns the screen exclusively while it is up.
2. Audio is sequential: the yokai's greet clip plays during the intro; the
   warmup TTS prompt plays only after the learner dismisses the intro.
3. Subsequent sessions of the same week skip the intro and open directly on
   warmup.
4. No engine-layer changes. The `YokaiOrchestrator.activeCutscene` state
   already encodes "is this a Monday intro" and stays the source of truth.

## 3. Non-goals

- Rewriting the four-panel `YokaiIntroFlow` first-launch onboarding.
- Replacing the Friday climax cutscene or the SRS cameo cutscene. Those
  remain `YokaiCutsceneOverlay` overlays — they are mid-session moments
  where overlay semantics are appropriate.
- Wiring the unused `.sessionStart` cutscene case (defined but no producer
  today; explicitly out of scope).
- Adding a Tue–Fri "session start" cameo. Out of scope.

## 4. Scope

In scope:

- New screen `WeeklyIntroView` in `MoraUI/Session/`.
- A gate in `SessionContainerView.content` that mounts `WeeklyIntroView`
  instead of `WarmupView` when the Monday intro is active.
- Suppression of the corresponding overlay path in `YokaiCutsceneOverlay`
  and the corner portrait + gauge HUD in `YokaiLayerView` so the screen
  is not double-rendered.

Out of scope: any change to engines, persistence, or onboarding.

## 5. User-facing flow

### 5.1 First session of a new week

1. User taps the home hero CTA → push `SessionContainerView`.
2. Bootstrap runs. Either the encounter is brand-new
   (`resolution.isNewEncounter`) or it is a Friday-handover row
   (`isUnstartedHandoff`). Both paths call
   `YokaiOrchestrator.startWeek(yokaiID:weekStart:)`, which sets
   `activeCutscene = .mondayIntro(yokaiID:)`.
3. `SessionOrchestrator.start()` advances `phase` to `.warmup`.
4. `SessionContainerView` renders `content`. The new gate detects
   `phase == .warmup && yokai.activeCutscene == .mondayIntro` and mounts
   **`WeeklyIntroView`** instead of `WarmupView`.
5. `WeeklyIntroView` auto-plays the yokai's `.greet` voice clip on first
   appearance. The Apple TTS prompt does not run.
6. Learner taps **Next**. `WeeklyIntroView` calls
   `yokai.dismissCutscene()`. `activeCutscene` becomes `nil`.
7. Re-render: the gate condition is now false, so `WarmupView` mounts for
   the first time. Its `.task` fires the "Which one says /sound/?" TTS
   sequence cleanly.

### 5.2 Tue–Fri sessions of the same week

Bootstrap calls `resume(encounter:)` (not `startWeek`). `resume` sets
`activeCutscene = nil`. The gate is false, so `WarmupView` mounts directly
as today.

### 5.3 App killed mid-intro

`startWeek` writes `friendshipPercent = 0.10` to the encounter as part of
its insert. On reopen, `WeekRotation.resolve` finds the existing encounter,
`isNewEncounter` is false, and `isUnstartedHandoff` evaluates to false
(`friendshipPercent != 0`). Bootstrap runs `resume()`, no `.mondayIntro`
fires, and the learner skips straight to warmup. This matches the
"first time only" intent of the user's request and is the existing
behavior — no change needed.

If the learner wants to see the intro again, the existing
"replay onboarding" path on `HomeView` opens the four-panel
`YokaiIntroFlow` in `.replay` mode. That entry point is unchanged.

## 6. UI

### 6.1 `WeeklyIntroView` layout

Top to bottom inside the SessionContainerView's content area (chrome —
the close `×`, phase pips, streak chip — sits above and is unchanged):

- Title: `strings.yokaiIntroTodayTitle` (existing `MoraStrings` key).
- Yokai portrait, 200×200, via `YokaiPortraitCorner(yokai:, sparkleTrigger: nil)`.
- Grapheme glyph, hero font.
- IPA, subtitle font.
- Body copy: `strings.yokaiIntroTodayBody`.
- "Listen again" capsule button — same teal capsule pattern as
  `WarmupView`'s `strings.warmupListenAgain` button. Replays the `.greet`
  voice clip.
- "Next" hero CTA — `strings.yokaiIntroNext`. Calls
  `yokai.dismissCutscene()`.

### 6.2 Behavior

- On first appear: `.task` calls `player.play(url:)` for the active
  yokai's `.greet` clip. Stops on disappear.
- Replay button: `player.stop()` then `player.play(url:)` for the same
  clip. Hidden when no clip URL is available — consistent with §10's
  silent fallback for yokai missing a `.greet` clip.
- CTA: dismisses the cutscene. SwiftUI's Observable re-render swaps
  `WeeklyIntroView` out for `WarmupView`.
- Reduce Motion: portrait scale spring is skipped (matches existing
  `TodaysYokaiPanel`).

### 6.3 Naming and reuse

- New file: `Packages/MoraUI/Sources/MoraUI/Session/WeeklyIntroView.swift`.
- Visually parallels `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift`
  but is **a separate file**. The onboarding panel has its own caller
  (`YokaiIntroFlow`) and a different content contract (no replay button,
  no chrome assumption); fork rather than couple.

## 7. Architecture

### 7.1 Where the gate lives

UI-only. `SessionContainerView.content` adds a sub-branch on `.warmup`.
The cutscene check first unwraps the optional `yokai` orchestrator, then
pattern-matches the optional `activeCutscene`:

```swift
case .warmup:
    if let yokai = orchestrator.yokai,
       case .mondayIntro = yokai.activeCutscene {
        WeeklyIntroView(yokai: yokai, store: yokaiStore, player: yokaiPlayer)
    } else {
        WarmupView(orchestrator: orchestrator, speech: speech, clipRouter: clipRouter)
    }
```

`yokaiStore` (a `BundledYokaiStore`) and `yokaiPlayer` (an
`AVFoundationYokaiClipPlayer`) need to be reachable from `content`. Today
the `BundledYokaiStore` is constructed locally inside `bootstrap()` and
held only by `YokaiOrchestrator` and `YokaiClipRouter`. Two acceptable
ways to surface them:

- Add `@State private var yokaiStore: BundledYokaiStore?` and
  `@State private var yokaiPlayer: any YokaiClipPlayer` to
  `SessionContainerView`, populated alongside `clipRouter` during
  bootstrap. Mirrors the existing `clipRouter` pattern.
- Re-init `BundledYokaiStore()` inside `WeeklyIntroView`'s `init`
  (matches `YokaiIntroFlow`'s pattern). Cheap (metadata-only load),
  decouples the screen from container-level state, but introduces a
  second store instance for the duration of the intro.

Either is acceptable. Leave the choice to the implementation plan.

### 7.2 Suppressing the redundant overlay

`YokaiCutsceneOverlay.body` switches on `activeCutscene`. Today its
default branch (`simpleStack`) handles `.mondayIntro`, `.sessionStart`,
and `.srsCameo`. After this change:

- `.mondayIntro` returns `EmptyView()` from the overlay (the screen
  is rendered by `WeeklyIntroView`, not the overlay).
- `.fridayClimax` keeps its dedicated path.
- `.srsCameo` continues using `simpleStack`.
- `.sessionStart` (still no producer) continues using `simpleStack`
  for forward-compat — out of scope to wire today.

The dead `.mondayIntro` arm in `subtitleText` is removed.

### 7.3 Suppressing the corner portrait

`YokaiLayerView` shows a corner portrait + friendship gauge whenever
`currentYokai != nil`. During `WeeklyIntroView`, that produces a
duplicate small portrait next to the centered intro portrait. Gate the
corner block with `if !isMondayIntroActive { ... }` where
`isMondayIntroActive` is derived from `orchestrator.activeCutscene`.

The friendship gauge HUD (`FriendshipGaugeHUD`) is similarly hidden
during `.mondayIntro` for the same visual reason — friendship is at
0.10 at this exact moment but the gauge is not the focal point yet.

## 8. Data flow

```
HomeView CTA
   └── push SessionContainerView
         └── bootstrap()
              ├── YokaiOrchestrator.startWeek(...)        // first session of week
              │     └── activeCutscene = .mondayIntro
              └── SessionOrchestrator.start()
                    └── phase = .warmup

SessionContainerView.content
   if phase == .warmup && activeCutscene == .mondayIntro
        WeeklyIntroView
            .task → player.play(.greet)
            user taps "Listen again" → player.play(.greet)   // optional
            user taps "Next"
                └── yokai.dismissCutscene()                  // activeCutscene = nil
   else
        WarmupView
            .task → "Which one says /sound/?" TTS → phoneme clip
```

## 9. Audio invariants

1. `WeeklyIntroView` plays exactly the `.greet` clip and no Apple TTS.
2. `WarmupView` plays its TTS sequence exactly once, when it first mounts.
3. There is no time window in which both `WeeklyIntroView`'s clip player
   and `WarmupView`'s TTS are running. The render gate guarantees the two
   views are never simultaneously mounted, and SwiftUI's `.task` semantics
   guarantee `WarmupView`'s `.task` runs only after it mounts.
4. `WeeklyIntroView.onDisappear` stops the clip player so a replay tap
   immediately followed by Next does not leave a tail playing under the
   warmup screen.

## 10. Edge cases

- **No `.greet` clip bundled** for some yokai: `voiceClipURL` returns nil;
  the screen renders silent and the Next CTA still works. Same forgiving
  fallback as `TodaysYokaiPanel`.
- **Learner backs out (×) during intro**: existing top-bar close button
  surfaces the standard confirm dialog; on End the session is dismissed
  without consuming Monday in any new way (encounter already exists from
  `startWeek`; reopen path follows §5.3).
- **Reduce Motion**: spring scale on portrait is skipped; clip playback
  is unaffected.
- **YokaiOrchestrator init failure**: bootstrap already swallows this
  into `yokaiOrchestrator = nil`. With no yokai orchestrator,
  `activeCutscene` cannot be `.mondayIntro`, so the gate never fires and
  `WarmupView` mounts as today.

## 11. Testing

New tests in `Packages/MoraUI/Tests/MoraUITests/`:

- `WeeklyIntroViewTests`
  - `.task` calls `player.play(url:)` exactly once with the active
    yokai's greet clip URL.
  - Replay button calls `player.play(url:)` again with the same URL.
  - CTA calls `yokai.dismissCutscene()`.
  - Yokai with no greet URL renders without crash and the Next CTA still
    works.
  - Disappear stops the player.
- `SessionContainerWeeklyIntroGateTests`
  - With `phase == .warmup && activeCutscene == .mondayIntro`, the
    rendered content tree contains `WeeklyIntroView` and not
    `WarmupView`.
  - After `dismissCutscene()`, the rendered content tree contains
    `WarmupView` and the warmup TTS hook fires exactly once.
- `YokaiCutsceneOverlayMondayIntroTests`
  - `.mondayIntro` makes the overlay produce no visible content.
  - `.fridayClimax` and `.srsCameo` are unaffected.
- Update `YokaiLayerView` snapshot/structural test (if present) to assert
  the corner portrait + gauge are hidden under `.mondayIntro`.

Existing tests that should remain green unchanged:

- `YokaiOrchestrator*Tests` (engine-layer behavior).
- `RootViewOnboardingGateTests` (first-launch onboarding gate).
- `WeekRotationTests` (week boundary detection).

## 12. Implementation order

1. Create `WeeklyIntroView` and its tests against a fake clip player.
2. Add the gate in `SessionContainerView.content`. Add gate tests.
3. Trim `.mondayIntro` from `YokaiCutsceneOverlay` and the corner
   portrait from `YokaiLayerView` under the same condition. Add
   regression tests.
4. Manual smoke on iPad simulator: fresh launch into the first yokai
   week, verify (a) intro screen appears and plays greet only, (b)
   tapping Next transitions cleanly into warmup with the TTS, (c) Tue
   session of the same week skips the intro.

## 13. Risks

- **State coupling.** The gate reads `yokai.activeCutscene` from inside a
  view; the `@Bindable` / `@Observable` propagation must trigger
  re-render when `dismissCutscene()` runs. Mitigation: `YokaiOrchestrator`
  is already `@Observable @MainActor` and `currentEncounter` /
  `activeCutscene` are observed by `YokaiLayerView` today, so the
  pattern is already proven inside `SessionContainerView`.
- **Test host for SessionContainerView gate test.** The existing test
  harness for SessionContainerView is light (most assertions live on
  `SessionContainerBootstrapLibraryTests`). May need a small view-host
  helper. Acceptable — same shape as `RootViewOnboardingGateTests`.

## 14. Open questions

None at design time.
