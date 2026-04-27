# A-Day Five Weeks + Yokai Live — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Realign the v1 A-day ladder to the bundled yokai cast (`sh → th → f → r → short_a`), drive weekly rotation through `YokaiEncounterEntity`, and wire the dormant `YokaiOrchestrator` into live sessions so the child can use the app daily across five weeks.

**Architecture:** Two-PR stack plus an independent side branch.
- **PR 1 (Curriculum Spine):** realigns `CurriculumEngine.defaultV1Ladder()`, adds per-skill warmup candidates and yokai IDs, authors four new bundled decoding JSONs, and makes `SessionContainerView.bootstrap` resolve the active `YokaiEncounterEntity` (creating an initial `sh` encounter on first launch). Leaves yokai UI dormant.
- **PR 2 (Yokai Live Wiring):** constructs `YokaiOrchestrator` in bootstrap, routes trial outcomes through the existing normal/Friday dispatch, inserts the next encounter on befriending, and surfaces a minimal "curriculum complete" state when all five are done.
- **Side branch (P2):** records adult-proxy fixtures on device, unskips `FeatureBasedEvaluatorFixtureTests`, tunes `PhonemeThresholds`. Independent merge order.

**Spec:** `docs/superpowers/specs/2026-04-24-a-day-five-weeks-yokai-live-design.md`.

**Tech Stack:** Swift 6 tools-version with `.swiftLanguageMode(.v5)`, SwiftUI, SwiftData, XcodeGen, iOS 17 / macOS 14 targets. Tests use XCTest (`swift test` per package). Lint via swift-format (CI `--strict`).

**Pre-conditions verified before starting:** `git log` shows `73e0d6e` (PR #71) on main. `YokaiOrchestrator` already ships `beginFridaySession`, `recordFridayFinalTrial`, `finalizeFridayIfNeeded` (private), `maybeTriggerCameo`. `FriendshipMeterMath.floorBoostWeight` is in place. `YokaiCutscene` cases are `.mondayIntro`, `.sessionStart`, `.fridayClimax`, `.srsCameo`.

---

## File Structure

### PR 1 — Curriculum Spine

**Create:**
- `Packages/MoraEngines/Sources/MoraEngines/Resources/th_week.json` — decoding content for `th_voiceless`.
- `Packages/MoraEngines/Sources/MoraEngines/Resources/f_week.json` — decoding content for `f_onset`.
- `Packages/MoraEngines/Sources/MoraEngines/Resources/r_week.json` — decoding content for `r_onset`.
- `Packages/MoraEngines/Sources/MoraEngines/Resources/short_a_week.json` — decoding content for `short_a`.
- `Packages/MoraEngines/Sources/MoraEngines/WeekRotation.swift` — pure helper that resolves the current skill/encounter from SwiftData state.
- `Packages/MoraEngines/Tests/MoraEnginesTests/WeekRotationTests.swift` — in-memory SwiftData tests for first-launch, mid-cycle, and all-befriended cases.
- `Packages/MoraEngines/Tests/MoraEnginesTests/SystematicPrincipleTests.swift` — asserts every session's trials stay on one target phoneme.
- `Packages/MoraEngines/Tests/MoraEnginesTests/BundledWeekDecodabilityTests.swift` — cross-week decodability audit.

**Modify:**
- `Packages/MoraCore/Sources/MoraCore/Skill.swift` — add `warmupCandidates: [Grapheme]` and `yokaiID: String?` plus an updated `init`.
- `Packages/MoraEngines/Sources/MoraEngines/CurriculumEngine.swift` — `defaultV1Ladder()` realigned; add `indexOf(_:)` and `nextSkill(after:)` helpers.
- `Packages/MoraEngines/Sources/MoraEngines/ScriptedContentProvider.swift` — add `bundled(for:)` factory; keep `bundledShWeek1()` for back-compat.
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — `bootstrap()` resolves active encounter and loads per-skill content; warmup options come from `skill.warmupCandidates`.
- `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` — hero target reads from the active encounter instead of `forWeekIndex: 0`.
- `Packages/MoraEngines/Tests/MoraEnginesTests/CurriculumEngineTests.swift` — add cases for realigned ladder + helpers.
- `Packages/MoraEngines/Tests/MoraEnginesTests/ScriptedContentProviderTests.swift` — add coverage for `bundled(for:)`.
- `Packages/MoraCore/Tests/MoraCoreTests/SkillTests.swift` — add cases for new fields.

### PR 2 — Yokai Live Wiring

**Create:**
- `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiProgressionSource.swift` — protocol + `ClosureYokaiProgressionSource` adapter so `YokaiOrchestrator` can advance the chain without depending on `CurriculumEngine` directly.
- `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorResumeTests.swift`.
- `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorNextEncounterTests.swift`.
- `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapTests.swift` — integration test hitting the bootstrap flow with an in-memory container.
- `Packages/MoraUI/Sources/MoraUI/CurriculumCompleteView.swift` — minimal terminal screen.

**Modify:**
- `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift` — add `resume(encounter:)`, `isFridaySession` state, Friday-dispatching `recordTrialOutcome`, and `progressionSource` injection for post-befriend next-encounter insertion.
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — construct `YokaiOrchestrator`, pass into `SessionOrchestrator`, route `startWeek` / `resume` / `beginFridaySession` based on `sessionCompletionCount`.
- `Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift` — call `yokai?.recordSessionCompletion()` when persisting the summary for non-Friday sessions.
- `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` — show the active yokai portrait corner and a curriculum-complete CTA when applicable.
- `Packages/MoraUI/Sources/MoraUI/RootView.swift` — new navigation destination for curriculum-complete.
- `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorMeterTests.swift` — adjust for new Friday-dispatch semantics.
- `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiGoldenWeekTests.swift` — extend the single-week fixture to all five yokai.

### Side branch — P2 (Adult-Proxy Fixtures / Calibration)

Independent of PR 1 and PR 2; file list tracked inside each of its own tasks.

---

## Phase 1 — PR 1: Curriculum Spine

> Branch name suggestion: `feat/curriculum-spine-five-weeks`. Open PR against `main`.

### Task 1.1: Add `warmupCandidates` and `yokaiID` to `Skill`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/Skill.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/SkillTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `Packages/MoraCore/Tests/MoraCoreTests/SkillTests.swift`:

```swift
func test_skill_exposesWarmupCandidatesAndYokaiID() {
    let g = Grapheme(letters: "sh")
    let skill = Skill(
        code: "sh_onset",
        level: .l3,
        displayName: "sh digraph",
        graphemePhoneme: .init(grapheme: g, phoneme: .init(ipa: "ʃ")),
        warmupCandidates: [
            Grapheme(letters: "s"),
            Grapheme(letters: "sh"),
            Grapheme(letters: "ch"),
        ],
        yokaiID: "sh"
    )
    XCTAssertEqual(skill.warmupCandidates.count, 3)
    XCTAssertTrue(skill.warmupCandidates.contains(g))
    XCTAssertEqual(skill.yokaiID, "sh")
}

func test_skill_defaultsAreEmpty_whenOmitted() {
    let skill = Skill(
        code: "x",
        level: .l2,
        displayName: "test"
    )
    XCTAssertTrue(skill.warmupCandidates.isEmpty)
    XCTAssertNil(skill.yokaiID)
}
```

- [ ] **Step 2: Run test to verify it fails**

```sh
(cd Packages/MoraCore && swift test --filter SkillTests.test_skill_exposesWarmupCandidatesAndYokaiID)
```
Expected: compile failure — `warmupCandidates` / `yokaiID` do not exist.

- [ ] **Step 3: Add the fields and updated init**

Replace the `Skill` struct in `Packages/MoraCore/Sources/MoraCore/Skill.swift` with:

```swift
public struct Skill: Hashable, Codable, Sendable, Identifiable {
    public var id: SkillCode { code }
    public let code: SkillCode
    public let level: OGLevel
    public let displayName: String
    public let graphemePhoneme: GraphemePhoneme?
    public let warmupCandidates: [Grapheme]
    public let yokaiID: String?

    public init(
        code: SkillCode,
        level: OGLevel,
        displayName: String,
        graphemePhoneme: GraphemePhoneme? = nil,
        warmupCandidates: [Grapheme] = [],
        yokaiID: String? = nil
    ) {
        self.code = code
        self.level = level
        self.displayName = displayName
        self.graphemePhoneme = graphemePhoneme
        self.warmupCandidates = warmupCandidates
        self.yokaiID = yokaiID
    }
}
```

Defaults of `[]` and `nil` keep every existing `Skill(...)` call site compiling; Task 1.2 adds real values for the v1 ladder.

- [ ] **Step 4: Run tests to verify they pass**

```sh
(cd Packages/MoraCore && swift test --filter SkillTests)
```
Expected: all SkillTests pass.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/Skill.swift Packages/MoraCore/Tests/MoraCoreTests/SkillTests.swift
git commit -m "core: add warmupCandidates + yokaiID to Skill

Defaults stay empty / nil so every existing call site keeps working;
CurriculumEngine.defaultV1Ladder() in a follow-up commit fills these in
for the v1 skills."
```

---

### Task 1.2: Realign `CurriculumEngine.defaultV1Ladder()` to the yokai cast

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/CurriculumEngine.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/CurriculumEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `Packages/MoraEngines/Tests/MoraEnginesTests/CurriculumEngineTests.swift`:

```swift
func test_defaultV1Ladder_has5SkillsAlignedToYokaiCast() {
    let ladder = CurriculumEngine.defaultV1Ladder()
    let codes = ladder.skills.map(\.code.rawValue)
    XCTAssertEqual(codes, ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"])
    let yokaiIDs = ladder.skills.map(\.yokaiID)
    XCTAssertEqual(yokaiIDs, ["sh", "th", "f", "r", "short_a"])
}

func test_eachV1Skill_hasThreeWarmupCandidatesIncludingTarget() {
    let ladder = CurriculumEngine.defaultV1Ladder()
    for skill in ladder.skills {
        let target = skill.graphemePhoneme!.grapheme
        XCTAssertEqual(
            skill.warmupCandidates.count, 3,
            "\(skill.code.rawValue) should expose 3 warmup candidates"
        )
        XCTAssertTrue(
            skill.warmupCandidates.contains(target),
            "\(skill.code.rawValue) warmup candidates must include target \(target.letters)"
        )
    }
}

func test_nextSkill_returnsSuccessor_thenNil() {
    let ladder = CurriculumEngine.defaultV1Ladder()
    XCTAssertEqual(ladder.nextSkill(after: "sh_onset")?.code.rawValue, "th_voiceless")
    XCTAssertEqual(ladder.nextSkill(after: "r_onset")?.code.rawValue, "short_a")
    XCTAssertNil(ladder.nextSkill(after: "short_a"))
    XCTAssertNil(ladder.nextSkill(after: "unknown_code"))
}

func test_indexOf_returnsZeroBased_orNilIfAbsent() {
    let ladder = CurriculumEngine.defaultV1Ladder()
    XCTAssertEqual(ladder.indexOf(code: "sh_onset"), 0)
    XCTAssertEqual(ladder.indexOf(code: "short_a"), 4)
    XCTAssertNil(ladder.indexOf(code: "nonsense"))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
(cd Packages/MoraEngines && swift test --filter CurriculumEngineTests.test_defaultV1Ladder_has5SkillsAlignedToYokaiCast)
```
Expected: assertion failures — current ladder is 4 skills with `ch_onset` / `ck_coda`; helpers don't exist.

- [ ] **Step 3: Replace `defaultV1Ladder` and add helpers**

In `Packages/MoraEngines/Sources/MoraEngines/CurriculumEngine.swift`, replace the `defaultV1Ladder()` body with:

```swift
public static func defaultV1Ladder() -> CurriculumEngine {
    let l2Alphabet: Set<Grapheme> = Set(
        "abcdefghijklmnopqrstuvwxyz".map { Grapheme(letters: String($0)) }
    )

    let skills: [Skill] = [
        Skill(
            code: "sh_onset", level: .l3, displayName: "sh digraph",
            graphemePhoneme: .init(
                grapheme: .init(letters: "sh"),
                phoneme: .init(ipa: "ʃ")
            ),
            warmupCandidates: [
                Grapheme(letters: "s"),
                Grapheme(letters: "sh"),
                Grapheme(letters: "ch"),
            ],
            yokaiID: "sh"
        ),
        Skill(
            code: "th_voiceless", level: .l3, displayName: "voiceless th",
            graphemePhoneme: .init(
                grapheme: .init(letters: "th"),
                phoneme: .init(ipa: "θ")
            ),
            warmupCandidates: [
                Grapheme(letters: "t"),
                Grapheme(letters: "th"),
                Grapheme(letters: "s"),
            ],
            yokaiID: "th"
        ),
        Skill(
            code: "f_onset", level: .l2, displayName: "f sound",
            graphemePhoneme: .init(
                grapheme: .init(letters: "f"),
                phoneme: .init(ipa: "f")
            ),
            warmupCandidates: [
                Grapheme(letters: "f"),
                Grapheme(letters: "h"),
                Grapheme(letters: "v"),
            ],
            yokaiID: "f"
        ),
        Skill(
            code: "r_onset", level: .l2, displayName: "r sound",
            graphemePhoneme: .init(
                grapheme: .init(letters: "r"),
                phoneme: .init(ipa: "r")
            ),
            warmupCandidates: [
                Grapheme(letters: "r"),
                Grapheme(letters: "l"),
                Grapheme(letters: "w"),
            ],
            yokaiID: "r"
        ),
        Skill(
            code: "short_a", level: .l2, displayName: "short a",
            graphemePhoneme: .init(
                grapheme: .init(letters: "a"),
                phoneme: .init(ipa: "æ")
            ),
            warmupCandidates: [
                Grapheme(letters: "a"),
                Grapheme(letters: "u"),
                Grapheme(letters: "e"),
            ],
            yokaiID: "short_a"
        ),
    ]

    return CurriculumEngine(skills: skills, baselineTaughtGraphemes: l2Alphabet)
}

public func indexOf(code: SkillCode) -> Int? {
    skills.firstIndex(where: { $0.code == code })
}

public func nextSkill(after code: SkillCode) -> Skill? {
    guard let idx = indexOf(code: code), idx + 1 < skills.count else { return nil }
    return skills[idx + 1]
}
```

- [ ] **Step 4: Run tests to verify they pass**

```sh
(cd Packages/MoraEngines && swift test --filter CurriculumEngineTests)
```
Expected: all `CurriculumEngineTests` pass. Other tests may fail because they assumed the old 4-skill ladder — that's expected and fixed in later tasks.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/CurriculumEngine.swift Packages/MoraEngines/Tests/MoraEnginesTests/CurriculumEngineTests.swift
git commit -m "engines: realign v1 ladder to yokai cast (sh → th → f → r → short_a)

Ladder now has 5 skills, each carrying 3 warmup candidates derived from
JapaneseL1Profile interference pairs and a yokaiID matching the bundled
catalog. Adds indexOf(code:) and nextSkill(after:) helpers used by the
rotation driver in a follow-up commit."
```

---

### Task 1.3: Author `th_week.json`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/th_week.json`

- [ ] **Step 1: Write the fixture**

```json
{
  "target": {
    "letters": "th",
    "phoneme": "θ"
  },
  "l2_taught_graphemes": [
    "a","b","c","d","e","f","g","h","i","j","k","l","m",
    "n","o","p","q","r","s","t","u","v","w","x","y","z","sh"
  ],
  "decode_words": [
    { "surface": "thin",  "graphemes": ["th","i","n"], "phonemes": ["θ","ɪ","n"], "note": "th onset" },
    { "surface": "thud",  "graphemes": ["th","u","d"], "phonemes": ["θ","ʌ","d"], "note": "th onset" },
    { "surface": "thump", "graphemes": ["th","u","m","p"], "phonemes": ["θ","ʌ","m","p"], "note": "th onset" },
    { "surface": "thug",  "graphemes": ["th","u","g"], "phonemes": ["θ","ʌ","g"], "note": "th onset" },
    { "surface": "thick", "graphemes": ["th","i","c","k"], "phonemes": ["θ","ɪ","k"], "note": "th onset" },
    { "surface": "moth",  "graphemes": ["m","o","th"], "phonemes": ["m","ɒ","θ"], "note": "th coda" },
    { "surface": "path",  "graphemes": ["p","a","th"], "phonemes": ["p","æ","θ"], "note": "th coda" },
    { "surface": "bath",  "graphemes": ["b","a","th"], "phonemes": ["b","æ","θ"], "note": "th coda" },
    { "surface": "math",  "graphemes": ["m","a","th"], "phonemes": ["m","æ","θ"], "note": "th coda" },
    { "surface": "with",  "graphemes": ["w","i","th"], "phonemes": ["w","ɪ","θ"], "note": "th coda" }
  ],
  "sentences": [
    {
      "text": "The moth is thin.",
      "words": [
        { "surface": "the",  "graphemes": ["t","h","e"],  "phonemes": ["ð","ə"] },
        { "surface": "moth", "graphemes": ["m","o","th"], "phonemes": ["m","ɒ","θ"] },
        { "surface": "is",   "graphemes": ["i","s"],      "phonemes": ["ɪ","z"] },
        { "surface": "thin", "graphemes": ["th","i","n"], "phonemes": ["θ","ɪ","n"] }
      ]
    },
    {
      "text": "I sit with a cat.",
      "words": [
        { "surface": "i",    "graphemes": ["i"],          "phonemes": ["aɪ"] },
        { "surface": "sit",  "graphemes": ["s","i","t"],  "phonemes": ["s","ɪ","t"] },
        { "surface": "with", "graphemes": ["w","i","th"], "phonemes": ["w","ɪ","θ"] },
        { "surface": "a",    "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "cat",  "graphemes": ["c","a","t"],  "phonemes": ["k","æ","t"] }
      ]
    },
    {
      "text": "A thin path.",
      "words": [
        { "surface": "a",    "graphemes": ["a"],           "phonemes": ["ə"] },
        { "surface": "thin", "graphemes": ["th","i","n"],  "phonemes": ["θ","ɪ","n"] },
        { "surface": "path", "graphemes": ["p","a","th"],  "phonemes": ["p","æ","θ"] }
      ]
    }
  ]
}
```

- [ ] **Step 2: Commit (bundled content lands alongside the provider factory)**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/th_week.json
git commit -m "engines: bundle th week decoding content (week 2)"
```

---

### Task 1.4: Author `f_week.json`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/f_week.json`

- [ ] **Step 1: Write the fixture**

```json
{
  "target": {
    "letters": "f",
    "phoneme": "f"
  },
  "l2_taught_graphemes": [
    "a","b","c","d","e","f","g","h","i","j","k","l","m",
    "n","o","p","q","r","s","t","u","v","w","x","y","z","sh","th"
  ],
  "decode_words": [
    { "surface": "fan",  "graphemes": ["f","a","n"], "phonemes": ["f","æ","n"], "note": "f onset" },
    { "surface": "fig",  "graphemes": ["f","i","g"], "phonemes": ["f","ɪ","g"], "note": "f onset" },
    { "surface": "fog",  "graphemes": ["f","o","g"], "phonemes": ["f","ɒ","g"], "note": "f onset" },
    { "surface": "fat",  "graphemes": ["f","a","t"], "phonemes": ["f","æ","t"], "note": "f onset" },
    { "surface": "fit",  "graphemes": ["f","i","t"], "phonemes": ["f","ɪ","t"], "note": "f onset" },
    { "surface": "fun",  "graphemes": ["f","u","n"], "phonemes": ["f","ʌ","n"], "note": "f onset" },
    { "surface": "if",   "graphemes": ["i","f"],     "phonemes": ["ɪ","f"],     "note": "f coda" },
    { "surface": "off",  "graphemes": ["o","f","f"], "phonemes": ["ɒ","f"],     "note": "f coda (double)" },
    { "surface": "puff", "graphemes": ["p","u","f","f"], "phonemes": ["p","ʌ","f"], "note": "f coda" },
    { "surface": "cuff", "graphemes": ["c","u","f","f"], "phonemes": ["k","ʌ","f"], "note": "f coda" }
  ],
  "sentences": [
    {
      "text": "The fan is on.",
      "words": [
        { "surface": "the", "graphemes": ["t","h","e"],  "phonemes": ["ð","ə"] },
        { "surface": "fan", "graphemes": ["f","a","n"],  "phonemes": ["f","æ","n"] },
        { "surface": "is",  "graphemes": ["i","s"],      "phonemes": ["ɪ","z"] },
        { "surface": "on",  "graphemes": ["o","n"],      "phonemes": ["ɒ","n"] }
      ]
    },
    {
      "text": "A fat fig.",
      "words": [
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "fat", "graphemes": ["f","a","t"],  "phonemes": ["f","æ","t"] },
        { "surface": "fig", "graphemes": ["f","i","g"],  "phonemes": ["f","ɪ","g"] }
      ]
    },
    {
      "text": "I puff if I run.",
      "words": [
        { "surface": "i",    "graphemes": ["i"],             "phonemes": ["aɪ"] },
        { "surface": "puff", "graphemes": ["p","u","f","f"], "phonemes": ["p","ʌ","f"] },
        { "surface": "if",   "graphemes": ["i","f"],         "phonemes": ["ɪ","f"] },
        { "surface": "i",    "graphemes": ["i"],             "phonemes": ["aɪ"] },
        { "surface": "run",  "graphemes": ["r","u","n"],     "phonemes": ["r","ʌ","n"] }
      ]
    }
  ]
}
```

- [ ] **Step 2: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/f_week.json
git commit -m "engines: bundle f week decoding content (week 3)"
```

---

### Task 1.5: Author `r_week.json`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/r_week.json`

- [ ] **Step 1: Write the fixture**

```json
{
  "target": {
    "letters": "r",
    "phoneme": "r"
  },
  "l2_taught_graphemes": [
    "a","b","c","d","e","f","g","h","i","j","k","l","m",
    "n","o","p","q","r","s","t","u","v","w","x","y","z","sh","th"
  ],
  "decode_words": [
    { "surface": "run", "graphemes": ["r","u","n"], "phonemes": ["r","ʌ","n"], "note": "r onset" },
    { "surface": "red", "graphemes": ["r","e","d"], "phonemes": ["r","ɛ","d"], "note": "r onset" },
    { "surface": "rag", "graphemes": ["r","a","g"], "phonemes": ["r","æ","g"], "note": "r onset" },
    { "surface": "rat", "graphemes": ["r","a","t"], "phonemes": ["r","æ","t"], "note": "r onset" },
    { "surface": "rib", "graphemes": ["r","i","b"], "phonemes": ["r","ɪ","b"], "note": "r onset" },
    { "surface": "rot", "graphemes": ["r","o","t"], "phonemes": ["r","ɒ","t"], "note": "r onset" },
    { "surface": "rub", "graphemes": ["r","u","b"], "phonemes": ["r","ʌ","b"], "note": "r onset" },
    { "surface": "rip", "graphemes": ["r","i","p"], "phonemes": ["r","ɪ","p"], "note": "r onset" },
    { "surface": "ram", "graphemes": ["r","a","m"], "phonemes": ["r","æ","m"], "note": "r onset" },
    { "surface": "rig", "graphemes": ["r","i","g"], "phonemes": ["r","ɪ","g"], "note": "r onset" }
  ],
  "sentences": [
    {
      "text": "The rat can run.",
      "words": [
        { "surface": "the", "graphemes": ["t","h","e"], "phonemes": ["ð","ə"] },
        { "surface": "rat", "graphemes": ["r","a","t"], "phonemes": ["r","æ","t"] },
        { "surface": "can", "graphemes": ["c","a","n"], "phonemes": ["k","æ","n"] },
        { "surface": "run", "graphemes": ["r","u","n"], "phonemes": ["r","ʌ","n"] }
      ]
    },
    {
      "text": "A red rag is on a rib.",
      "words": [
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "red", "graphemes": ["r","e","d"],  "phonemes": ["r","ɛ","d"] },
        { "surface": "rag", "graphemes": ["r","a","g"],  "phonemes": ["r","æ","g"] },
        { "surface": "is",  "graphemes": ["i","s"],      "phonemes": ["ɪ","z"] },
        { "surface": "on",  "graphemes": ["o","n"],      "phonemes": ["ɒ","n"] },
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "rib", "graphemes": ["r","i","b"],  "phonemes": ["r","ɪ","b"] }
      ]
    },
    {
      "text": "A ram can rub a rig.",
      "words": [
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "ram", "graphemes": ["r","a","m"],  "phonemes": ["r","æ","m"] },
        { "surface": "can", "graphemes": ["c","a","n"],  "phonemes": ["k","æ","n"] },
        { "surface": "rub", "graphemes": ["r","u","b"],  "phonemes": ["r","ʌ","b"] },
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "rig", "graphemes": ["r","i","g"],  "phonemes": ["r","ɪ","g"] }
      ]
    }
  ]
}
```

- [ ] **Step 2: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/r_week.json
git commit -m "engines: bundle r week decoding content (week 4)"
```

---

### Task 1.6: Author `short_a_week.json`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/short_a_week.json`

- [ ] **Step 1: Write the fixture**

```json
{
  "target": {
    "letters": "a",
    "phoneme": "æ"
  },
  "l2_taught_graphemes": [
    "a","b","c","d","e","f","g","h","i","j","k","l","m",
    "n","o","p","q","r","s","t","u","v","w","x","y","z","sh","th"
  ],
  "decode_words": [
    { "surface": "cat",  "graphemes": ["c","a","t"],  "phonemes": ["k","æ","t"], "note": "short a medial" },
    { "surface": "bat",  "graphemes": ["b","a","t"],  "phonemes": ["b","æ","t"], "note": "short a medial" },
    { "surface": "rat",  "graphemes": ["r","a","t"],  "phonemes": ["r","æ","t"], "note": "short a medial" },
    { "surface": "fan",  "graphemes": ["f","a","n"],  "phonemes": ["f","æ","n"], "note": "short a medial" },
    { "surface": "ran",  "graphemes": ["r","a","n"],  "phonemes": ["r","æ","n"], "note": "short a medial" },
    { "surface": "map",  "graphemes": ["m","a","p"],  "phonemes": ["m","æ","p"], "note": "short a medial" },
    { "surface": "mad",  "graphemes": ["m","a","d"],  "phonemes": ["m","æ","d"], "note": "short a medial" },
    { "surface": "bad",  "graphemes": ["b","a","d"],  "phonemes": ["b","æ","d"], "note": "short a medial" },
    { "surface": "pat",  "graphemes": ["p","a","t"],  "phonemes": ["p","æ","t"], "note": "short a medial" },
    { "surface": "sat",  "graphemes": ["s","a","t"],  "phonemes": ["s","æ","t"], "note": "short a medial" }
  ],
  "sentences": [
    {
      "text": "A cat ran.",
      "words": [
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "cat", "graphemes": ["c","a","t"],  "phonemes": ["k","æ","t"] },
        { "surface": "ran", "graphemes": ["r","a","n"],  "phonemes": ["r","æ","n"] }
      ]
    },
    {
      "text": "The fat rat sat on a map.",
      "words": [
        { "surface": "the", "graphemes": ["t","h","e"],  "phonemes": ["ð","ə"] },
        { "surface": "fat", "graphemes": ["f","a","t"],  "phonemes": ["f","æ","t"] },
        { "surface": "rat", "graphemes": ["r","a","t"],  "phonemes": ["r","æ","t"] },
        { "surface": "sat", "graphemes": ["s","a","t"],  "phonemes": ["s","æ","t"] },
        { "surface": "on",  "graphemes": ["o","n"],      "phonemes": ["ɒ","n"] },
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "map", "graphemes": ["m","a","p"],  "phonemes": ["m","æ","p"] }
      ]
    },
    {
      "text": "A bad bat is mad.",
      "words": [
        { "surface": "a",   "graphemes": ["a"],          "phonemes": ["ə"] },
        { "surface": "bad", "graphemes": ["b","a","d"],  "phonemes": ["b","æ","d"] },
        { "surface": "bat", "graphemes": ["b","a","t"],  "phonemes": ["b","æ","t"] },
        { "surface": "is",  "graphemes": ["i","s"],      "phonemes": ["ɪ","z"] },
        { "surface": "mad", "graphemes": ["m","a","d"],  "phonemes": ["m","æ","d"] }
      ]
    }
  ]
}
```

- [ ] **Step 2: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Resources/short_a_week.json
git commit -m "engines: bundle short-a week decoding content (week 5)"
```

---

### Task 1.7: Add `ScriptedContentProvider.bundled(for:)` factory

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/ScriptedContentProvider.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/ScriptedContentProviderTests.swift`

- [ ] **Step 1: Write failing tests**

Add to `Packages/MoraEngines/Tests/MoraEnginesTests/ScriptedContentProviderTests.swift`:

```swift
func test_bundledFor_returnsProviderForEveryV1SkillCode() throws {
    let codes: [SkillCode] = ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"]
    for code in codes {
        let provider = try ScriptedContentProvider.bundled(for: code)
        XCTAssertFalse(
            provider.words.isEmpty,
            "\(code.rawValue) should bundle decode words"
        )
        XCTAssertFalse(
            provider.sentences.isEmpty,
            "\(code.rawValue) should bundle sentences"
        )
    }
}

func test_bundledFor_unknownCode_throws() {
    XCTAssertThrowsError(try ScriptedContentProvider.bundled(for: "no_such_skill"))
}

func test_bundledFor_thWeek_targetPhonemeIsVoicelessTh() throws {
    let provider = try ScriptedContentProvider.bundled(for: "th_voiceless")
    XCTAssertEqual(provider.target, Grapheme(letters: "th"))
    let request = ContentRequest(
        target: provider.target,
        taughtGraphemes: provider.taughtGraphemes,
        interests: [],
        count: 10
    )
    let words = try provider.decodeWords(request)
    XCTAssertFalse(words.isEmpty)
    for w in words {
        XCTAssertTrue(
            w.word.phonemes.contains(Phoneme(ipa: "θ")),
            "\(w.word.surface) expected to contain /θ/"
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
(cd Packages/MoraEngines && swift test --filter ScriptedContentProviderTests.test_bundledFor_returnsProviderForEveryV1SkillCode)
```
Expected: compile failure — `bundled(for:)` does not exist.

- [ ] **Step 3: Add the factory**

In `Packages/MoraEngines/Sources/MoraEngines/ScriptedContentProvider.swift`, add after `bundledShWeek1()`:

```swift
    /// Resource filename prefix per v1 skill code. Extending v1 means adding
    /// a case here and a matching `*_week.json` under `Resources/`.
    private static func resourceName(for code: SkillCode) -> String? {
        switch code.rawValue {
        case "sh_onset": return "sh_week1"
        case "th_voiceless": return "th_week"
        case "f_onset": return "f_week"
        case "r_onset": return "r_week"
        case "short_a": return "short_a_week"
        default: return nil
        }
    }

    public static func bundled(for code: SkillCode) throws -> ScriptedContentProvider {
        guard let name = resourceName(for: code) else {
            throw ScriptedContentError.resourceMissing("bundled provider for \(code.rawValue)")
        }
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw ScriptedContentError.resourceMissing("\(name).json")
        }
        let data = try Data(contentsOf: url)
        let payload = try JSONDecoder().decode(ShWeek1Payload.self, from: data)
        let targetPhoneme = Phoneme(ipa: payload.target.phoneme)
        return ScriptedContentProvider(
            target: Grapheme(letters: payload.target.letters),
            taughtGraphemes: Set(payload.l2TaughtGraphemes.map(Grapheme.init(letters:))),
            words: payload.decodeWords.map { $0.asDecodeWord(targetPhoneme: targetPhoneme) },
            sentences: payload.sentences.map { $0.asDecodeSentence(targetPhoneme: targetPhoneme) }
        )
    }
```

The payload shape already matches all five JSONs (same field names, `l2_taught_graphemes` can include `sh`/`th`/etc. as it's just a `[String]`).

- [ ] **Step 4: Run tests to verify they pass**

```sh
(cd Packages/MoraEngines && swift test --filter ScriptedContentProviderTests)
```
Expected: all pass.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/ScriptedContentProvider.swift Packages/MoraEngines/Tests/MoraEnginesTests/ScriptedContentProviderTests.swift
git commit -m "engines: add ScriptedContentProvider.bundled(for: SkillCode)

Resolves one of the five bundled *_week.json files keyed on SkillCode.
Keeps bundledShWeek1() for source-compat with existing call sites;
bootstrap migrates to bundled(for:) in a follow-up commit."
```

---

### Task 1.8: Add cross-week decodability audit

**Files:**
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/BundledWeekDecodabilityTests.swift`

- [ ] **Step 1: Write the test file**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/BundledWeekDecodabilityTests.swift
import MoraCore
import XCTest

@testable import MoraEngines

final class BundledWeekDecodabilityTests: XCTestCase {
    func test_everyBundledWeek_decodeWords_useOnlyTaughtOrTargetGraphemes() throws {
        let codes: [SkillCode] = ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"]
        for code in codes {
            let provider = try ScriptedContentProvider.bundled(for: code)
            let allowed = provider.taughtGraphemes.union([provider.target])
            for dw in provider.words {
                for g in dw.word.graphemes {
                    XCTAssertTrue(
                        allowed.contains(g),
                        "\(code.rawValue): \(dw.word.surface) uses untaught grapheme \(g.letters)"
                    )
                }
            }
        }
    }

    func test_everyBundledWeek_sentences_wordsUseOnlyTaughtOrTargetGraphemes() throws {
        let codes: [SkillCode] = ["sh_onset", "th_voiceless", "f_onset", "r_onset", "short_a"]
        for code in codes {
            let provider = try ScriptedContentProvider.bundled(for: code)
            let allowed = provider.taughtGraphemes.union([provider.target])
            for sentence in provider.sentences {
                for w in sentence.words {
                    for g in w.graphemes {
                        XCTAssertTrue(
                            allowed.contains(g),
                            "\(code.rawValue) sentence: \(w.surface) uses untaught grapheme \(g.letters)"
                        )
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run tests**

```sh
(cd Packages/MoraEngines && swift test --filter BundledWeekDecodabilityTests)
```
Expected: all pass. Failures mean a word in one of the JSONs uses a grapheme not in `taught ∪ {target}` — fix by removing the word or adjusting its graphemes.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/BundledWeekDecodabilityTests.swift
git commit -m "engines: decodability audit for all five bundled weeks"
```

---

### Task 1.9: Add `WeekRotation.resolve(...)` helper

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/WeekRotation.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/WeekRotationTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/WeekRotationTests.swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class WeekRotationTests: XCTestCase {
    private func freshContainer() throws -> ModelContainer {
        try MoraModelContainer.inMemory()
    }

    func test_resolve_emptyStore_createsInitialShEncounter() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        XCTAssertNotNil(res)
        XCTAssertEqual(res?.skill.code, "sh_onset")
        XCTAssertEqual(res?.encounter.yokaiID, "sh")
        XCTAssertEqual(res?.encounter.state, .active)
        XCTAssertTrue(res?.isNewEncounter == true)

        let saved = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.yokaiID, "sh")
    }

    func test_resolve_existingActiveEncounter_returnsMatchingSkill() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let existing = YokaiEncounterEntity(
            yokaiID: "th",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            state: .active,
            friendshipPercent: 0.4,
            sessionCompletionCount: 2
        )
        ctx.insert(existing)
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date() }
        )

        XCTAssertEqual(res?.skill.code, "th_voiceless")
        XCTAssertEqual(res?.encounter.yokaiID, "th")
        XCTAssertFalse(res?.isNewEncounter == true)
        XCTAssertEqual(res?.encounter.sessionCompletionCount, 2)
    }

    func test_resolve_allBefriended_returnsNil() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        for id in ["sh", "th", "f", "r", "short_a"] {
            ctx.insert(
                BestiaryEntryEntity(yokaiID: id, befriendedAt: Date())
            )
        }
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date() }
        )

        XCTAssertNil(res)
    }

    func test_resolve_someBefriendedNoActive_createsNextUnfinishedEncounter() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        ctx.insert(BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date()))
        ctx.insert(BestiaryEntryEntity(yokaiID: "th", befriendedAt: Date()))
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        XCTAssertEqual(res?.skill.code, "f_onset")
        XCTAssertTrue(res?.isNewEncounter == true)
    }

    func test_resolve_carryoverEncounter_resumesSameYokai() throws {
        let container = try freshContainer()
        let ctx = ModelContext(container)
        let carry = YokaiEncounterEntity(
            yokaiID: "f",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            state: .carryover,
            friendshipPercent: 0.88,
            sessionCompletionCount: 5
        )
        ctx.insert(carry)
        try ctx.save()

        let res = try WeekRotation.resolve(
            context: ctx,
            ladder: .defaultV1Ladder(),
            clock: { Date() }
        )

        XCTAssertEqual(res?.skill.code, "f_onset")
        XCTAssertEqual(res?.encounter.state, .carryover)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
(cd Packages/MoraEngines && swift test --filter WeekRotationTests)
```
Expected: compile failure — `WeekRotation` doesn't exist.

- [ ] **Step 3: Implement `WeekRotation`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/WeekRotation.swift
import Foundation
import MoraCore
import SwiftData

/// Pure helper that decides which skill a learner should be working on,
/// using `YokaiEncounterEntity` as the authoritative source of rotation
/// state and `BestiaryEntryEntity` to avoid re-offering befriended yokai.
///
/// Returns `nil` when every skill in the ladder has a bestiary entry —
/// i.e. the v1 alpha's curriculum is complete and no next session makes
/// sense.
public enum WeekRotation {
    public struct Resolution: Sendable {
        public let skill: Skill
        public let encounter: YokaiEncounterEntity
        public let isNewEncounter: Bool
    }

    @MainActor
    public static func resolve(
        context: ModelContext,
        ladder: CurriculumEngine,
        clock: () -> Date = Date.init
    ) throws -> Resolution? {
        var activeDescriptor = FetchDescriptor<YokaiEncounterEntity>(
            predicate: #Predicate { $0.stateRaw == "active" || $0.stateRaw == "carryover" },
            sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
        )
        activeDescriptor.fetchLimit = 1
        if let open = try context.fetch(activeDescriptor).first,
           let skill = ladder.skills.first(where: { $0.yokaiID == open.yokaiID })
        {
            return Resolution(skill: skill, encounter: open, isNewEncounter: false)
        }

        let bestiary = try context.fetch(FetchDescriptor<BestiaryEntryEntity>())
        let befriended = Set(bestiary.map(\.yokaiID))
        guard let nextSkill = ladder.skills.first(where: {
            guard let yid = $0.yokaiID else { return false }
            return !befriended.contains(yid)
        }) else {
            return nil
        }

        guard let yokaiID = nextSkill.yokaiID else { return nil }
        let encounter = YokaiEncounterEntity(
            yokaiID: yokaiID,
            weekStart: clock(),
            state: .active,
            friendshipPercent: 0
        )
        context.insert(encounter)
        try context.save()
        return Resolution(skill: nextSkill, encounter: encounter, isNewEncounter: true)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```sh
(cd Packages/MoraEngines && swift test --filter WeekRotationTests)
```
Expected: all five pass.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/WeekRotation.swift Packages/MoraEngines/Tests/MoraEnginesTests/WeekRotationTests.swift
git commit -m "engines: WeekRotation.resolve drives the per-session skill pick

Reads YokaiEncounterEntity + BestiaryEntryEntity from SwiftData and
resolves the next skill from the v1 ladder. Creates an initial sh
encounter on first launch, returns nil when all five yokai are
befriended."
```

---

### Task 1.10: Add `SystematicPrincipleTests`

**Files:**
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/SystematicPrincipleTests.swift`

- [ ] **Step 1: Write the tests**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/SystematicPrincipleTests.swift
import MoraCore
import XCTest

@testable import MoraEngines

final class SystematicPrincipleTests: XCTestCase {
    func test_everyBundledWeek_decodeWords_useExactlyTheWeeksTargetPhoneme() throws {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            guard let target = skill.graphemePhoneme else {
                XCTFail("\(skill.code.rawValue) missing graphemePhoneme")
                continue
            }
            let provider = try ScriptedContentProvider.bundled(for: skill.code)
            let request = ContentRequest(
                target: target.grapheme,
                taughtGraphemes: provider.taughtGraphemes,
                interests: [],
                count: 20
            )
            let words = try provider.decodeWords(request)
            XCTAssertFalse(
                words.isEmpty,
                "\(skill.code.rawValue) provider returned zero decode words"
            )
            for dw in words {
                XCTAssertTrue(
                    dw.word.phonemes.contains(target.phoneme),
                    "\(skill.code.rawValue): \(dw.word.surface) lacks target /\(target.phoneme.ipa)/"
                )
            }
        }
    }

    func test_everyBundledWeek_sentences_containAWordWithTargetGrapheme() throws {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            guard let target = skill.graphemePhoneme else { continue }
            let provider = try ScriptedContentProvider.bundled(for: skill.code)
            let request = ContentRequest(
                target: target.grapheme,
                taughtGraphemes: provider.taughtGraphemes,
                interests: [],
                count: 10
            )
            let sentences = try provider.decodeSentences(request)
            XCTAssertFalse(sentences.isEmpty, "\(skill.code.rawValue) returned zero sentences")
            for s in sentences {
                XCTAssertTrue(
                    s.words.contains(where: { $0.graphemes.contains(target.grapheme) }),
                    "\(skill.code.rawValue) sentence '\(s.text)' lacks target grapheme '\(target.grapheme.letters)'"
                )
            }
        }
    }

    func test_everySkill_warmupCandidates_containTargetGrapheme() {
        let ladder = CurriculumEngine.defaultV1Ladder()
        for skill in ladder.skills {
            guard let target = skill.graphemePhoneme?.grapheme else { continue }
            XCTAssertTrue(
                skill.warmupCandidates.contains(target),
                "\(skill.code.rawValue) warmup candidates must contain \(target.letters)"
            )
        }
    }
}
```

- [ ] **Step 2: Run tests**

```sh
(cd Packages/MoraEngines && swift test --filter SystematicPrincipleTests)
```
Expected: all pass. Failures here mean a content JSON needs a fix — treat as a blocker.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/SystematicPrincipleTests.swift
git commit -m "tests: systematic-principle regression for five-week ladder"
```

---

### Task 1.11: Bootstrap uses active encounter + new warmup + per-skill content

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Locate the bootstrap block**

```sh
grep -n "bundledShWeek1\|forWeekIndex: 0\|warmupOptions: \[" Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
```

Expect the current block (around lines 213-245) that calls `currentTarget(forWeekIndex: 0)` + `bundledShWeek1()` + hardcoded `[s, sh, ch]` warmup.

- [ ] **Step 2: Replace with active-encounter-driven bootstrap**

Replace the `do { ... let curriculum = CurriculumEngine.sharedV1 ... } catch { ... }` block with:

```swift
do {
    let ladder = CurriculumEngine.sharedV1
    guard let resolution = try WeekRotation.resolve(
        context: context,
        ladder: ladder
    ) else {
        // All five yokai befriended. PR 2 replaces this with a proper
        // curriculum-complete navigation; for PR 1 we surface a plain
        // message so the session does not crash.
        bootError = "Curriculum complete — all five yokai befriended."
        return
    }
    let skill = resolution.skill
    let target = Target(weekStart: resolution.encounter.weekStart, skill: skill)
    let weekIdx = ladder.indexOf(code: skill.code) ?? 0
    let taught = ladder.taughtGraphemes(beforeWeekIndex: weekIdx)
    guard let targetGrapheme = target.grapheme else {
        bootError =
            "Target skill \(skill.code.rawValue) has no grapheme/phoneme mapping"
        return
    }
    let provider = try ScriptedContentProvider.bundled(for: skill.code)
    let sentences = try provider.decodeSentences(
        ContentRequest(
            target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2
        ))
    self.orchestrator = SessionOrchestrator(
        target: target,
        taughtGraphemes: taught,
        warmupOptions: skill.warmupCandidates,
        chainProvider: LibraryFirstWordChainProvider(),
        sentences: sentences,
        assessment: AssessmentEngine(
            l1Profile: JapaneseL1Profile(),
            evaluator: shadowEvaluatorFactory.make(context.container)
        )
    )
} catch {
    bootError = String(describing: error)
}
```

- [ ] **Step 3: Build and run the UI test suite**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
(cd Packages/MoraUI && swift test)
```
Expected: build succeeds, tests pass. Any existing UI test that hardcoded the bootstrap target should pre-insert a `YokaiEncounterEntity(yokaiID: "sh", ...)` in its setUp.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "ui: SessionContainerView.bootstrap resolves active encounter

Bootstrap now reads from WeekRotation instead of forWeekIndex: 0. Warmup
distractors come from skill.warmupCandidates so each week has appropriate
L1-interference distractors. First launch creates an initial sh encounter
via WeekRotation. YokaiOrchestrator is still not constructed — that lands
in PR 2."
```

---

### Task 1.12: HomeView hero reads the active encounter's skill

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

- [ ] **Step 1: Find the hero `target` computed property**

```sh
grep -n "currentTarget\|forWeekIndex" Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
```

- [ ] **Step 2: Switch target resolution to read the active encounter**

At the top of `HomeView`, add:

```swift
@Environment(\.modelContext) private var modelContext
@Query(
    filter: #Predicate<YokaiEncounterEntity> { $0.stateRaw == "active" || $0.stateRaw == "carryover" },
    sort: \YokaiEncounterEntity.weekStart,
    order: .reverse
)
private var openEncounters: [YokaiEncounterEntity]

private var target: Target {
    let ladder = CurriculumEngine.sharedV1
    if let enc = openEncounters.first,
       let skill = ladder.skills.first(where: { $0.yokaiID == enc.yokaiID })
    {
        return Target(weekStart: enc.weekStart, skill: skill)
    }
    return ladder.currentTarget(forWeekIndex: 0)
}
```

Replace any prior `private var target: Target { ... }`. `ipaLine` already derives from `target.ipa`.

- [ ] **Step 3: Build**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "ui: HomeView hero target follows the active encounter

Hero now resolves off the latest active/carryover YokaiEncounterEntity.
First-launch fallback stays on the ladder's first skill so the home
screen still paints on an empty store before bootstrap seeds one."
```

---

### Task 1.13: Fix any fallout in existing tests

- [ ] **Step 1: Run the full test suite across packages**

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```

- [ ] **Step 2: For each failure, update the test**

Likely suspects:
- `SessionOrchestrator*Tests` that constructed a session with hardcoded warmup options or `bundledShWeek1()` — switch to `try ScriptedContentProvider.bundled(for: "sh_onset")` and `CurriculumEngine.sharedV1.skills[0].warmupCandidates`.
- `FullADayIntegrationTests` — engine-layer tests should be unaffected; UI ones may need to seed a `YokaiEncounterEntity`.
- `HomeView` snapshot tests (if any) — update baselines if the hero layout shifts.

- [ ] **Step 3: Rebuild + re-run**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```
Expected: all green.

- [ ] **Step 4: Commit fixes**

```sh
git add <changed test files>
git commit -m "tests: follow ladder realignment through existing fixtures"
```

(Skip if nothing needed fixing.)

---

### Task 1.14: Lint, final build, open PR 1

- [ ] **Step 1: Lint**

```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```
Expected: clean. If not, `swift-format format --in-place --recursive Mora Packages/*/Sources Packages/*/Tests` then re-lint.

- [ ] **Step 2: Final full build**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Push and open PR**

```sh
git push -u origin feat/curriculum-spine-five-weeks
gh pr create --title "feat: curriculum spine — five weeks aligned to yokai cast" --body "$(cat <<'EOF'
## Summary

- Realigns `CurriculumEngine.defaultV1Ladder()` from `[sh_onset, ch_onset, th_voiceless, ck_coda]` to `[sh_onset, th_voiceless, f_onset, r_onset, short_a]` — the bundled yokai cast order.
- Adds `warmupCandidates: [Grapheme]` and `yokaiID: String?` to `Skill` (defaults keep every existing call site compiling).
- Bundles four new decoding JSONs (`th_week`, `f_week`, `r_week`, `short_a_week`) alongside the existing `sh_week1`.
- `ScriptedContentProvider.bundled(for: SkillCode)` resolves the right JSON per skill.
- `WeekRotation.resolve(...)` replaces `forWeekIndex: 0` in `SessionContainerView.bootstrap`: reads `YokaiEncounterEntity` + `BestiaryEntryEntity`, creates an initial `sh` encounter on first launch, returns `nil` when all five are befriended.
- `HomeView` hero reads the active encounter's skill.
- Systematic-principle + decodability regression tests cover all five weeks.

Spec: `docs/superpowers/specs/2026-04-24-a-day-five-weeks-yokai-live-design.md`

**Out of scope** (lands in a follow-up PR): constructing `YokaiOrchestrator` from bootstrap, Monday intro / Friday befriend cutscenes, bestiary handoff, curriculum-complete UI.

## Test plan

- [x] `(cd Packages/MoraCore && swift test)` passes
- [x] `(cd Packages/MoraEngines && swift test)` passes
- [x] `(cd Packages/MoraUI && swift test)` passes
- [x] `(cd Packages/MoraTesting && swift test)` passes
- [x] `xcodebuild build ... CODE_SIGNING_ALLOWED=NO` BUILD SUCCEEDED
- [x] `swift-format lint --strict` clean
- [ ] Manual smoke on iPad simulator: fresh launch shows `sh` hero, sh session still works end-to-end.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Move to PR-autofix loop**

Invoke the pr-autofix-loop skill so the PR is babysat through CI and review.

---

## Phase 2 — PR 2: Yokai Live Wiring

> Branch name suggestion: `feat/yokai-live-wiring`. Opened against `main` after PR 1 merges; rebase on top of merged PR 1 before starting.

### Task 2.1: Add `YokaiProgressionSource` protocol + closure adapter

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiProgressionSource.swift`

- [ ] **Step 1: Write the protocol**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiProgressionSource.swift
import Foundation

/// Look up the yokai that should follow `currentID` in the weekly
/// rotation. Returns `nil` when the curriculum has no further yokai.
public protocol YokaiProgressionSource: Sendable {
    func nextYokaiID(after currentID: String) -> String?
}

/// Closure-backed default. The v1 bootstrap wires this to
/// `CurriculumEngine.sharedV1.nextSkill(after:).yokaiID`.
public struct ClosureYokaiProgressionSource: YokaiProgressionSource {
    private let resolver: @Sendable (String) -> String?
    public init(_ resolver: @escaping @Sendable (String) -> String?) {
        self.resolver = resolver
    }
    public func nextYokaiID(after currentID: String) -> String? {
        resolver(currentID)
    }
}
```

- [ ] **Step 2: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiProgressionSource.swift
git commit -m "engines: YokaiProgressionSource protocol for next-week lookup"
```

---

### Task 2.2: `YokaiOrchestrator.resume(encounter:)`

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorResumeTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorResumeTests.swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class YokaiOrchestratorResumeTests: XCTestCase {
    private func makeStore() throws -> BundledYokaiStore {
        try BundledYokaiStore()
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try MoraModelContainer.inMemory())
    }

    func test_resume_restoresStateFromExistingEncounter() throws {
        let ctx = try makeContext()
        let store = try makeStore()
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: Date(timeIntervalSince1970: 1_700_000_000),
            state: .active,
            friendshipPercent: 0.42,
            sessionCompletionCount: 2
        )
        ctx.insert(encounter)
        try ctx.save()

        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        orch.resume(encounter: encounter)

        XCTAssertEqual(orch.currentEncounter?.yokaiID, "sh")
        XCTAssertEqual(orch.currentYokai?.id, "sh")
        XCTAssertNil(orch.activeCutscene, "resume must not fire Monday intro again")
    }

    func test_resume_onSessionCount4_doesNotAutoPlayClimax() throws {
        let ctx = try makeContext()
        let store = try makeStore()
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: Date(),
            state: .active,
            friendshipPercent: 0.9,
            sessionCompletionCount: 4
        )
        ctx.insert(encounter)
        try ctx.save()

        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        orch.resume(encounter: encounter)

        XCTAssertNil(orch.activeCutscene)
        XCTAssertEqual(orch.currentEncounter?.sessionCompletionCount, 4)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiOrchestratorResumeTests)
```
Expected: compile failure — `resume(encounter:)` does not exist.

- [ ] **Step 3: Add `resume(encounter:)`**

In `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`, add right after `startWeek(yokaiID:weekStart:)`:

```swift
    /// Re-attach the orchestrator to an existing encounter without creating
    /// a new one. Used by bootstrap after the first session of a week has
    /// already happened (`sessionCompletionCount >= 1`). Preserves the stored
    /// friendship percent, session count, and all other encounter fields;
    /// clears transient per-day state.
    public func resume(encounter: YokaiEncounterEntity) {
        currentEncounter = encounter
        currentYokai = store.catalog().first(where: { $0.id == encounter.yokaiID })
        activeCutscene = nil
        dayGainSoFar = 0
    }
```

- [ ] **Step 4: Run tests**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiOrchestratorResumeTests)
```
Expected: pass.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorResumeTests.swift
git commit -m "engines: YokaiOrchestrator.resume attaches to existing encounter"
```

---

### Task 2.3: Friday-mode dispatch in `recordTrialOutcome` + next-encounter handoff

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorNextEncounterTests.swift`

- [ ] **Step 1: Write the tests**

```swift
// Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorNextEncounterTests.swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class YokaiOrchestratorNextEncounterTests: XCTestCase {
    private func makeOrch(
        progression: YokaiProgressionSource = ClosureYokaiProgressionSource { _ in "th" }
    ) throws -> (YokaiOrchestrator, ModelContext) {
        let ctx = ModelContext(try MoraModelContainer.inMemory())
        let orch = YokaiOrchestrator(
            store: try BundledYokaiStore(),
            modelContext: ctx,
            progressionSource: progression
        )
        return (orch, ctx)
    }

    func test_finalizeFriday_atHundredPercent_befriendsAndInsertsNextEncounter() throws {
        let (orch, ctx) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.98
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordTrialOutcome(correct: true)  // Friday dispatch

        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
        let encounters = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
        XCTAssertEqual(encounters.count, 2, "sh befriended + new th encounter")
        XCTAssertEqual(
            encounters.first(where: { $0.state == .active })?.yokaiID,
            "th"
        )
    }

    func test_finalizeFriday_withoutNextYokai_befriendsButInsertsNoNewEncounter() throws {
        let (orch, ctx) = try makeOrch(
            progression: ClosureYokaiProgressionSource { _ in nil }
        )
        try orch.startWeek(yokaiID: "short_a", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.99
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordTrialOutcome(correct: true)

        XCTAssertEqual(orch.currentEncounter?.state, .befriended)
        let active = try ctx.fetch(
            FetchDescriptor<YokaiEncounterEntity>(
                predicate: #Predicate { $0.stateRaw == "active" }
            )
        )
        XCTAssertTrue(active.isEmpty, "no next yokai means no new active encounter")
    }

    func test_recordTrialOutcome_normalMode_usesPerDayCapMath() throws {
        let (orch, _) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.dismissCutscene()
        orch.beginDay()

        for _ in 0..<20 {
            orch.recordTrialOutcome(correct: true)
        }
        let pct = orch.currentEncounter?.friendshipPercent ?? 0
        XCTAssertEqual(pct, 0.35, accuracy: 1e-9, "start 0.10 + day cap 0.25")
    }

    func test_recordTrialOutcome_fridayMode_usesFloorBoost() throws {
        let (orch, _) = try makeOrch()
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.50
        orch.currentEncounter?.sessionCompletionCount = 4

        orch.beginFridaySession(trialsPlanned: 10)
        orch.recordTrialOutcome(correct: true)

        XCTAssertEqual(orch.currentEncounter?.friendshipPercent ?? 0, 1.0, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run to verify failure**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiOrchestratorNextEncounterTests)
```
Expected: compile failures — `progressionSource` init param does not exist; `recordTrialOutcome` does not dispatch to Friday.

- [ ] **Step 3: Extend `YokaiOrchestrator`**

Edit `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`:

1. Add stored property + updated init:

```swift
    private let progressionSource: YokaiProgressionSource?
    private var isFridaySession: Bool = false

    public init(
        store: YokaiStore,
        modelContext: ModelContext,
        calendar: Calendar = .current,
        progressionSource: YokaiProgressionSource? = nil
    ) {
        self.store = store
        self.modelContext = modelContext
        self.calendar = calendar
        self.progressionSource = progressionSource
    }
```

2. Flag Friday mode in `beginFridaySession`, clear in `beginDay`:

```swift
    public func beginDay() {
        dayGainSoFar = 0
        isFridaySession = false
    }

    public func beginFridaySession(trialsPlanned: Int) {
        beginDay()
        fridayTrialsRemaining = trialsPlanned
        isFridaySession = true
    }
```

3. Dispatch in `recordTrialOutcome`:

```swift
    public func recordTrialOutcome(correct: Bool) {
        if isFridaySession {
            recordFridayFinalTrial(correct: correct)
            return
        }
        guard let encounter = currentEncounter else { return }
        let result = FriendshipMeterMath.applyTrialOutcome(
            percent: encounter.friendshipPercent,
            correct: correct,
            dayGainSoFar: dayGainSoFar
        )
        encounter.friendshipPercent = result.percent
        dayGainSoFar = result.dayGain
        if correct {
            encounter.correctReadCount += 1
            lastCorrectTrialID = UUID()
        }
        try? modelContext.save()
    }
```

4. Extend `finalizeFridayIfNeeded` to insert the next encounter:

```swift
    private func finalizeFridayIfNeeded() {
        guard let encounter = currentEncounter, let yokai = currentYokai else { return }
        if encounter.friendshipPercent >= 1.0 - 1e-9 {
            encounter.state = .befriended
            let when = Date()
            encounter.befriendedAt = when
            let entry = BestiaryEntryEntity(yokaiID: yokai.id, befriendedAt: when)
            modelContext.insert(entry)

            if let nextID = progressionSource?.nextYokaiID(after: yokai.id) {
                let next = YokaiEncounterEntity(
                    yokaiID: nextID,
                    weekStart: when,
                    state: .active,
                    friendshipPercent: 0
                )
                modelContext.insert(next)
            }

            try? modelContext.save()
            activeCutscene = .fridayClimax(yokaiID: yokai.id)
            isFridaySession = false
        } else {
            encounter.state = .carryover
            encounter.storedRolloverFlag = true
            try? modelContext.save()
            isFridaySession = false
        }
    }
```

- [ ] **Step 4: Run new tests**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiOrchestratorNextEncounterTests)
```
Expected: all four pass.

- [ ] **Step 5: Update existing meter / golden-week tests if needed**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiOrchestratorMeterTests)
(cd Packages/MoraEngines && swift test --filter YokaiGoldenWeekTests)
```
If any call sequenced `beginFridaySession` then called `recordTrialOutcome` expecting per-day-cap math, rename / reshape the test to assert floor-boost math. Default (`isFridaySession = false`) preserves prior behavior.

- [ ] **Step 6: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorNextEncounterTests.swift
git commit -m "engines: Friday dispatch + next-encounter handoff in YokaiOrchestrator"
```

---

### Task 2.4: Extend `YokaiGoldenWeekTests` to all five yokai

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiGoldenWeekTests.swift`

- [ ] **Step 1: Replace the body with a parameterized form**

```swift
import MoraCore
import SwiftData
import XCTest

@testable import MoraEngines

@MainActor
final class YokaiGoldenWeekTests: XCTestCase {
    private struct Scenario { let yokaiID: String; let next: String? }

    private let scenarios: [Scenario] = [
        .init(yokaiID: "sh", next: "th"),
        .init(yokaiID: "th", next: "f"),
        .init(yokaiID: "f", next: "r"),
        .init(yokaiID: "r", next: "short_a"),
        .init(yokaiID: "short_a", next: nil),
    ]

    func test_goldenWeek_eachYokai_reachesBefriendAndHandsOff() throws {
        for scenario in scenarios {
            let ctx = ModelContext(try MoraModelContainer.inMemory())
            let store = try BundledYokaiStore()
            let progression = ClosureYokaiProgressionSource { id in
                id == scenario.yokaiID ? scenario.next : nil
            }
            let orch = YokaiOrchestrator(
                store: store, modelContext: ctx, progressionSource: progression
            )
            try orch.startWeek(yokaiID: scenario.yokaiID, weekStart: Date())
            orch.dismissCutscene()

            for _ in 0..<4 {
                orch.beginDay()
                for _ in 0..<20 { orch.recordTrialOutcome(correct: true) }
                orch.recordSessionCompletion()
            }

            orch.beginFridaySession(trialsPlanned: 1)
            orch.recordTrialOutcome(correct: true)

            XCTAssertEqual(
                orch.currentEncounter?.state, .befriended,
                "\(scenario.yokaiID) should befriend by session 5"
            )

            let encounters = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
            let nextActive = encounters.first { $0.state == .active }
            if let nextID = scenario.next {
                XCTAssertEqual(nextActive?.yokaiID, nextID,
                    "\(scenario.yokaiID) should hand off to \(nextID)")
            } else {
                XCTAssertNil(nextActive,
                    "\(scenario.yokaiID) is last — no further active encounter")
            }
        }
    }
}
```

- [ ] **Step 2: Run**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiGoldenWeekTests)
```
Expected: pass.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/YokaiGoldenWeekTests.swift
git commit -m "tests: YokaiGoldenWeek covers all five yokai + handoff chain"
```

---

### Task 2.5: Construct `YokaiOrchestrator` in bootstrap

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Extend the bootstrap block (post PR 1 shape)**

Inside `bootstrap()`, after the `let resolution = try WeekRotation.resolve(...)` block, insert yokai construction before `self.orchestrator = SessionOrchestrator(...)`:

```swift
let progression = ClosureYokaiProgressionSource { currentID in
    ladder.skills
        .first(where: { $0.yokaiID == currentID })
        .flatMap { ladder.nextSkill(after: $0.code) }
        .flatMap { $0.yokaiID }
}
let yokaiOrchestrator: YokaiOrchestrator?
do {
    let store = try BundledYokaiStore()
    let orch = YokaiOrchestrator(
        store: store,
        modelContext: context,
        progressionSource: progression
    )
    if resolution.isNewEncounter {
        try orch.startWeek(
            yokaiID: resolution.encounter.yokaiID,
            weekStart: resolution.encounter.weekStart
        )
        // startWeek inserts its own encounter; WeekRotation already inserted
        // one. Delete ours to keep the orchestrator-owned one as the single
        // source of truth for cutscene state.
        context.delete(resolution.encounter)
        try context.save()
    } else {
        orch.resume(encounter: resolution.encounter)
        if resolution.encounter.sessionCompletionCount == 4 {
            // trialsPlanned matches the total trial budget for a session:
            // tile-board phase emits one trial per chain link (up to 12),
            // sentences phase emits up to `sentences.count` trials (2 here).
            // Use an upper bound so floor math always reaches 100%.
            orch.beginFridaySession(trialsPlanned: 14)
        }
    }
    yokaiOrchestrator = orch
} catch {
    speechLog.error("YokaiOrchestrator init failed: \(String(describing: error))")
    yokaiOrchestrator = nil
}
```

Change the `SessionOrchestrator(...)` call to pass it:

```swift
self.orchestrator = SessionOrchestrator(
    target: target,
    taughtGraphemes: taught,
    warmupOptions: skill.warmupCandidates,
    chainProvider: LibraryFirstWordChainProvider(),
    sentences: sentences,
    assessment: AssessmentEngine(
        l1Profile: JapaneseL1Profile(),
        evaluator: shadowEvaluatorFactory.make(context.container)
    ),
    yokai: yokaiOrchestrator
)
```

- [ ] **Step 2: Build**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run UI tests**

```sh
(cd Packages/MoraUI && swift test)
```
Expected: all pass.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "ui: bootstrap constructs and passes YokaiOrchestrator

Chooses startWeek vs resume based on whether WeekRotation created a
fresh encounter. beginFridaySession fires when sessionCompletionCount
is exactly 4 so floor-guarantee math drives the fifth session."
```

---

### Task 2.6: CompletionView fires `recordSessionCompletion`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift`

- [ ] **Step 1: Find `persistOnce()`**

```sh
grep -n "persistOnce\|persistSummary" Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift
```

- [ ] **Step 2: Add the call after the summary persist**

Inside `persistOnce()`, right after `persistSummary(summary)`:

```swift
// For normal (non-Friday) sessions, advance the yokai's
// sessionCompletionCount + apply the +5% session bonus. Friday sessions
// auto-finalize through finalizeFridayIfNeeded when the last trial lands,
// so calling recordSessionCompletion here would double-count.
if orchestrator.yokai?.currentEncounter?.state == .active {
    orchestrator.yokai?.recordSessionCompletion()
}
```

- [ ] **Step 3: Build + test**

```sh
(cd Packages/MoraUI && swift test)
```
Expected: pass.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Session/CompletionView.swift
git commit -m "ui: CompletionView advances yokai session count on normal finish"
```

---

### Task 2.7: HomeView shows the active yokai portrait corner

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

- [ ] **Step 1: Extend the hero VStack**

After the `NavigationLink(value: "session")` block inside the hero, add:

```swift
if let enc = openEncounters.first,
   let store = try? BundledYokaiStore(),
   let yokai = store.catalog().first(where: { $0.id == enc.yokaiID })
{
    YokaiPortraitCorner(yokai: yokai, sparkleTrigger: nil)
        .frame(width: 96, height: 96)
        .accessibilityLabel("This week's sound-friend: \(enc.yokaiID)")
}
```

- [ ] **Step 2: Build + manual smoke**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift
git commit -m "ui: HomeView surfaces the active yokai portrait corner"
```

---

### Task 2.8: Curriculum-complete terminal screen

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/CurriculumCompleteView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/RootView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Create the view**

```swift
// Packages/MoraUI/Sources/MoraUI/CurriculumCompleteView.swift
import SwiftUI

public struct CurriculumCompleteView: View {
    @Environment(\.moraStrings) private var strings
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            Spacer()
            Text("You befriended all five sound-friends!")
                .font(MoraType.heading())
                .foregroundStyle(MoraTheme.Ink.primary)
                .multilineTextAlignment(.center)

            NavigationLink(value: "bestiary") {
                Label("Open your Sound-Friend Register", systemImage: "book.closed.fill")
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(MoraTheme.Space.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoraTheme.Background.page.ignoresSafeArea())
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }
}
```

- [ ] **Step 2: Add navigation destination in RootView**

Extend `navigationDestination(for: String.self)`:

```swift
case "curriculumComplete":
    CurriculumCompleteView()
        .environment(\.moraStrings, resolvedStrings)
```

- [ ] **Step 3: HomeView routes to it when all befriended**

Add a Query for bestiary and a CTA branch:

```swift
@Query private var bestiary: [BestiaryEntryEntity]

private var isCurriculumComplete: Bool {
    openEncounters.isEmpty && bestiary.count >= 5
}
```

Replace the `NavigationLink(value: "session")` block with:

```swift
if isCurriculumComplete {
    NavigationLink(value: "curriculumComplete") {
        Text("All befriended — view your Register")
            .font(MoraType.cta())
            .foregroundStyle(.white)
            .padding(.horizontal, MoraTheme.Space.xl)
            .padding(.vertical, MoraTheme.Space.md)
            .frame(minHeight: 88)
            .background(MoraTheme.Accent.orange, in: .capsule)
    }
    .buttonStyle(.plain)
} else {
    // existing NavigationLink(value: "session") { ... }
}
```

- [ ] **Step 4: SessionContainerView bounces back if resolution nil**

Replace:

```swift
bootError = "Curriculum complete — all five yokai befriended."
return
```

with:

```swift
dismiss()
return
```

- [ ] **Step 5: Build + manual smoke**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Manual: seed 5 `BestiaryEntryEntity` rows in simulator (or inline in a test preview), confirm home flips to "All befriended" CTA.

- [ ] **Step 6: Commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/CurriculumCompleteView.swift Packages/MoraUI/Sources/MoraUI/RootView.swift Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift
git commit -m "ui: curriculum-complete terminal screen"
```

---

### Task 2.9: Bootstrap integration test

**Files:**
- Create: `Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapTests.swift`

- [ ] **Step 1: Confirm MoraUI has a test target**

```sh
cat Packages/MoraUI/Package.swift
```

If no test target exists, add one to `Package.swift`. If adding one, match the existing SPM pattern (dependency on `MoraUI`, resources copy if needed, `.swiftLanguageMode(.v5)`).

- [ ] **Step 2: Write the test**

```swift
// Packages/MoraUI/Tests/MoraUITests/SessionContainerBootstrapTests.swift
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI
import XCTest

@testable import MoraUI

@MainActor
final class SessionContainerBootstrapTests: XCTestCase {
    func test_bootstrapSurface_activeEncounterYieldsYokaiOrchestrator() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: Date(),
            state: .active,
            friendshipPercent: 0.1,
            sessionCompletionCount: 0
        )
        ctx.insert(encounter)
        try ctx.save()

        let ladder = CurriculumEngine.sharedV1
        let resolution = try WeekRotation.resolve(context: ctx, ladder: ladder)
        XCTAssertNotNil(resolution)
        XCTAssertEqual(resolution?.skill.code, "sh_onset")

        let store = try BundledYokaiStore()
        let progression = ClosureYokaiProgressionSource { id in
            ladder.skills.first(where: { $0.yokaiID == id })
                .flatMap { ladder.nextSkill(after: $0.code) }
                .flatMap(\.yokaiID)
        }
        let yokai = YokaiOrchestrator(
            store: store, modelContext: ctx, progressionSource: progression
        )
        yokai.resume(encounter: resolution!.encounter)

        XCTAssertEqual(yokai.currentYokai?.id, "sh")
        XCTAssertEqual(yokai.currentEncounter?.yokaiID, "sh")
    }
}
```

- [ ] **Step 3: Run**

```sh
(cd Packages/MoraUI && swift test --filter SessionContainerBootstrapTests)
```
Expected: pass.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraUI/Tests Packages/MoraUI/Package.swift
git commit -m "tests(ui): bootstrap integration for active encounter path"
```

---

### Task 2.10: Lint, full build, open PR 2

- [ ] **Step 1: Lint**

```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 2: Full build**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 3: Full test sweep**

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```

- [ ] **Step 4: Push + open PR**

```sh
git push -u origin feat/yokai-live-wiring
gh pr create --title "feat: yokai live wiring — monday intro, friday befriend, bestiary handoff" --body "$(cat <<'EOF'
## Summary

- Constructs `YokaiOrchestrator` in `SessionContainerView.bootstrap`; passes it into `SessionOrchestrator`.
- `YokaiOrchestrator.resume(encounter:)` attaches to mid-week encounters without firing the Monday intro cutscene again.
- `recordTrialOutcome` dispatches to Friday floor-boost math when `beginFridaySession` has activated Friday mode.
- `finalizeFridayIfNeeded` inserts the next encounter via a pluggable `YokaiProgressionSource`.
- `CompletionView` calls `recordSessionCompletion` on the orchestrator for non-Friday sessions.
- `HomeView` shows the active yokai portrait corner and flips to a "view your Register" CTA when all five are befriended.
- New `CurriculumCompleteView` terminal screen routed from home and from post-rotation bootstrap.
- `YokaiGoldenWeekTests` extended to cover all five yokai + the chain of handoffs.

Spec: `docs/superpowers/specs/2026-04-24-a-day-five-weeks-yokai-live-design.md`

## Test plan

- [x] `(cd Packages/MoraCore && swift test)`
- [x] `(cd Packages/MoraEngines && swift test)`
- [x] `(cd Packages/MoraUI && swift test)`
- [x] `(cd Packages/MoraTesting && swift test)`
- [x] `xcodebuild build ... CODE_SIGNING_ALLOWED=NO` BUILD SUCCEEDED
- [x] `swift-format lint --strict` clean
- [ ] Manual smoke on iPad simulator: fresh launch shows sh monday-intro cutscene; five sessions complete → friday climax → th encounter starts automatically.
- [ ] Manual verification of curriculum-complete state.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: pr-autofix-loop**

Invoke the pr-autofix-loop skill.

---

## Phase 3 — Side Branch: Adult-Proxy Fixtures + Calibration (P2)

> Branch: `bench/adult-proxy-fixtures-calibration`. Independent of PR 1 / PR 2; branches from `main`.

### Task 3.1: Record adult-proxy fixtures on device (MANUAL)

- [ ] **Step 1: Build + install the recorder**

```sh
cd recorder/MoraFixtureRecorder
xcodegen generate
xcodebuild build -project MoraFixtureRecorder.xcodeproj -scheme MoraFixtureRecorder -destination 'generic/platform=iOS' CODE_SIGNING_REQUIRED=NO
```

Install on the physical iPad.

- [ ] **Step 2: Record 12 fixtures**

Follow `docs/superpowers/plans/2026-04-23-pronunciation-bench-followups.md` Task A1 Steps 1–3: 4 r/l + 4 v/b + 4 aeuh patterns. AirDrop to `~/mora-fixtures-adult/`.

- [ ] **Step 3: Verify**

```sh
ls ~/mora-fixtures-adult/rl ~/mora-fixtures-adult/vb ~/mora-fixtures-adult/aeuh
```
Expected: 4 WAVs + 4 JSON sidecars each.

---

### Task 3.2: Unskip `FeatureBasedEvaluatorFixtureTests`

- [ ] **Step 1: Copy fixtures**

```sh
mkdir -p Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/adult
cp -r ~/mora-fixtures-adult/* Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/adult/
```

- [ ] **Step 2: Remove `XCTSkip`**

```sh
grep -n XCTSkip Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift
```

Remove the skip line.

- [ ] **Step 3: Run**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureBasedEvaluatorFixtureTests)
```

Most pass; failures feed Task 3.3.

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/adult Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorFixtureTests.swift
git commit -m "tests(engine-a): unskip fixture tests with adult-proxy recordings"
```

---

### Task 3.3: Tune `PhonemeThresholds`

- [ ] **Step 1: Run the bench**

```sh
cd dev-tools/pronunciation-bench
swift run bench --fixtures ../../Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/adult --output ../../bench-adult.csv
```

- [ ] **Step 2: Update thresholds**

Adjust `PhonemeThresholds.swift` constants; add / extend `PhonemeThresholdsTests.swift` cases per changed pair.

- [ ] **Step 3: Re-run**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureBasedEvaluatorFixtureTests)
(cd Packages/MoraEngines && swift test --filter PhonemeThresholdsTests)
```

- [ ] **Step 4: Commit + PR**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeThresholds.swift Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeThresholdsTests.swift
git commit -m "engine-a: tune phoneme thresholds against adult-proxy fixtures"

git push -u origin bench/adult-proxy-fixtures-calibration
gh pr create --title "engine-a: adult-proxy calibration" --body "See spec §5 Side Branch."
```

---

## Cross-PR Verification

Once both PR 1 and PR 2 merge:

- [ ] Wipe the app's SwiftData on an iPad simulator.
- [ ] Launch → confirm `sh` hero + monday intro cutscene.
- [ ] Complete 5 sessions for `sh` → friday climax → bestiary gains `sh`.
- [ ] Next launch shows `th` hero.
- [ ] Repeat through `short_a` → curriculum-complete screen appears.
- [ ] Open the Sound-Friend Register; verify 5 cards.

---

## Self-Review Checklist

### Spec coverage

- G1 ladder realigned — Task 1.2
- G2 week rotation via `YokaiEncounterEntity` — Tasks 1.9 / 1.11
- G3 four new JSONs — Tasks 1.3 / 1.4 / 1.5 / 1.6
- G4 `YokaiOrchestrator` constructed — Task 2.5
- G5 Friday floor guarantee — Task 2.3
- G6 systematic-principle regression — Task 1.10
- C1 rotation — Task 1.9 tests
- C2 Monday intro once per encounter — Task 2.5 + Task 2.2 semantics
- C3 Friday + bestiary handoff — Tasks 2.3 / 2.4
- C4 curriculum-complete screen — Task 2.8
- C5 full test sweep — Tasks 1.14 / 2.10

### Placeholder scan

No "TBD" / "TODO". Every task has exact file paths, complete code blocks, explicit verification commands.

### Type consistency

- `Skill.warmupCandidates: [Grapheme]`, `Skill.yokaiID: String?` — consistent Task 1.1 → 1.2 → 1.11 → 1.12.
- `YokaiOrchestrator.resume(encounter:)` — Task 2.2 matches Task 2.5 call site.
- `YokaiProgressionSource.nextYokaiID(after:)` — Task 2.1 matches Task 2.3 + 2.5 usage.
- `WeekRotation.Resolution` (skill, encounter, isNewEncounter) — Task 1.9 matches Task 1.11 / Task 2.5 consumption.
- `ScriptedContentProvider.bundled(for: SkillCode)` — Task 1.7 matches Task 1.10 / 1.11 / 2.9 usage.
