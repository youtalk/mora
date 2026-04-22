# mora — iPad-first A-day UX + Real Speech/TTS (alpha) Design Spec

- **Date:** 2026-04-22
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Follows:** `2026-04-21-mora-scaffold-and-first-a-day.md` (Phase 1–10 complete)
- **Supersedes nothing.** Extends the v1 surface described in `2026-04-21-mora-dyslexia-esl-design.md`.

---

## 1. Overview

The A-day scaffold (warmup → new rule → decoding → short sentences → completion) has been implemented end-to-end using fake Speech/TTS engines and placeholder "Correct/Wrong" tap buttons. The SwiftUI surface renders in the simulator but is sized to content and sits in a small centered stack on iPad — the app does not use the iPad's screen area, and the fakes prevent the target learner from actually reading aloud.

This plan turns the existing scaffold into an **alpha version the target user (Yutaka's 8-year-old son) can use on a real iPad**. It covers four intertwined concerns:

1. An iPad-native design system (tokens + components) tuned for dyslexia legibility and a playful tone
2. A full-bleed "Fullscreen Focus" session layout and a "Single Hero" home screen that use the full iPad canvas
3. A first-run onboarding flow (name, interests, permissions)
4. Real on-device Speech (`SFSpeechRecognizer`) and TTS (`AVSpeechSynthesizer`) wired through the existing engine protocols, using a **tap-to-listen** interaction model

C-day, Parent Mode, CloudKit, AdaptivePlanEngine/SRS, EscalationManager rungs L2–L4, Settings, and the LLM vocabulary expander are explicitly **not** in this plan — each gets its own plan after this alpha.

## 2. Motivation

- The primary learner is 8 years old with dyslexia. The current visual design (small centered stack, no hero treatment, placeholder buttons) does not hold attention on a 10.9" iPad.
- Without real ASR + TTS, the learning loop cannot actually run. The child taps Correct/Wrong by proxy today, which is not a learning experience.
- The visual and behavior work share enough surface area (session views, assessment flow, state persistence) that splitting them across two plans would force us to rewrite the same views twice.
- The bench app on `worktree-memoized-percolating-wren` validates v1.5 LLM feasibility independently. This plan deliberately does not depend on that work landing.

## 3. Goals and Non-Goals

### Goals

- iPad canvas is fully used. No more small-centered layouts; each session phase fills the screen edge to edge with a hero treatment.
- The target grapheme is the visual centerpiece at home and in every phase.
- The child reads words and sentences aloud and the app scores them via on-device ASR.
- The app speaks to the child (target phoneme, rule explanation, scaffolding on miss) using on-device TTS.
- First launch includes a short onboarding that captures name (optional), interests, and permissions.
- Microphone / speech-recognition denial falls back to the existing tap mode — the session never breaks.
- All content policies from the v1 spec (on-device only, L1-aware via `L1Profile`, decodability-guaranteed content, dyslexia-friendly typography and color) are upheld.

### Non-Goals

- C-day (Reading Adventure) and `StoryLibrary` — separate plan.
- Parent Mode, CloudKit pairing, weekly reports — separate plan.
- `AdaptivePlanEngine` state machine, spaced repetition, weekly re-targeting — separate plan. A minimal `AssessmentLeniency` enum is added here only so UI can pass `.newWord`.
- `EscalationManager` rungs L2–L4 (in-session "let's take a breath", help-request push, weekly attention items).
- A Settings screen. The font toggle, interest re-pick, and onboarding reset defined for v1 are deferred.
- `LLMVocabularyExpander` and anything under `MoraMLX`. The package stays empty.
- A second `L1Profile` implementation. `JapaneseL1Profile` remains the only profile used.
- iPhone or Mac Catalyst layout optimization. The child app runs on iPad only; other platforms will render but are not tuned.
- SwiftUI snapshot tests — deferred as low-ROI for this phase (no existing infrastructure, brittle).

### Out of Scope: Relationship to the bench worktree

The `worktree-memoized-percolating-wren` branch contains an independent LLM benchmark iPad app under `bench/`. This plan:

- Does **not** touch anything under `bench/`.
- Does **not** add any MLX-related dependency to Mora, the packages, or `project.yml`. `MoraMLX` stays empty per v1 spec §11.5.
- Produces no merge conflict with the bench branch regardless of which lands on `main` first.

If bench merges to `main` mid-plan, no change is needed. If it does not merge during this plan, no change is needed.

## 4. Design Decisions

### 4.1 Visual tone: "Playful Adventurer"

Chosen from three candidates (Warm Scholar / Playful Adventurer / Focused Minimalist) explored via visual mockups during brainstorming.

- Primary font for body / prose: **OpenDyslexic Regular** (SIL OFL, bundled as a package resource)
- Hero font for target grapheme and numerals: **SF Pro Rounded Heavy** (Apple system)
- Background: warm off-white (`#FFFBF5`), never pure white, never pure black text
- Primary accent: orange (`#FF7A00`), with shadow variant (`#C85800`) for 3D-press button effect
- Secondary accent: teal (`#00A896`) for streak / success states
- Soft mint (`#D5F0EA`) for streak chip background
- Press-shadow CTA (drop-shadow offset-y with darker variant) gives buttons a tactile feel appropriate for a kid
- Warm cream (`#FFE8D6`, `#FFCFA5`) for large surfaces

Dyslexia-friendly baselines from spec §7 are preserved under this tone: generous letter spacing, wide line spacing, large touch targets (≥88pt for main actions), warm off-white background.

### 4.2 Session layout: "Fullscreen Focus" (L1)

Each session phase fills the iPad screen with a three-band structure:

- Top chrome: close (✕) · phase pips (5 dots: warmup / newRule / decoding / shortSentences / completion) · streak chip (🔥 N)
- Body: flex-filled, hero-centered content, scaled to iPad (96–180pt headings)
- Bottom chrome (optional per phase): progress text, hint buttons

No sidebar during session. Close button opens a confirmation dialog before returning to Home.

### 4.3 Home screen: "Single Hero" (H1)

Minimal home with one intent: start today's quest.

- Wordmark "mora" top-left
- Streak chip top-right
- Hero block centered: "Today's quest" label + 180pt target grapheme + IPA and example words
- Primary CTA: big orange "▶ Start" capsule with press-shadow
- Below: three pills (duration / word count / sentence count)

No tabs, no dashboard, no history view on H1. All three are deferred.

### 4.4 Speech interaction: Tap-to-listen

- The child sees the word. A large orange mic button sits in the mic area.
- Tap the mic → engine starts listening. Mic button pulses with a teal ring.
- The child reads. Partial transcripts appear in small grey text below the word.
- 2.5 s of silence (or 15 s total timeout) → engine emits `.final` → orchestrator assesses → feedback animation → next word.
- Mic denied fallback: the mic button is replaced by the existing Correct / Wrong tap pair.

Auto-listen (no tap) and hold-to-speak were considered and rejected: auto-listen surprises a child whose reading cadence is slow and hesitant; hold-to-speak is physically awkward on a flat iPad surface.

### 4.5 Implementation approach: UI-first, behavior-second

Seven phases are ordered so the visual foundation lands before live-device behavior. At the end of Phase 3 the app is a visually convincing iPad experience (still running on fakes) that can be shown to the learner. Phases 5–7 replace fakes with real engines and add the alpha polish.

## 5. Architecture

### 5.1 Package layout (no new packages)

The v1 five-package structure is preserved. All additions land in existing packages.

```
Packages/
├── MoraCore/
│   └── Persistence/
│       ├── LearnerProfile.swift            [new @Model]
│       └── DailyStreak.swift               [new @Model]
│   └── L1Profile.swift                     [extended: exemplars(for:)]
│
├── MoraEngines/
│   ├── AssessmentEngine.swift              [extended: AssessmentLeniency]
│   ├── SpeechEngine.swift                  [protocol reshaped: SpeechEvent stream]
│   └── Speech/                             [new subdirectory]
│       ├── SpeechEvent.swift
│       ├── AppleSpeechEngine.swift
│       ├── AppleTTSEngine.swift
│       └── PermissionCoordinator.swift
│
├── MoraUI/
│   └── Sources/MoraUI/
│       ├── Design/                         [new subdirectory]
│       │   ├── MoraTheme.swift             (colors, type, spacing tokens)
│       │   ├── Typography.swift            (OpenDyslexic registration)
│       │   └── Components/
│       │       ├── HeroCTA.swift
│       │       ├── MicButton.swift
│       │       ├── PhasePips.swift
│       │       ├── StreakChip.swift
│       │       └── FeedbackOverlay.swift
│       ├── Home/
│       │   └── HomeView.swift              (H1)
│       ├── Onboarding/                     [new subdirectory]
│       │   ├── OnboardingFlow.swift
│       │   ├── WelcomeView.swift
│       │   ├── NameView.swift
│       │   ├── InterestPickView.swift
│       │   └── PermissionRequestView.swift
│       ├── Session/                        [reorganized]
│       │   ├── SessionContainerView.swift  (top/bottom chrome + phase dispatch)
│       │   ├── WarmupView.swift            (L1)
│       │   ├── NewRuleView.swift           (L1)
│       │   ├── DecodeActivityView.swift    (L1 + tap-to-listen)
│       │   ├── ShortSentencesView.swift    (L1 + tap-to-listen)
│       │   └── CompletionView.swift        (L1 + celebration)
│       └── RootView.swift                  (branch: onboarding vs Home)
│   └── Sources/MoraUI/Resources/
│       └── Fonts/OpenDyslexic-Regular.otf
│
├── MoraTesting/
│   ├── FakeSpeechEngine.swift              [migrated to stream API]
│   ├── FakeTTSEngine.swift                 [unchanged]
│   └── FakePermissionSource.swift          [new]
│
└── MoraMLX/                                 (empty, unchanged)
```

Dependency direction (`Core ← Engines ← UI`, `Testing` depending on Core + Engines) is preserved.

### 5.2 Persistence additions

```swift
@Model public final class LearnerProfile {
    public var id: UUID
    public var displayName: String            // "" allowed (skip during onboarding)
    public var l1Identifier: String           // "ja" for v1
    public var interests: [String]            // InterestCategory.key values
    public var preferredFontKey: String       // "openDyslexic" | "sfRounded"
    public var createdAt: Date
}

@Model public final class DailyStreak {
    public var id: UUID
    public var currentCount: Int
    public var longestCount: Int
    public var lastCompletedOn: Date?         // date-of (local calendar), not wall time
}
```

Both are synced-to-disk, not CloudKit-synced in this plan (CloudKit wiring is deferred). `SessionSummaryEntity` is unchanged.

Onboarding-completed flag is stored in `UserDefaults` under `tech.reenable.Mora.onboarded` rather than SwiftData — it is a boot-time UI branch, not a domain object.

### 5.3 Navigation

```
MoraApp
└── RootView
    └── if !UserDefaults.bool("tech.reenable.Mora.onboarded")
        → OnboardingFlow (replaces root)
        else
        → NavigationStack
            ├── HomeView (root)
            └── push → SessionContainerView
                         (completion tap or close confirm → popToRoot)
```

During session, `NavigationStack.toolbar(.hidden)` hides the nav bar. The session's own top chrome provides close + phase pips + streak.

## 6. Design System (MoraDesign tokens)

### 6.1 Color tokens

```swift
public enum MoraTheme {
    public enum Background {
        public static let page: Color    = Color(hex: 0xFFFBF5)
        public static let cream: Color   = Color(hex: 0xFFE8D6)
        public static let peach: Color   = Color(hex: 0xFFCFA5)
        public static let mint:  Color   = Color(hex: 0xD5F0EA)
    }
    public enum Accent {
        public static let orange:         Color = Color(hex: 0xFF7A00)
        public static let orangeShadow:   Color = Color(hex: 0xC85800)
        public static let teal:           Color = Color(hex: 0x00A896)
        public static let tealShadow:     Color = Color(hex: 0x007F73)
    }
    public enum Ink {
        public static let primary:  Color = Color(hex: 0x2A1E13)
        public static let secondary: Color = Color(hex: 0x8A7453)
        public static let muted:    Color = Color(hex: 0x888888)
    }
    public enum Feedback {
        public static let correct: Color = Color(hex: 0x00A896)
        public static let wrong:   Color = Color(hex: 0xFF7A00)
    }
}
```

All contrast ratios checked against WCAG AA for body text on `Background.page`.

### 6.2 Typography tokens

```swift
public extension MoraTheme {
    enum TypeScale {
        static func hero(_ size: CGFloat = 180) -> Font  // SF Rounded Heavy
        static func bodyReading() -> Font                  // OpenDyslexic Regular 22
        static func heading() -> Font                      // SF Rounded Bold 28
        static func label() -> Font                        // SF Rounded SemiBold 14
        static func pill() -> Font                         // SF Rounded SemiBold 12
    }
}
```

`bodyReading()` resolves via `LearnerProfile.preferredFontKey`: when `"openDyslexic"`, returns the custom font; when `"sfRounded"`, returns the system rounded design. v1 defaults to `"openDyslexic"`; the toggle UI is deferred to Settings.

### 6.3 Spacing / radius tokens

```swift
public extension MoraTheme {
    enum Space {
        static let xs: CGFloat = 4, sm: CGFloat = 8, md: CGFloat = 16
        static let lg: CGFloat = 24, xl: CGFloat = 32, xxl: CGFloat = 48
    }
    enum Radius {
        static let button: CGFloat = 999   // capsule
        static let card: CGFloat = 22
        static let chip: CGFloat = 999
        static let tile: CGFloat = 14
    }
}
```

### 6.4 Components

| Component | Purpose | Key traits |
|---|---|---|
| `HeroCTA` | Primary start / continue button | Orange capsule, 18pt text, press-shadow offset 5pt, haptic on tap |
| `MicButton` | Tap-to-listen trigger | 96pt circle, orange, teal pulsing ring during listen state, transitions idle/listening/assessing |
| `PhasePips` | Session progress | 5 × 34pt×6pt rounded caps, teal done / orange active / grey pending |
| `StreakChip` | Current streak visibility | Mint pill with flame emoji + count, tappable (no destination in this plan — stub) |
| `FeedbackOverlay` | Correct / Wrong animation | Full-view overlay: green glow + checkmark OR shake + orange border, timed 400–600ms |

### 6.5 Font bundling

- OpenDyslexic Regular ships as `Packages/MoraUI/Sources/MoraUI/Resources/Fonts/OpenDyslexic-Regular.otf`
- Registration via `CTFontManagerRegisterGraphicsFont` in `Typography.swift` at package init (not in the app target)
- Package `Package.swift` adds the font to resources, and the app target inherits via the `MoraUI` product
- License: SIL OFL, compatible with PolyForm Noncommercial 1.0.0

## 7. Session Layout (L1 Fullscreen Focus)

### 7.1 SessionContainerView frame

```
SessionContainerView
├── top chrome (safeAreaInset .top)
│   HStack {
│     CloseButton(action: confirmExit)
│     Spacer()
│     PhasePips(current: orchestrator.phase)
│     Spacer()
│     StreakChip(count: streak.currentCount)
│   }.padding(MoraTheme.Space.md)
│
├── phase body
│   @ViewBuilder switch orchestrator.phase { ... }
│   .frame(maxWidth: .infinity, maxHeight: .infinity)
│   .padding(.horizontal, MoraTheme.Space.xxl)
│
└── feedback overlay (z-above)
    FeedbackOverlay(state: uiState.feedback) — renders when set, then auto-clears
```

Background: `MoraTheme.Background.page` applied to the container's `.ignoresSafeArea()` so the color reaches the edges of the iPad display.

### 7.2 Per-phase body layout

| Phase | Hero | Interaction | Bottom |
|---|---|---|---|
| Warmup | Three 140×140pt grapheme tiles in HStack, 84pt SF Rounded Heavy letters | Tap a tile (Speech not used here) | "🔊 Listen again" button → replays target phoneme via TTS |
| NewRule | `sh → /ʃ/` in 80pt, then three worked example tiles ("ship", "shop", "fish") | "Got it" CTA when TTS finishes reading the rule | TTS play/pause control |
| Decoding | Target word in SF Rounded Heavy 96pt (120pt in landscape) | `MicButton` (tap-to-listen) center-bottom | "Word 3 of 5 · long-press to hear" |
| ShortSentences | Sentence in SF Rounded Medium 52pt (64pt landscape), multiline center-aligned | `MicButton` center-bottom | "Sentence 1 of 2 · long-press to hear" |
| Completion | "Quest complete!" 60pt + "6 / 7" huge scoreline | Tap anywhere → return to Home | Streak +1 animation pulse + "Come back tomorrow" |

### 7.3 Size classes and orientation

- Primary target: iPad landscape, `horizontalSizeClass == .regular` in both portrait and landscape
- `DecodeActivityView` and `ShortSentencesView` split into two columns in landscape (hero left, `MicButton` right) when screen width > 1100pt; otherwise stacked
- Portrait on iPad mini is still usable (stacked) but not optimized with a separate branch

## 8. Home (H1 Single Hero)

```swift
struct HomeView: View {
    @Query private var profiles: [LearnerProfile]
    @Query private var streaks: [DailyStreak]
    @State private var todaysTarget: Target? = nil

    var body: some View {
        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()

            VStack(spacing: MoraTheme.Space.lg) {
                HStack {
                    Text("mora")
                        .font(MoraTheme.TypeScale.heading())
                        .foregroundStyle(MoraTheme.Accent.orange)
                    Spacer()
                    StreakChip(count: streaks.first?.currentCount ?? 0)
                }.padding(MoraTheme.Space.md)

                Spacer()

                VStack(spacing: MoraTheme.Space.md) {
                    Text("Today's quest")
                        .font(MoraTheme.TypeScale.label())
                        .foregroundStyle(MoraTheme.Ink.muted)

                    Text(todaysTarget?.letters ?? "--")
                        .font(MoraTheme.TypeScale.hero(180))
                        .foregroundStyle(MoraTheme.Ink.primary)

                    Text(todaysTarget?.ipaAndExamples ?? "")
                        .font(MoraTheme.TypeScale.label())
                        .foregroundStyle(MoraTheme.Ink.secondary)

                    HeroCTA(title: "▶ Start", action: startQuest)
                        .padding(.top, MoraTheme.Space.md)

                    HStack(spacing: MoraTheme.Space.sm) {
                        Pill("16 min"); Pill("5 words"); Pill("2 sentences")
                    }
                }

                Spacer()
            }
        }
    }
}
```

Today's target comes from `CurriculumEngine.currentTarget(forWeekIndex:)`. Week index is derived from `daysSince(LearnerProfile.createdAt) / 7` (capped at curriculum length).

"▶ Start" push-navigates to `SessionContainerView` inside a `NavigationStack`. When the session completes or is cancelled, popToRoot returns here.

## 9. Onboarding Flow

Four screens, back navigation enabled, skipped entirely on subsequent launches.

### 9.1 Step flow

1. **Welcome** — `mora` wordmark + "Let's learn English sounds together" + `HeroCTA("Get started")`
2. **Name** — "What should we call you?" + TextField + Skip (top-right) + `HeroCTA("Next")`. Empty string is allowed.
3. **InterestPick** — 2×3 grid of category tiles from `JapaneseL1Profile.interestCategories` (6 categories: animals, dinosaurs, vehicles, space, sports, robots). Min 3 selections to enable `HeroCTA("Next")`, max 5.
4. **PermissionRequest** — "We'll listen when you read." + `HeroCTA("Allow")` + secondary "Not now". Triggers mic + speech permission via `PermissionCoordinator.request()`. On any result, proceeds to finish.

Bottom of every onboarding view: 4-dot progress indicator (same component as `PhasePips` repurposed).

### 9.2 Completion

When step 4 completes:
- `modelContext.insert(LearnerProfile(displayName: name, l1Identifier: "ja", interests: keys, preferredFontKey: "openDyslexic", createdAt: now))`
- `modelContext.insert(DailyStreak(currentCount: 0, longestCount: 0, lastCompletedOn: nil))`
- `try modelContext.save()`
- `UserDefaults.standard.set(true, forKey: "tech.reenable.Mora.onboarded")`
- Navigate to Home (replace root, no back)

### 9.3 Interest catalog (JapaneseL1Profile v1)

Bundled categories come from `JapaneseL1Profile.interestCategories`: `animals`, `dinosaurs`, `vehicles`, `space`, `sports`, `robots` (6 total). This plan does not add new categories or extend the `InterestCategory` model.

Emoji icons for the grid tiles are mapped locally in the UI layer (a `key → emoji` dictionary in `InterestPickView.swift`), so the core `InterestCategory` struct stays free of display-layer concerns. Initial mapping: `animals 🐕` · `dinosaurs 🦖` · `vehicles 🚗` · `space 🚀` · `sports ⚽` · `robots 🤖`.

### 9.4 Re-entry

Reset, re-pick interests, and re-request permissions are all deferred to a future Settings screen.

## 10. Speech Engine

### 10.1 Protocol reshape

The current protocol is `func listen() async throws -> ASRResult`. It is replaced with a streaming form so the UI can render partial transcripts and react to end-of-utterance.

```swift
public enum SpeechEvent: Sendable {
    case started
    case partial(String)
    case final(ASRResult)
}

public protocol SpeechEngine: Sendable {
    func listen() -> AsyncThrowingStream<SpeechEvent, Error>
    func cancel()
}
```

All call sites (orchestrator wiring, `FakeSpeechEngine`, test doubles) migrate in the same commit as the protocol change. There is no compatibility shim.

### 10.2 `AppleSpeechEngine`

- `SFSpeechRecognizer(locale: Locale(identifier: "en-US"))`
- Asserts `supportsOnDeviceRecognition == true`; otherwise initializer throws
- `request.requiresOnDeviceRecognition = true` (enforced offline-only per spec §3)
- New `SFSpeechRecognizer` + `SFSpeechAudioBufferRecognitionRequest` + `AVAudioEngine` per `listen()` call (avoids the ~1-minute per-task limit)
- `AVAudioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil)` → `request.append(audioBuffer:)`
- Silence timer: 2.5 s since last `.partial` → `request.endAudio()` + synthesize `.final`
- Hard timeout: 15 s total → same `.endAudio()` with empty transcript
- Tear-down: `audioEngine.stop()`, remove tap, cancel task
- `cancel()` is idempotent; safe from any state

### 10.3 `PermissionCoordinator`

```swift
@MainActor public final class PermissionCoordinator {
    public enum Status: Equatable {
        case notDetermined
        case allGranted
        case partial(micDenied: Bool, speechDenied: Bool)
    }
    public func current() -> Status
    public func request() async -> Status
}
```

- `request()` calls `AVAudioApplication.requestRecordPermission` then `SFSpeechRecognizer.requestAuthorization`, in sequence
- `current()` reads `AVAudioApplication.shared.recordPermission` + `SFSpeechRecognizer.authorizationStatus()` synchronously
- A `PermissionSource` protocol wraps these OS calls so `FakePermissionSource` can drive tests

Info.plist additions (via `project.yml` → `infoPlist`):

```yaml
NSMicrophoneUsageDescription: "mora listens when you read aloud during practice."
NSSpeechRecognitionUsageDescription: "mora recognizes the words you read so it can score them."
```

### 10.4 Tap-to-listen UI state machine

Each of `DecodeActivityView` and `ShortSentencesView` owns:

```swift
enum MicUIState {
    case idle
    case listening(partialText: String)
    case assessing
    case feedback(correct: Bool)
}
```

Transitions:

```
.idle
  -- tap MicButton --> .listening(partialText: "")
      Task { for try await event in engine.listen() { ... } }
      partial → state.partialText = text
      final(asr)
        → .assessing (120 ms visual beat)
        → orchestrator.handle(.answerResult(correct: judge(asr, expected), asr: asr))
        → .feedback(correct:)
            overlay animates 400–600 ms
        → .idle (for next word) or advance to next phase
  error / cancel → .idle with inline banner "let's try once more"
```

Judge function: uses `AssessmentEngine.assess(expected:asr:leniency: .newWord)`.

### 10.5 OrchestratorEvent reshape (judge inside the orchestrator, not the UI)

Today `OrchestratorEvent.answerResult(correct: Bool, asr: ASRResult)` lets the UI pre-decide correctness. With real ASR this is wrong: the orchestrator is the source of truth and must score using `AssessmentEngine.assess(... leniency: .newWord)`. Two events replace the current one:

```swift
public enum OrchestratorEvent: Sendable {
    case warmupTap(Grapheme)
    case advance
    case answerHeard(ASRResult)          // from AppleSpeechEngine
    case answerManual(correct: Bool)     // from tap-fallback Correct/Wrong
    // existing: warmupMissed handled internally
}
```

- `answerHeard`: orchestrator calls `assessment.assess(expected: expected, asr: asr, leniency: .newWord)` and records the resulting `TrialAssessment`
- `answerManual`: orchestrator records a trial with the explicit correctness flag (same semantics as today's `answerResult(correct:)` path, for tap-fallback mode)

Existing integration tests that construct `.answerResult(correct:asr:)` are migrated to `.answerManual(correct:)` in the same commit that reshapes the enum.

### 10.6 Fallback when permission is denied

- On `SessionContainerView.onAppear`: `PermissionCoordinator.current()` is consulted
- `.partial` or `.notDetermined` with prior denial → `sessionUIMode = .tapFallback`
- In `.tapFallback` mode, `DecodeActivityView` and `ShortSentencesView` render the existing `Correct` / `Wrong` button pair instead of `MicButton`. All other L1 layout choices are unchanged.
- The same orchestrator `.answerResult` event is sent in both modes, so the state machine is mode-agnostic.

## 11. TTS Engine

### 11.1 `AppleTTSEngine`

```swift
public actor AppleTTSEngine: TTSEngine {
    public init(preferredVoiceIdentifier: String? = nil, rate: Float = 0.45)
    public func speak(_ text: String) async
    public func speak(phoneme: Phoneme) async
    public nonisolated var needsEnhancedVoice: Bool { get }
}
```

- `AVSpeechSynthesizer` underneath; conformance to `AVSpeechSynthesizerDelegate` via an internal proxy class. `didFinish` resumes a `CheckedContinuation<Void, Never>`, giving us an awaitable `speak`.
- Voice selection: pick the highest-quality en-US voice installed (`premium` → `enhanced` → `default`). If none is enhanced, `needsEnhancedVoice` is true.
- Rate 0.45 is slower than system default (0.5) for child readability.
- `speak(phoneme:)` uses `L1Profile.exemplars(for:)` to build "sh, as in ship" for a /ʃ/ input.

### 11.2 `L1Profile.exemplars(for:)`

New method on the protocol:

```swift
public protocol L1Profile {
    // ... existing ...
    func exemplars(for phoneme: Phoneme) -> [String]
}
```

`JapaneseL1Profile` returns 1–3 curated exemplar words per phoneme from the v1 taught set. When empty (unknown phoneme), `speak(phoneme:)` reads just the IPA symbol's human-friendly name ("the 'sh' sound").

### 11.3 Enhanced voice prompt

- `HomeView` observes `AppleTTSEngine.needsEnhancedVoice`
- When true, a small secondary chip appears to the left of the streak chip: `"Better voice available ›"`
- Tap opens `UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)` to let the user install the enhanced voice from Settings → Accessibility → Spoken Content
- The app continues to function with the default voice

### 11.4 Usage in session flow

| Phase | TTS trigger |
|---|---|
| Warmup | On entry: `engine.speak(phoneme: target.phoneme)`. "Listen again" button: same call. |
| NewRule | On entry: reads the rule sentence, then each worked example in sequence. "Got it" is disabled until `speak` resolves. |
| Decoding | Long-press on the word: `engine.speak(word.surface)`. On wrong answer scaffold: `engine.speak("Listen: " + word.surface)`. |
| ShortSentences | Long-press on the sentence: `engine.speak(sentence.text)`. Scaffold on miss: same. |
| Completion | On entry: `engine.speak("Quest complete! You got \(correct) out of \(total).")` |

## 12. Assessment Leniency

Minimal `AssessmentLeniency` addition — full mastery tracking is deferred to the `AdaptivePlanEngine` plan.

```swift
public enum AssessmentLeniency: Sendable { case newWord, mastered }

public extension AssessmentEngine {
    func assess(
        expected: Word,
        asr: ASRResult,
        leniency: AssessmentLeniency
    ) -> TrialAssessment
}
```

- `.newWord`: allows one additional edit-distance unit beyond the default threshold and lowers the confidence floor to 0.25
- `.mastered`: uses the strict threshold (equivalent to the existing `assess(expected:asr:)` path)

Migration of the existing 2-argument `assess(expected:asr:)` method:

- It is preserved as a thin wrapper that delegates to the 3-argument form with `.mastered`, so existing tests keep passing without edits
- `SessionOrchestrator` is updated to call the 3-argument form with `.newWord` during this plan (UI surfaces pass `.newWord` on every trial because no mastery tracking exists yet)

The pre-existing `AssessmentEngine.leniency: Double` property (currently unused, reserved for future use) becomes formally dormant. It is not removed in this plan — a follow-up refactor inside the `AdaptivePlanEngine` plan will clean it up alongside the broader leniency story.

Existing tests are extended to cover both `.newWord` and `.mastered` branches with deterministic ASR fixtures (same `expected` + near-miss transcript producing different correctness between the two levels).

## 13. Feedback, Animation, Haptics

- **Correct answer**: 400 ms — green glow overlay (teal, 30% alpha) + centered ✓, `UINotificationFeedbackGenerator.notificationOccurred(.success)`. Orchestrator advances mid-animation.
- **Wrong answer**: 600 ms — horizontal shake (3 cycles, 12pt amplitude) on the word, orange border flash, `.error` haptic. Scaffold TTS kicks in after the shake.
- **Phase transition**: 250 ms ease-in-out slide (push left) between phase bodies.
- **Session completion**: streak number pulses (1.0 → 1.2 → 1.0 over 700 ms, repeats ×2), confetti-style dots around the score.
- **Mic listening**: teal ring pulses 1.0 → 1.12 → 1.0 at 900 ms period.

No SFX in this plan. A future plan may add correct / wrong sound effects.

## 14. Phase Plan

| Phase | Title | Deliverables | Est. tasks |
|---|---|---|---|
| 1 | Design foundation | OpenDyslexic registration, `MoraTheme` tokens, component library (`HeroCTA`, `MicButton`, `StreakChip`, `PhasePips`, `FeedbackOverlay`) | 4 |
| 2 | Fullscreen session layout | `SessionContainerView` chrome rework, Warmup / NewRule / Decode / Sentences / Completion L1 rewrite (tap mode preserved) | 5 |
| 3 | Home screen (H1) | `HomeView` new, `RootView` branch, `NavigationStack` rewiring | 2 |
| 4 | Onboarding flow | `OnboardingFlow` + four screens, `LearnerProfile` + `DailyStreak` SwiftData entities, UserDefaults flag | 4 |
| 5 | Real Speech | `SpeechEvent` + `SpeechEngine` reshape (including `OrchestratorEvent` split into `answerHeard` / `answerManual`), `PermissionCoordinator`, `AppleSpeechEngine`, tap-to-listen UI wiring, mic-denied fallback | 5 |
| 6 | Real TTS | `AppleTTSEngine`, enhanced-voice chip, Warmup / NewRule / scaffold wiring, `L1Profile.exemplars` | 3 |
| 7 | Persistence & polish | Streak logic, `AssessmentLeniency`, feedback animations and haptics, device smoke checklist | 4 |

Approximately 27 tasks across 7 phases. Each phase ends with `swift test` across all packages, `xcodebuild build` using the CI command, and a simulator screenshot attached to the PR.

## 15. Testing Strategy

### 15.1 Unit (swift test)

- `MoraTheme` token values frozen as constants (catches accidental changes)
- `AssessmentEngine` leniency: same ASR input flips correctness between `.newWord` and `.mastered`
- `PermissionCoordinator` via injected `FakePermissionSource`: not-determined → grants → `.allGranted`; denied + granted → `.partial(micDenied: true, speechDenied: false)`
- `AppleSpeechEngine` (without real audio): drive it with a harness that injects `SFSpeechRecognitionResult` fixtures to verify `.partial → .final` mapping — only if feasible; otherwise skip with a TODO and rely on device smoke
- `FakeSpeechEngine.yielding([events])` convenience initializer, consumed by orchestrator tests
- `OnboardingFlow` state transitions: step progression, skip semantics, final persistence, "Not now" permission path

### 15.2 Integration (existing `FullADayIntegrationTests` + new)

- Existing end-to-end A-day tests: update `FakeSpeechEngine` construction to the new stream API; assertions on orchestrator state remain valid
- New `OnboardingPersistenceTests`: run the flow, assert `LearnerProfile.interests` matches selection
- New `SpeechWiringTests`: via `DecodeActivityView` sitting on a fake orchestrator + `FakeSpeechEngine`, assert `.answerResult` fires with the expected `ASRResult`

### 15.3 Device smoke (manual, not in CI)

- Phase 2 end: simulator screenshot of each phase in landscape + portrait, attached to PR
- Phase 4 end: simulator walkthrough of onboarding from clean install to Home
- Phase 5 end: physical iPad — read "ship", "fish", "shop" three times each; confirm partial transcripts appear, final ASR scores correctly, mic-denied fallback works when permission is revoked mid-session
- Phase 7 end: physical iPad — alpha session with the target learner; capture a short video

### 15.4 What this plan does not test

- SwiftUI visual regression (no snapshot tests). Visual correctness relies on manual review against this spec and the brainstorm mockups.
- Real CloudKit sync — Parent Mode is deferred.
- Long-session thermals / Jetsam — that is the bench app's responsibility.

## 16. Error & Boundary Handling

| Scenario | Handling |
|---|---|
| `SFSpeechRecognizer.isAvailable == false` at session start | Session runs in tap-fallback mode; no user-visible error |
| Mic busy (phone call, etc.) | `listen()` throws; session shows "Microphone is busy — try again in a moment" banner and reverts to `.idle` |
| 15 s no-speech timeout | `.final(ASRResult(transcript: "", confidence: 0))`; orchestrator treats as wrong; scaffold TTS fires |
| Recognition `assetsNotReady` | One auto-retry after 2 s; on second failure, session switches to tap-fallback for the remainder |
| TTS enhanced voice missing | `needsEnhancedVoice = true` → Home chip; session continues with default voice |
| Mic permission revoked mid-session | Current trial completes in fallback; subsequent trials use tap mode |
| SwiftData corruption | Existing on-disk → in-memory fallback in `MoraApp` unchanged |
| User hits Close mid-session | Confirmation dialog; on confirm, `SessionSummaryEntity(partial: true, …)` is written and Home is popped to |

## 17. Open Questions

1. **"Better voice available" chip wording and placement** — the Home top-right real estate is tight. Consider a small inline banner under the hero instead once in device testing.
2. **OpenDyslexic vs Lexend as default body font** — spec §7 specifies OpenDyslexic; some recent research favors Lexend's readability for dyslexic readers. Will evaluate with the target learner and revisit in Settings plan.
3. **Streak rollover timing** — 3 AM local time (to cover late sessions) vs strict midnight. v1.5 decision; this plan uses strict calendar day.
4. **Haptic intensity for an 8-year-old** — default is fine on an iPad, but heavy patterns may surprise. Use `.notificationOccurred` (mild) rather than sharp `impactOccurred(.heavy)`.
5. **Completion screen duration before Home pop** — auto-return after 5 s or wait for tap? Plan assumes tap-to-dismiss; device testing may flip this.

## 18. References

- Primary product spec: `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md` (§7 Dyslexia-Friendly UX, §8 Architecture, §9 Multi-L1, §10 Content Pipeline, §11 Assessment, §14 Error Handling)
- v1 SPM-layout design: `docs/superpowers/specs/2026-04-21-mora-design.md` (§4 Hybrid architecture, §10 Package layout)
- Prior implementation plan (complete): `docs/superpowers/plans/2026-04-21-mora-scaffold-and-first-a-day.md`
- Bench app plan (independent track): `~/.claude/plans/elegant-frolicking-moon.md`
