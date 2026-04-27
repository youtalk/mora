# Yokai Intro Onboarding + Tile Board Tutorial — Design Spec

- **Date:** 2026-04-25
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Project:** `mora`
- **Relates to:**
  - `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md` (canonical product spec)
  - `docs/superpowers/specs/2026-04-22-tile-board-decoding-design.md` (tile board mechanics — this spec adds a tutorial layer on top, no engine changes)
  - `docs/superpowers/specs/2026-04-22-native-language-and-age-selection-design.md` (existing `LanguageAgeFlow`)
  - `docs/superpowers/specs/2026-04-24-a-day-five-weeks-yokai-live-design.md` (5-yokai cast + per-encounter cadence — the source of truth for "5 sessions per yokai")
  - `docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md` (in-flight; this spec assumes its bundled `BundledYokaiStore` and `AVFoundationYokaiClipPlayer` are on `main`, but does not depend on Track A's `YokaiClipRouter`)

- **Scope:**
  - Add a 4-panel **Yokai intro flow** between the existing `OnboardingFlow.permission` step and `HomeView`, conveying (a) what yokai are, (b) the active week's yokai, (c) one session's shape, and (d) the 5-sessions-per-yokai progression.
  - Add a 2-panel **tile board pre-tutorial** that fires once before the first ever Decoding phase, plus a Help "?" button on `DecodeBoardView` that re-shows the same panels on demand.
  - Add an **"あそびかた" link** on `HomeView` that replays the Yokai intro flow as a sheet without flipping persistence flags.

---

## 1. Overview

The alpha learner — an 8-year-old L1-Japanese dyslexic child who tested the build — got stuck in two ways that the current launch flow does not address:

1. **The tile board (`DecodeBoardView`) was opaque.** The child did not realize tiles were draggable, did not understand what the slot row represented, and did not connect the spoken target word from TTS to "this is what you build". The existing β-scaffold (which briefly shows the target word in-place before tiles scatter) ran on his first build and was insufficient.
2. **The first launch had no narrative orientation.** `LanguageAgeFlow` collects language + age, `OnboardingFlow` collects name + interests + permission, and then `HomeView` shows a session-start CTA. The yokai concept, the session shape, and the per-yokai progression are never explained, so the child enters the first session with no model of what is about to happen or why.

This spec adds two single-purpose, English-text-translatable, **persistence-gated** introductions:

- A **Yokai intro flow** appended to the existing onboarding chain, ending where `HomeView` begins.
- A **tile board pre-tutorial** layered on top of `DecodeBoardView`, gated on a separate flag, with a Help button for replay.

Neither addition changes engines, content, SwiftData, or any persisted entity; both consist of new SwiftUI views in `MoraUI` plus 22 new keys in `MoraStrings`. Each is once-only by default and replayable on demand.

## 2. Motivation & Context

### 2.1 What the child got stuck on

In a face-to-face session with the alpha learner, the developer observed:

- **Gesture confusion** — the child tapped tiles instead of dragging, then released too quickly to start a drag.
- **Concept confusion** — the row of empty slots did not register as "the spelling of the word"; he treated them as decorative.
- **Audio-to-screen disconnect** — when TTS spoke the target word, he heard it as ambient narration rather than as "this is the word to build".

These three failure modes form a triple miss: the child cannot succeed by accident, and the existing scaffold ladder (`bounceBack → ttsHint → reducePool → autoFill`) is structured as a recovery from a wrong drop, not as orientation before the first drop. The per-day β-scaffold is a single static "see-and-rebuild" gesture that did not break through the triple miss either.

### 2.2 Why first-launch needs Yokai narrative framing

The alpha currently presents the yokai through the home hero (a portrait next to the target letter) and a Monday cutscene at the start of each new week's first session. Neither moment introduces the *concept* of yokai — that each English sound has a friendly creature you befriend by mastering that sound. A new learner sees a cartoon next to a letter and is left to infer the link.

Worse, the first session begins with no preview of the daily structure (warmup → tile board → short sentences) or the per-yokai progression (5 sessions → befriend → next yokai). The Monday cutscene tells the child "this is `<yokai name>`" but does not tell them "you and this yokai will be working together for 5 sessions". A child who does not know how many sessions form an arc has no anchor for "am I close to befriending or far?".

### 2.3 Calendar-based framing was rejected as misleading

An earlier draft of this spec used "月曜日 〜 金曜日" (Monday–Friday) as the framing for the per-yokai arc. The user observed that this implies (a) sessions are forbidden on weekends, (b) only one session per day, and (c) a strict 5-day calendar pace. The actual implementation advances on `sessionCompletionCount` regardless of calendar, so the calendar framing is both wrong and limiting. This spec uses **session-count framing** ("5 sessions per yokai") throughout.

### 2.4 Audio constraint

mora's voice assets (yokai `greet` / `phoneme` / `example_*` clips, any potential narrator audio) are part of the curriculum — the learner is meant to hear English regardless of L1. They stay English in all locales. UI text, on the other hand, is `MoraStrings`-driven and trivially localizable. This spec therefore uses text liberally and avoids any TTS-narrated panel content; the only audio in onboarding is the active yokai's bundled English `greet` clip on Panel 2.

## 3. Goals & Non-Goals

### Goals

- **G1**: A first-time install on `main` produces this sequence before `HomeView` appears: `LanguageAgeFlow → OnboardingFlow (welcome / name / interests / permission) → YokaiIntroFlow (4 panels) → HomeView`.
- **G2**: A first-time entry into the `.decoding` session phase produces a 2-panel tutorial overlay before `DecodeBoardView` appears; subsequent decoding entries skip the tutorial.
- **G3**: The Yokai intro is replayable from `HomeView` via an "あそびかた" link as a sheet, without affecting persistence.
- **G4**: The tile board tutorial is replayable from a "?" button on `DecodeBoardView`, without affecting persistence.
- **G5**: The yokai's bundled English `greet` clip plays once on Panel 2 (Today's Yokai) appearance.
- **G6**: All new strings live in `MoraStrings` and conform to the existing `JapaneseL1Profile.stringsMid` kanji budget (`JPKanjiLevel.grade1And2` only) so future locales drop in cleanly.
- **G7**: No new SwiftData entities, no migrations, no engine changes, no content authoring.
- **G8**: Each addition (Yokai intro flow, tile tutorial) ships as an independent PR; either can revert without affecting the other.

### Non-Goals

- 5-week roadmap visualization (the user explicitly rejected the cumulative roadmap as scope-creep that would distract from the immediate session).
- Per-age string variants (`stringsEarly` / `stringsLate`); alpha keeps the mid-band single table per the existing `uiStrings(forAgeYears:)` switch.
- Adding a `displayName` field to `YokaiCatalog.json` so yokai have personal names ("Shen", "Thad", …); deferred to a future bestiary-polish spec.
- TTS narration of panel text. The dyslexic 8-year-old is fluent in JP kana, and adding TTS to read panel text would create a per-locale audio asset burden that conflicts with the "audio is English curriculum, text is localized UI" invariant.
- Tile tutorial replay from `HomeView` (out of context — replay belongs on the board itself).
- Settings UI for re-editing onboarding choices (separate future spec).
- Modifying the existing scaffold ladder (`ChainScaffoldLadder`) or β see-and-rebuild scaffold; both stay as-is.
- Migrating `LanguageAgeFlow` or `OnboardingFlow` strings to follow the new naming pattern (their existing keys remain).

### Success Criteria

- **C1 (Yokai intro fires first time)**: A fresh install with no `UserDefaults` and an empty SwiftData store reaches `HomeView` only after stepping through 4 yokai-intro panels. The `tech.reenable.Mora.yokaiIntroSeen` flag is `true` after the user taps `▶ はじめる` on Panel 4.
- **C2 (Yokai intro skipped second launch)**: A second app launch goes directly to `HomeView`; `YokaiIntroFlow` is not shown.
- **C3 (Yokai intro replayable)**: Tapping the "あそびかた" link on `HomeView` shows the same 4 panels as a `.sheet`. Closing the sheet (Panel 4 CTA = "とじる") does not change `yokaiIntroSeen`.
- **C4 (Panel 2 audio)**: On Panel 2 appear, the active yokai's `greet` `.m4a` plays exactly once. Panel transition stops the clip.
- **C5 (Tile tutorial fires first time)**: A fresh install's first entry to the `.decoding` phase shows a 2-panel tutorial. Tapping `▶ やってみる` dismisses the tutorial, sets `tech.reenable.Mora.decodingTutorialSeen` to `true`, and the actual `DecodeBoardView` appears.
- **C6 (Tile tutorial skipped second time)**: A subsequent session enters `.decoding` without the tutorial.
- **C7 (Tile tutorial replay)**: Tapping the "?" button on `DecodeBoardView` shows the same 2 panels as a `.sheet`. Closing does not affect persistence.
- **C8 (No regression)**: Existing tests pass. `LanguageAgeFlow`, `OnboardingFlow`, `HomeView`, `SessionContainerView`, and `DecodeBoardView` keep their pre-spec behavior on already-onboarded installs (flags = `true`).
- **C9 (Kanji budget)**: All 22 new strings compose only `JPKanjiLevel.grade1And2` characters (and hiragana, katakana, ASCII, emoji).

## 4. Approach

Three structural choices were considered and rejected before settling on the chosen shape:

- **A1 — Single combined flow**: append all 6 panels (4 yokai-intro + 2 tile-tutorial) to `OnboardingFlow`. Rejected because the tile-tutorial only makes sense in front of the actual board (audio-to-screen connection requires the board to be the next thing the user sees); attaching it to onboarding splits the panels from their context.
- **A2 — Lean on coachmarks across `HomeView` and `DecodeBoardView`**: avoid dedicated panels, use SwiftUI tooltips / dim overlays in-context. Rejected because (a) the user picked the 4-panel story format for i18n and authoring clarity, and (b) the coachmark style would still require translatable text and an interactive overlay engine that is more code than 6 simple panel views.
- **A3 — Two independent gated flows**: `YokaiIntroFlow` (4 panels) before `HomeView`, `DecodingTutorialOverlay` (2 panels) before first `DecodeBoardView`. Each replayable from its natural surface. **Chosen** because it isolates the two cognitive issues (concept-orientation vs. mechanics-orientation), each panel set is i18n-ready as plain strings, and the two flows ship as orthogonal PRs.

The format for both flows uses the same shape: full-screen panels with title + body + visual + CTA, matching the existing `WelcomeView` / `NameView` / `InterestPickView` / `PermissionRequestView` style. Animation is SwiftUI-native (no SpriteKit, no third-party libraries), respects `accessibilityReduceMotion`, and reuses `MoraType` typography and `MoraTheme` palette.

The gating mechanism is two boolean `UserDefaults` keys mirroring the existing `tech.reenable.Mora.onboarded` and `tech.reenable.Mora.languageAgeOnboarded` patterns. No SwiftData entity, no migration.

## 5. Yokai Intro Flow

### 5.1 Trigger

`RootView` extends its existing two-stage gate (`languageAgeOnboarded → onboarded → HomeView`) to a three-stage gate:

```
languageAgeOnboarded → onboarded → yokaiIntroSeen → HomeView
```

```swift
public var body: some View {
    Group {
        if !languageAgeOnboarded {
            LanguageAgeFlow { languageAgeOnboarded = true }
        } else if !onboarded {
            OnboardingFlow { onboarded = true }
                .environment(\.moraStrings, resolvedStrings)
        } else if !yokaiIntroSeen {
            YokaiIntroFlow(mode: .firstTime) { yokaiIntroSeen = true }
                .environment(\.moraStrings, resolvedStrings)
        } else {
            NavigationStack { HomeView() ... }
        }
    }
}
```

The `yokaiIntroSeen` `@State` is initialized from `UserDefaults.standard.bool(forKey: YokaiIntroState.onboardedKey)`. The flow's `onFinished` callback flips the flag and the SwiftUI re-render swaps `YokaiIntroFlow` for the `NavigationStack { HomeView() }`.

### 5.2 State machine

A small shared enum distinguishes first-time onboarding from on-demand replay. Both new flows (Yokai intro + Decoding tutorial) consume it. Lives in a new file `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift`:

```swift
public enum OnboardingPlayMode: Equatable, Sendable {
    case firstTime  // flips the persistence flag on completion
    case replay     // does not touch persistence; CTA may differ
}
```

```swift
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

`YokaiIntroFlow` itself owns a `mode: OnboardingPlayMode` and only calls `state.finalize(in:)` when `mode == .firstTime`. Replay mode swaps the Panel 4 CTA from "▶ はじめる" to "とじる" (key `yokaiIntroClose`) and dismisses the sheet on tap.

### 5.3 Panels

The four panels share a common layout (top: title, middle: visual, bottom: body + CTA) parameterized by `step`. Each panel is a separate `View` so layouts can diverge without wrapping conditionals.

#### Panel 1 — `YokaiConceptPanel`

| | |
|---|---|
| Title (`yokaiIntroConceptTitle`) | 音には ともだちが いるよ |
| Body (`yokaiIntroConceptBody`) | えいごの 音 ひとつ ひとつに、Yokai が すんでいる。なかよく なるには、その 音を よく 聞いて、ことばに しよう。 |
| Visual | A horizontal arc of the 5 v1 yokai silhouettes (loaded via `BundledYokaiStore.catalog()` + `YokaiPortraitCorner` rendered at reduced size, no name overlay), each with a small phoneme glyph above (/ʃ/, /θ/, /f/, /r/, /æ/) |
| CTA (`yokaiIntroNext`) | つぎへ |

#### Panel 2 — `TodaysYokaiPanel`

| | |
|---|---|
| Title (`yokaiIntroTodayTitle`) | 今週の ともだち |
| Visual | Active yokai's portrait (large, centered) + grapheme letters in `MoraType.heroWord(120)` + ipa in `MoraType.subtitle()`. Yokai resolution: `CurriculumEngine.sharedV1.skills.first?.yokaiID` → `BundledYokaiStore.catalog().first(where: $0.id == yokaiID)`. (At this point in onboarding no `YokaiEncounterEntity` has been created yet — `SessionContainerView.bootstrap` is the first place that does so.) |
| Body (`yokaiIntroTodayBody`) | 今週は この 音を いっしょに れんしゅうしよう。 |
| Audio | On `.task`, play the yokai's `greet` clip via `BundledYokaiStore.voiceClipURL(for: yokaiID, clip: .greet)` → `AVFoundationYokaiClipPlayer.play(url:)` (the same `YokaiClipPlayer`-conforming concrete used by `SessionContainerView.bootstrap` for the in-session router). On panel-leave (`.onDisappear`), call `player.stop()`. Failure to resolve the URL or `play(url:) == false` is silent — the panel still renders. |
| CTA (`yokaiIntroNext`) | つぎへ |

#### Panel 3 — `SessionShapePanel`

| | |
|---|---|
| Title (`yokaiIntroSessionTitle`) | 1回の すすめかた |
| Visual | Three step icons in a horizontal row with arrows between them: 🎧 → 🟦 → 🗣️. Each icon labeled with the corresponding step name. |
| Step labels | `yokaiIntroSessionStep1` = きく / `yokaiIntroSessionStep2` = ならべる / `yokaiIntroSessionStep3` = 話す |
| Body (`yokaiIntroSessionBody`) | 1回 だいたい 10分。 |
| CTA (`yokaiIntroNext`) | つぎへ |

The "だいたい 10分" wording is empirically grounded: the developer observed a child close to him completing one full session in ~10 minutes. Earlier "15分" was authored from spec assumptions and rejected as inflated.

#### Panel 4 — `ProgressPanel`

| | |
|---|---|
| Title (`yokaiIntroProgressTitle`) | 5回で ともだちに なる |
| Visual | Five circles in a horizontal row, numbered 1–5. The first circle hosts the active yokai's portrait (small, scaled-down version of Panel 2's portrait). The fifth circle hosts a 🤝 icon. Circles 2–4 are empty / faintly outlined. |
| Body (`yokaiIntroProgressBody`) | Yokai と 5回 れんしゅうすると、なかよく なれる。1日 1回 でも、すきな ペースで OK。 |
| CTA (`yokaiIntroBegin`) firstTime / (`yokaiIntroClose`) replay | ▶ はじめる / とじる |

The "1日 1回 でも、すきな ペースで OK" sentence is load-bearing: it explicitly counters the "must do one per day on weekdays only" framing the earlier calendar-based draft induced.

### 5.4 Replay path from `HomeView`

`HomeView` adds an `@State private var showYokaiIntroReplay = false` and renders a `Button` (not `NavigationLink`) in `heroFooter` next to the existing Bestiary link:

```swift
Button { showYokaiIntroReplay = true } label: {
    Label(strings.homeRecapLink, systemImage: "questionmark.circle")
        .font(MoraType.label())
}
.buttonStyle(.bordered)
.controlSize(.large)
.sheet(isPresented: $showYokaiIntroReplay) {
    YokaiIntroFlow(mode: .replay) { showYokaiIntroReplay = false }
        .environment(\.moraStrings, strings)
}
```

`Button` + `.sheet` is preferred over `NavigationLink` here because the replay is modal — the user is "popping up" an orientation refresher, not navigating to a permanent destination. `RootView.navigationDestination(for:)` is **not** modified for the replay path.

`mode: .replay` means:
- Panel 2 still plays the `greet` clip (greet replay is an explicit feature for the learner who wants to hear it again).
- Panel 4 CTA reads "とじる" instead of "▶ はじめる".
- `YokaiIntroState.finalize` is **not** called — the flag stays whatever it was (already `true` since the user passed onboarding once).

### 5.5 Animation

Each panel transition uses the same SwiftUI move-leading + opacity pattern as the existing `OnboardingFlow`:

```swift
.transition(.move(edge: .leading).combined(with: .opacity))
```

Per-panel internal animation:
- Panel 1: silhouettes fade in with 80 ms stagger on `.task`.
- Panel 2: portrait scale-in (`.spring(response: 0.4, damping: 0.7)`), `greet` clip plays in parallel.
- Panel 3: step icons appear left-to-right with 120 ms stagger.
- Panel 4: circles fill left-to-right with 120 ms stagger; the yokai portrait drops into circle 1, the 🤝 fades into circle 5.

`@Environment(\.accessibilityReduceMotion)` substitutes 120 ms linear fades for all spring / stagger animations.

## 6. Tile Board Tutorial

### 6.1 Trigger

`SessionContainerView` reads `tech.reenable.Mora.decodingTutorialSeen` into a `@State` boolean and a sibling `@State showFirstTimeTutorial: Bool`. The `case .decoding:` branch wraps the existing `DecodeBoardView` and gates on `showFirstTimeTutorial`:

```swift
case .decoding:
    decodingPhaseContent
        .fullScreenCover(isPresented: $showFirstTimeTutorial) {
            DecodingTutorialOverlay(mode: .firstTime) {
                // onFinished
                decodingTutorialSeen = true
                UserDefaults.standard.set(true, forKey: DecodingTutorialState.seenKey)
                showFirstTimeTutorial = false
            }
        }
        .task {
            if !decodingTutorialSeen, !showFirstTimeTutorial {
                showFirstTimeTutorial = true
            }
        }
```

The `.task` runs once on the first time `case .decoding` is rendered in this session; subsequent re-renders see `showFirstTimeTutorial = true` (cover up) or `decodingTutorialSeen = true` and skip. After dismiss, the cover is gone and the underlying `DecodeBoardView` is already mounted (the `case .decoding` already emitted its hierarchy), so the tutorial-to-board transition is a single cover-dismiss.

### 6.2 State machine

```swift
@Observable
@MainActor
final class DecodingTutorialState {
    enum Step: Equatable { case slot, audio, finished }
    var step: Step = .slot

    static let seenKey = "tech.reenable.Mora.decodingTutorialSeen"

    func advance() {
        switch step {
        case .slot: step = .audio
        case .audio: step = .finished
        case .finished: break
        }
    }

    func dismiss(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.seenKey)
    }
}
```

`DecodingTutorialOverlay(mode:)` calls `state.dismiss(...)` only when `mode == .firstTime`. Replay (Help button) does not write the flag.

### 6.3 Panels

#### Panel T1 — `SlotMeaningPanel`

| | |
|---|---|
| Title (`tileTutorialSlotTitle`) | 文字を ますに 入れて ことばを つくる |
| Visual | A 3-slot row + a 5-tile pool (visually identical to `DecodeBoardView`'s layout but at 75% scale). A ghost-hand emoji animates a tile (`sh`) from the pool to the leftmost slot in a 1.5 s loop: pickup → drift → drop → reset. With `accessibilityReduceMotion`, the loop is replaced by 3 still frames cross-faded at 800 ms intervals. |
| Body (`tileTutorialSlotBody`) | ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。 |
| CTA (`tileTutorialNext`) | つぎへ |

#### Panel T2 — `AudioLinkPanel`

| | |
|---|---|
| Title (`tileTutorialAudioTitle`) | 聞いた 音を つくろう |
| Visual | A 🔊 icon at the top with sound-wave decorations. A vertical arrow drops from the speaker toward an empty slot row at the bottom. With `accessibilityReduceMotion`, the wave decoration is static; otherwise it pulses at 1 Hz. |
| Body (`tileTutorialAudioBody`) | はじめに 🔊 が 音を 聞かせる。きいた 音と 同じに なるよう、タイルを ならべよう。聞きなおすときは「もう一度 きく」を タップ。 |
| CTA (`tileTutorialTry`) | ▶ やってみる |

The CTA on Panel T2 is "▶ やってみる" rather than "つぎへ" so the learner has a clear handoff signal — closing this panel hands control to the actual board.

### 6.4 Help button on `DecodeBoardView`

`DecodeBoardView` adds a top-trailing-aligned overlay button that triggers a `.sheet` carrying `DecodingTutorialOverlay(mode: .replay)`:

```swift
.overlay(alignment: .topTrailing) {
    Button { showHelp = true } label: {
        Image(systemName: "questionmark.circle.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(MoraTheme.Accent.teal)
            .frame(width: 44, height: 44)
            .accessibilityLabel(strings.decodingHelpLabel)
    }
    .buttonStyle(.plain)
    .padding(.trailing, 12)
    .padding(.top, 8)
}
.sheet(isPresented: $showHelp) {
    DecodingTutorialOverlay(mode: .replay) { showHelp = false }
}
```

When the Help button fires:
1. The sheet presentation pauses input on the underlying `DecodeBoardView` automatically.
2. Before presentation, `speech?.stop()` is called via the existing `SpeechController` reference so an in-flight TTS does not bleed over the panel audio (the panels themselves are silent).
3. Closing the sheet returns the user to the same trial state — `engine.state` is unchanged, `engine.filled` is preserved, the active slot is the same. The user can resume by tapping a tile or pressing "もう一度 きく".

The Help button is not wired into the existing scaffold ladder — it does not increment `slotMissCount` or reduce the pool. It is purely an out-of-band orientation tool.

## 7. MoraStrings Catalog Additions

22 new keys split across two functional groups. All values authored against `JPKanjiLevel.grade1And2` (no kanji above grade 2). Hiragana spaces between bunsetsu match existing `stringsMid` style. Katakana, ASCII letters, digits, and emoji are unrestricted.

### 7.1 Yokai intro panels (15 keys)

| Key | JP value | Notes |
|---|---|---|
| `yokaiIntroConceptTitle` | 音には ともだちが いるよ | |
| `yokaiIntroConceptBody` | えいごの 音 ひとつ ひとつに、Yokai が すんでいる。なかよく なるには、その 音を よく 聞いて、ことばに しよう。 | "Yokai" rendered in romaji to match the existing romaji-mixed catalog idiom (the catalog already uses `Mora` and `iPad` as romaji words). |
| `yokaiIntroTodayTitle` | 今週の ともだち | |
| `yokaiIntroTodayBody` | 今週は この 音を いっしょに れんしゅうしよう。 | 練 / 習 are grade 3 → hiragana れんしゅう. |
| `yokaiIntroSessionTitle` | 1回の すすめかた | "1回" emphasizes per-session, not per-day. |
| `yokaiIntroSessionBody` | 1回 だいたい 10分。 | Empirical 10-minute session length, not the spec-assumed 15. |
| `yokaiIntroSessionStep1` | きく | |
| `yokaiIntroSessionStep2` | ならべる | 並 / 替 are grade 6 → hiragana ならべる. |
| `yokaiIntroSessionStep3` | 話す | 話 is grade 2 ✓. |
| `yokaiIntroProgressTitle` | 5回で ともだちに なる | 達 is grade 4 → hiragana ともだち. |
| `yokaiIntroProgressBody` | Yokai と 5回 れんしゅうすると、なかよく なれる。1日 1回 でも、すきな ペースで OK。 | "1日 1回 でも、すきな ペースで OK" defangs the calendar-pace inference. |
| `yokaiIntroNext` | つぎへ | |
| `yokaiIntroBegin` | ▶ はじめる | Reuses the visual "▶" prefix from the existing `homeStart` / `welcomeCTA` family. |
| `yokaiIntroClose` | とじる | Replay mode CTA. |
| `homeRecapLink` | あそびかた | |

### 7.2 Tile board tutorial (7 keys)

| Key | JP value | Notes |
|---|---|---|
| `tileTutorialSlotTitle` | 文字を ますに 入れて ことばを つくる | 文字 = grade 1, ますに = hiragana. 葉 is grade 3, so 言葉 → ことば (matches existing `stringsMid` style which already prefers ことば in hiragana). |
| `tileTutorialSlotBody` | ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。 | |
| `tileTutorialAudioTitle` | 聞いた 音を つくろう | |
| `tileTutorialAudioBody` | はじめに 🔊 が 音を 聞かせる。きいた 音と 同じに なるよう、タイルを ならべよう。聞きなおすときは「もう一度 きく」を タップ。 | |
| `tileTutorialNext` | つぎへ | |
| `tileTutorialTry` | ▶ やってみる | |
| `decodingHelpLabel` | あそびかたを 見る | VoiceOver / accessibility label for the "?" button. |

### 7.3 Catalog-level changes

- `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`: 22 `public let` declarations added to the `MoraStrings` struct, in initializer-parameter order matching the struct order. Initializer signature grows by 22 parameters.
- `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`: `stringsMid` literal grows by 22 lines.
- `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift`: the existing non-empty / kanji-budget loops add 22 entries.

## 8. Persistence

### 8.1 New `UserDefaults` keys

| Key | Type | Default | When `true` is written |
|---|---|---|---|
| `tech.reenable.Mora.yokaiIntroSeen` | `Bool` | `false` | `YokaiIntroState.finalize(defaults:)` from `YokaiIntroFlow(mode: .firstTime)` Panel 4 CTA tap |
| `tech.reenable.Mora.decodingTutorialSeen` | `Bool` | `false` | `DecodingTutorialState.dismiss(defaults:)` from `DecodingTutorialOverlay(mode: .firstTime)` Panel T2 CTA tap |

Both keys mirror the existing pattern used by `LanguageAgeState.onboardedKey` and `OnboardingState.onboardedKey`. No `MoraCore` change needed beyond the `static let` declarations on the new state classes.

### 8.2 Reset for development

`HomeView.resetCurriculum()` (the `#if DEBUG` Reset button) gains two lines that remove the new keys. While there, this PR also confirms that the existing flags (`languageAgeOnboardedKey`, `OnboardingState.onboardedKey`) are reset in `resetCurriculum()` — if they are not, that gap is fixed in the same diff so a single Reset tap restores a true first-launch state.

### 8.3 No SwiftData impact

No new entities, no new fields on existing entities, no migrations. The pre-existing on-disk → in-memory fallback in `MoraApp` continues to work unchanged.

## 9. Architecture & Code Organization

```
Packages/MoraUI/Sources/MoraUI/
├── Onboarding/
│   ├── OnboardingFlow.swift          (existing — unchanged)
│   ├── WelcomeView.swift             (existing — unchanged)
│   ├── NameView.swift                (existing — unchanged)
│   ├── InterestPickView.swift        (existing — unchanged)
│   ├── PermissionRequestView.swift   (existing — unchanged)
│   ├── YokaiIntroFlow.swift          (new — state machine + flow View)
│   └── YokaiIntro/
│       ├── YokaiConceptPanel.swift   (new)
│       ├── TodaysYokaiPanel.swift    (new — uses BundledYokaiStore inline)
│       ├── SessionShapePanel.swift   (new)
│       └── ProgressPanel.swift       (new)
└── Session/
    └── TileBoard/
        ├── DecodeBoardView.swift     (modified — adds top-right "?" overlay)
        ├── DecodingTutorialOverlay.swift (new — state machine + sheet View)
        └── Tutorial/
            ├── SlotMeaningPanel.swift (new)
            └── AudioLinkPanel.swift  (new)
```

Only `MoraUI` changes substantially. `MoraCore` adds 22 strings + initializer growth. No `MoraEngines` change. No `MoraTesting` change (the new tests use existing fakes / in-memory `ModelContainer`). No `MoraMLX` change.

The dependency direction `Core ← Engines ← UI` is preserved: `YokaiIntroFlow`'s Panel 2 reads `MoraCore.CurriculumEngine.sharedV1` and `MoraCore.BundledYokaiStore`, both pre-existing. `AVFoundationYokaiClipPlayer` lives in `MoraEngines.Yokai/` and is already used by `YokaiCutsceneOverlay`; importing it into the new panel is one more `import MoraEngines` line.

## 10. Testing Strategy

### 10.1 `MoraCore`

- `MoraStringsTests` (existing): the `nonEmpty` and `kanjiBudget` loops already iterate every `public let` on `MoraStrings`. Add 22 entries to those loops.

### 10.2 `MoraUI`

- `YokaiIntroStateTests` (new):
  - `advance()` walks `concept → todayYokai → sessionShape → progress → finished`.
  - `finalize(defaults:)` flips the flag.
  - `mode == .replay` does not call `finalize` (verified by test driver).
- `DecodingTutorialStateTests` (new):
  - `advance()` walks `slot → audio → finished`.
  - `dismiss(defaults:)` flips the flag in `.firstTime`; not in `.replay`.
- `RootViewOnboardingGateTests` (new, in-memory `ModelContainer` + ephemeral `UserDefaults`):
  - All flags `false` → `LanguageAgeFlow` is the rendered view.
  - `languageAgeOnboarded = true` only → `OnboardingFlow`.
  - `onboarded = true`, `yokaiIntroSeen = false` → `YokaiIntroFlow`.
  - All true → `HomeView` (or its `NavigationStack`).
- `YokaiIntroPanel2AudioTests` (new):
  - Stubbed `AVAudioPlayer` (or fake clip player injected via environment) records that `.play()` is called exactly once on Panel 2 appearance and `.stop()` on disappearance.
- `SessionContainerDecodingTutorialTests` (new):
  - `decodingTutorialSeen = false` + entering `.decoding` → `showFirstTimeTutorial` becomes `true`, `DecodingTutorialOverlay` is presented.
  - Tutorial dismiss flips the flag and clears the cover.
  - `decodingTutorialSeen = true` + entering `.decoding` → no cover.

### 10.3 SwiftUI Previews (manual review only)

Previews for each of the 6 panels in `Light / Dark / iPad portrait / iPad landscape`. CI builds the previews; visual diffing is by-eye. No snapshot-testing dependency added.

### 10.4 No regression

`swift test` across all four packages (`MoraCore`, `MoraEngines`, `MoraUI`, `MoraTesting`) must pass. `xcodegen generate && xcodebuild build` for the app target must build clean.

## 11. Phasing & PR Plan

Two PRs. Either may merge first. The 3 shared files (`MoraStrings.swift`, `JapaneseL1Profile.swift`, `MoraStringsTests.swift`) produce trivial textual conflicts that resolve in seconds; no logical conflict.

### 11.1 PR 1 — Yokai Intro Onboarding (~600 LOC, ~1 week)

**New files**
- `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift` (shared with PR 2)
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift`

**Modified files**
- `Packages/MoraUI/Sources/MoraUI/RootView.swift` — three-stage gate (no new navigation destination; replay is local to `HomeView`).
- `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` — `homeRecapLink` link in `heroFooter`.
- `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift` — 15 keys (14 yokai-intro + 1 home).
- `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift` — 15 values in `stringsMid`.
- `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift` — 15 entries.

**Tests**: `YokaiIntroStateTests`, `RootViewOnboardingGateTests`, `YokaiIntroPanel2AudioTests`.

**Done state**: a fresh install reaches `HomeView` only after stepping through the 4 yokai-intro panels; `HomeView` exposes an "あそびかた" link that replays them.

### 11.2 PR 2 — Tile Board Tutorial (~400 LOC, ~1 week)

**New files**
- `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift` (also created by PR 1; whichever PR ships first creates the file, the second PR rebases as a no-op since the contents are identical)
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift`
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/SlotMeaningPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/AudioLinkPanel.swift`

**Modified files**
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — `.decoding` branch wraps existing content in `.fullScreenCover` for first-time tutorial.
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift` — top-trailing "?" overlay button + Help-replay sheet.
- `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift` — 7 keys (6 tile-tutorial + 1 help label).
- `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift` — 7 values in `stringsMid`.
- `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift` — 7 entries.

**Tests**: `DecodingTutorialStateTests`, `SessionContainerDecodingTutorialTests`.

**Done state**: a fresh install's first decoding phase shows the 2 tutorial panels; the board's top-right "?" replays them at any time.

### 11.3 Optional polish (later, separate PR)

- `HomeView.resetCurriculum()` (`#if DEBUG`) clears the new flags + audits the existing flags for parity. Confirmation that a single Reset tap fully restores a first-launch state.
- Per-age string variants (`stringsEarly` / `stringsLate`) for the new 22 keys. Alpha can ship without them — `JapaneseL1Profile.uiStrings(forAgeYears:)` already returns `stringsMid` for every bucket.

### 11.4 Calendar timing

PR 1 and PR 2 ship in parallel (separate worktrees, file-disjoint apart from the 3 strings files). Total calendar time ~1–2 weeks depending on review cycles. Track A (`YokaiClipRouter`) and Track B (sentence library) of the in-flight 2026-04-25 voice-wiring spec are unaffected and may merge in any order.

## 12. Open Questions / Forward Hooks

1. **Yokai personal names.** Panel 2 currently presents the active yokai by `grapheme` + `ipa` (e.g., "sh", "/ʃ/"). The in-flight sentence library spec lists proper-noun pools per phoneme (`Shen`, `Thad`, `Finn`, `Rex`, `Sam`) that could double as yokai display names. Adding a `displayName` field to `YokaiCatalog.json` and rendering it on Panel 2 + Bestiary cards is a one-PR follow-up that warms the entire app's yokai voice without touching this spec's mechanics.
2. **"おさらい" entry-point copy.** "あそびかた" is approachable for the alpha learner. Once Settings exists, a more discoverable alternative is the standard iOS "ヘルプ" pattern. Today's link is intentionally on `HomeView` proper, not behind a Settings shell.
3. **Tile tutorial telemetry.** The Help button is tap-only and unrecorded. If alpha feedback shows learners replay the tutorial mid-session as a stalling tactic, a future `BuildAttemptRecord`-adjacent counter could surface that signal to a parent dashboard.
4. **Session-shape panel adaptivity.** The 3 step icons (🎧 / 🟦 / 🗣️) match the v1 phase set (`warmup` / `decoding` / `shortSentences`). When C-day reading-adventure ships, this panel grows a 4th step or splits into A-day / C-day variants. Schema-wise the strings are independent so this is purely a Panel 3 rewrite.

## 13. Acceptance Checklist

For PR 1:
- [ ] Fresh install with empty `UserDefaults` and empty store reaches `HomeView` only after the 4-panel `YokaiIntroFlow`.
- [ ] `tech.reenable.Mora.yokaiIntroSeen = true` after Panel 4 CTA tap.
- [ ] Second app launch goes directly to `HomeView`.
- [ ] "あそびかた" link on `HomeView` replays the 4 panels as a `.sheet`; closing leaves `yokaiIntroSeen` unchanged.
- [ ] Panel 2 plays the active yokai's `greet` clip exactly once on appear; clip stops on panel leave.
- [ ] All 15 new strings present in `JapaneseL1Profile.stringsMid` and pass the existing kanji-budget loop.
- [ ] `swift test` green on `MoraCore` and `MoraUI`. `xcodegen generate && xcodebuild build` green.

For PR 2:
- [ ] Fresh install's first `.decoding` phase entry shows the 2 tutorial panels in a `.fullScreenCover`.
- [ ] `▶ やってみる` flips `decodingTutorialSeen` and dismisses to the actual board.
- [ ] Subsequent `.decoding` entries skip the tutorial.
- [ ] Top-right "?" on `DecodeBoardView` re-shows the panels as a `.sheet` without changing persistence.
- [ ] Help-button presentation calls `speech?.stop()` so no TTS bleeds over the tutorial.
- [ ] All 7 new strings present in `JapaneseL1Profile.stringsMid`.
- [ ] `swift test` green; existing scaffold-ladder and β-scaffold behavior unchanged.
