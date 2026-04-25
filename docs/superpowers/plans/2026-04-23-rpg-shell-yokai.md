# RPG Shell Yokai Befriending — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a weekly yokai-befriending RPG overlay on top of the existing mora A-day / C-day session flow, starting with five yokai (`sh`, `th`, `f`, `r`, `short_a`).

**Architecture:** Additive SwiftUI overlay driven by a new `YokaiOrchestrator` in MoraEngines that subscribes to the existing `SessionOrchestrator`. New SwiftData entities under MoraCore track encounter state, bestiary, and SRS cameos. Asset generation happens off-device on a Linux RTX 5090 workstation; the app bundles pre-baked portraits and voice clips via Git LFS.

**Tech Stack:** Swift 6 (language mode .v5), SwiftUI, SwiftData, iOS 17 / macOS 14, XcodeGen, ComfyUI + Flux.1 dev + Style LoRA (Ubuntu RTX 5090 session), Fish Speech S2 Pro + Bark (Ubuntu RTX 5090 session), Git LFS.

**Execution topology:** Two Claude Code sessions collaborate via Git.

- **Mac session** (this worktree at `.claude/worktrees/peaceful-crunching-pancake`) owns the Swift / SwiftUI / Xcode work (phases R1, R2, R5) and opens the corresponding PRs.
- **Ubuntu session** — started directly on `youtalk-desktop` (not SSH) — owns the asset forge (phases R3 and R4). The Ubuntu host has its own clone of the repo so it can commit and push asset files on its own feature branches; the Mac session pulls those commits to run Xcode smoke tests and open PRs that include them.

There is no SSH or SCP in this plan; all cross-machine coordination is `git push` / `git pull` through the remote.

**Spec:** `docs/superpowers/specs/2026-04-23-rpg-shell-yokai-design.md` (committed at `981a375`).

---

## Phases and PRs

| Phase | PR title | Runs in | Pre-reqs | Effort |
|---|---|---|---|---|
| R1 | `feat(rpg): yokai core engine and SwiftData persistence` | Mac session | — | 4–6 d |
| R2 | `feat(rpg): yokai UI overlay and bestiary view (placeholder assets)` | Mac session | R1 merged | 2–3 d |
| R3 | `tools(yokai-forge): prompt library and ComfyUI workflows` | Ubuntu session | — (parallel with R1/R2) | 2–3 d |
| R4 | `assets(yokai): bundle first five yokai (portraits + voice via LFS)` | Ubuntu session (commit/push) + Mac session (smoke test, PR) | R3 complete | 2–3 d |
| R5 | `feat(rpg): cutscene polish, accessibility, haptics, carryover` | Mac session | R2 + R4 merged | 2–3 d |

All five PRs combine into an end-to-end first ship of the RPG shell.

---

## File Structure (all phases)

### MoraCore (new files)

```
Packages/MoraCore/Sources/MoraCore/
  Yokai/
    YokaiDefinition.swift          # Codable value type (R1.1)
    YokaiClipKey.swift             # voice-clip enum (R1.1)
    YokaiCatalogLoader.swift       # JSON + resource resolution (R1.3)
    YokaiCatalog.json              # bundled 5-yokai catalog (R1.2, refined in R4)
  Persistence/
    YokaiEncounterEntity.swift     # @Model weekly encounter (R1.4)
    YokaiEncounterState.swift      # state enum (R1.4)
    BestiaryEntryEntity.swift      # @Model befriended card (R1.5)
    YokaiCameoEntity.swift         # @Model SRS cameo log (R1.6)
  Resources/Yokai/<id>/            # per-yokai assets (filled in R4)
    portrait.png
    voice/{phoneme,example1,...}.m4a
```

### MoraEngines (new files)

```
Packages/MoraEngines/Sources/MoraEngines/Yokai/
  YokaiStore.swift                 # protocol (R1.8)
  BundledYokaiStore.swift          # concrete impl using MoraCore catalog (R1.9)
  YokaiOrchestrator.swift          # @Observable, meter + state machine (R1.11..R1.17)
  YokaiCutscene.swift              # cutscene trigger enum (R1.11)
  FriendshipMeterMath.swift        # pure math helpers for unit test isolation (R1.12)
```

### MoraEngines (modified)

```
Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift  # inject yokai hook (R1.18)
```

### MoraTesting (new files)

```
Packages/MoraTesting/Sources/MoraTesting/
  FakeYokaiStore.swift             # in-memory fake (R1.10)
  YokaiFixtures.swift              # sample YokaiDefinition records (R1.10)
```

### MoraUI (new files — R2)

```
Packages/MoraUI/Sources/MoraUI/Yokai/
  YokaiLayerView.swift             # ZStack overlay root (R2.2)
  FriendshipGaugeHUD.swift         # top-right meter bar (R2.3)
  YokaiPortraitCorner.swift        # bottom-right static portrait (R2.4)
  YokaiCutsceneOverlay.swift       # full-screen conditional (R2.5)
Packages/MoraUI/Sources/MoraUI/Bestiary/
  BestiaryView.swift               # grid of cards (R2.6)
  BestiaryCardView.swift           # card cell (R2.7)
  BestiaryDetailView.swift         # expanded card + audio playback (R2.8)
```

### MoraUI (modified)

```
Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift    # insert layer (R2.9)
Packages/MoraUI/Sources/MoraUI/RootView.swift                        # bestiary nav (R2.10)
```

### Asset forge tools (new — R3)

```
tools/yokai-forge/
  README.md                        # bootstrap + usage (R3.1)
  requirements.txt                 # python deps (R3.2)
  prompts/
    style_layer.txt                # Layer-1 constant (R3.3)
    yokai_sh.json                  # MVP-five per-yokai JSON (R3.4)
    yokai_th.json
    yokai_f.json
    yokai_r.json
    yokai_short_a.json
  scripts/
    bootstrap_style.py             # 100-image bootstrap (R3.5)
    train_style_lora.sh            # Ostris invocation wrapper (R3.6)
    render_portraits.py            # per-yokai batch renderer (R3.7)
    synthesize_voices.py           # Fish Speech + Bark batch (R3.8)
    master_audio.py                # normalize/trim/m4a encode (R3.9)
  workflows/
    flux_style.json                # ComfyUI workflow for style bootstrap (R3.5)
    flux_portrait.json             # ComfyUI workflow for per-yokai (R3.7)
```

### LFS + assets (R4)

```
.gitattributes                     # add PNG + M4A LFS rules (R4.1)
Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/portrait.png
Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/voice/*.m4a
...  (×5 yokai)
Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json  # finalize voice descriptions (R4.2)
```

---

## Phase R1: Yokai Core Engine

**Merge criterion:** All MoraCore and MoraEngines tests pass; `xcodebuild build` succeeds; no UI; no real assets. The engine drives a full week purely from trial-outcome events.

### Task R1.1: YokaiDefinition + YokaiClipKey value types

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiDefinition.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiClipKey.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/YokaiDefinitionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// YokaiDefinitionTests.swift
import Testing
@testable import MoraCore

@Suite("YokaiDefinition decoding")
struct YokaiDefinitionTests {
    @Test("decodes canonical JSON record")
    func decodesCanonical() throws {
        let json = """
        {
            "id": "sh",
            "grapheme": "sh",
            "ipa": "/ʃ/",
            "personality": "mischievous whisper spirit",
            "sound_gesture": "finger to lips",
            "word_decor": ["sailor hat", "seashell ears", "fin tail"],
            "palette": ["teal", "cream"],
            "expression": "playful smirk",
            "voice": {
                "character_description": "young whispery",
                "clips": {
                    "phoneme": "Shhh /ʃ/",
                    "example_1": "ship",
                    "example_2": "shop",
                    "example_3": "shell",
                    "greet": "Shhh",
                    "encourage": "Yes",
                    "gentle_retry": "Again",
                    "friday_acknowledge": "Yours"
                }
            }
        }
        """
        let data = Data(json.utf8)
        let yokai = try JSONDecoder().decode(YokaiDefinition.self, from: data)
        #expect(yokai.id == "sh")
        #expect(yokai.grapheme == "sh")
        #expect(yokai.ipa == "/ʃ/")
        #expect(yokai.wordDecor.count == 3)
        #expect(yokai.voice.clips[.phoneme] == "Shhh /ʃ/")
        #expect(yokai.voice.clips[.example1] == "ship")
        #expect(yokai.voice.clips[.fridayAcknowledge] == "Yours")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```sh
(cd Packages/MoraCore && swift test --filter YokaiDefinitionTests)
```

Expected: FAIL with "cannot find type 'YokaiDefinition'".

- [ ] **Step 3: Create YokaiClipKey**

```swift
// Packages/MoraCore/Sources/MoraCore/Yokai/YokaiClipKey.swift
import Foundation

public enum YokaiClipKey: String, CaseIterable, Codable, Sendable {
    case phoneme
    case example1 = "example_1"
    case example2 = "example_2"
    case example3 = "example_3"
    case greet
    case encourage
    case gentleRetry = "gentle_retry"
    case fridayAcknowledge = "friday_acknowledge"
}
```

- [ ] **Step 4: Create YokaiDefinition**

```swift
// Packages/MoraCore/Sources/MoraCore/Yokai/YokaiDefinition.swift
import Foundation

public struct YokaiDefinition: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let grapheme: String
    public let ipa: String
    public let personality: String
    public let soundGesture: String
    public let wordDecor: [String]
    public let palette: [String]
    public let expression: String
    public let voice: Voice

    public struct Voice: Codable, Hashable, Sendable {
        public let characterDescription: String
        public let clips: [YokaiClipKey: String]

        enum CodingKeys: String, CodingKey {
            case characterDescription = "character_description"
            case clips
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, grapheme, ipa, personality
        case soundGesture = "sound_gesture"
        case wordDecor = "word_decor"
        case palette, expression, voice
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

```sh
(cd Packages/MoraCore && swift test --filter YokaiDefinitionTests)
```

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/Yokai/ Packages/MoraCore/Tests/MoraCoreTests/YokaiDefinitionTests.swift
git commit -m "feat(core): YokaiDefinition and YokaiClipKey value types"
```

### Task R1.2: YokaiCatalog JSON (placeholder content for 5 yokai)

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json`

(This is placeholder data; R4 finalizes the palette / expression / voice descriptions after real asset generation.)

- [ ] **Step 1: Write catalog JSON with 5 records**

```json
[
  {
    "id": "sh",
    "grapheme": "sh",
    "ipa": "/ʃ/",
    "personality": "mischievous whisper spirit",
    "sound_gesture": "index finger pursed to lips in a shushing pose, one eye winking",
    "word_decor": ["paper sailor hat shaped like a small ship", "pointed seashell ears", "fluffy fin-like tail"],
    "palette": ["teal", "cream", "foam-white"],
    "expression": "playful smirk, large round sparkling eyes",
    "voice": {
      "character_description": "young mischievous whispery boy, softly spoken with playful cadence, subtle wind-like breath",
      "clips": {
        "phoneme": "Shhh /ʃ/",
        "example_1": "ship",
        "example_2": "shop",
        "example_3": "shell",
        "greet": "Shhh! You made it. Can you hear my sound?",
        "encourage": "That's it! Hear it whisper?",
        "gentle_retry": "So close. Listen once more.",
        "friday_acknowledge": "You found my sound. Now I am yours to remember."
      }
    }
  },
  {
    "id": "th",
    "grapheme": "th",
    "ipa": "/θ/",
    "personality": "tongue-showing prankster yokai",
    "sound_gesture": "tongue poked out between front teeth, puffing air",
    "word_decor": ["small lightning-bolt ear tufts", "thumb-up paw held forward", "thorny leaf cape"],
    "palette": ["violet", "mustard", "cream"],
    "expression": "cheeky grin with visible tongue tip",
    "voice": {
      "character_description": "bright playful child voice with slight lisp, mischievous cadence",
      "clips": {
        "phoneme": "Thhh /θ/",
        "example_1": "thumb",
        "example_2": "thunder",
        "example_3": "thorn",
        "greet": "Thhh! Show me if you can make my sound!",
        "encourage": "Nice! Feel the air on your tongue?",
        "gentle_retry": "Keep the tongue out. Try again.",
        "friday_acknowledge": "Perfect! Now I am yours, friend."
      }
    }
  },
  {
    "id": "f",
    "grapheme": "f",
    "ipa": "/f/",
    "personality": "windy breath spirit",
    "sound_gesture": "upper teeth resting on lower lip, blowing a soft breeze",
    "word_decor": ["koi-fish tail fin", "round paper fan in one paw", "soft feather on one ear"],
    "palette": ["sky-blue", "white", "peach"],
    "expression": "calm soft smile, closed eyes like meditating",
    "voice": {
      "character_description": "gentle airy voice, older wiser than the others, calm cadence",
      "clips": {
        "phoneme": "Ffff /f/",
        "example_1": "fish",
        "example_2": "fan",
        "example_3": "feather",
        "greet": "Ffff. Breathe softly, little one.",
        "encourage": "Yes. Let the wind out.",
        "gentle_retry": "Light breath. Feel your top teeth.",
        "friday_acknowledge": "You carry my breath now. I am with you."
      }
    }
  },
  {
    "id": "r",
    "grapheme": "r",
    "ipa": "/r/",
    "personality": "tiger-cub rumble yokai",
    "sound_gesture": "tongue curled back, low growl pose, fists on hips",
    "word_decor": ["rabbit-ear hood with one bent tip", "rainbow scarf", "tiny rocket-fin boots"],
    "palette": ["crimson", "saffron", "cobalt"],
    "expression": "confident grin baring small fangs",
    "voice": {
      "character_description": "raspy bright child voice with rolled r, energetic, slightly barky",
      "clips": {
        "phoneme": "Rrrr /r/",
        "example_1": "rabbit",
        "example_2": "rainbow",
        "example_3": "rocket",
        "greet": "Rrrr! Are you brave enough to roar my sound?",
        "encourage": "Roar! That was real!",
        "gentle_retry": "Curl your tongue up and back. One more.",
        "friday_acknowledge": "You earned my roar. Carry it proudly."
      }
    }
  },
  {
    "id": "short_a",
    "grapheme": "a",
    "ipa": "/æ/",
    "personality": "wide-mouth surprise yokai",
    "sound_gesture": "mouth dropped wide open, eyes big, hands up as if astonished",
    "word_decor": ["apple-shaped hat with a leaf", "ant-antenna headband", "tiny wooden axe prop"],
    "palette": ["apple-red", "leaf-green", "cream"],
    "expression": "surprised wonder, mouth wide, eyebrows up",
    "voice": {
      "character_description": "expressive exclamatory child voice, drawn-out vowels, always sounding amazed",
      "clips": {
        "phoneme": "Aaah /æ/",
        "example_1": "apple",
        "example_2": "ant",
        "example_3": "axe",
        "greet": "Aaah! What a strong voice! Can you say my sound?",
        "encourage": "Aaamazing! Open wide!",
        "gentle_retry": "Drop your jaw. Big open mouth.",
        "friday_acknowledge": "Aaah! You mastered me. I am yours!"
      }
    }
  }
]
```

- [ ] **Step 2: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json
git commit -m "feat(core): bundle placeholder YokaiCatalog for MVP five"
```

### Task R1.3: YokaiCatalogLoader

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalogLoader.swift`
- Modify: `Packages/MoraCore/Package.swift` (add `Resources` declaration to target)
- Test: `Packages/MoraCore/Tests/MoraCoreTests/YokaiCatalogLoaderTests.swift`

- [ ] **Step 1: Update Package.swift to include Resources**

Find the `.target(name: "MoraCore", ...)` block. It currently has no `resources:` argument. Change it to:

```swift
.target(
    name: "MoraCore",
    resources: [.process("Resources"), .copy("Yokai/YokaiCatalog.json")],
    swiftSettings: [.swiftLanguageMode(.v5)]
),
```

Note: `Yokai/YokaiCatalog.json` is copied rather than processed so the JSON stays byte-exact. `Resources/` is processed (handles the Yokai portraits/voice once R4 lands).

- [ ] **Step 2: Write the failing test**

```swift
// YokaiCatalogLoaderTests.swift
import Testing
@testable import MoraCore

@Suite("YokaiCatalogLoader")
struct YokaiCatalogLoaderTests {
    @Test("loads the bundled five-yokai catalog")
    func loadsBundled() throws {
        let loader = YokaiCatalogLoader.bundled()
        let catalog = try loader.load()
        #expect(catalog.count == 5)
        let ids = Set(catalog.map(\.id))
        #expect(ids == ["sh", "th", "f", "r", "short_a"])
    }

    @Test("finds yokai by id")
    func findsById() throws {
        let catalog = try YokaiCatalogLoader.bundled().load()
        let sh = catalog.first { $0.id == "sh" }
        #expect(sh?.grapheme == "sh")
        #expect(sh?.ipa == "/ʃ/")
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```sh
(cd Packages/MoraCore && swift test --filter YokaiCatalogLoaderTests)
```

Expected: FAIL with "cannot find 'YokaiCatalogLoader'".

- [ ] **Step 4: Implement YokaiCatalogLoader**

```swift
// Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalogLoader.swift
import Foundation

public struct YokaiCatalogLoader: Sendable {
    private let source: () throws -> Data

    public init(source: @escaping () throws -> Data) {
        self.source = source
    }

    public static func bundled(bundle: Bundle = .module) -> YokaiCatalogLoader {
        YokaiCatalogLoader {
            guard let url = bundle.url(forResource: "YokaiCatalog", withExtension: "json") else {
                throw YokaiCatalogError.resourceMissing
            }
            return try Data(contentsOf: url)
        }
    }

    public func load() throws -> [YokaiDefinition] {
        let data = try source()
        return try JSONDecoder().decode([YokaiDefinition].self, from: data)
    }
}

public enum YokaiCatalogError: Error, Equatable {
    case resourceMissing
}
```

- [ ] **Step 5: Run test to verify it passes**

```sh
(cd Packages/MoraCore && swift test --filter YokaiCatalogLoaderTests)
```

Expected: PASS (all two cases).

- [ ] **Step 6: Commit**

```sh
git add Packages/MoraCore/Package.swift \
        Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalogLoader.swift \
        Packages/MoraCore/Tests/MoraCoreTests/YokaiCatalogLoaderTests.swift
git commit -m "feat(core): YokaiCatalogLoader reads bundled catalog"
```

### Task R1.4: YokaiEncounterEntity + state enum

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/YokaiEncounterState.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/YokaiEncounterEntity.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Persistence/YokaiEncounterEntityTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// YokaiEncounterEntityTests.swift
import Testing
import SwiftData
@testable import MoraCore

@MainActor
@Suite("YokaiEncounterEntity")
struct YokaiEncounterEntityTests {
    @Test("persists and retrieves an encounter")
    func persists() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let monday = Date(timeIntervalSince1970: 1_746_403_200) // 2025-05-05 UTC — some Monday
        let encounter = YokaiEncounterEntity(
            yokaiID: "sh",
            weekStart: monday,
            state: .active,
            friendshipPercent: 0.1,
            correctReadCount: 0,
            sessionCompletionCount: 0,
            befriendedAt: nil,
            storedRolloverFlag: false
        )
        ctx.insert(encounter)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.yokaiID == "sh")
        #expect(fetched.first?.state == .active)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```sh
(cd Packages/MoraCore && swift test --filter YokaiEncounterEntityTests)
```

Expected: FAIL (type not found).

- [ ] **Step 3: Create state enum**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/YokaiEncounterState.swift
import Foundation

public enum YokaiEncounterState: String, Codable, CaseIterable, Sendable {
    case upcoming
    case active
    case befriended
    case carryover
}
```

- [ ] **Step 4: Create @Model entity**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/YokaiEncounterEntity.swift
import Foundation
import SwiftData

@Model
public final class YokaiEncounterEntity {
    public var id: UUID
    public var yokaiID: String
    public var weekStart: Date
    public var stateRaw: String
    public var friendshipPercent: Double
    public var correctReadCount: Int
    public var sessionCompletionCount: Int
    public var befriendedAt: Date?
    public var storedRolloverFlag: Bool

    public var state: YokaiEncounterState {
        get { YokaiEncounterState(rawValue: stateRaw) ?? .upcoming }
        set { stateRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        yokaiID: String,
        weekStart: Date,
        state: YokaiEncounterState,
        friendshipPercent: Double = 0.0,
        correctReadCount: Int = 0,
        sessionCompletionCount: Int = 0,
        befriendedAt: Date? = nil,
        storedRolloverFlag: Bool = false
    ) {
        self.id = id
        self.yokaiID = yokaiID
        self.weekStart = weekStart
        self.stateRaw = state.rawValue
        self.friendshipPercent = friendshipPercent
        self.correctReadCount = correctReadCount
        self.sessionCompletionCount = sessionCompletionCount
        self.befriendedAt = befriendedAt
        self.storedRolloverFlag = storedRolloverFlag
    }
}
```

SwiftData requires storing the state as `stateRaw: String` rather than directly as `YokaiEncounterState`; exposing `state` via computed property preserves the clean API while remaining schema-stable. This matches how other Mora entities encode enums (e.g. `SessionSummaryEntity.sessionType: String`).

- [ ] **Step 5: Register the entity in MoraModelContainer**

Modify `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift`. Find the schema array and append `YokaiEncounterEntity.self`:

```swift
public static let schema = Schema([
    LearnerEntity.self,
    SkillEntity.self,
    SessionSummaryEntity.self,
    PerformanceEntity.self,
    LearnerProfile.self,
    DailyStreak.self,
    PronunciationTrialLog.self,
    YokaiEncounterEntity.self,          // <— added
])
```

- [ ] **Step 6: Run test to verify it passes**

```sh
(cd Packages/MoraCore && swift test --filter YokaiEncounterEntityTests)
```

Expected: PASS.

- [ ] **Step 7: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/Persistence/YokaiEncounterState.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/YokaiEncounterEntity.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift \
        Packages/MoraCore/Tests/MoraCoreTests/Persistence/YokaiEncounterEntityTests.swift
git commit -m "feat(core): YokaiEncounterEntity SwiftData model"
```

### Task R1.5: BestiaryEntryEntity

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/BestiaryEntryEntity.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Persistence/BestiaryEntryEntityTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// BestiaryEntryEntityTests.swift
import Testing
import SwiftData
@testable import MoraCore

@MainActor
@Suite("BestiaryEntryEntity")
struct BestiaryEntryEntityTests {
    @Test("records a befriended yokai")
    func records() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let entry = BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date(timeIntervalSince1970: 0))
        ctx.insert(entry)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.yokaiID == "sh")
        #expect(fetched.first?.playbackCount == 0)
    }

    @Test("increments playback count")
    func incrementsPlayback() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let entry = BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date())
        ctx.insert(entry)
        entry.playbackCount += 1
        entry.lastPlayedAt = Date()
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>()).first
        #expect(fetched?.playbackCount == 1)
        #expect(fetched?.lastPlayedAt != nil)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Expected: FAIL.

- [ ] **Step 3: Implement entity**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/BestiaryEntryEntity.swift
import Foundation
import SwiftData

@Model
public final class BestiaryEntryEntity {
    public var id: UUID
    public var yokaiID: String
    public var befriendedAt: Date
    public var playbackCount: Int
    public var lastPlayedAt: Date?

    public init(
        id: UUID = UUID(),
        yokaiID: String,
        befriendedAt: Date,
        playbackCount: Int = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.id = id
        self.yokaiID = yokaiID
        self.befriendedAt = befriendedAt
        self.playbackCount = playbackCount
        self.lastPlayedAt = lastPlayedAt
    }
}
```

- [ ] **Step 4: Register in schema**

Add `BestiaryEntryEntity.self,` to the schema array in `MoraModelContainer.swift`.

- [ ] **Step 5: Run test to verify pass**

```sh
(cd Packages/MoraCore && swift test --filter BestiaryEntryEntityTests)
```

Expected: PASS.

- [ ] **Step 6: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/Persistence/BestiaryEntryEntity.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift \
        Packages/MoraCore/Tests/MoraCoreTests/Persistence/BestiaryEntryEntityTests.swift
git commit -m "feat(core): BestiaryEntryEntity SwiftData model"
```

### Task R1.6: YokaiCameoEntity (local-only)

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/YokaiCameoEntity.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Persistence/YokaiCameoEntityTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// YokaiCameoEntityTests.swift
import Testing
import SwiftData
@testable import MoraCore

@MainActor
@Suite("YokaiCameoEntity")
struct YokaiCameoEntityTests {
    @Test("logs a cameo with outcome")
    func logs() async throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let sid = UUID()
        let cameo = YokaiCameoEntity(
            yokaiID: "sh",
            sessionID: sid,
            triggeredAt: Date(),
            pronunciationSuccess: true
        )
        ctx.insert(cameo)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<YokaiCameoEntity>()).first
        #expect(fetched?.yokaiID == "sh")
        #expect(fetched?.sessionID == sid)
        #expect(fetched?.pronunciationSuccess == true)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

Expected: FAIL.

- [ ] **Step 3: Implement entity**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/YokaiCameoEntity.swift
import Foundation
import SwiftData

/// Local-only cameo log. Not synced via CloudKit (matches `PerformanceEntity` policy
/// in the canonical spec §13).
@Model
public final class YokaiCameoEntity {
    public var id: UUID
    public var yokaiID: String
    public var sessionID: UUID
    public var triggeredAt: Date
    public var pronunciationSuccess: Bool

    public init(
        id: UUID = UUID(),
        yokaiID: String,
        sessionID: UUID,
        triggeredAt: Date,
        pronunciationSuccess: Bool
    ) {
        self.id = id
        self.yokaiID = yokaiID
        self.sessionID = sessionID
        self.triggeredAt = triggeredAt
        self.pronunciationSuccess = pronunciationSuccess
    }
}
```

- [ ] **Step 4: Register + test + commit**

```sh
# add YokaiCameoEntity.self to schema in MoraModelContainer.swift
(cd Packages/MoraCore && swift test --filter YokaiCameoEntityTests)
# expect PASS
git add Packages/MoraCore/Sources/MoraCore/Persistence/YokaiCameoEntity.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift \
        Packages/MoraCore/Tests/MoraCoreTests/Persistence/YokaiCameoEntityTests.swift
git commit -m "feat(core): YokaiCameoEntity local-only model"
```

### Task R1.7: MoraModelContainerSchema test covers new entities

**Files:**
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/MoraModelContainerSchemaTests.swift`

- [ ] **Step 1: Extend schema test**

Locate the existing schema-assertion test. Add:

```swift
@Test("schema includes yokai models")
func schemaIncludesYokai() {
    let names = MoraModelContainer.schema.entities.map(\.name)
    #expect(names.contains("YokaiEncounterEntity"))
    #expect(names.contains("BestiaryEntryEntity"))
    #expect(names.contains("YokaiCameoEntity"))
}
```

- [ ] **Step 2: Run test**

```sh
(cd Packages/MoraCore && swift test --filter MoraModelContainerSchemaTests)
```

Expected: PASS.

- [ ] **Step 3: Commit**

```sh
git add Packages/MoraCore/Tests/MoraCoreTests/MoraModelContainerSchemaTests.swift
git commit -m "test(core): assert yokai entities registered in schema"
```

### Task R1.8: YokaiStore protocol

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiStore.swift`

- [ ] **Step 1: Write the protocol (no tests yet — implementations are tested next)**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiStore.swift
import Foundation
import MoraCore

public protocol YokaiStore: Sendable {
    /// All yokai defined in the bundled catalog.
    func catalog() -> [YokaiDefinition]

    /// Resource URL for the yokai's portrait PNG. Returns `nil` if the asset
    /// is not yet bundled (placeholder phase R2).
    func portraitURL(for id: String) -> URL?

    /// Resource URL for a yokai voice clip. Returns `nil` if the asset is
    /// not yet bundled.
    func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL?
}
```

- [ ] **Step 2: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiStore.swift
git commit -m "feat(engines): YokaiStore protocol"
```

### Task R1.9: BundledYokaiStore (concrete impl)

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/BundledYokaiStore.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/BundledYokaiStoreTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// BundledYokaiStoreTests.swift
import Testing
@testable import MoraEngines
@testable import MoraCore

@Suite("BundledYokaiStore")
struct BundledYokaiStoreTests {
    @Test("returns five yokai from the bundled catalog")
    func catalogHasFive() throws {
        let store = try BundledYokaiStore()
        #expect(store.catalog().count == 5)
    }

    @Test("portraitURL is nil when asset missing (pre-R4 placeholder phase)")
    func portraitNilWhenAbsent() throws {
        let store = try BundledYokaiStore()
        // R4 ships portraits; until then URLs are nil and UI falls back to placeholders.
        #expect(store.portraitURL(for: "sh") == nil)
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```sh
(cd Packages/MoraEngines && swift test --filter BundledYokaiStoreTests)
```

Expected: FAIL.

- [ ] **Step 3: Implement BundledYokaiStore**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/BundledYokaiStore.swift
import Foundation
import MoraCore

public final class BundledYokaiStore: YokaiStore {
    private let definitions: [YokaiDefinition]
    private let bundle: Bundle

    public init(bundle: Bundle = .module, loader: YokaiCatalogLoader? = nil) throws {
        self.bundle = bundle
        let actualLoader = loader ?? YokaiCatalogLoader.bundled(bundle: .module /* MoraCore */ )
        self.definitions = try actualLoader.load()
    }

    public func catalog() -> [YokaiDefinition] { definitions }

    public func portraitURL(for id: String) -> URL? {
        // Assets live in MoraCore's resource bundle under Resources/Yokai/<id>/portrait.png.
        // Bundle.module here is MoraEngines' — we resolve via MoraCore.Bundle.module
        // by using a tiny helper at the MoraCore side. For now, check MoraCore bundle.
        let core = Bundle(for: _MoraCoreBundleToken.self)
        return core.url(forResource: "portrait", withExtension: "png", subdirectory: "Yokai/\(id)")
    }

    public func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL? {
        let core = Bundle(for: _MoraCoreBundleToken.self)
        return core.url(forResource: clip.rawValue, withExtension: "m4a", subdirectory: "Yokai/\(id)/voice")
    }
}

// Class-based bundle token so `Bundle(for:)` resolves to MoraCore's resource bundle.
final class _MoraCoreBundleToken {}
```

Wait — `_MoraCoreBundleToken` is declared in MoraEngines, so `Bundle(for:)` would resolve to MoraEngines. We actually need a public token in MoraCore. Adjust:

- [ ] **Step 3a: Add a public token in MoraCore**

Create `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiResourceAnchor.swift`:

```swift
// Packages/MoraCore/Sources/MoraCore/Yokai/YokaiResourceAnchor.swift
import Foundation

/// Anchor class whose module-resolution lets consumers locate the MoraCore
/// resource bundle from outside the package.
public final class YokaiResourceAnchor {
    public static var bundle: Bundle { Bundle(for: YokaiResourceAnchor.self) }
}
```

- [ ] **Step 3b: Rewrite BundledYokaiStore to use the anchor**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/BundledYokaiStore.swift
import Foundation
import MoraCore

public final class BundledYokaiStore: YokaiStore {
    private let definitions: [YokaiDefinition]
    private let resourceBundle: Bundle

    public init(loader: YokaiCatalogLoader? = nil, resourceBundle: Bundle? = nil) throws {
        let actualBundle = resourceBundle ?? YokaiResourceAnchor.bundle
        self.resourceBundle = actualBundle
        let actualLoader = loader ?? YokaiCatalogLoader.bundled(bundle: actualBundle)
        self.definitions = try actualLoader.load()
    }

    public func catalog() -> [YokaiDefinition] { definitions }

    public func portraitURL(for id: String) -> URL? {
        resourceBundle.url(forResource: "portrait", withExtension: "png", subdirectory: "Yokai/\(id)")
    }

    public func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL? {
        resourceBundle.url(forResource: clip.rawValue, withExtension: "m4a", subdirectory: "Yokai/\(id)/voice")
    }
}
```

- [ ] **Step 4: Run test to verify PASS**

```sh
(cd Packages/MoraEngines && swift test --filter BundledYokaiStoreTests)
```

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraCore/Sources/MoraCore/Yokai/YokaiResourceAnchor.swift \
        Packages/MoraEngines/Sources/MoraEngines/Yokai/BundledYokaiStore.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/BundledYokaiStoreTests.swift
git commit -m "feat(engines): BundledYokaiStore via MoraCore resource anchor"
```

### Task R1.10: FakeYokaiStore + fixtures

**Files:**
- Create: `Packages/MoraTesting/Sources/MoraTesting/YokaiFixtures.swift`
- Create: `Packages/MoraTesting/Sources/MoraTesting/FakeYokaiStore.swift`

- [ ] **Step 1: Write fixtures**

```swift
// Packages/MoraTesting/Sources/MoraTesting/YokaiFixtures.swift
import Foundation
import MoraCore

public enum YokaiFixtures {
    public static let shDefinition = YokaiDefinition(
        id: "sh", grapheme: "sh", ipa: "/ʃ/",
        personality: "mischievous whisper",
        soundGesture: "finger to lips",
        wordDecor: ["sailor hat", "seashell ears", "fin tail"],
        palette: ["teal", "cream"],
        expression: "smirk",
        voice: .init(
            characterDescription: "young whispery",
            clips: [
                .phoneme: "Shhh",
                .example1: "ship", .example2: "shop", .example3: "shell",
                .greet: "Hello", .encourage: "Nice",
                .gentleRetry: "Again", .fridayAcknowledge: "Yours"
            ]
        )
    )

    public static let smallCatalog: [YokaiDefinition] = [shDefinition]
}
```

Wait — `YokaiDefinition` doesn't have a memberwise public initializer (it's synthesized, but all stored properties are `let` so the compiler-synthesized init is internal). Add a public init.

- [ ] **Step 1a: Add public init to YokaiDefinition**

Edit `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiDefinition.swift` and add inside `struct YokaiDefinition`:

```swift
public init(
    id: String,
    grapheme: String,
    ipa: String,
    personality: String,
    soundGesture: String,
    wordDecor: [String],
    palette: [String],
    expression: String,
    voice: Voice
) {
    self.id = id
    self.grapheme = grapheme
    self.ipa = ipa
    self.personality = personality
    self.soundGesture = soundGesture
    self.wordDecor = wordDecor
    self.palette = palette
    self.expression = expression
    self.voice = voice
}
```

And inside `struct Voice`:

```swift
public init(characterDescription: String, clips: [YokaiClipKey: String]) {
    self.characterDescription = characterDescription
    self.clips = clips
}
```

- [ ] **Step 2: Write FakeYokaiStore**

```swift
// Packages/MoraTesting/Sources/MoraTesting/FakeYokaiStore.swift
import Foundation
import MoraCore
import MoraEngines

public final class FakeYokaiStore: YokaiStore, @unchecked Sendable {
    public var definitions: [YokaiDefinition]
    public var portraitURLs: [String: URL] = [:]
    public var clipURLs: [String: [YokaiClipKey: URL]] = [:]

    public init(definitions: [YokaiDefinition] = YokaiFixtures.smallCatalog) {
        self.definitions = definitions
    }

    public func catalog() -> [YokaiDefinition] { definitions }

    public func portraitURL(for id: String) -> URL? { portraitURLs[id] }

    public func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL? {
        clipURLs[id]?[clip]
    }
}
```

- [ ] **Step 3: Build and commit**

```sh
(cd Packages/MoraTesting && swift build)
git add Packages/MoraCore/Sources/MoraCore/Yokai/YokaiDefinition.swift \
        Packages/MoraTesting/Sources/MoraTesting/YokaiFixtures.swift \
        Packages/MoraTesting/Sources/MoraTesting/FakeYokaiStore.swift
git commit -m "feat(testing): FakeYokaiStore + fixture helpers"
```

### Task R1.11: YokaiCutscene + YokaiOrchestrator skeleton

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiCutscene.swift`
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`

- [ ] **Step 1: Define cutscene enum**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiCutscene.swift
import Foundation

public enum YokaiCutscene: Equatable, Sendable {
    case mondayIntro(yokaiID: String)
    case sessionStart(yokaiID: String)   // 3–4s cameo at start of Tue–Fri
    case fridayClimax(yokaiID: String)
    case srsCameo(yokaiID: String)
}
```

- [ ] **Step 2: Define orchestrator skeleton (no logic yet)**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift
import Foundation
import MoraCore
import Observation
import SwiftData

@Observable
@MainActor
public final class YokaiOrchestrator {
    public private(set) var currentEncounter: YokaiEncounterEntity?
    public private(set) var currentYokai: YokaiDefinition?
    public private(set) var activeCutscene: YokaiCutscene?

    private let store: YokaiStore
    private let modelContext: ModelContext
    private let calendar: Calendar

    public init(
        store: YokaiStore,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.modelContext = modelContext
        self.calendar = calendar
    }

    public func dismissCutscene() { activeCutscene = nil }
}
```

- [ ] **Step 3: Build to verify compile cleanly**

```sh
(cd Packages/MoraEngines && swift build)
```

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiCutscene.swift \
        Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift
git commit -m "feat(engines): YokaiOrchestrator skeleton + cutscene enum"
```

### Task R1.12: Friendship meter math (pure helpers)

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Yokai/FriendshipMeterMath.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/FriendshipMeterMathTests.swift`

Rationale: separate the numeric rules (+2% / +5% / 25% day cap / floor boost) from orchestrator state so they can be unit-tested in isolation.

- [ ] **Step 1: Write failing tests covering all rules**

```swift
// FriendshipMeterMathTests.swift
import Testing
@testable import MoraEngines

@Suite("FriendshipMeterMath")
struct FriendshipMeterMathTests {
    @Test("correct trial adds 2 percentage points")
    func correctAddsTwo() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.10, correct: true, dayGainSoFar: 0.0)
        #expect(after.percent == 0.12)
        #expect(after.dayGain == 0.02)
    }

    @Test("missed trial leaves percent unchanged")
    func missedUnchanged() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.10, correct: false, dayGainSoFar: 0.0)
        #expect(after.percent == 0.10)
        #expect(after.dayGain == 0.0)
    }

    @Test("day gain cap at 25 percent halts further credit")
    func dayCap() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.50, correct: true, dayGainSoFar: 0.25)
        #expect(after.percent == 0.50) // cap reached before
        #expect(after.dayGain == 0.25)
    }

    @Test("session completion bonus adds 5pp within day cap")
    func sessionCompletion() {
        let after = FriendshipMeterMath.applySessionCompletion(percent: 0.30, dayGainSoFar: 0.15)
        #expect(after.percent == 0.35)
        #expect(after.dayGain == 0.20)
    }

    @Test("session completion respects day cap")
    func sessionCompletionClamped() {
        let after = FriendshipMeterMath.applySessionCompletion(percent: 0.40, dayGainSoFar: 0.22)
        // only 3pp of the 5pp bonus fits before the 25pp day cap
        #expect(abs(after.percent - 0.43) < 1e-9)
        #expect(abs(after.dayGain - 0.25) < 1e-9)
    }

    @Test("percent is clamped to [0, 1]")
    func clamped() {
        let after = FriendshipMeterMath.applyTrialOutcome(percent: 0.99, correct: true, dayGainSoFar: 0.0)
        #expect(after.percent == 1.0)
    }

    @Test("floor boost lifts final-Friday trial toward 100")
    func floorBoost() {
        // Under-performing week: Friday with 60% at trial 6 of 10 should weight remaining trials.
        let boost = FriendshipMeterMath.floorBoostWeight(
            currentPercent: 0.60,
            trialsRemaining: 4
        )
        // Each remaining trial must contribute >= (100 - 60) / 4 = 10pp to guarantee 100% floor.
        #expect(boost >= 0.10)
    }
}
```

- [ ] **Step 2: Run to confirm FAIL**

Expected: FAIL.

- [ ] **Step 3: Implement math helpers**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Yokai/FriendshipMeterMath.swift
import Foundation

public enum FriendshipMeterMath {
    public static let correctTrialGain: Double = 0.02
    public static let sessionCompletionBonus: Double = 0.05
    public static let perDayCap: Double = 0.25

    public struct Result: Equatable, Sendable {
        public let percent: Double
        public let dayGain: Double
    }

    public static func applyTrialOutcome(
        percent: Double,
        correct: Bool,
        dayGainSoFar: Double
    ) -> Result {
        guard correct else { return Result(percent: percent, dayGain: dayGainSoFar) }
        let remainingDay = max(0, perDayCap - dayGainSoFar)
        let gain = min(correctTrialGain, remainingDay)
        let next = clamp(percent + gain)
        return Result(percent: next, dayGain: dayGainSoFar + gain)
    }

    public static func applySessionCompletion(
        percent: Double,
        dayGainSoFar: Double
    ) -> Result {
        let remainingDay = max(0, perDayCap - dayGainSoFar)
        let gain = min(sessionCompletionBonus, remainingDay)
        let next = clamp(percent + gain)
        return Result(percent: next, dayGain: dayGainSoFar + gain)
    }

    /// Per-trial gain magnitude that would guarantee the Friday floor of 100%
    /// given `trialsRemaining` trials in the Friday session.
    public static func floorBoostWeight(currentPercent: Double, trialsRemaining: Int) -> Double {
        guard trialsRemaining > 0 else { return 0 }
        let deficit = max(0, 1.0 - currentPercent)
        return deficit / Double(trialsRemaining)
    }

    private static func clamp(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
}
```

- [ ] **Step 4: Run tests to PASS**

```sh
(cd Packages/MoraEngines && swift test --filter FriendshipMeterMathTests)
```

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Yokai/FriendshipMeterMath.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/FriendshipMeterMathTests.swift
git commit -m "feat(engines): FriendshipMeterMath with day cap + floor boost"
```

### Task R1.13: Orchestrator — trial outcome wiring

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorMeterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// YokaiOrchestratorMeterTests.swift
import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — meter")
struct YokaiOrchestratorMeterTests {
    func makeSubject() throws -> (YokaiOrchestrator, ModelContext) {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let store = FakeYokaiStore()
        let orch = YokaiOrchestrator(store: store, modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date(timeIntervalSince1970: 1_746_403_200))
        return (orch, ctx)
    }

    @Test("starts the week at 10% (greeting bonus)")
    func startsAtTen() throws {
        let (orch, _) = try makeSubject()
        #expect(orch.currentEncounter?.friendshipPercent == 0.10)
    }

    @Test("correct trial adds 2pp")
    func correctAddsTwo() throws {
        let (orch, _) = try makeSubject()
        orch.recordTrialOutcome(correct: true)
        #expect(orch.currentEncounter?.friendshipPercent == 0.12)
    }

    @Test("missed trial leaves meter unchanged")
    func missedUnchanged() throws {
        let (orch, _) = try makeSubject()
        orch.recordTrialOutcome(correct: false)
        #expect(orch.currentEncounter?.friendshipPercent == 0.10)
    }

    @Test("day cap stops further credit within a single day")
    func dayCap() throws {
        let (orch, _) = try makeSubject()
        // 13 correct trials -> would be 26pp, but day cap 25pp halts at index 12.
        for _ in 0..<13 { orch.recordTrialOutcome(correct: true) }
        #expect(orch.currentEncounter?.friendshipPercent == 0.10 + 0.25)
    }
}
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement `startWeek` + `recordTrialOutcome`**

Edit `YokaiOrchestrator.swift`:

```swift
private var dayGainSoFar: Double = 0

public func startWeek(yokaiID: String, weekStart: Date) throws {
    guard let yokai = store.catalog().first(where: { $0.id == yokaiID }) else { return }
    currentYokai = yokai
    let encounter = YokaiEncounterEntity(
        yokaiID: yokaiID,
        weekStart: weekStart,
        state: .active,
        friendshipPercent: 0.10
    )
    modelContext.insert(encounter)
    try modelContext.save()
    currentEncounter = encounter
    activeCutscene = .mondayIntro(yokaiID: yokaiID)
    dayGainSoFar = 0
}

public func recordTrialOutcome(correct: Bool) {
    guard let encounter = currentEncounter else { return }
    let result = FriendshipMeterMath.applyTrialOutcome(
        percent: encounter.friendshipPercent,
        correct: correct,
        dayGainSoFar: dayGainSoFar
    )
    encounter.friendshipPercent = result.percent
    dayGainSoFar = result.dayGain
    if correct { encounter.correctReadCount += 1 }
}

public func beginDay() {
    dayGainSoFar = 0
}
```

- [ ] **Step 4: Run tests → PASS**

- [ ] **Step 5: Commit**

```sh
git commit -am "feat(engines): YokaiOrchestrator trial-outcome wiring"
```

### Task R1.14: Session completion bonus + day reset

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorSessionBonusTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// YokaiOrchestratorSessionBonusTests.swift
import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — session bonus + day reset")
struct YokaiOrchestratorSessionBonusTests {
    @Test("completing a session adds 5pp")
    func sessionBonus() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.recordSessionCompletion()
        #expect(orch.currentEncounter?.friendshipPercent == 0.15)
        #expect(orch.currentEncounter?.sessionCompletionCount == 1)
    }

    @Test("beginDay resets per-day cap tracking")
    func beginDayResets() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        for _ in 0..<13 { orch.recordTrialOutcome(correct: true) }
        // day cap hit at +25pp -> 0.35
        #expect(orch.currentEncounter?.friendshipPercent == 0.35)

        orch.beginDay()
        orch.recordTrialOutcome(correct: true)
        // new day: 2pp added
        #expect(orch.currentEncounter?.friendshipPercent == 0.37)
    }
}
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement `recordSessionCompletion`**

Add to `YokaiOrchestrator`:

```swift
public func recordSessionCompletion() {
    guard let encounter = currentEncounter else { return }
    let result = FriendshipMeterMath.applySessionCompletion(
        percent: encounter.friendshipPercent,
        dayGainSoFar: dayGainSoFar
    )
    encounter.friendshipPercent = result.percent
    dayGainSoFar = result.dayGain
    encounter.sessionCompletionCount += 1
}
```

- [ ] **Step 4: Run → PASS**

- [ ] **Step 5: Commit**

```sh
git commit -am "feat(engines): session-completion bonus + per-day reset"
```

### Task R1.15: State machine — befriend on Friday final trial

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorStateTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// YokaiOrchestratorStateTests.swift
import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — state machine")
struct YokaiOrchestratorStateTests {
    @Test("Friday final-trial meter at 100 produces BestiaryEntry and .befriended state")
    func befriendsOnFriday() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.98   // pre-seeded for test
        orch.recordFridayFinalTrial(correct: true)        // triggers befriending check
        #expect(orch.currentEncounter?.state == .befriended)
        #expect(orch.activeCutscene == .fridayClimax(yokaiID: "sh"))
        let entries = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        #expect(entries.count == 1)
        #expect(entries.first?.yokaiID == "sh")
    }

    @Test("Friday with under-performing week triggers floor boost and befriends")
    func floorBoost() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.60   // still low entering Friday
        orch.beginFridaySession(trialsPlanned: 4)
        for _ in 0..<3 { orch.recordTrialOutcome(correct: true) }
        orch.recordFridayFinalTrial(correct: true)
        #expect(orch.currentEncounter?.friendshipPercent == 1.0)
        #expect(orch.currentEncounter?.state == .befriended)
    }

    @Test("Friday missed final with no boost room -> carryover")
    func carryover() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        orch.currentEncounter?.friendshipPercent = 0.30
        orch.beginFridaySession(trialsPlanned: 4)
        orch.recordTrialOutcome(correct: false)
        orch.recordTrialOutcome(correct: false)
        orch.recordTrialOutcome(correct: false)
        orch.recordFridayFinalTrial(correct: false)
        #expect(orch.currentEncounter?.state == .carryover)
        let entries = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        #expect(entries.isEmpty)
    }
}
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement Friday handling**

Add to `YokaiOrchestrator`:

```swift
private var fridayTrialsRemaining: Int = 0

public func beginFridaySession(trialsPlanned: Int) {
    beginDay()
    fridayTrialsRemaining = trialsPlanned
}

public func recordFridayFinalTrial(correct: Bool) {
    guard let encounter = currentEncounter else { return }
    if correct, fridayTrialsRemaining >= 0 {
        let boost = FriendshipMeterMath.floorBoostWeight(
            currentPercent: encounter.friendshipPercent,
            trialsRemaining: max(1, fridayTrialsRemaining)
        )
        let effectiveGain = max(FriendshipMeterMath.correctTrialGain, boost)
        encounter.friendshipPercent = min(1.0, encounter.friendshipPercent + effectiveGain)
        encounter.correctReadCount += 1
    }
    fridayTrialsRemaining = max(0, fridayTrialsRemaining - 1)
    finalizeFridayIfNeeded()
}

private func finalizeFridayIfNeeded() {
    guard let encounter = currentEncounter, let yokai = currentYokai else { return }
    if encounter.friendshipPercent >= 1.0 - 1e-9 {
        encounter.state = .befriended
        encounter.befriendedAt = Date()
        let entry = BestiaryEntryEntity(yokaiID: yokai.id, befriendedAt: encounter.befriendedAt!)
        modelContext.insert(entry)
        try? modelContext.save()
        activeCutscene = .fridayClimax(yokaiID: yokai.id)
    } else {
        encounter.state = .carryover
        encounter.storedRolloverFlag = true
        try? modelContext.save()
    }
}
```

Also update `recordTrialOutcome` so that during Friday-final trials, callers use `recordFridayFinalTrial`, and ordinary Tue–Thu sessions use `recordTrialOutcome`. This distinction is explicit by API surface and keeps the floor-boost logic localized.

- [ ] **Step 4: Run → PASS**

- [ ] **Step 5: Commit**

```sh
git commit -am "feat(engines): Friday climax path — floor boost, befriend, carryover"
```

### Task R1.16: SRS cameo trigger

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiOrchestratorCameoTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// YokaiOrchestratorCameoTests.swift
import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — SRS cameo")
struct YokaiOrchestratorCameoTests {
    @Test("previously-befriended grapheme triggers cameo during review")
    func cameoTriggers() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        ctx.insert(BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date(timeIntervalSinceNow: -86_400)))
        try ctx.save()
        let sessionID = UUID()
        orch.maybeTriggerCameo(grapheme: "sh", sessionID: sessionID, pronunciationSuccess: true)
        #expect(orch.activeCutscene == .srsCameo(yokaiID: "sh"))
        let cameos = try ctx.fetch(FetchDescriptor<YokaiCameoEntity>())
        #expect(cameos.count == 1)
        #expect(cameos.first?.sessionID == sessionID)
        #expect(cameos.first?.pronunciationSuccess == true)
    }

    @Test("non-befriended grapheme does not cameo")
    func noCameoIfNotFriend() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        orch.maybeTriggerCameo(grapheme: "sh", sessionID: UUID(), pronunciationSuccess: true)
        #expect(orch.activeCutscene == nil)
    }

    @Test("cameo does not affect current meter")
    func cameoDoesNotAffectMeter() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())
        ctx.insert(BestiaryEntryEntity(yokaiID: "sh", befriendedAt: Date(timeIntervalSinceNow: -86_400)))
        let before = orch.currentEncounter!.friendshipPercent
        orch.maybeTriggerCameo(grapheme: "sh", sessionID: UUID(), pronunciationSuccess: true)
        #expect(orch.currentEncounter?.friendshipPercent == before)
    }
}
```

- [ ] **Step 2: Implement**

```swift
public func maybeTriggerCameo(grapheme: String, sessionID: UUID, pronunciationSuccess: Bool) {
    // Find a befriended yokai that matches this grapheme.
    let descriptor = FetchDescriptor<BestiaryEntryEntity>()
    guard let entries = try? modelContext.fetch(descriptor) else { return }
    guard let befriended = entries.first(where: { entry in
        store.catalog().first(where: { $0.id == entry.yokaiID })?.grapheme == grapheme
    }) else { return }
    let cameo = YokaiCameoEntity(
        yokaiID: befriended.yokaiID,
        sessionID: sessionID,
        triggeredAt: Date(),
        pronunciationSuccess: pronunciationSuccess
    )
    modelContext.insert(cameo)
    try? modelContext.save()
    activeCutscene = .srsCameo(yokaiID: befriended.yokaiID)
}
```

- [ ] **Step 3: Run → PASS + commit**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiOrchestratorCameoTests)
git commit -am "feat(engines): SRS cameo trigger for befriended yokai"
```

### Task R1.17: Golden-week integration test

**Files:**
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiGoldenWeekTests.swift`

- [ ] **Step 1: Write the test (no new code; wire-up only)**

```swift
// YokaiGoldenWeekTests.swift
import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — golden week")
struct YokaiGoldenWeekTests {
    @Test("five strong days befriend a yokai by Friday")
    func strongWeekBefriends() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        try orch.startWeek(yokaiID: "sh", weekStart: Date())

        // Mon already seeded to 10% via startWeek; explicit session complete.
        orch.recordSessionCompletion()
        orch.beginDay() // Tue
        for _ in 0..<10 { orch.recordTrialOutcome(correct: true) }
        orch.recordSessionCompletion()

        orch.beginDay() // Wed
        for _ in 0..<10 { orch.recordTrialOutcome(correct: true) }
        orch.recordSessionCompletion()

        orch.beginDay() // Thu
        for _ in 0..<10 { orch.recordTrialOutcome(correct: true) }
        orch.recordSessionCompletion()

        // Fri
        orch.beginFridaySession(trialsPlanned: 10)
        for _ in 0..<9 { orch.recordTrialOutcome(correct: true) }
        orch.recordFridayFinalTrial(correct: true)

        #expect(orch.currentEncounter?.state == .befriended)
        #expect(orch.currentEncounter?.friendshipPercent == 1.0)
        let entries = try ctx.fetch(FetchDescriptor<BestiaryEntryEntity>())
        #expect(entries.count == 1)
    }
}
```

- [ ] **Step 2: Run → PASS (should work given prior tasks) + commit**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiGoldenWeekTests)
git add Packages/MoraEngines/Tests/MoraEnginesTests/YokaiGoldenWeekTests.swift
git commit -m "test(engines): golden-week integration walk for YokaiOrchestrator"
```

### Task R1.18: SessionOrchestrator integration hook

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`

- [ ] **Step 1: Add optional yokai hook (backward compatible)**

Find the declaration line `public final class SessionOrchestrator {`. Add a stored property and constructor parameter:

```swift
public let yokai: YokaiOrchestrator?

public init(
    // ... existing parameters ...
    yokai: YokaiOrchestrator? = nil
) {
    // ... existing assignments ...
    self.yokai = yokai
}
```

- [ ] **Step 2: Forward trial outcomes where `AssessmentEngine` currently records correct/incorrect**

Find the site where `SessionOrchestrator` records a trial result (a call like `trials.append(...)` followed by updates). Immediately after, insert:

```swift
yokai?.recordTrialOutcome(correct: assessment.correct)
```

(Exact insertion line depends on current source; see file `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift` around the trial-recording block.)

- [ ] **Step 3: Build both packages**

```sh
(cd Packages/MoraCore && swift build)
(cd Packages/MoraEngines && swift build)
(cd Packages/MoraEngines && swift test)
```

All existing tests should still PASS (backward-compatible `nil` default).

- [ ] **Step 4: Commit**

```sh
git commit -am "feat(engines): SessionOrchestrator optionally drives YokaiOrchestrator"
```

### Task R1.19: Root project regen + xcodebuild smoke

**Files:**
- Regen: `Mora.xcodeproj` via `xcodegen generate`

- [ ] **Step 1: Inject development team, regen, and revert**

Per the repo's convention (memory: xcodegen team injection), prepend the team ID before running, then revert:

```sh
./scripts/xcodegen-with-team.sh   # if such a wrapper exists
# OR manually:
sed -i '' 's/^#  DEVELOPMENT_TEAM:.*/  DEVELOPMENT_TEAM: 2AFT9XT8R2/' project.yml
xcodegen generate
git checkout -- project.yml
```

- [ ] **Step 2: xcodebuild smoke**

```sh
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED. Warnings OK, errors NOT.

### Task R1.20: PR submission for R1

- [ ] **Step 1: Open PR**

Title: `feat(rpg): yokai core engine and SwiftData persistence`

Body:

```markdown
## Summary
- Adds `YokaiDefinition`, `YokaiClipKey`, `YokaiCatalogLoader` under MoraCore.
- Adds `YokaiEncounterEntity`, `BestiaryEntryEntity`, `YokaiCameoEntity` SwiftData models registered in `MoraModelContainer`.
- Adds `YokaiStore` protocol + `BundledYokaiStore` concrete impl and `FakeYokaiStore` in MoraTesting.
- Adds `YokaiOrchestrator` with friendship-meter math, state machine, and SRS cameo.
- `SessionOrchestrator` optionally forwards trial outcomes to `YokaiOrchestrator`; default = nil, fully backward-compatible.
- No UI, no assets.

## Test plan
- [ ] `(cd Packages/MoraCore && swift test)` green
- [ ] `(cd Packages/MoraEngines && swift test)` green
- [ ] `xcodebuild build` green (generic iOS Simulator, CODE_SIGNING_ALLOWED=NO)
- [ ] Schema still loads on-disk without migration errors (manual verify with `MoraModelContainer.onDisk()`)
- [ ] Manual play-through not required (no UI yet)

## Spec
`docs/superpowers/specs/2026-04-23-rpg-shell-yokai-design.md` §5, §6, §13.
```

---

## Phase R2: UI Shell (placeholder assets + TTS fallback)

**Merge criterion:** Session renders meter HUD and portrait overlay with placeholder assets; BestiaryView reachable from home; Reduce Motion respected; all tests green; `xcodebuild build` succeeds. No real yokai art.

### Task R2.1: Fallback assets (placeholder PNG + TTS voice)

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/_placeholder/portrait.png`
- Create: `Packages/MoraCore/Sources/MoraCore/Yokai/PlaceholderPortraitProvider.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/BundledYokaiStore.swift`

- [ ] **Step 1: Generate a placeholder PNG (blank white 1024×1024 with grapheme text)**

```sh
mkdir -p Packages/MoraCore/Sources/MoraCore/Resources/Yokai/_placeholder
# Use a small helper; or a pre-made 1024x1024 white PNG.
# A minimal 1x1 transparent PNG also works; SwiftUI will scale.
/usr/bin/printf '\x89PNG\r\n\x1a\n' > /tmp/placeholder.png
# Prefer: use sips to make a clean 1024x1024:
sips -s format png --resampleHeightWidth 1024 1024 --padToHeightWidth 1024 1024 \
   /System/Library/Desktop\ Pictures/Solid\ Colors/White.heic \
   --out Packages/MoraCore/Sources/MoraCore/Resources/Yokai/_placeholder/portrait.png 2>/dev/null || echo "fallback method required"
```

If `sips` is not appropriate, commit a 1024×1024 white PNG created in a drawing app. The placeholder is intentionally blank so the UI layout is visible without any branding assumptions.

- [ ] **Step 2: Teach BundledYokaiStore to fall back to placeholder**

Modify `portraitURL(for:)`:

```swift
public func portraitURL(for id: String) -> URL? {
    if let url = resourceBundle.url(forResource: "portrait", withExtension: "png", subdirectory: "Yokai/\(id)") {
        return url
    }
    return resourceBundle.url(forResource: "portrait", withExtension: "png", subdirectory: "Yokai/_placeholder")
}
```

For voice, return `nil` for missing clips; `YokaiPortraitCorner` (R2.4) falls back to `AVSpeechSynthesizer` playback of the clip text (pulled from `YokaiDefinition.voice.clips`).

- [ ] **Step 3: Build + commit**

```sh
(cd Packages/MoraEngines && swift build)
git add Packages/MoraCore/Sources/MoraCore/Resources/Yokai/_placeholder/portrait.png \
        Packages/MoraEngines/Sources/MoraEngines/Yokai/BundledYokaiStore.swift
git commit -m "chore(core): placeholder yokai portrait with store fallback"
```

### Task R2.2: YokaiLayerView (overlay root)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift`

- [ ] **Step 1: Write the view**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift
import SwiftUI
import MoraEngines

public struct YokaiLayerView: View {
    @Bindable var orchestrator: YokaiOrchestrator

    public init(orchestrator: YokaiOrchestrator) {
        self.orchestrator = orchestrator
    }

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
                        YokaiPortraitCorner(yokai: yokai)
                            .frame(width: 80, height: 80)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.top, 24)

                if orchestrator.activeCutscene != nil {
                    YokaiCutsceneOverlay(orchestrator: orchestrator)
                        .transition(.opacity)
                }
            }
        }
        .allowsHitTesting(orchestrator.activeCutscene != nil)
    }
}
```

- [ ] **Step 2: Build + commit**

```sh
(cd Packages/MoraUI && swift build)
git add Packages/MoraUI/Sources/MoraUI/Yokai/YokaiLayerView.swift
git commit -m "feat(ui): YokaiLayerView overlay root"
```

### Task R2.3: FriendshipGaugeHUD

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/FriendshipGaugeHUD.swift`

- [ ] **Step 1: Write the view**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/FriendshipGaugeHUD.swift
import SwiftUI

public struct FriendshipGaugeHUD: View {
    let percent: Double

    public init(percent: Double) { self.percent = percent }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(white: 0.94))
                RoundedRectangle(cornerRadius: 9)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.40, green: 0.75, blue: 0.70), Color(red: 0.55, green: 0.85, blue: 0.80)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * percent)
                    .animation(.easeOut(duration: 0.35), value: percent)
            }
            .overlay(
                Text("\(Int(round(percent * 100)))%")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8),
                alignment: .trailing
            )
            .accessibilityElement()
            .accessibilityLabel("Friendship")
            .accessibilityValue("\(Int(round(percent * 100))) percent")
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        FriendshipGaugeHUD(percent: 0.12).frame(width: 200, height: 18)
        FriendshipGaugeHUD(percent: 0.48).frame(width: 200, height: 18)
        FriendshipGaugeHUD(percent: 1.00).frame(width: 200, height: 18)
    }.padding()
}
```

- [ ] **Step 2: Build + commit**

```sh
(cd Packages/MoraUI && swift build)
git add Packages/MoraUI/Sources/MoraUI/Yokai/FriendshipGaugeHUD.swift
git commit -m "feat(ui): FriendshipGaugeHUD with animation and a11y"
```

### Task R2.4: YokaiPortraitCorner

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift`

- [ ] **Step 1: Write the view**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift
import SwiftUI
import MoraCore
import MoraEngines

public struct YokaiPortraitCorner: View {
    let yokai: YokaiDefinition
    @State private var pulse: Bool = false

    public init(yokai: YokaiDefinition) { self.yokai = yokai }

    public var body: some View {
        if let store = try? BundledYokaiStore(),
           let url = store.portraitURL(for: yokai.id),
           let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .scaleEffect(pulse ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
                .accessibilityLabel(Text("\(yokai.grapheme) yokai"))
        } else {
            Circle()
                .fill(Color(white: 0.85))
                .overlay(Text(yokai.grapheme).font(.title2).fontWeight(.bold))
        }
    }
}
```

Note: `UIImage(contentsOfFile:)` works only on iOS. For Mac Catalyst, the existing typealias patterns in the codebase apply (check how other views in `Packages/MoraUI/Sources/MoraUI/Session/` handle platform imaging; use `#if canImport(UIKit)` guard if needed).

- [ ] **Step 2: Build + commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift
git commit -m "feat(ui): YokaiPortraitCorner with idle-breath animation"
```

### Task R2.5: YokaiCutsceneOverlay (barebones)

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift`

- [ ] **Step 1: Write the view**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift
import SwiftUI
import MoraEngines

public struct YokaiCutsceneOverlay: View {
    @Bindable var orchestrator: YokaiOrchestrator

    public init(orchestrator: YokaiOrchestrator) {
        self.orchestrator = orchestrator
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            if let yokai = orchestrator.currentYokai {
                VStack(spacing: 24) {
                    YokaiPortraitCorner(yokai: yokai)
                        .frame(width: 240, height: 240)
                    Text(subtitleText(for: orchestrator.activeCutscene, yokai: yokai))
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                    Button("Tap to continue") { orchestrator.dismissCutscene() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func subtitleText(for cutscene: YokaiCutscene?, yokai: MoraCore.YokaiDefinition) -> String {
        switch cutscene {
        case .mondayIntro: return yokai.voice.clips[.greet] ?? ""
        case .fridayClimax: return yokai.voice.clips[.fridayAcknowledge] ?? ""
        case .srsCameo: return yokai.voice.clips[.encourage] ?? ""
        case .sessionStart, nil: return ""
        }
    }
}
```

Need to `import MoraCore` at top. (The placeholder `MoraCore.YokaiDefinition` in the subtitle function method is a pseudo-prefix; remove the qualifier and add the import.) Corrected version:

```swift
import SwiftUI
import MoraCore
import MoraEngines

public struct YokaiCutsceneOverlay: View {
    @Bindable var orchestrator: YokaiOrchestrator

    public init(orchestrator: YokaiOrchestrator) {
        self.orchestrator = orchestrator
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            if let yokai = orchestrator.currentYokai {
                VStack(spacing: 24) {
                    YokaiPortraitCorner(yokai: yokai)
                        .frame(width: 240, height: 240)
                    Text(subtitleText(for: orchestrator.activeCutscene, yokai: yokai))
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                    Button("Tap to continue") { orchestrator.dismissCutscene() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func subtitleText(for cutscene: YokaiCutscene?, yokai: YokaiDefinition) -> String {
        switch cutscene {
        case .mondayIntro: return yokai.voice.clips[.greet] ?? ""
        case .fridayClimax: return yokai.voice.clips[.fridayAcknowledge] ?? ""
        case .srsCameo: return yokai.voice.clips[.encourage] ?? ""
        case .sessionStart, .none: return ""
        }
    }
}
```

- [ ] **Step 2: Build + commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift
git commit -m "feat(ui): YokaiCutsceneOverlay barebones (pre-polish)"
```

### Task R2.6: BestiaryView + BestiaryCardView + BestiaryDetailView

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryView.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryCardView.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryDetailView.swift`

- [ ] **Step 1: Write `BestiaryView`**

```swift
// Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryView.swift
import SwiftUI
import SwiftData
import MoraCore
import MoraEngines

public struct BestiaryView: View {
    @Query(sort: \BestiaryEntryEntity.befriendedAt, order: .forward)
    private var entries: [BestiaryEntryEntity]
    @State private var store: BundledYokaiStore?

    public init() {}

    public var body: some View {
        let catalog = store?.catalog() ?? []
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(catalog, id: \.id) { yokai in
                    if let entry = entries.first(where: { $0.yokaiID == yokai.id }) {
                        NavigationLink {
                            BestiaryDetailView(yokai: yokai, entry: entry)
                        } label: {
                            BestiaryCardView(yokai: yokai, state: .befriended)
                        }
                    } else {
                        BestiaryCardView(yokai: yokai, state: .locked)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Sound-Friend Register")
        .onAppear { if store == nil { store = try? BundledYokaiStore() } }
    }
}
```

- [ ] **Step 2: Write `BestiaryCardView`**

```swift
// Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryCardView.swift
import SwiftUI
import MoraCore

public struct BestiaryCardView: View {
    public enum CardState { case befriended, locked }
    let yokai: YokaiDefinition
    let state: CardState

    public var body: some View {
        VStack(spacing: 8) {
            if state == .befriended {
                YokaiPortraitCorner(yokai: yokai).frame(width: 80, height: 80)
                Text(yokai.grapheme).font(.title2.weight(.bold))
                Text(yokai.ipa).font(.caption).foregroundStyle(.secondary)
            } else {
                Circle().fill(Color(white: 0.9)).frame(width: 80, height: 80)
                Text("?").font(.title)
            }
        }
        .padding()
        .background(Color(white: 0.98))
        .cornerRadius(16)
        .accessibilityLabel(state == .befriended ? Text("\(yokai.grapheme) yokai, befriended") : Text("Locked"))
    }
}
```

- [ ] **Step 3: Write `BestiaryDetailView`**

```swift
// Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryDetailView.swift
import SwiftUI
import AVFoundation
import MoraCore
import MoraEngines

public struct BestiaryDetailView: View {
    let yokai: YokaiDefinition
    let entry: BestiaryEntryEntity
    @State private var player: AVAudioPlayer?
    @State private var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()

    public var body: some View {
        VStack(spacing: 24) {
            YokaiPortraitCorner(yokai: yokai).frame(width: 200, height: 200)
            VStack(spacing: 4) {
                Text(yokai.grapheme).font(.largeTitle.weight(.bold))
                Text(yokai.ipa).font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                ForEach([YokaiClipKey.example1, .example2, .example3], id: \.self) { key in
                    if let word = yokai.voice.clips[key] {
                        Button(word) { play(clip: key) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            Button("🔊 Play greeting") { play(clip: .greet) }
                .buttonStyle(.borderedProminent)
            Text("Befriended: \(entry.befriendedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func play(clip: YokaiClipKey) {
        guard let store = try? BundledYokaiStore() else { return }
        if let url = store.voiceClipURL(for: yokai.id, clip: clip) {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        } else if let text = yokai.voice.clips[clip] {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }
}
```

- [ ] **Step 4: Build + commit**

```sh
(cd Packages/MoraUI && swift build)
git add Packages/MoraUI/Sources/MoraUI/Bestiary/
git commit -m "feat(ui): BestiaryView + card + detail (placeholder/TTS fallback)"
```

### Task R2.7: Hook YokaiLayerView into SessionContainerView

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`

- [ ] **Step 1: Wrap session phase view in a ZStack with YokaiLayerView**

Locate the body root of `SessionContainerView`. Wrap the existing phase switch:

```swift
ZStack {
    // existing body content (phase switch, etc.) goes here
    if let yokai = orchestrator.yokai {
        YokaiLayerView(orchestrator: yokai)
            .ignoresSafeArea()
    }
}
```

If `SessionContainerView` does not currently hold `orchestrator`, adapt the parameter passing to match existing patterns. Do not introduce a new ownership model; if the orchestrator is read from environment in the existing code, keep it that way.

- [ ] **Step 2: Build + commit**

```sh
(cd Packages/MoraUI && swift build)
git commit -am "feat(ui): SessionContainerView mounts YokaiLayerView"
```

### Task R2.8: Add bestiary navigation from home

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/RootView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`

- [ ] **Step 1: Add a "Register" button in HomeView**

Find `HomeView.swift`. Add a secondary button near the "Session" CTA:

```swift
NavigationLink(value: "bestiary") {
    Label("Sound-Friend Register", systemImage: "book.closed.fill")
}
.buttonStyle(.bordered)
```

- [ ] **Step 2: Add nav destination in RootView**

In the `navigationDestination(for: String.self)` switch, add:

```swift
case "bestiary":
    BestiaryView()
        .environment(\.moraStrings, resolvedStrings)
```

- [ ] **Step 3: Build + xcodegen regen + xcodebuild**

```sh
xcodegen generate   # with team inject/revert wrapper as before
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```sh
git commit -am "feat(ui): bestiary navigation from home"
```

### Task R2.9: Open PR for R2

- [ ] **Step 1: Open PR**

Title: `feat(rpg): yokai UI overlay and bestiary view (placeholder assets)`

Body:

```markdown
## Summary
- `YokaiLayerView` overlay + `FriendshipGaugeHUD` + `YokaiPortraitCorner` render during sessions.
- `YokaiCutsceneOverlay` handles Monday/Friday/SRS cutscene dismiss.
- `BestiaryView` accessible from home; `BestiaryDetailView` plays voice clips via bundled audio or Apple TTS fallback.
- Placeholder portrait PNG keeps layout honest while R3/R4 produce real assets.

## Test plan
- [ ] `(cd Packages/MoraUI && swift test)` green
- [ ] Manual: run app in iOS Simulator, start a session; verify meter HUD + corner portrait appear.
- [ ] Manual: tap "Sound-Friend Register" from home → BestiaryView shows 5 locked cards.

## Spec
§12 UI, §13 Data Model, §14 Accessibility.
```

---

## Phase R3: Asset Pipeline Bootstrap (tools/yokai-forge)

**Goal:** Produce a scripted, reproducible tool chain on the Ubuntu RTX 5090 that takes a per-yokai JSON spec and emits portrait PNGs (via ComfyUI + Flux + Style LoRA) and voice clips (via Fish Speech + Bark + mastering).

**Runs off the mora app repo**, under `tools/yokai-forge/`, except for the 5 per-yokai JSON specs and workflow graph JSONs that are checked in.

### Task R3.1: tools/yokai-forge directory + README

**Files:**
- Create: `tools/yokai-forge/README.md`
- Create: `tools/yokai-forge/requirements.txt`
- Create: `tools/yokai-forge/.gitignore`

- [ ] **Step 1: Write README**

```markdown
# yokai-forge

Offline asset pipeline for mora's yokai portraits and voice clips.

## Ubuntu bootstrap (RTX 5090)

Host: `youtalk-desktop.local`. Python 3.12 system. See Appendix A of
`docs/superpowers/plans/2026-04-23-rpg-shell-yokai.md` for the exact
commands (run manually on the workstation).

## Inputs

- `prompts/style_layer.txt` — Layer-1 constant prompt, feeds every portrait.
- `prompts/yokai_*.json` — Per-yokai JSON spec following the schema in design spec §7.

## Outputs

- `outputs/portraits/<yokai_id>/candidate_*.png` — batch generations.
- `outputs/voice/<yokai_id>/<clip>.m4a` — mastered audio.

## Workflow

1. Run `scripts/bootstrap_style.py` once to seed the Style LoRA training set.
2. Train Style LoRA via `scripts/train_style_lora.sh`.
3. Run `scripts/render_portraits.py --yokai sh` to generate 20–30 candidates.
4. Curate; copy the chosen PNG into mora repo at `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/<id>/portrait.png`.
5. Run `scripts/synthesize_voices.py --yokai sh` for voice clips.
6. Master via `scripts/master_audio.py`; copy outputs into mora repo.

Binary assets ship via Git LFS.
```

- [ ] **Step 2: Write requirements.txt**

```txt
torch
torchvision
torchaudio
diffusers>=0.30
transformers>=4.45
huggingface_hub>=0.25
accelerate
safetensors
Pillow
numpy
scipy
librosa
soundfile
hf_transfer
omegaconf
einops
ftfy
```

- [ ] **Step 3: Write .gitignore**

```gitignore
outputs/
refs/
tools/ComfyUI/
venv/
__pycache__/
*.safetensors
*.ckpt
```

- [ ] **Step 4: Commit**

```sh
git add tools/yokai-forge/README.md tools/yokai-forge/requirements.txt tools/yokai-forge/.gitignore
git commit -m "tools(yokai-forge): scaffold with requirements + README"
```

### Task R3.2: Layer-1 style prompt + negative prompt

**Files:**
- Create: `tools/yokai-forge/prompts/style_layer.txt`
- Create: `tools/yokai-forge/prompts/negative.txt`

- [ ] **Step 1: Write the style layer**

```txt
a chibi kawaii yokai character, thick black outlines, flat pastel colors,
rounded soft forms, studio ghibli x splatoon x yo-kai watch aesthetic,
centered character portrait, 3/4 body angle, plain white background,
soft rim lighting, high quality illustration
```

- [ ] **Step 2: Write the negative prompt**

```txt
realistic, photograph, dark, scary, weapon, violence, adult, text, watermark, extra limbs, extra fingers, low quality, blurry
```

- [ ] **Step 3: Commit**

```sh
git add tools/yokai-forge/prompts/
git commit -m "tools(yokai-forge): Layer-1 style + negative prompt"
```

### Task R3.3: Per-yokai prompt JSONs (5 MVP)

**Files:**
- Create: `tools/yokai-forge/prompts/yokai_sh.json`
- Create: `tools/yokai-forge/prompts/yokai_th.json`
- Create: `tools/yokai-forge/prompts/yokai_f.json`
- Create: `tools/yokai-forge/prompts/yokai_r.json`
- Create: `tools/yokai-forge/prompts/yokai_short_a.json`

- [ ] **Step 1: Copy each record from `YokaiCatalog.json`**

Each file mirrors the corresponding entry from `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json` (Task R1.2), with the same JSON structure. This duplication is intentional — the forge tools read these files by name without depending on the Swift side.

- [ ] **Step 2: Commit**

```sh
git add tools/yokai-forge/prompts/yokai_*.json
git commit -m "tools(yokai-forge): per-yokai JSON specs for MVP five"
```

### Task R3.4: Prompt composer script

**Files:**
- Create: `tools/yokai-forge/scripts/compose_prompt.py`

- [ ] **Step 1: Write the composer (pure function)**

```python
# tools/yokai-forge/scripts/compose_prompt.py
"""Compose a Flux prompt from a yokai JSON spec + the Layer-1 style lock."""
from __future__ import annotations
import json
import pathlib
import argparse

ROOT = pathlib.Path(__file__).resolve().parents[1]
STYLE = (ROOT / "prompts" / "style_layer.txt").read_text().strip()
NEG = (ROOT / "prompts" / "negative.txt").read_text().strip()


def compose_positive(spec: dict) -> str:
    decor = spec["word_decor"]
    palette = ", ".join(spec["palette"])
    return (
        f"{STYLE}, "
        f"a {spec['personality']}, "
        f"{spec['sound_gesture']}, "
        f"wearing {decor[0]}, with {decor[1]}, and {decor[2]}, "
        f"{palette} color scheme, {spec['expression']}"
    )


def compose_negative() -> str:
    return NEG


def load_spec(path: pathlib.Path) -> dict:
    return json.loads(path.read_text())


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True, help="id, e.g. sh / th / f / r / short_a")
    args = ap.parse_args()
    spec_path = ROOT / "prompts" / f"yokai_{args.yokai}.json"
    spec = load_spec(spec_path)
    print("POSITIVE:")
    print(compose_positive(spec))
    print("\nNEGATIVE:")
    print(compose_negative())
```

- [ ] **Step 2: Commit**

```sh
git add tools/yokai-forge/scripts/compose_prompt.py
git commit -m "tools(yokai-forge): prompt composer (Layer 1 + per-yokai)"
```

### Task R3.5: Bootstrap render script (pre-LoRA)

**Files:**
- Create: `tools/yokai-forge/scripts/bootstrap_style.py`

- [ ] **Step 1: Write the bootstrap driver**

```python
# tools/yokai-forge/scripts/bootstrap_style.py
"""Generate ~100 style-bootstrap images before Style LoRA training.

Uses diffusers directly (no ComfyUI dependency) so the script runs
as a plain Python workload on the RTX 5090. Reads prompt variations
from the 5 per-yokai JSON specs to force variety in the bootstrap pool.

Usage:
    python scripts/bootstrap_style.py --count 100
"""
from __future__ import annotations
import argparse
import pathlib
import itertools
import random

import torch
from diffusers import FluxPipeline

from compose_prompt import compose_positive, compose_negative, load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "outputs" / "style_bootstrap"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=100)
    ap.add_argument("--steps", type=int, default=28)
    ap.add_argument("--guidance", type=float, default=3.5)
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-dev",
        torch_dtype=torch.bfloat16,
    ).to("cuda")

    specs = sorted((ROOT / "prompts").glob("yokai_*.json"))
    variants = list(itertools.cycle([load_spec(p) for p in specs]))

    for i in range(args.count):
        spec = variants[i]
        prompt = compose_positive(spec)
        neg = compose_negative()
        seed = random.randint(0, 2**31 - 1)
        generator = torch.Generator(device="cuda").manual_seed(seed)
        image = pipe(
            prompt=prompt,
            negative_prompt=neg,
            num_inference_steps=args.steps,
            guidance_scale=args.guidance,
            generator=generator,
            height=1024, width=1024,
        ).images[0]
        image.save(OUT / f"bootstrap_{i:03d}_{spec['id']}_{seed}.png")
        print(f"saved bootstrap_{i:03d}_{spec['id']}_{seed}.png")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Commit**

```sh
git add tools/yokai-forge/scripts/bootstrap_style.py
git commit -m "tools(yokai-forge): bootstrap_style.py (pre-LoRA generation)"
```

### Task R3.6: Style LoRA training wrapper

**Files:**
- Create: `tools/yokai-forge/scripts/train_style_lora.sh`
- Create: `tools/yokai-forge/scripts/prepare_lora_dataset.py`

- [ ] **Step 1: Write dataset prep script**

```python
# tools/yokai-forge/scripts/prepare_lora_dataset.py
"""Take a user-curated directory of ~50 style-bootstrap images and
emit a captioned dataset directory compatible with Ostris AI Toolkit.

Caption strategy: fixed style-token caption plus lightweight tag.
"""
from __future__ import annotations
import argparse
import pathlib
import shutil

STYLE_TAG = "moraforge-kawaii-yokai-style"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--curated", required=True, help="directory of hand-picked bootstrap images")
    ap.add_argument("--out", required=True, help="output dataset directory")
    args = ap.parse_args()
    src = pathlib.Path(args.curated)
    dst = pathlib.Path(args.out)
    dst.mkdir(parents=True, exist_ok=True)
    for i, img in enumerate(sorted(src.glob("*.png"))):
        stem = f"{STYLE_TAG}_{i:03d}"
        shutil.copy(img, dst / f"{stem}.png")
        (dst / f"{stem}.txt").write_text(
            f"{STYLE_TAG}, chibi kawaii yokai character, thick black outlines, flat pastel colors, 3/4 portrait, plain white background"
        )
    print(f"wrote {i+1} image+caption pairs to {dst}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Write training wrapper**

```sh
# tools/yokai-forge/scripts/train_style_lora.sh
#!/usr/bin/env bash
set -euo pipefail

# Requires Ostris AI Toolkit cloned under tools/ai-toolkit.
# Usage: ./train_style_lora.sh /path/to/dataset

DATASET="${1:-}"
if [[ -z "$DATASET" ]]; then
  echo "usage: $0 <dataset_dir>" >&2; exit 1
fi

# Ostris invocation using a pinned config file. The config
# is checked in as config/style_lora.yaml next to this script.
python "${AI_TOOLKIT_ROOT:-$HOME/ai-toolkit}/run.py" \
  "$(dirname "$0")/../config/style_lora.yaml"
```

- [ ] **Step 3: Create Ostris config**

```yaml
# tools/yokai-forge/config/style_lora.yaml
job: extension
config:
  name: moraforge_style_lora
  process:
    - type: sd_trainer
      training_folder: outputs/lora
      device: cuda:0
      trigger_word: moraforge-kawaii-yokai-style
      network:
        type: lora
        linear: 16
        linear_alpha: 16
      save:
        dtype: bf16
        save_every: 500
        max_step_saves_to_keep: 4
      datasets:
        - folder_path: outputs/lora_dataset
          caption_ext: txt
          resolution:
            - 1024
      train:
        batch_size: 1
        steps: 2000
        gradient_accumulation_steps: 1
        train_unet: true
        train_text_encoder: false
        gradient_checkpointing: true
        noise_scheduler: flowmatch
        optimizer: adamw8bit
        lr: 1.0e-4
        dtype: bf16
      model:
        name_or_path: black-forest-labs/FLUX.1-dev
        is_flux: true
        quantize: true
```

- [ ] **Step 4: Commit**

```sh
chmod +x tools/yokai-forge/scripts/train_style_lora.sh
git add tools/yokai-forge/scripts/prepare_lora_dataset.py \
        tools/yokai-forge/scripts/train_style_lora.sh \
        tools/yokai-forge/config/style_lora.yaml
git commit -m "tools(yokai-forge): Style LoRA training scripts + Ostris config"
```

### Task R3.7: Per-yokai portrait renderer

**Files:**
- Create: `tools/yokai-forge/scripts/render_portraits.py`

- [ ] **Step 1: Write the renderer**

```python
# tools/yokai-forge/scripts/render_portraits.py
"""Render 20–30 portrait candidates per yokai using Flux.1 dev + trained Style LoRA.

Usage:
    python scripts/render_portraits.py --yokai sh --count 24 --lora outputs/lora/moraforge_style_lora.safetensors
"""
from __future__ import annotations
import argparse
import pathlib
import random

import torch
from diffusers import FluxPipeline

from compose_prompt import compose_positive, compose_negative, load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    ap.add_argument("--count", type=int, default=24)
    ap.add_argument("--lora", required=True)
    ap.add_argument("--lora_strength", type=float, default=0.8)
    ap.add_argument("--steps", type=int, default=32)
    ap.add_argument("--guidance", type=float, default=3.5)
    args = ap.parse_args()

    spec = load_spec(ROOT / "prompts" / f"yokai_{args.yokai}.json")
    out = ROOT / "outputs" / "portraits" / args.yokai
    out.mkdir(parents=True, exist_ok=True)

    pipe = FluxPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-dev", torch_dtype=torch.bfloat16
    ).to("cuda")
    pipe.load_lora_weights(args.lora, adapter_name="style")
    pipe.set_adapters(["style"], adapter_weights=[args.lora_strength])

    prompt = compose_positive(spec) + ", moraforge-kawaii-yokai-style"
    neg = compose_negative()

    for i in range(args.count):
        seed = random.randint(0, 2**31 - 1)
        generator = torch.Generator(device="cuda").manual_seed(seed)
        image = pipe(
            prompt=prompt,
            negative_prompt=neg,
            num_inference_steps=args.steps,
            guidance_scale=args.guidance,
            generator=generator,
            height=1024, width=1024,
        ).images[0]
        image.save(out / f"{args.yokai}_candidate_{i:03d}_{seed}.png")
        print(f"saved {args.yokai}_candidate_{i:03d}_{seed}.png")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Commit**

```sh
git add tools/yokai-forge/scripts/render_portraits.py
git commit -m "tools(yokai-forge): render_portraits.py per-yokai batch with Style LoRA"
```

### Task R3.8: Voice synthesis + mastering scripts

**Files:**
- Create: `tools/yokai-forge/scripts/synthesize_voices.py`
- Create: `tools/yokai-forge/scripts/master_audio.py`

- [ ] **Step 1: Write synthesize_voices.py (Fish Speech + Bark stub)**

```python
# tools/yokai-forge/scripts/synthesize_voices.py
"""Generate the 8 voice clips for one yokai.

Fish Speech S2 Pro handles the main clips (clean pronunciation).
Bark handles non-verbal tag mixing for greet / friday_acknowledge.

Inputs: refs/<yokai_id>_reference.wav — user-curated reference clip.
Outputs: outputs/voice/<yokai_id>/<clip_key>.wav (pre-mastering).

Usage:
    python scripts/synthesize_voices.py --yokai sh
"""
from __future__ import annotations
import argparse
import pathlib
import subprocess

from compose_prompt import load_spec

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    args = ap.parse_args()
    spec = load_spec(ROOT / "prompts" / f"yokai_{args.yokai}.json")
    ref = ROOT / "refs" / f"{args.yokai}_reference.wav"
    if not ref.exists():
        raise SystemExit(f"reference missing: {ref}")
    out = ROOT / "outputs" / "voice" / args.yokai
    out.mkdir(parents=True, exist_ok=True)

    # Fish Speech (via fish-speech CLI — installed separately; see README).
    # We shell out so this script stays ABI-stable across Fish Speech releases.
    for key, text in spec["voice"]["clips"].items():
        wav = out / f"{key}.wav"
        cmd = [
            "fish-speech", "generate",
            "--ref-audio", str(ref),
            "--text", text,
            "--output", str(wav),
        ]
        subprocess.run(cmd, check=True)
        print(f"generated {wav}")

    # TODO-FOR-R4-USER: optional Bark head-tail mix for greet / friday_acknowledge.
    # The Bark command is tool-specific; see tools/yokai-forge/README.md.


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Write master_audio.py**

```python
# tools/yokai-forge/scripts/master_audio.py
"""Master raw WAVs to -16 LUFS AAC m4a, 22050 Hz mono.

Usage:
    python scripts/master_audio.py --yokai sh
"""
from __future__ import annotations
import argparse
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def master(src: pathlib.Path, dst: pathlib.Path) -> None:
    # ffmpeg loudnorm + resample + AAC encode.
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-af", "loudnorm=I=-16:TP=-1.5:LRA=11,silenceremove=start_periods=1:start_silence=0.05:start_threshold=-40dB:stop_periods=1:stop_silence=0.05:stop_threshold=-40dB",
        "-ar", "22050", "-ac", "1",
        "-c:a", "aac", "-b:a", "96k",
        str(dst),
    ]
    subprocess.run(cmd, check=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yokai", required=True)
    args = ap.parse_args()
    src_dir = ROOT / "outputs" / "voice" / args.yokai
    dst_dir = ROOT / "outputs" / "voice" / args.yokai / "mastered"
    dst_dir.mkdir(parents=True, exist_ok=True)
    for wav in sorted(src_dir.glob("*.wav")):
        dst = dst_dir / (wav.stem + ".m4a")
        master(wav, dst)
        print(f"mastered {dst}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Commit**

```sh
git add tools/yokai-forge/scripts/synthesize_voices.py \
        tools/yokai-forge/scripts/master_audio.py
git commit -m "tools(yokai-forge): voice synthesis + mastering scripts"
```

### Task R3.9: Open PR for R3

Title: `tools(yokai-forge): prompt library and ComfyUI workflows`

Body:

```markdown
## Summary
Scripted asset forge under `tools/yokai-forge/`:
- Per-yokai JSON specs (5 MVP)
- Layer-1 style prompt + negative prompt
- Prompt composer (`compose_prompt.py`)
- Bootstrap renderer (`bootstrap_style.py`) for pre-LoRA pool
- Style LoRA trainer wrapper (Ostris AI Toolkit config + shell wrapper)
- Per-yokai portrait renderer (`render_portraits.py`)
- Voice synth + audio mastering scripts
Runs on the `youtalk-desktop` RTX 5090 workstation. Binary outputs are ignored; the PR ships only source + configs.

## Test plan
- [ ] `compose_prompt.py --yokai sh` prints a valid Flux prompt
- [ ] Ubuntu bootstrap (Appendix A of the plan) succeeds
- [ ] One dry bootstrap generation completes (saved to outputs/)

## Spec
§8–§11 (asset pipeline).
```

---

## Phase R4: First 5 Yokai Assets

**Goal:** Produce, curate, and bundle real portraits + voice clips for sh/th/f/r/short_a; update `YokaiCatalog.json` to match finalized designs; ship via Git LFS.

This phase is **user-driven execution** of the forge tool chain. The repo changes are small: asset files + catalog touch-ups + `.gitattributes` additions.

### Task R4.1: .gitattributes LFS rules

**Files:**
- Modify: `.gitattributes`

- [ ] **Step 1: Append LFS rules**

```text
Packages/MoraCore/Sources/MoraCore/Resources/Yokai/**/*.png filter=lfs diff=lfs merge=lfs -text
Packages/MoraCore/Sources/MoraCore/Resources/Yokai/**/*.m4a filter=lfs diff=lfs merge=lfs -text
```

- [ ] **Step 2: Commit**

```sh
git add .gitattributes
git commit -m "chore: track yokai portraits and voice clips via LFS"
```

### Task R4.2: Generate, curate, bundle assets (user-driven)

All generation, curation, and asset-file commits happen in the **Ubuntu session**. The Ubuntu host has a clone of the mora repo at `~/mora` (from Appendix A.3); generation outputs land under `~/mora/tools/yokai-forge/outputs/` and picked finals are copied into the Resources directory of the same clone. The Ubuntu session commits and pushes those files on its working branch. The **Mac session** pulls and runs the Xcode smoke test before opening the PR.

For each yokai in [sh, th, f, r, short_a]:

- [ ] **Step 1 (Ubuntu session): Generate portrait candidates**

```sh
cd ~/mora/tools/yokai-forge
source ~/mora-forge-work/venv/bin/activate
python scripts/render_portraits.py --yokai sh --count 24 --lora outputs/lora/moraforge_style_lora.safetensors
```

- [ ] **Step 2 (Ubuntu session): Pick the best and place in the repo**

Open `outputs/portraits/sh/` in a file manager / image viewer, hand-pick one candidate, then copy it into the Resources tree of the same repo clone:

```sh
mkdir -p ~/mora/Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh
cp outputs/portraits/sh/<chosen>.png ~/mora/Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/portrait.png
```

- [ ] **Step 3 (Ubuntu session): Generate voice clips**

Pre-requisite: a 30-second reference clip of the voice character has been saved at `refs/sh_reference.wav` under `~/mora/tools/yokai-forge/` (e.g., from an ElevenLabs v3 free-tier export of the `character_description` string).

```sh
python scripts/synthesize_voices.py --yokai sh
python scripts/master_audio.py --yokai sh
```

- [ ] **Step 4 (Ubuntu session): Bundle mastered clips**

```sh
mkdir -p ~/mora/Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/voice
cp outputs/voice/sh/mastered/*.m4a ~/mora/Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/voice/
```

- [ ] **Step 5 (Ubuntu session): Commit and push**

```sh
cd ~/mora
git add Packages/MoraCore/Sources/MoraCore/Resources/Yokai/sh/
git commit -m "assets(yokai): bundle sh portrait + voice clips"
git push origin <branch>
```

- [ ] **Step 6 (Mac session): Pull and smoke-test Xcode**

```sh
git pull
xcodegen generate   # with the repo's team-inject/revert wrapper
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Repeat steps 1–6 for th, f, r, short_a**

### Task R4.3: Finalize catalog JSON

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json`

- [ ] **Step 1: Update palette/expression to match actually-chosen portraits**

Hand-edit each of the 5 records in the catalog to reflect the final picked designs (e.g., if the `sh` yokai you picked leans more towards mint-green than teal, update `palette`). This is a bookkeeping pass.

- [ ] **Step 2: Run MoraCore tests**

```sh
(cd Packages/MoraCore && swift test)
```

All green.

### Task R4.4: Open PR for R4

Title: `assets(yokai): bundle first five yokai (portraits + voice via LFS)`

Body:

```markdown
## Summary
- Adds portrait PNG + 8 voice m4a clips for each of sh / th / f / r / short_a under `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/`.
- Finalizes `YokaiCatalog.json` palette/expression to match actual picks.
- Registers `.png` and `.m4a` under `Resources/Yokai/` in `.gitattributes` for LFS.

## Test plan
- [ ] `git lfs ls-files` shows 5 × (1 png + 8 m4a) = 45 LFS-tracked files
- [ ] `xcodebuild build` green
- [ ] Manual: running a session shows each yokai portrait and plays its greeting

## Spec
§7 (monster design), §9 (voice pipeline), §11 (asset workflow).
```

---

## Phase R5: Polish

**Goal:** Upgrade placeholders to production-grade UX: cutscene staging, washi-paper wrap, sparkle reactions, haptics, Reduce Motion branches, OpenDyslexic subtitles, Friday carryover end-to-end.

### Task R5.1: Particle sparkle overlay for correct reads

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/SparkleOverlay.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift`

- [ ] **Step 1: Write SparkleOverlay**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/SparkleOverlay.swift
import SwiftUI

public struct SparkleOverlay: View {
    let trigger: AnyHashable
    @State private var show = false

    public init(trigger: AnyHashable) { self.trigger = trigger }

    public var body: some View {
        ZStack {
            if show {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                        .offset(
                            x: CGFloat.random(in: -40...40),
                            y: CGFloat.random(in: -40...40)
                        )
                        .opacity(show ? 0 : 1)
                        .animation(.easeOut(duration: 0.6).delay(Double(i) * 0.05), value: show)
                }
            }
        }
        .onChange(of: trigger) { _, _ in
            show = false
            withAnimation(.easeOut(duration: 0.6)) { show = true }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Attach to YokaiPortraitCorner**

Extend `YokaiPortraitCorner` with a `@Binding` / `@Observable` trigger from the orchestrator (add a `lastCorrectTrialID: UUID` to `YokaiOrchestrator`, mutated on each correct read; the portrait observes it and drives the sparkle).

- [ ] **Step 3: Build + commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Yokai/SparkleOverlay.swift \
        Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift \
        Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift
git commit -m "feat(ui): sparkle reaction on correct reads"
```

### Task R5.2: Washi card morph for Friday climax

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/WashiCardMorph.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Resources/Washi/texture.png`
- Create: `Packages/MoraCore/Sources/MoraCore/Resources/Washi/card_base.png`

- [ ] **Step 1: Add washi textures to resources**

Procure / generate two textures (approx 1024×1024 beige washi paper and a card silhouette). Commit under `Resources/Washi/`.

- [ ] **Step 2: Write the morph view**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/WashiCardMorph.swift
import SwiftUI

public struct WashiCardMorph: View {
    @Binding var progress: Double  // 0.0 ... 1.0 across ~7 s

    public var body: some View {
        ZStack {
            Image("Washi/texture", bundle: .module)
                .resizable()
                .scaledToFit()
                .opacity(progress)
                .scaleEffect(1 + progress * 0.25)
        }
    }
}
```

- [ ] **Step 3: Wire into YokaiCutsceneOverlay for `.fridayClimax`**

Replace the barebones implementation with a timed 4-phase choreography (fade bg / enlarge portrait / speak / morph). Reuse voice asset if present; fall back to TTS otherwise.

- [ ] **Step 4: Build + commit**

```sh
git add Packages/MoraUI/Sources/MoraUI/Yokai/WashiCardMorph.swift \
        Packages/MoraCore/Sources/MoraCore/Resources/Washi/ \
        Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift
git commit -m "feat(ui): washi paper morph for Friday climax cutscene"
```

### Task R5.3: Reduce Motion branches

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiPortraitCorner.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/WashiCardMorph.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/SparkleOverlay.swift`

- [ ] **Step 1: Add `@Environment(\.accessibilityReduceMotion) private var reduceMotion`**

In each animated view. Gate any non-fade animation behind `if !reduceMotion`. Every animation falls back to a 0.2 s opacity fade.

- [ ] **Step 2: Commit**

```sh
git commit -am "feat(ui): respect Reduce Motion across yokai overlays"
```

### Task R5.4: Haptics on meter increment and Friday completion

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiHaptics.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/FriendshipGaugeHUD.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift`

- [ ] **Step 1: Write haptics helper**

```swift
// Packages/MoraUI/Sources/MoraUI/Yokai/YokaiHaptics.swift
import UIKit

public enum YokaiHaptics {
    public static func meterTick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    public static func fridaySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
```

- [ ] **Step 2: Call `meterTick` when percent increments (use `.onChange(of: percent)`) and `fridaySuccess` when cutscene transitions to fridayClimax**

- [ ] **Step 3: Commit**

```sh
git commit -am "feat(ui): haptic feedback on meter increment + Friday success"
```

### Task R5.5: OpenDyslexic subtitle track under voice clips

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Yokai/YokaiCutsceneOverlay.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Bestiary/BestiaryDetailView.swift`

- [ ] **Step 1: Apply OpenDyslexic font modifier to all subtitle Text**

Existing mora typography already provides OpenDyslexic via the `moraStrings` / design token path. Follow the convention from `Packages/MoraUI/Sources/MoraUI/Design/` (e.g., `.moraFont(.body)` or similar — inspect the Design/ dir for the exact modifier).

- [ ] **Step 2: Commit**

```sh
git commit -am "feat(ui): OpenDyslexic subtitles on yokai voice moments"
```

### Task R5.6: Friday carryover end-to-end

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/YokaiCarryoverE2ETests.swift`

- [ ] **Step 1: Write failing test**

```swift
// YokaiCarryoverE2ETests.swift
import Testing
import SwiftData
import Foundation
@testable import MoraEngines
@testable import MoraCore
import MoraTesting

@MainActor
@Suite("YokaiOrchestrator — carryover E2E")
struct YokaiCarryoverE2ETests {
    @Test("carryover encounter re-used on next Monday")
    func carryoverMonday() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = ModelContext(container)
        let orch = YokaiOrchestrator(store: FakeYokaiStore(), modelContext: ctx)
        // Week 1: fails
        try orch.startWeek(yokaiID: "sh", weekStart: Date(timeIntervalSince1970: 1_000_000))
        orch.currentEncounter?.friendshipPercent = 0.30
        orch.beginFridaySession(trialsPlanned: 1)
        orch.recordFridayFinalTrial(correct: false)
        #expect(orch.currentEncounter?.state == .carryover)

        // Week 2: same yokai reused
        try orch.startWeek(yokaiID: "sh", weekStart: Date(timeIntervalSince1970: 1_604_800 + 1_000_000))
        #expect(orch.currentEncounter?.yokaiID == "sh")
        #expect(orch.currentEncounter?.state == .active)
        // Carryover flag preserved in history
        let past = try ctx.fetch(FetchDescriptor<YokaiEncounterEntity>(predicate: #Predicate { $0.storedRolloverFlag == true }))
        #expect(past.count == 1)
    }
}
```

- [ ] **Step 2: Ensure startWeek honors carryover**

Add to `startWeek`: if the previous week's encounter for the same yokai was `.carryover`, reset and proceed (current logic already creates a new encounter; no change needed as long as carryover state is preserved on the old one).

- [ ] **Step 3: Run → PASS**

```sh
(cd Packages/MoraEngines && swift test --filter YokaiCarryoverE2ETests)
```

- [ ] **Step 4: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/YokaiCarryoverE2ETests.swift \
        Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift
git commit -m "test(engines): carryover path preserves history across weeks"
```

### Task R5.7: Open PR for R5

Title: `feat(rpg): cutscene polish, accessibility, haptics, carryover`

Body:

```markdown
## Summary
- Sparkle reaction on correct reads.
- Washi paper morph + 4-phase choreography for Friday climax.
- Reduce Motion branches in all yokai overlays.
- Haptics on meter increment and Friday completion.
- OpenDyslexic subtitles under every voice moment.
- Friday carryover E2E test covering same-yokai reuse on next Monday.

## Test plan
- [ ] All package tests green
- [ ] `xcodebuild build` green
- [ ] Manual: run simulator with Reduce Motion on, verify no wrap/pulse/particle animations
- [ ] Manual: complete a golden week, observe Friday climax choreography and haptic tap

## Spec
§12 (UI), §14 (accessibility), §6 (carryover path).
```

---

## Appendix A: Ubuntu bootstrap commands (manual, run by user)

Run these inside a Claude Code session started directly on `youtalk-desktop` (not via SSH from the Mac). Each block is a small, reviewable chunk that you can paste into the Ubuntu session interactively and approve step by step.

### A.1 Workspace + venv

```sh
mkdir -p ~/mora-forge-work
cd ~/mora-forge-work
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel setuptools
```

### A.2 PyTorch for Blackwell

```sh
# Requires Python 3.12 and a Blackwell-compatible driver (590.x+ — already present).
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu126

# Smoke test:
python -c "
import torch
assert torch.cuda.is_available(), 'CUDA not available'
print('device:', torch.cuda.get_device_name(0))
print('compute cap:', torch.cuda.get_device_capability(0))
x = torch.randn(1024, 1024, device='cuda')
print('matmul OK, norm:', float((x @ x.T).norm()))
"
```

Expected: prints `NVIDIA GeForce RTX 5090` and a reasonable norm value.

### A.3 mora repo clone (the Ubuntu-side working copy)

```sh
# Clone the repo at ~/mora so asset commits can happen from this machine.
git clone <mora repo URL> ~/mora

# Install the forge's Python deps into the workstation venv created in A.1.
source ~/mora-forge-work/venv/bin/activate
pip install -r ~/mora/tools/yokai-forge/requirements.txt
```

Switch to the branch the Mac session is working on (or a dedicated asset branch):

```sh
cd ~/mora
git fetch origin
git switch <branch-name>   # e.g. worktree-peaceful-crunching-pancake, or asset/yokai-first-five
```

### A.4 Flux.1 dev weights

```sh
pip install huggingface_hub hf_transfer
export HF_HUB_ENABLE_HF_TRANSFER=1
# Requires acceptance of the FLUX.1-dev model license on Hugging Face.
huggingface-cli login    # user pastes an HF token
python -c "
from diffusers import FluxPipeline
import torch
pipe = FluxPipeline.from_pretrained(
    'black-forest-labs/FLUX.1-dev',
    torch_dtype=torch.bfloat16,
)
print('Flux.1 dev loaded')
"
```

### A.5 Ostris AI Toolkit

```sh
cd ~
git clone https://github.com/ostris/ai-toolkit.git
cd ai-toolkit
pip install -r requirements.txt
```

### A.6 Fish Speech S2 Pro

```sh
cd ~
git clone https://github.com/fishaudio/fish-speech.git
cd fish-speech
pip install -e .
# Download S2 Pro checkpoint per upstream README.
```

### A.7 Bark

```sh
pip install git+https://github.com/suno-ai/bark.git
python -c "from bark import SAMPLE_RATE, generate_audio, preload_models; preload_models()"
```

### A.8 Sudo-required (ask user)

These are the only steps that need sudo. The user runs them manually:

```sh
sudo apt-get update
sudo apt-get install -y cuda-toolkit-12-6  # optional — only needed if nvcc is required
```

---

## Appendix B: Self-review checklist

After all phases merge, confirm:

- [ ] Every task in `YokaiCatalog.json` has a corresponding bundled portrait + 8 clips.
- [ ] `git lfs ls-files` shows 45 yokai asset files.
- [ ] `xcodebuild build` on a clean checkout succeeds.
- [ ] All Swift package tests pass individually (`swift test` in each of MoraCore, MoraEngines, MoraUI, MoraTesting).
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` clean.
- [ ] Manual α with the son: one full week runs end-to-end without breaking; child can name the yokai and reproduce its sound gesture at end of week.

---

## Self-review (authoring)

**Spec coverage:**
- §1–§4 narrative + decisions → covered by R1.1–R1.2 + R2 cutscenes + R4 assets.
- §5 narrative characters → R2.5 + R4 assets.
- §6 battle loop → R1.12–R1.17 math + state machine; R5.6 carryover.
- §7 phoneme monster schema → R1.1 types + R1.2 catalog + R3.3 JSONs.
- §8 unified prompt → R3.2 style + R3.4 composer.
- §9 voice pipeline → R3.8 scripts + R4 asset generation.
- §10 LoRA strategy → R3.5–R3.6 bootstrap + training.
- §11 workflow phases → mirrored by R3/R4 task chain.
- §12 UI → R2.2–R2.8 + R5 polish.
- §13 data model → R1.4–R1.7 entities + schema registration.
- §14 relationship to canonical → relationship documented in spec; no plan task needed.
- §15 testing → each entity/unit has a dedicated test (R1.x), plus golden (R1.17) and carryover (R5.6).
- §16 phasing → R1..R5 PR decomposition.
- §17 future work → explicitly deferred, no plan tasks.
- §18 open questions → noted in spec; not blocking implementation.

**Placeholder scan:** one "TODO-FOR-R4-USER" in `synthesize_voices.py` intentionally marks the optional Bark mixing step as user-driven; all other "TBD/TODO/later" language is absent.

**Type consistency:** `YokaiEncounterEntity`, `BestiaryEntryEntity`, `YokaiCameoEntity` (with `Entity` suffix) are used consistently across MoraCore, MoraEngines, tests, and UI queries. `YokaiStore.portraitURL(for:)` and `voiceClipURL(for:clip:)` signatures match across protocol / concrete / fake. `YokaiOrchestrator.recordTrialOutcome(correct:)` / `recordSessionCompletion()` / `recordFridayFinalTrial(correct:)` / `beginDay()` / `beginFridaySession(trialsPlanned:)` / `maybeTriggerCameo(grapheme:sessionID:pronunciationSuccess:)` are stable method names used in both tests and callers.
