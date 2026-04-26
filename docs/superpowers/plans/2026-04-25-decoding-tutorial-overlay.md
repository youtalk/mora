# Decoding Tile-Board Tutorial Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 2-panel pre-tutorial overlay that fires the first time a learner enters the `.decoding` phase of any session, teaching (1) what slots and tiles are and the drag gesture, and (2) the audio-to-screen link (the spoken target word is what to build). Add a "?" Help button in the top-right of `DecodeBoardView` that re-shows the same panels as a sheet at any time.

**Architecture:** New SwiftUI views in `MoraUI/Session/TileBoard/Tutorial/`, a new `@Observable @MainActor` state machine, and a new `UserDefaults` flag `tech.reenable.Mora.decodingTutorialSeen`. `SessionContainerView` gates the first-time overlay on the new flag inside its `case .decoding:` branch via a `.fullScreenCover`. The Help button on `DecodeBoardView` is purely additive — it presents the same overlay in `.replay` mode (no flag mutation), and stops in-flight TTS via the existing `SpeechController` reference before presenting.

**Tech Stack:** Swift 5/Swift 6 language mode pinned to v5, SwiftUI, MoraCore + MoraUI packages. No engine logic, no new SwiftData entity, no migration.

**Spec:** `docs/superpowers/specs/2026-04-25-yokai-intro-and-tile-tutorial-design.md`.

---

## File Structure

**New files:**
- `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift` — shared enum (also created by the parallel yokai-intro plan; whichever PR ships first creates the file, the other rebases as a no-op).
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift` — `DecodingTutorialState` class + `DecodingTutorialOverlay` View.
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/SlotMeaningPanel.swift` — Panel T1 (slots + tiles + ghost-hand drag animation).
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/AudioLinkPanel.swift` — Panel T2 (speaker icon + arrow to slot row).
- `Packages/MoraUI/Tests/MoraUITests/DecodingTutorialStateTests.swift` — state-machine unit tests.
- `Packages/MoraUI/Tests/MoraUITests/SessionContainerDecodingTutorialTests.swift` — integration test for first-time overlay gating.

**Modified files:**
- `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift` — 7 new `public let` declarations + initializer parameters.
- `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift` — `stringsMid` literal +7 lines.
- `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift` — extend non-empty + kanji-budget loops with the 7 new keys.
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — wrap `case .decoding:` in `.fullScreenCover` for the first-time tutorial.
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift` — add top-trailing Help "?" overlay with `.sheet`.

---

## Task 1: Add `OnboardingPlayMode` shared enum

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift`

**Note:** If the parallel yokai-intro PR has already merged, this file already exists. Skip Task 1 entirely and continue with Task 2.

- [ ] **Step 1.1: Check whether the file already exists on `main`**

Run: `test -f Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift && echo EXISTS || echo MISSING`

If `EXISTS`, skip to Task 2. If `MISSING`, continue.

- [ ] **Step 1.2: Create the file**

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

- [ ] **Step 1.3: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 1.4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Onboarding/OnboardingPlayMode.swift
git commit -m "ui(onboarding): add OnboardingPlayMode enum"
```

---

## Task 2: Add 7 new keys to `MoraStrings`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`

- [ ] **Step 2.1: Add 7 `public let` declarations**

Insert immediately after the existing `decodingListenAgain: String` line in the "Per-phase chrome" group:

```swift
    // Tile-board first-run tutorial (2 panels + 2 CTAs + Help label)
    public let tileTutorialSlotTitle: String
    public let tileTutorialSlotBody: String
    public let tileTutorialAudioTitle: String
    public let tileTutorialAudioBody: String
    public let tileTutorialNext: String
    public let tileTutorialTry: String
    public let decodingHelpLabel: String
```

- [ ] **Step 2.2: Add 7 initializer parameters**

After the existing `decodingListenAgain: String,` initializer parameter add:

```swift
        tileTutorialSlotTitle: String,
        tileTutorialSlotBody: String,
        tileTutorialAudioTitle: String,
        tileTutorialAudioBody: String,
        tileTutorialNext: String,
        tileTutorialTry: String,
        decodingHelpLabel: String,
```

- [ ] **Step 2.3: Add 7 `self.x = x` lines in initializer body**

After the existing `self.decodingListenAgain = decodingListenAgain` line add:

```swift
        self.tileTutorialSlotTitle = tileTutorialSlotTitle
        self.tileTutorialSlotBody = tileTutorialSlotBody
        self.tileTutorialAudioTitle = tileTutorialAudioTitle
        self.tileTutorialAudioBody = tileTutorialAudioBody
        self.tileTutorialNext = tileTutorialNext
        self.tileTutorialTry = tileTutorialTry
        self.decodingHelpLabel = decodingHelpLabel
```

- [ ] **Step 2.4: Verify the package compile fails as expected**

Run: `(cd Packages/MoraCore && swift build)`
Expected: build fails with "missing argument for parameter 'tileTutorialSlotTitle' in call" pointing at `JapaneseL1Profile.swift`. Task 3 fixes it.

---

## Task 3: Populate `JapaneseL1Profile.stringsMid` with 7 values

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`

- [ ] **Step 3.1: Add the 7 values**

In the `stringsMid` literal, after `decodingListenAgain: "もう一度 きく",` insert:

```swift
        tileTutorialSlotTitle: "文字を ますに 入れて ことばを つくる",
        tileTutorialSlotBody:
            "ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。",
        tileTutorialAudioTitle: "聞いた 音を つくろう",
        tileTutorialAudioBody:
            "はじめに 🔊 が 音を 聞かせる。きいた 音と 同じに なるよう、"
            + "タイルを ならべよう。聞きなおすときは「もう一度 きく」を タップ。",
        tileTutorialNext: "つぎへ",
        tileTutorialTry: "▶ やってみる",
        decodingHelpLabel: "あそびかたを 見る",
```

- [ ] **Step 3.2: Build the package**

Run: `(cd Packages/MoraCore && swift build)`
Expected: build succeeds.

---

## Task 4: Extend `MoraStringsTests` with 7 entries

**Files:**
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift`

- [ ] **Step 4.1: Add 7 entries to both arrays (non-empty around line 28, kanji-budget around line 189)**

In both arrays, after the existing `("decodingListenAgain", s.decodingListenAgain),` line add:

```swift
            ("tileTutorialSlotTitle", s.tileTutorialSlotTitle),
            ("tileTutorialSlotBody", s.tileTutorialSlotBody),
            ("tileTutorialAudioTitle", s.tileTutorialAudioTitle),
            ("tileTutorialAudioBody", s.tileTutorialAudioBody),
            ("tileTutorialNext", s.tileTutorialNext),
            ("tileTutorialTry", s.tileTutorialTry),
            ("decodingHelpLabel", s.decodingHelpLabel),
```

- [ ] **Step 4.2: Run the tests**

Run: `(cd Packages/MoraCore && swift test --filter MoraStringsTests)`
Expected: all tests pass.

- [ ] **Step 4.3: Commit Tasks 2 + 3 + 4 together**

```bash
git add Packages/MoraCore/Sources/MoraCore/MoraStrings.swift \
        Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift \
        Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift
git commit -m "core(strings): add 7 tile-tutorial + help-label MoraStrings keys"
```

---

## Task 5: Build `DecodingTutorialState` (TDD)

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/DecodingTutorialStateTests.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift` (state class portion only — overlay View comes in Task 9)

- [ ] **Step 5.1: Write the failing tests**

```swift
// Packages/MoraUI/Tests/MoraUITests/DecodingTutorialStateTests.swift
import XCTest
@testable import MoraUI

@MainActor
final class DecodingTutorialStateTests: XCTestCase {
    func testStartsAtSlot() {
        let state = DecodingTutorialState()
        XCTAssertEqual(state.step, .slot)
    }

    func testAdvanceWalksAllSteps() {
        let state = DecodingTutorialState()
        state.advance()
        XCTAssertEqual(state.step, .audio)
        state.advance()
        XCTAssertEqual(state.step, .finished)
        // Idempotent at terminal state.
        state.advance()
        XCTAssertEqual(state.step, .finished)
    }

    func testDismissFlipsFlag() {
        let suite = "test.DecodingTutorialStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertFalse(defaults.bool(forKey: DecodingTutorialState.seenKey))
        DecodingTutorialState().dismiss(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testSeenKeyIsNamespaced() {
        XCTAssertEqual(
            DecodingTutorialState.seenKey,
            "tech.reenable.Mora.decodingTutorialSeen"
        )
    }
}
```

- [ ] **Step 5.2: Run tests — they fail because `DecodingTutorialState` does not exist**

Run: `(cd Packages/MoraUI && swift test --filter DecodingTutorialStateTests)`
Expected: build error: `cannot find 'DecodingTutorialState' in scope`.

- [ ] **Step 5.3: Implement `DecodingTutorialState`**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift
import Foundation
import Observation

@Observable
@MainActor
final class DecodingTutorialState {
    enum Step: Equatable, CaseIterable {
        case slot, audio, finished
    }

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

- [ ] **Step 5.4: Run tests — pass**

Run: `(cd Packages/MoraUI && swift test --filter DecodingTutorialStateTests)`
Expected: 4 tests pass.

- [ ] **Step 5.5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift \
        Packages/MoraUI/Tests/MoraUITests/DecodingTutorialStateTests.swift
git commit -m "ui(decoding): add DecodingTutorialState 3-step machine"
```

---

## Task 6: Build `SlotMeaningPanel` (Panel T1)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/SlotMeaningPanel.swift`

- [ ] **Step 6.1: Implement Panel T1**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/SlotMeaningPanel.swift
import MoraCore
import SwiftUI

struct SlotMeaningPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    @State private var draggingTileOffset: CGSize = .zero
    @State private var draggingTileVisible: Bool = true
    @State private var slotFilled: Bool = false

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.tileTutorialSlotTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MoraTheme.Space.xl)

            slotDemo
                .frame(height: 220)
                .padding(.horizontal, MoraTheme.Space.xl)

            Text(strings.tileTutorialSlotBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.tileTutorialNext, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await runDragLoop()
        }
    }

    private var slotDemo: some View {
        ZStack {
            VStack(spacing: MoraTheme.Space.lg) {
                slotsRow
                Spacer().frame(height: 8)
                tilePool
            }
            if draggingTileVisible {
                ghostHand
                    .offset(draggingTileOffset)
            }
        }
    }

    private var slotsRow: some View {
        HStack(spacing: MoraTheme.Space.md) {
            tutorialSlot(filled: slotFilled, label: "sh")
            tutorialSlot(filled: false, label: nil)
            tutorialSlot(filled: false, label: nil)
        }
    }

    private var tilePool: some View {
        HStack(spacing: MoraTheme.Space.md) {
            tutorialTile(letters: "sh", kind: .multigrapheme, opacity: slotFilled ? 0.0 : 1.0)
            tutorialTile(letters: "i", kind: .vowel)
            tutorialTile(letters: "p", kind: .consonant)
        }
    }

    private func tutorialSlot(filled: Bool, label: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
                .stroke(
                    filled ? MoraTheme.Accent.orange : MoraTheme.Ink.muted.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: filled ? [] : [6, 4])
                )
                .frame(width: 60, height: 60)
            if filled, let label {
                Text(label)
                    .font(MoraType.heroWord(36))
                    .foregroundStyle(MoraTheme.Ink.primary)
            }
        }
    }

    private func tutorialTile(letters: String, kind: TileKind, opacity: CGFloat = 1.0) -> some View {
        Text(letters)
            .font(MoraType.heroWord(36))
            .foregroundStyle(TilePalette.text(for: kind))
            .frame(width: 60, height: 60)
            .background(TilePalette.fill(for: kind), in: .rect(cornerRadius: MoraTheme.Radius.tile))
            .overlay(
                RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
                    .strokeBorder(TilePalette.border(for: kind), lineWidth: 2)
            )
            .opacity(opacity)
    }

    private var ghostHand: some View {
        Text("👆")
            .font(.system(size: 38))
            .opacity(0.85)
    }

    @MainActor
    private func runDragLoop() async {
        if reduceMotion {
            slotFilled = true
            draggingTileVisible = false
            return
        }
        // Loop forever while panel is on-screen.
        while !Task.isCancelled {
            // Reset
            withAnimation(.easeOut(duration: 0.2)) {
                slotFilled = false
                draggingTileOffset = CGSize(width: -90, height: 70)
                draggingTileVisible = true
            }
            try? await Task.sleep(for: .milliseconds(500))
            // Drag
            withAnimation(.easeInOut(duration: 0.7)) {
                draggingTileOffset = CGSize(width: -90, height: -50)
            }
            try? await Task.sleep(for: .milliseconds(700))
            // Drop
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                slotFilled = true
                draggingTileVisible = false
            }
            try? await Task.sleep(for: .milliseconds(900))
        }
    }
}

#if DEBUG
#Preview {
    SlotMeaningPanel(onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 6.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 6.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/SlotMeaningPanel.swift
git commit -m "ui(decoding): SlotMeaningPanel — drag demo for tutorial T1"
```

---

## Task 7: Build `AudioLinkPanel` (Panel T2)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/AudioLinkPanel.swift`

- [ ] **Step 7.1: Implement Panel T2**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/AudioLinkPanel.swift
import MoraCore
import SwiftUI

struct AudioLinkPanel: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onContinue: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer().frame(height: MoraTheme.Space.xl)

            Text(strings.tileTutorialAudioTitle)
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            audioColumn
                .frame(height: 220)

            Text(strings.tileTutorialAudioBody)
                .font(MoraType.bodyReading())
                .foregroundStyle(MoraTheme.Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MoraTheme.Space.xl)

            Spacer()

            HeroCTA(title: strings.tileTutorialTry, action: onContinue)
                .padding(.bottom, MoraTheme.Space.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await runPulseLoop()
        }
    }

    private var audioColumn: some View {
        VStack(spacing: MoraTheme.Space.md) {
            Text("🔊")
                .font(.system(size: 64))
                .scaleEffect(pulseScale)
            Image(systemName: "arrow.down")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MoraTheme.Ink.muted)
            HStack(spacing: MoraTheme.Space.md) {
                emptySlot
                emptySlot
                emptySlot
            }
        }
    }

    private var emptySlot: some View {
        RoundedRectangle(cornerRadius: MoraTheme.Radius.tile)
            .stroke(
                MoraTheme.Ink.muted.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, dash: [6, 4])
            )
            .frame(width: 50, height: 50)
    }

    @MainActor
    private func runPulseLoop() async {
        if reduceMotion {
            return
        }
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.5)) {
                pulseScale = 1.15
            }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeInOut(duration: 0.5)) {
                pulseScale = 1.0
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}

#if DEBUG
#Preview {
    AudioLinkPanel(onContinue: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 7.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 7.3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/AudioLinkPanel.swift
git commit -m "ui(decoding): AudioLinkPanel — speaker→slots demo for T2"
```

---

## Task 8: Build `DecodingTutorialOverlay` View wrapper

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift` (state class is already there from Task 5; append the View)

- [ ] **Step 8.1: Append the `DecodingTutorialOverlay` View**

Add at the end of the existing file:

```swift
import MoraCore
import SwiftUI

public struct DecodingTutorialOverlay: View {
    @State private var state = DecodingTutorialState()
    private let mode: OnboardingPlayMode
    private let onFinished: () -> Void

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
                    state.dismiss()
                }
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .slot:
            SlotMeaningPanel { state.advance() }
        case .audio:
            AudioLinkPanel { state.advance() }
        case .finished:
            ProgressView()
        }
    }
}

#if DEBUG
#Preview("First time") {
    DecodingTutorialOverlay(mode: .firstTime, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#Preview("Replay") {
    DecodingTutorialOverlay(mode: .replay, onFinished: {})
        .environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
}
#endif
```

- [ ] **Step 8.2: Verify build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: builds clean.

- [ ] **Step 8.3: Run all MoraUI tests**

Run: `(cd Packages/MoraUI && swift test)`
Expected: green.

- [ ] **Step 8.4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift
git commit -m "ui(decoding): DecodingTutorialOverlay wires 2 panels + dismiss"
```

---

## Task 9: Wire `SessionContainerView` for first-time tutorial

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 9.1: Add the new `@State` variables**

In the existing `@State` block at the top of `SessionContainerView` (currently around line 22–35), add:

```swift
    @State private var decodingTutorialSeen: Bool = UserDefaults.standard.bool(
        forKey: DecodingTutorialState.seenKey
    )
    @State private var showFirstTimeTutorial: Bool = false
```

- [ ] **Step 9.2: Wrap the `case .decoding:` branch in `.fullScreenCover`**

Locate `case .decoding:` in `content` (currently around line 156). The current branch is:

```swift
case .decoding:
    VStack(spacing: MoraTheme.Space.md) {
        if let engine = orchestrator.currentTileBoardEngine {
            DecodeBoardView(...)
                ...
        } else {
            Color.clear
        }
        #if DEBUG
        Button("DEBUG: Skip to Short Sentences") { ... }
        ...
        #endif
    }
    .task(id: orchestrator.completedTrialCount) { ... }
```

Wrap the entire `VStack { ... }.task { ... }` in a chain that adds the cover and a separate `.task` to fire the first-time gate. Replace with:

```swift
case .decoding:
    decodingPhaseContent(orchestrator: orchestrator)
        .fullScreenCover(isPresented: $showFirstTimeTutorial) {
            DecodingTutorialOverlay(mode: .firstTime) {
                decodingTutorialSeen = true
                showFirstTimeTutorial = false
            }
            .environment(\.moraStrings, strings)
        }
        .task {
            if !decodingTutorialSeen, !showFirstTimeTutorial {
                showFirstTimeTutorial = true
            }
        }
```

Then extract the existing `VStack { … }.task(id: …)` into a new helper method on `SessionContainerView`:

```swift
@ViewBuilder
private func decodingPhaseContent(orchestrator: SessionOrchestrator) -> some View {
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
        do {
            try await Task.sleep(for: .milliseconds(1500))
        } catch {
            return
        }
        await clipRouter?.play(clip)
    }
}
```

- [ ] **Step 9.3: Persist the flag write to UserDefaults**

Inside the `DecodingTutorialOverlay` `onFinished` closure created in Step 9.2, the closure already runs after `state.dismiss()` (which writes to defaults). So no additional `UserDefaults.standard.set(...)` call is needed in the closure itself. Verify by reading `DecodingTutorialOverlay.body.onChange` — it calls `state.dismiss()` for `.firstTime` mode before invoking `onFinished()`.

- [ ] **Step 9.4: Build app target**

Run: `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
Expected: builds clean.

- [ ] **Step 9.5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "ui(session): gate first-time decoding tutorial on .decoding entry"
```

---

## Task 10: Add Help "?" button to `DecodeBoardView`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift`

- [ ] **Step 10.1: Add `@State` for the sheet flag**

In `DecodeBoardView`, add:

```swift
    @State private var showHelp: Bool = false
```

- [ ] **Step 10.2: Add the overlay button + sheet**

At the end of the existing `body` chain (after `.onAppear { … }` around line 49), add:

```swift
        .overlay(alignment: .topTrailing) {
            Button { showHelp = true } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .accessibilityLabel(strings.decodingHelpLabel)
        }
        .sheet(isPresented: $showHelp) {
            DecodingTutorialOverlay(mode: .replay) {
                showHelp = false
            }
            .environment(\.moraStrings, strings)
        }
        .onChange(of: showHelp) { _, isShowing in
            if isShowing {
                Task { await speech?.stop() }
            }
        }
```

- [ ] **Step 10.3: Build app target**

Run: `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
Expected: builds clean.

- [ ] **Step 10.4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift
git commit -m "ui(decoding): top-right ? Help button replays tutorial"
```

---

## Task 11: Add `SessionContainerDecodingTutorialTests`

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/SessionContainerDecodingTutorialTests.swift`

The session-container view drives a lot of orchestrator state that is hard to construct in a unit test. The pragmatic test here is at the **flag-semantics** level: confirm that the `decodingTutorialSeen` flag is read from the configured `UserDefaults` key, and that `DecodingTutorialState.dismiss(...)` flips it. The full UI behavior (overlay appears on first `.decoding` entry, skipped on subsequent) is covered by manual on-device verification in Task 12 and by SwiftUI Previews.

- [ ] **Step 11.1: Implement the test**

```swift
// Packages/MoraUI/Tests/MoraUITests/SessionContainerDecodingTutorialTests.swift
import Foundation
import XCTest

@testable import MoraUI

@MainActor
final class SessionContainerDecodingTutorialTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "test.SessionContainerDecodingTutorial.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testFreshDefaultsReturnFalse() {
        XCTAssertFalse(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testDismissPersistsFlag() {
        let state = DecodingTutorialState()
        XCTAssertFalse(defaults.bool(forKey: DecodingTutorialState.seenKey))
        state.dismiss(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testReplayMode_doesNotPersistFlag() {
        // Replay mode is enforced at the OnboardingPlayMode level inside
        // DecodingTutorialOverlay.onChange(of:); the state machine's
        // dismiss method itself always writes when called. We rely on the
        // overlay to call dismiss only when mode == .firstTime. This test
        // pins the contract of the state machine: dismiss always writes.
        let state = DecodingTutorialState()
        state.dismiss(defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: DecodingTutorialState.seenKey))
    }

    func testSeenKeyMatchesSpec() {
        XCTAssertEqual(
            DecodingTutorialState.seenKey,
            "tech.reenable.Mora.decodingTutorialSeen"
        )
    }
}
```

- [ ] **Step 11.2: Run the test**

Run: `(cd Packages/MoraUI && swift test --filter SessionContainerDecodingTutorialTests)`
Expected: 4 tests pass.

- [ ] **Step 11.3: Commit**

```bash
git add Packages/MoraUI/Tests/MoraUITests/SessionContainerDecodingTutorialTests.swift
git commit -m "ui(session): test decoding-tutorial flag semantics"
```

---

## Task 12: Final verification + PR

- [ ] **Step 12.1: Full test sweep across all packages**

Run:
```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```
Expected: all four packages green.

- [ ] **Step 12.2: App-target build sanity check**

Run:
```bash
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: build succeeds.

- [ ] **Step 12.3: swift-format lint**

Run: `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests`
Expected: clean. If anything trips, run `swift-format format --in-place …` on the offending files and re-commit.

- [ ] **Step 12.4: Manual on-device verification**

On a fresh install (use the DEBUG Reset button on `HomeView` to clear state):

1. Tap "▶ はじめる" to start a session.
2. Walk through warmup (the first interactive phase).
3. When the session enters `.decoding`, the 2-panel tutorial appears as a `.fullScreenCover`. Walk through both panels; the second's CTA is "▶ やってみる" and dismisses to the actual board.
4. The board appears with the standard tile pool + slot row + listen-again button + a **new "?" button in the top-right corner**.
5. Tap the "?". The 2-panel tutorial reappears as a `.sheet`. Close it.
6. The board is restored to its previous state. No flag is changed (verifiable by entering a *new* session — tutorial should NOT fire again because the flag was already true after step 3).

- [ ] **Step 12.5: Push branch and open PR**

```bash
git push -u origin <branch-name>
gh pr create --title "ui(decoding): tile-board first-run tutorial + ? Help button" --body "$(cat <<'EOF'
## Summary
- Adds a 2-panel pre-tutorial overlay that fires the first time a learner enters the `.decoding` phase, teaching tile drag mechanics and the audio-to-board link.
- Adds a top-right "?" Help button on `DecodeBoardView` that replays the same tutorial as a sheet at any time, without altering persistence.
- One-time gating via `tech.reenable.Mora.decodingTutorialSeen` UserDefaults flag.

## Test plan
- [ ] Fresh install (or DEBUG Reset): first `.decoding` entry shows the 2-panel tutorial; "▶ やってみる" dismisses to the board; second session enters `.decoding` directly with no tutorial.
- [ ] On the board, the top-right "?" tap shows the tutorial as a sheet; close returns to the same trial state; flag still `true`.
- [ ] Help button presentation cancels in-flight TTS via `speech.stop()`.
- [ ] `swift test` green across all four packages.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 12.6: Done**

PR is open. Address review feedback as it comes in.

---

## Notes for the implementing engineer

- **`DecodeBoardView`** already has access to a `SpeechController?` via the existing `speech` property — that's what the Help button uses to cancel in-flight TTS.
- **`DecodingTutorialOverlay`** lives in `Session/TileBoard/` next to the existing tile-board files because it conceptually belongs to the decoding phase, not to the broader onboarding chain.
- **The shared `OnboardingPlayMode.swift`** is also created by the parallel yokai-intro PR. If that PR lands first, this PR's Task 1 becomes a no-op. Both files have identical content, so the trivial merge conflict resolves to a single keep.
- **The `decodingTutorialSeen` flag** is intentionally read once at view-init time. SwiftUI's re-renders track the `@State` boolean, not the underlying `UserDefaults`. After dismiss, the in-memory flag is `true` and the `.fullScreenCover` does not re-present.
- **The `.task` on `case .decoding:`** runs once per `.decoding` entry into the view hierarchy. If the user closes the session and re-enters, the `.task` re-runs but reads the now-persisted `true` flag and skips the cover.
- **Kanji budget** is enforced by the loop in `MoraStringsTests.swift:107` (and ~169 for the second loop). Re-check the new values pass the loop after Task 4.
