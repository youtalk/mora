# Mora — Learner-Observing Multimodal Language Drill iPad App: Design Spec

- **Date**: 2026-04-21
- **Project**: `mora`
- **Platform**: iPadOS 18+ (SwiftUI, local-only)
- **Target device**: iPad Air 5 (2022 / Apple M1 / 8 GB RAM) as the lower bound; any Apple Silicon iPad
- **LLM runtime**: MLX Swift
- **LLM model**: Qwen 3.5 4B Instruct (MLX 4-bit quantization)

## 1. Purpose and Scope

### 1.1 Goal
Build a local-only iPad app for language drill practice. The app continuously observes the learner through the front camera and microphone to estimate focus, interest, and conversational momentum, and uses an on-device LLM to fill word-level slots in predefined sentence templates. Keyboard input is minimized; voice is the primary input modality.

### 1.2 Non-goals (explicitly out of scope)
- Free-form or long-form generation (restricted to template + slot filling)
- Server-side inference or cloud sync (fully offline)
- User accounts, authentication, or billing
- Multi-user / concurrent sessions on a single device
- Grammar tutoring or long-term analytics dashboards (deferred beyond initial release)

### 1.3 Success criteria
- On iPad Air 5 (M1, 8 GB), median turn latency (end-of-utterance → next sentence rendered) **≤ 1.5 s**
- 20 minutes of continuous session on the device must not trigger Jetsam termination or noticeable thermal throttling
- With camera, microphone, **and** network all denied, the app must still allow learning via a text-input fallback

## 2. Target User and Usage

- **User**: an individual language learner (primary assumption: Japanese native speaker learning English; the design generalizes to other target languages)
- **Setting**: at home or in a cafe, iPad placed on a desk, learner facing the screen, short sessions of 10–30 minutes

## 3. Device and Runtime Constraints

| Item | Value |
|---|---|
| Chip | Apple M1 (iPad Air 5 baseline) |
| Physical RAM | 8 GB unified memory |
| Per-process memory ceiling | ~5–6 GB (Jetsam) |
| LLM weights (Qwen 3.5 4B, MLX 4-bit) | ~2.3 GB |
| Peak inference RAM (text-only, hybrid mode) | ~3.0 GB |
| Network | Used for initial model download only; not required afterward |

## 4. Architecture (Hybrid)

Four-layer structure. Each layer depends only on the protocols of the layer below it. Dependency injection enables swapping implementations freely.

```
┌─────────────────────────────────────────────────┐
│ Presentation (SwiftUI)                          │
│   LibraryView / SessionView / SettingsView      │
└──────────────────────┬──────────────────────────┘
                       │ observes @Observable state
┌──────────────────────▼──────────────────────────┐
│ Orchestration                                   │
│   SessionOrchestrator  /  EngagementPolicy      │
└────┬──────────────┬──────────────┬──────┬──────┘
     │              │              │      │
┌────▼─────┐ ┌──────▼──────┐ ┌─────▼────┐ ┌▼──────┐
│ Vision   │ │ Speech      │ │ LLM      │ │ TTS   │
│ Engine   │ │ Engine      │ │ Engine   │ │ Engine│
│ (AVFound │ │ (SFSpeech   │ │ (MLX     │ │ (AVSp │
│ +Vision) │ │  Recognizer)│ │  Swift + │ │ eech) │
│          │ │             │ │  Qwen)   │ │       │
└──────────┘ └─────────────┘ └──────────┘ └───────┘
          │
┌─────────▼───────────────────────────────────────┐
│ Domain & Storage (SwiftData)                    │
│   TemplateStore / SessionLog / ModelCatalog     │
└─────────────────────────────────────────────────┘
```

### 4.1 Design principles
- **Single responsibility**: each component owns one concern
- **Pure-function judgement**: the decision logic (`EngagementPolicy`) is a pure function and can be unit-tested without an LLM
- **Protocol-first**: every engine is exposed as a protocol; fake implementations unlock unit testing
- **MLX isolation**: MLX Swift dependencies are confined to the `MoraMLX` package; other layers access it only through protocols

## 5. Components

### 5.1 VisionEngine
- **Responsibility**: Capture front-camera frames via `AVCaptureSession` and emit a face-observation signal every 500 ms using Apple's Vision framework
- **Input**: front-camera video
- **Output**: `AsyncStream<EngagementSignal>`
- **Vision APIs used**:
  - `VNDetectFaceRectanglesRequest` (presence and location of a face)
  - `VNDetectFaceLandmarksRequest` (eye/mouth landmarks → simple expression classification)
- **Capture preset**: `.medium` (≈ 640×480). Sufficient for engagement estimation
- **Power**: fully stopped while the orchestrator is idle

### 5.2 SpeechEngine
- **Responsibility**: Transcribe microphone audio using `SFSpeechRecognizer` in **on-device mode**; emit an `Utterance` when 1.5 s of silence marks end-of-turn
- **Input**: microphone audio
- **Output**: `AsyncStream<SpeechEvent>` with cases `.partial(text)`, `.final(utterance)`, `.error`
- **Requirement**: pick a `Locale` where `supportsOnDeviceRecognition == true` (English and Japanese qualify)
- **Constraint**: `SFSpeechRecognizer` must be re-instantiated per turn because a single recognition task cannot exceed roughly one minute

### 5.3 LLMEngine
- **Responsibility**: Run Qwen 3.5 4B Instruct on MLX Swift and, given `(Template, Directive, history, user utterance)`, pick the vocabulary for each slot
- **Input**: `GenerationRequest` (template id, directive, recent N utterances, user's latest utterance)
- **Output**: `FilledTemplate` (a `chosenVocabId` per slot)
- **Decoding**: JSON-constrained decoding producing shapes like `{ "VERB": "eat", "NOUN": "apple" }`; low temperature (~0.4)
- **Protocol**:
  ```swift
  protocol LLMEngine {
    func load() async throws
    func generate(_ request: GenerationRequest) async throws -> FilledTemplate
    func unload() async
  }
  ```
- **Memory management**: on `applicationDidReceiveMemoryWarning`, call `unload()`; reload lazily on the next `generate`

### 5.4 TTSEngine
- **Responsibility**: Speak the rendered `FilledTemplate` via `AVSpeechSynthesizer`
- **Configuration**: the target-language voice (`AVSpeechSynthesisVoice(language:)`); speaking rate is user-configurable

### 5.5 SessionOrchestrator
- **Responsibility**: Drive the state machine `IDLE → CALIBRATING → LISTENING → THINKING → SPEAKING → LISTENING → ...`
- **State**: `@Observable`, bound to SwiftUI
- **Event handling**: subscribes to `VisionEngine` and `SpeechEngine` streams via `Task`, triggering state transitions

### 5.6 EngagementPolicy
- **Responsibility**: Pure function turning the most recent 2-second window of `EngagementSignal` samples plus session history into a `Directive`
- **Input**: `[EngagementSignal]`, `SessionHistory`
- **Output**: `Directive(difficulty: .easy | .normal | .hard, topicHint: String?, pacing: .slow | .normal | .fast)`
- **Example rules**:
  - Face absent > 3 s → notify `SessionOrchestrator` to pause
  - Off-screen gaze > 50% **and** expression == confused → `difficulty = .easy`
  - Speech onset delay > 5 s → `difficulty = .easy`, `pacing = .slow`
  - Rising smile frequency & short turn gaps → `difficulty = .hard`, `pacing = .fast`

### 5.7 TemplateStore
- **Responsibility**: Persist templates and vocabulary
- **Technology**: SwiftData
- **Entities**: `Template`, `Slot`, `VocabItem` (template categorization is carried on `Template.tags: [String]`)
- **Seed data**: a bundled JSON of roughly 50 beginner-level English templates, loaded on first launch

### 5.8 SessionLog
- **Responsibility**: Persist session history for next-session context and retrospective summaries
- **Retained data**: utterance timestamps, selected vocab, and an aggregated engagement time series. **No raw images or audio are stored.**

### 5.9 ModelCatalog
- **Responsibility**: Download, version, and integrity-check the LLM
- **Behavior**: on first launch, if weights are missing, download from a Hugging Face repo such as `mlx-community/Qwen3.5-4B-MLX-4bit` (~2.3 GB)
- **Verification**: SHA-256 check; resumable download backed by `URLSession.downloadTask`

## 6. Domain Model

### 6.1 Template

```swift
struct Template: Identifiable, Codable {
  let id: UUID
  let locale: Locale                 // target language
  let pattern: String                // "I want to [VERB] a [NOUN]."
  let slots: [Slot]
  let tags: [String]                 // ["beginner", "daily", "food"]
}

struct Slot: Codable {
  let name: String                   // "VERB"
  let category: SlotCategory
  let vocab: [VocabItem]             // candidate vocabulary
}

struct VocabItem: Codable {
  let id: String
  let surface: String                // "eat"
  let difficulty: Difficulty
  let meta: [String: String]         // part-of-speech etc.
}

enum Difficulty: String, Codable { case easy, normal, hard }
```

### 6.2 EngagementSignal

```swift
struct EngagementSignal {
  let timestamp: Date
  let facePresent: Bool
  let gazeOnScreen: Bool?            // nil = cannot measure
  let expression: Expression         // .neutral | .smile | .puzzled | .yawning
  let speechActivity: Bool
}
```

### 6.3 Directive

```swift
struct Directive {
  let difficulty: Difficulty
  let topicHint: String?             // "food", "travel", ...
  let pacing: Pacing                 // .slow | .normal | .fast
  let shouldPause: Bool              // set when face is absent, etc.
}
```

### 6.4 FilledTemplate

```swift
struct FilledTemplate {
  let templateID: UUID
  let choices: [String: String]      // slot name → chosen vocab surface
  var rendered: String { /* fills the pattern with chosen slots */ }
}
```

### 6.5 GenerationRequest

```swift
struct GenerationRequest {
  let template: Template
  let directive: Directive
  let recentHistory: [Utterance]     // last N (≈ 5)
  let userUtterance: Utterance       // the current turn's utterance
}

struct Utterance {
  let text: String
  let timestamp: Date
  let durationSec: Double
}
```

## 7. Turn Loop (Data Flow)

```
1. App launch
     → ModelCatalog.ensureAvailable()
     → LLMEngine.load()
     → Import bundled templates into SwiftData (first launch only)

2. Start session
     → SessionOrchestrator.state = .calibrating
     → VisionEngine.start() / SpeechEngine.start()
     → Measure engagement baseline for 5 s
     → state = .listening

3. LISTENING
     → SpeechEngine emits .partial → UI shows it live
     → VisionEngine emits an EngagementSignal every 500 ms
     → SpeechEngine emits .final on 1.5 s silence

4. THINKING (target < 1.5 s)
     → EngagementPolicy.evaluate(signals: window(2 s), history) → Directive
     → If Directive.shouldPause → state = .paused; back to step 2
     → Otherwise: LLMEngine.generate(
         template = selectNextTemplate(directive),
         directive = directive,
         history = last5Utterances,
         userUtterance = final.text
       ) → FilledTemplate

5. SPEAKING
     → SessionView renders FilledTemplate.rendered
     → TTSEngine.speak(rendered)
     → SessionLog.append(...)

6. Loop back to step 3 (continuous)

7. End of session (user action or timer)
     → VisionEngine.stop() / SpeechEngine.stop()
     → SessionLog.finalize() → summary view
     → Keep LLMEngine loaded for instant next-session start
```

## 8. Error and Boundary Handling

| Event | Response |
|---|---|
| First launch, model not yet downloaded | Progress-bar download screen, SHA-256 verification, resumable via `URLSession` resume data |
| Camera permission denied | Vision disabled. Engagement estimation falls back to speech-only signals (speech rate, pause length) |
| Microphone permission denied | Fall back to keyboard input. Show an explicit explanation to the user |
| `SFSpeechRecognizer` lacks on-device support for the selected Locale | Exclude that language from the supported list; surface a warning in Settings |
| `didReceiveMemoryWarning` | Slow VisionEngine sampling from 500 ms to 2000 ms, reduce capture resolution, shrink SessionLog cache |
| LLM generation timeout (> 3 s) | Fallback: deterministically pick a vocab item from the template's candidates that matches the Directive |
| LLM returns invalid JSON | Retry once; if it fails again, run the same fallback |
| Camera, microphone, **and** keyboard all unavailable | Cannot start a session; deep-link user to Settings |

## 9. Testing Strategy

### 9.1 Pure unit tests (no MLX, fast)
- `EngagementPolicy` branch coverage: every signal combination → expected `Directive`
- `TemplateStore` CRUD plus category/tag queries
- JSON schema parser and pattern renderer
- `Directive` → vocab subset filter logic

### 9.2 Engine unit tests
- `LLMEngine` is invoked through `LLMEngineProtocol`; substitute a `FakeLLMEngine` to unit-test `SessionOrchestrator`
- Smoke test with a very small model (e.g., `mlx-community/SmolLM-135M-4bit`) in an optional CI job

### 9.3 Integration tests
- Drive `SessionOrchestrator` with `FakeVisionEngine` / `FakeSpeechEngine`
- Assert the expected sequence: calibrate → listen → think → speak → listen

### 9.4 SwiftUI snapshot tests
- Cover the three primary screens (Library / Session / Settings)

### 9.5 Device smoke (manual, excluded from CI)
- On real hardware, run a 10-minute continuous session; verify no Jetsam, no frame drops, acceptable thermals, latency in budget

## 10. Module Layout (Swift Package Manager)

```
mora/
├── mora.xcodeproj                  # App target only
├── App/
│   ├── MoraApp.swift               # @main, minimal boot
│   └── Assets.xcassets
├── Packages/
│   ├── MoraCore/                   # Template, Slot, Directive, EngagementPolicy (pure)
│   │   └── Sources/MoraCore
│   ├── MoraEngines/                # VisionEngine, SpeechEngine, LLMEngine, TTSEngine (protocols + impls)
│   │   └── Sources/MoraEngines
│   ├── MoraMLX/                    # MLX Swift dependency isolated here; LLMEngine impl lives here
│   │   └── Sources/MoraMLX
│   ├── MoraUI/                     # SwiftUI views
│   │   └── Sources/MoraUI
│   └── MoraTesting/                # Fake implementations and snapshot helpers
│       └── Sources/MoraTesting
└── docs/
    └── superpowers/specs/2026-04-21-mora-design.md
```

### 10.1 Package dependencies
- `MoraCore`: no external deps
- `MoraEngines`: `MoraCore` + Apple frameworks (AVFoundation, Vision, Speech)
- `MoraMLX`: `MoraCore`, `MoraEngines`, `ml-explore/mlx-swift-examples` (`MLXLLM`)
- `MoraUI`: `MoraCore`, `MoraEngines`
- `MoraTesting`: `MoraCore`, `MoraEngines`
- App target: all packages

## 11. External Libraries

| Library | Version target (tentative) | Purpose |
|---|---|---|
| `ml-explore/mlx-swift` | `from: "0.25.0"` | MLX runtime |
| `ml-explore/mlx-swift-examples` (`MLXLLM`) | track `main` | Model definitions and loaders (e.g., Qwen) |
| `apple/swift-collections` | `from: "1.0.0"` | Ring buffers etc. |
| `pointfreeco/swift-snapshot-testing` | `from: "1.15.0"` | SwiftUI snapshot tests (test target only) |

## 12. Security and Privacy

- **Fully local processing.** Camera frames, audio, and transcripts never leave the device.
- **Info.plist** usage descriptions must be explicit:
  - `NSCameraUsageDescription`: "Used to estimate learner focus via the front camera during study sessions."
  - `NSMicrophoneUsageDescription`: "Used to listen to spoken responses during study sessions."
  - `NSSpeechRecognitionUsageDescription`: "Used to transcribe spoken responses for the learning loop."
- Surface a **baseline-calibration screen** on first run that makes the face-processing behavior explicit.
- **Session logs never contain raw images or audio** — only transcripts and aggregated metrics.

## 13. Distribution and App Review Notes

- Because the camera and microphone are used near-continuously, the App Store privacy labels must indicate "data used in-app, not linked to user, not used for tracking."
- The ~2.3 GB model weights are **not bundled**. They are downloaded on first launch to stay within App Store size limits and to spread out the initial download cost.
- iPadOS 18+ only (driven by SwiftData and MLX Swift support).

## 14. Open Questions

1. Template authoring — can users create their own templates, or are they always bundled by the app author? Initial release will ship with fixed bundled templates; user authoring is deferred.
2. Additional learning languages beyond English — Qwen 3.5 supports roughly 29 languages, but each new language carries setup cost for vocabulary lists and TTS voices.
3. Engagement visualization UI — whether to show a dashboard or just minimal hints. Decide via UX mockups in a follow-up.
4. **Model alternatives** — under tighter memory/storage pressure, step down to **Qwen 3.5 2B MLX-4bit** (~1.2 GB). If the LLM ever needs to handle images or audio directly, **Gemma 4 E2B** (image + audio + text, ~1.0 GB) remains an option.
5. Room to evolve toward Approach B (raw audio to the LLM) so that prosody and hesitation can inform decisions. Worth evaluating once basic flow is stable.
6. Revisit whether to feed images directly to the LLM once Swift-side VLM support (e.g., Qwen3-VL 4B) matures.

## 15. Implementation Phases

1. **Phase 0 — Skeleton**: Xcode project, SPM split, empty `MoraApp`
2. **Phase 1 — LLM pipeline**: `ModelCatalog` + `LLMEngine` + `MoraMLX`. Validate the "fill one JSON template" path with `swift test` (`MoraMLXTests`) and one standalone SwiftUI test screen.
3. **Phase 2 — Session foundation**: `TemplateStore`, `SessionOrchestrator`, `SessionView` with button-driven template advance
4. **Phase 3 — Speech integration**: `SpeechEngine` drives template advance from voice input
5. **Phase 4 — Vision integration**: `VisionEngine` + `EngagementPolicy`, hooked into `Directive` with a calibration screen
6. **Phase 5 — TTS and polish**: `TTSEngine`, UI polish, snapshot test suite
7. **Phase 6 — Device evaluation and tuning**: 20-minute continuous session on iPad Air 5; verify Jetsam, thermals, latency
