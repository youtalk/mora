# mora RPG Shell: Yokai Befriending Layer Design Spec

- **Date:** 2026-04-23
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Relates to:** Canonical design `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md`
- **Scope:** Additive layer over the existing mora session flow; no breaking changes to current domain model or engine responsibilities.

---

## 1. Overview

This spec adds a light RPG layer on top of mora's existing A-day / C-day learning loop. Every week, a new "sound-guardian yokai" appears. The yokai personifies the week's target grapheme through a recognizable sound gesture, three word-mnemonic visual decorations, and a bespoke voice. The child never sees an avatar of themselves; the camera is a first-person POV facing the yokai. Throughout the week, correct decoding reads fill a **Friendship Meter** from 0% toward 100%. On the final Friday session, the meter always reaches 100%; the yokai acknowledges the learner and becomes a permanent card in a bestiary called the **Sound-Friend Register**. Tapping a register card replays the yokai's signature voice clips, turning the character itself into a portable mnemonic for the grapheme.

The layer is strictly non-combative (no damage, HP reduction, enemy retaliation, or penalty states) and strictly child-facing (no new Parent Mode UI). It is designed so that the yokai character becomes a robust memory anchor for the phoneme, an explicit product goal. All yokai assets (portraits and voice clips) are AI-synthesized at development time and bundled with the app; there is no runtime generation or network dependency for the RPG layer.

The first iteration ships five yokai — `sh`, `th`, `f`, `r`, `short_a` — chosen to cover two digraphs and three Japanese-L1 interference targets, plus a short-vowel case, to stretch the generation pipeline and front-load high-value learning targets.

## 2. Motivation & Context

The canonical mora spec identifies retention and daily adherence as its largest unsolved risks ("A-only would likely bore the child within weeks"). The pronunciation feedback and tile-board features shipped recently have hardened the technical backbone, but the emotional payoff of each session is still thin (streak animation + XP). A short survey of dyslexia-targeted literacy apps (Nessy, Lexia Core5, GraphoGame, Teach Your Monster to Read, Prodigy Math, Mila-Learn) confirms that a game-shell around structured practice is the dominant approach to sustaining daily use, and rhythm / character-driven mnemonic designs have the strongest dyslexia-specific research support.

The user (father of an 8-year-old Japanese-L1 son with dyslexia) requested a gamified layer that provides competitive appeal and adrenaline, *and* that turns phonemes into memorable characters. A pure combat RPG (Prodigy-style) raises the known stress / anxiety vulnerability of dyslexic children, and collides with mora's ASR false-negative sensitivity. A befriending-through-skillful-pronunciation frame — modeled after Yo-kai Watch Season 1 plus Ghibli plus Splatoon — preserves motivational stakes while staying psychologically safe.

## 3. Goals & Non-Goals

### Goals

- Add a weekly yokai encounter that personifies the active target grapheme through sound gesture + word-mnemonic decor + distinct voice.
- Keep the RPG-layer time overhead under ~10 seconds per session on average, never starving the OG curriculum time budget.
- Make each yokai a portable mnemonic: the Sound-Friend Register is itself a study tool.
- Commit to AI-synthesized, locally-generated assets that the user (developer-parent) curates by hand.
- Guarantee that every week ends with a befriending event; misses never attack or punish.
- Stay strictly multi-L1 × mono-L2-English: L1 can be localized (Japanese in v1, Korean / Mandarin / etc. in v2+), but the yokai cast and their voices are shared across all L1 variants forever.

### Non-Goals (v1)

- No player avatar / companion / equipment / inventory / overworld map.
- No combat damage model, enemy attacks, HP reduction, failure states.
- No Parent-Mode UI changes specifically for the RPG layer.
- No runtime AI generation. All assets are pre-baked and bundled.
- No second L2 language. Yokai always speak English.
- No talking-mouth animation in v1. Static portraits with scale/opacity/particle effects only.
- No character LoRAs in v1. Each yokai ships as one static portrait.
- No full 24-32 yokai cast in MVP. MVP ships 5; remaining yokai arrive in v1.5+.

## 4. Locked Decisions (Design Invariants)

| Axis | Decision | Rationale |
|---|---|---|
| RPG scope | Minimal — one weekly monster, no avatar/equipment/pets | Contains asset cost, preserves OG session time budget. |
| Battle model | Weekly Friendship Meter filling 0→100% | Week-long narrative arc matches OG weekly-target cadence. |
| Narrative tone | Befriending (no combat, no damage) | Dyslexic-child stress vulnerability; ASR false-negative tolerance. |
| Art style | Chibi kawaii (Yo-kai Watch × Splatoon × Kirby / Ghibli) | Cultural resonance for Japanese-L1 son; strong LoRA support. |
| Phoneme theming | Sound gesture + word-mnemonic decor, both present | Maximum mnemonic density per character. |
| Voice language | English, forever (mono-L2) | Asset reuse across all future L1 profiles. |
| Runtime speech | Pre-baked voice clips, no runtime TTS for yokai | Character preservation; offline guarantee. |
| Voice stack | Fish Speech S2 Pro (main) + Bark (non-verbal) + optional ElevenLabs v3 (Friday hero lines) | Local-first on RTX 5090; SaaS allowed only for asset-gen time. |
| Image stack | Flux.1 dev + Style LoRA, local on RTX 5090 via ComfyUI | Consistent kawaii world; unlimited iteration. |
| MVP size | 5 yokai (sh, th, f, r, short_a) | Pipeline validation; ~1 month of content while full cast is produced. |

## 5. Narrative & World

### Premise

> In the land of *Mora*, every word is guarded by a **sound-spirit yokai**. From time to time, a yokai visits the human world looking for someone who can speak its sound. When one finds you, it challenges you to a week-long **"let me hear your sound"** test. If it is satisfied, it enters your **Sound-Friend Register** — and from then on will visit you whenever its sound is needed.

Scene language: serene rural Japan (paper lanterns, verandas, washi textures). Visual mood avoids horror and overt combat motifs.

### On-Screen Characters

- **The yokai** — 1 per week, the only on-screen character. Rendered as a single static portrait per yokai.
- **The learner** — never rendered. Camera is yokai-POV, addressing "you". This removes avatar asset cost and lets the child project themselves directly.

### Off-Screen (explicitly excluded from v1)

- No shishou / sensei / guide character.
- No Parent Mode companion role.
- No recurring story narrator.

## 6. Battle Loop (Weekly)

### Friendship Meter Rules

- Range: 0.0 ... 1.0, displayed as 0–100%.
- `+2%` per correct decoding trial.
- `+5%` bonus per completed session.
- Per-day cap: 25% (prevents front-loaded over-fill).
- Misses never subtract; the yokai never retaliates or regenerates.
- Existing parent override (`Performance.correct` retroactive flip, spec §14) feeds back into the meter because the meter is a deterministic function of recorded trials.
- Floor guarantee: Friday's final correct trial must bring the meter to 100% regardless of the week's earlier pace. If the week was under-performing, the Friday session weights are increased internally for the last ~10 trials so 100% is reached.

### Weekly Timeline

| Day | Session type (canonical §7) | Yokai staging | Meter milestone |
|---|---|---|---|
| Mon | Intro (new-rule day) | Full introduction cutscene, 12–15 s | 0 → 10% (greeting bonus) |
| Tue | A-day (Core Decoder) | 3–4 s start cameo + corner portrait + 3–5 s end meter update | 10% → 35% |
| Wed | C-day (Reading Adventure) | same | 35% → 55% |
| Thu | A-day | same | 55% → 80% |
| Fri | C-day (story + climax) | 3–4 s start + **15–20 s final cutscene** | 80% → 100% |
| Sat / Sun | Rest | none | — |

Average per-session RPG overhead: ~10 s. Friday overhead: ~25 s.

### Effect Polarity (authoritative table)

| Event | Allowed staging | Forbidden staging |
|---|---|---|
| Correct trial | Yokai nod / sparkle / meter +2% / SFX | — |
| Missed trial | Yokai "let me hear it again" line; meter unchanged | Retaliation; HP regen; anger; distress |
| Consecutive miss | Gentle hint prompt | Meter decrement; yokai leaves |
| Session complete | +5% bonus + "see you tomorrow" line | Failure framing |
| Week complete (Fri) | Always 100% + Sound-Friend Register card | Defeat / rejection |

### Special Events

- **SRS cameo**: when a previously-befriended grapheme is re-surfaced by the spaced-repetition engine (spec §11, intervals 1 / 3 / 7 / 14 d), its yokai appears for a 1-second portrait greeting at trial start and plays 2–3 voice clips on success. Does not affect the current week's Friendship Meter. Purely a character-recall reinforcement device.
- **Friday carryover**: in the rare case Friday's final trial is missed and the floor-boost has been exhausted, the yokai says a "not quite this week — see you again" line, the encounter transitions to state `.carryover`, and the same yokai reappears the following Monday (a one-week override of the curriculum schedule, explicitly permitted because OG systematic principle requires *staying on* the target, not advancing).

## 7. Phoneme Monster Design System

Every yokai is defined by six structural components. Each component carries both a mnemonic role (what it teaches the child) and a prompt role (how it feeds into generation).

| # | Component | Mnemonic role | Prompt role |
|---|---|---|---|
| 1 | Grapheme & IPA | The learning target identifier | Card label, voice clip text |
| 2 | Sound gesture | Physical pose embodying the sound | Portrait pose axis |
| 3 | Word decor (2–3 items) | Visual references to common words containing the grapheme | Portrait accessories / silhouette shape |
| 4 | Personality archetype | Single-word character, tied to voice tone | Facial expression + voice prompt |
| 5 | Palette (2–3 colors) | Immediate color-recall cue | Color scheme in prompt |
| 6 | Shared world traits | The common chibi-kawaii skin | Style LoRA (reused across all yokai) |

### Definition Schema

Each yokai is a JSON record matching this schema (stored in `Packages/MoraCore/Sources/MoraCore/Yokai/YokaiCatalog.json`):

```json
{
  "id": "sh",
  "grapheme": "sh",
  "ipa": "/ʃ/",
  "personality": "mischievous whisper spirit",
  "sound_gesture": "index finger pursed to lips in a shushing pose, one eye winking",
  "word_decor": [
    "paper sailor hat shaped like a small ship",
    "pointed seashell ears",
    "fluffy fin-like tail"
  ],
  "palette": ["teal", "cream", "foam-white"],
  "expression": "playful smirk, large round sparkling eyes",
  "voice": {
    "character_description": "young mischievous whispery boy, softly spoken with playful cadence, subtle wind-like breath",
    "clips": {
      "phoneme": "Shhh... /ʃ/",
      "example_1": "ship",
      "example_2": "shop",
      "example_3": "shell",
      "greet": "Shhh! You made it. Can you hear my sound?",
      "encourage": "That's it! Hear it whisper?",
      "gentle_retry": "So close. Listen once more.",
      "friday_acknowledge": "You found my sound. Now I am yours to remember."
    }
  }
}
```

### MVP Cast (v1, first five)

| Order | ID | Grapheme | IPA | L1 interference | Chosen for |
|---|---|---|---|---|---|
| 1 | `sh` | sh | /ʃ/ | — | Iconic shushing gesture; easy pipeline warmup |
| 2 | `th` | th | /θ/ | /θ/→/s/,/t/ | Highest-priority digraph |
| 3 | `f` | f | /f/ | /f/→/h/ | Critical consonant |
| 4 | `r` | r | /r/ | /r/↔/l/ | Critical consonant |
| 5 | `short_a` | a | /æ/ | /æ/↔/ʌ/ | Vowel-yokai case; tests non-consonant design |

Remaining L2+L3 coverage (≈19–27 additional yokai) is deferred to post-MVP content expansion.

## 8. Unified Prompt Structure (Visual)

All yokai portraits are generated from a five-layer prompt whose first layer is held constant to lock the shared world style. Per-yokai parameters drive layers 2–5. The constant layer is paired with a Style LoRA that further enforces aesthetic consistency.

```
[LAYER 1 — STYLE LOCK, constant across all yokai]
a chibi kawaii yokai character, thick black outlines, flat pastel colors,
rounded soft forms, studio ghibli x splatoon x yo-kai watch aesthetic,
centered character portrait, 3/4 body angle, plain white background,
soft rim lighting, high quality illustration

[LAYER 2 — PERSONALITY]        a {{personality}}
[LAYER 3 — GESTURE]            {{sound_gesture}}
[LAYER 4 — WORD DECOR]         wearing {{word_decor[0]}}, with {{word_decor[1]}}, and {{word_decor[2]}}
[LAYER 5 — PALETTE/EXPRESSION] {{palette|join}} color scheme, {{expression}}
```

Negative prompt: `realistic, photograph, dark, scary, weapon, violence, adult, text, watermark, extra limbs`.

Output: 1024×1024 PNG, portrait centered, transparent-white background (subject only).

## 9. Voice Asset Pipeline

Voice assets are generated via the same JSON spec that drives the visuals, using a three-stage pipeline. All generation happens locally on the RTX 5090 Ubuntu workstation.

### Stage 1 — Reference voice capture (one-time per yokai)

Per-yokai unique voice identity is established by generating a 30–60 second reference clip from the `voice.character_description` string, using either:

- Parler-TTS (natural-language voice description, fully local), or
- A one-shot generation via ElevenLabs v3 Free tier (manually exported for archival).

The reference clip is stored in the authoring workspace, not shipped.

### Stage 2 — Main clip synthesis

Each clip listed under `voice.clips` is synthesized via **Fish Speech S2 Pro** (zero-shot voice cloning from the Stage-1 reference). Outputs are 24 kHz WAV.

### Stage 3 — Non-verbal flavor mixing

Selected clips (typically `greet`, `friday_acknowledge`, optional `encourage` variants) are post-processed by generating a short **Bark** segment with inline tags (`[giggles]`, `[whispers]`, `[gasps]`, `[hums]`) using the same voice reference. The Bark segment is mixed as a 0.3–0.5 s head or tail into the Fish Speech clip.

### Stage 4 — Mastering

Loudness-normalize to -16 LUFS, trim leading/trailing silence to 40 ms, resample to 22.05 kHz mono, encode to AAC at 96 kbps (`.m4a`). Store under `Packages/MoraCore/Sources/MoraCore/Resources/Yokai/{id}/voice/{clip_key}.m4a`.

### Size budget

Per yokai: 8 clips × ~2 s × 96 kbps = ~200 KB compressed. Five yokai: ~1 MB. Full 24-yokai cast: ~5 MB. Comfortably within App Store resource limits and well below the on-device ML model budgets already in the app.

### Hero-line exception

For the `friday_acknowledge` clip specifically, ElevenLabs v3 may be used in place of Fish Speech if local synthesis lacks sufficient emotional range. 5 yokai × 1 clip is within the ElevenLabs free tier's monthly character allowance.

## 10. LoRA Strategy

### v1 scope

**One Style LoRA, trained once, used for all yokai.** No character LoRAs.

### Training data

40–60 curated images. Bootstrap procedure:

1. Run ~100 Flux.1 dev generations with Layer-1 constant prompt and diverse Layer 2–5 placeholder variations.
2. Manually curate 40–60 that match the target aesthetic.
3. Auto-caption with WD Tagger; lightly manual-edit captions to emphasize style tokens.
4. Train with Ostris AI Toolkit or kohya-ss/sd-scripts.

### Hyperparameters (starting values)

- Base: Flux.1 dev, BF16 (FP8 if stable on the 5090 toolchain).
- Rank (dim) 16, alpha 16.
- Steps 2000, learning rate 1e-4.
- Optimizer AdamW8bit.
- Batch size 1 (2 if VRAM allows with rank 16).
- Resolution 1024.

### Training time estimate (RTX 5090, Blackwell, 32 GB VRAM)

- Raw training: 25–35 min (BF16), 15–25 min if FP8 pipeline is stable.
- Data prep + captioning: 30–60 min.
- Evaluate + iterate: typically 2–3 additional training runs with tweaks.
- **End-to-end to ship-quality: 3–5 hours.**

### Deferred

- Character LoRAs: out of scope for v1 (each yokai ships as one portrait only).
- Per-pose generation (combat stances, reaction frames): out of scope for v1.

## 11. Asset Generation Workflow

Performed entirely on the user's RTX 5090 Ubuntu workstation via SSH.

### Workspace layout

```
~/mora-forge/
  ├── comfyui/                    # ComfyUI install
  ├── models/                     # Flux base weights, LoRAs
  ├── prompts/                    # Layer-1 constant + per-yokai JSON
  ├── refs/                       # Stage-1 voice reference clips (authoring-only)
  ├── outputs/
  │   ├── style_bootstrap/        # Pre-LoRA curation pool
  │   ├── portraits/              # Per-yokai candidate batches
  │   └── voice/                  # Synthesized clips (pre-mastering)
  └── workflows/                  # ComfyUI .json workflow graphs
```

### Phases

| Phase | Effort | Output |
|---|---|---|
| P0 — Prompt library | 1 day | Layer-1 constant + MVP-five yokai JSON |
| P1 — Style bootstrap | 2 days | 100 generations → 40–60 curated |
| P2 — Style LoRA | 0.5 day | Trained LoRA ready |
| P3 — Portrait batch | 2 days | 5 yokai × ~20 candidates → 5 picked |
| P4 — Voice synthesis | 2 days | 5 × 8 = 40 clips mastered |
| P5 — Bundle | 1 day | Catalog JSON + assets committed |

Total asset-track effort: ~8 days of user-driven work. Can run in parallel with Phases R1, R2, R5 of the Swift implementation track.

### File formats checked into the repo

- `Resources/Yokai/{id}/portrait.png` — 1024×1024 PNG, transparent background.
- `Resources/Yokai/{id}/voice/*.m4a` — mastered AAC at 96 kbps.
- `Yokai/YokaiCatalog.json` — full yokai metadata.

Binary assets ship via Git LFS (same mechanism the repo already uses for the wav2vec2 model).

## 12. UI & Visual Integration

### Architectural overlay

```
RootView (existing)
  └── SessionContainerView (existing)
        └── ZStack
              ├── [existing] Phase views (Warmup / DecodeActivity / ShortSentences / Story / Completion)
              └── [new] YokaiLayerView
                          ├── FriendshipGaugeHUD        — always visible during session (slim top-right bar)
                          ├── YokaiPortraitCorner       — always visible during session (80 pt bottom-right)
                          └── YokaiCutsceneOverlay      — full-screen on Monday / Friday events
```

A new top-level screen:

```
RootView
  └── BestiaryView (Sound-Friend Register)  — reachable from the home screen
```

### Screen sketch (iPad landscape, decoding phase)

```
┌───────────────────────────────────────────────────────────┐
│ Mora    [Friendship ■■■■■░░░░░ 48%]             [Menu]   │
│                                                           │
│                                                           │
│                  Read this word aloud                     │
│                                                           │
│                       s h i p                             │
│                                                           │
│                       [🎤 mic]                             │
│                                                           │
│                                                           │
│                                        [sh-yokai 80 pt]   │
└───────────────────────────────────────────────────────────┘
```

### Cutscene staging

**Monday intro (~14 s):**

1. 0.0 s — particle swirl begins.
2. 1.5 s — yokai portrait fades in center-screen.
3. 2.5 s — `greet` voice clip plays (~4 s).
4. 6.5 s — subtitle appears in OpenDyslexic.
5. 11 s — "Tap to continue" appears; earliest dismissal at 5 s.

**Friday climax (~20 s):**

1. Phase 1 (0–5 s): meter fills to 100%, yokai portrait enlarges center-screen with glow.
2. Phase 2 (5–10 s): `friday_acknowledge` voice clip plays.
3. Phase 3 (10–17 s): washi-paper wrap animation morphs portrait into a Sound-Friend Register card.
4. Phase 4 (17–20 s): card flies to the Register icon (bottom-right); "New Friend!" banner.

### Bestiary layout

Grid of cards, with befriended yokai shown and upcoming/future yokai as silhouettes. Tapping a card opens a larger view with:

- Portrait at top.
- Grapheme + IPA in large OpenDyslexic type.
- Three example words as tappable chips (each plays its `example_N` voice clip).
- A "play all" button that replays the phoneme + greeting.
- The date first befriended.

### Animation budget (v1)

| Effect | Implementation | Extra assets |
|---|---|---|
| Portrait idle pulse | SwiftUI `withAnimation` scale 1.0↔1.02, continuous | none |
| Correct-read reaction | Scale pulse + SwiftUI particles | none |
| Voice playback indicator | Scale 1.0↔1.05 synced to clip duration | none |
| Entrance | Opacity fade + particle swirl | none |
| Friday wrap | SwiftUI path animation (washi texture + card morph) | washi texture, card base |
| Register fly-in | Position + scale tween | none |

No talking-mouth animation in v1. The illusion of speech is produced by the pulse + subtitle synchronization.

### Accessibility

- Full OpenDyslexic subtitle track for every voice clip.
- Respect iOS Reduce Motion: particle / wrap / pulse effects collapse to 0.2 s opacity fades.
- Color-blind safe: Friendship Meter exposes a text label (e.g. `48%`) in addition to hue.
- Haptic feedback on meter increment (`.light`) and on Friday completion (`.success`).

## 13. Data Model Additions

Three new `@Model` types and one enum, all in `Packages/MoraCore`. Existing models from canonical spec §13 remain unchanged.

```swift
@Model final class YokaiEncounter {
    var id: UUID
    var yokaiID: String              // "sh", "th", "f", "r", "short_a"
    var weekStart: Date              // Monday date
    var state: YokaiEncounterState
    var friendshipPercent: Double    // 0.0 ... 1.0
    var correctReadCount: Int
    var sessionCompletionCount: Int  // 0 ... 5
    var befriendedAt: Date?
    var storedRolloverFlag: Bool     // Friday carryover path
}

enum YokaiEncounterState: String, Codable {
    case upcoming
    case active
    case befriended
    case carryover
}

@Model final class BestiaryEntry {
    var id: UUID
    var yokaiID: String
    var befriendedAt: Date
    var playbackCount: Int           // register replay counter (mnemonic metric)
    var lastPlayedAt: Date?
}

@Model final class YokaiCameo {
    var id: UUID
    var yokaiID: String
    var sessionID: UUID
    var triggeredAt: Date
    var pronunciationSuccess: Bool   // SRS review-word outcome
}
```

### Catalog (read-only, not a SwiftData entity)

`YokaiDefinition` is a plain `Codable` struct loaded from `YokaiCatalog.json` at startup via a `YokaiCatalogLoader`. It is never persisted to SwiftData; only IDs cross the boundary.

### Protocols and orchestrator

```swift
protocol YokaiStore {
    func catalog() -> [YokaiDefinition]
    func portraitURL(for id: String) -> URL
    func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL
}

@MainActor @Observable
final class YokaiOrchestrator {
    private(set) var currentEncounter: YokaiEncounter?
    private(set) var currentYokai: YokaiDefinition?
    private(set) var activeCutscene: YokaiCutscene?

    func onSessionEvent(_ event: OrchestratorEvent) { /* meter, cameo */ }
    func triggerMondayIntroIfNeeded() { }
    func triggerFridayClimaxIfReached() { }
}

enum YokaiClipKey: String {
    case phoneme, example1, example2, example3
    case greet, encourage, gentleRetry, fridayAcknowledge
}
```

`SessionOrchestrator` (existing) holds a `YokaiOrchestrator` as an observed child and forwards trial outcomes to it. Existing responsibilities are not altered.

### CloudKit sync policy

- `YokaiEncounter`: synced (parent can see "sh yokai in progress this week" in existing dashboard without UI changes).
- `BestiaryEntry`: synced (parent can see the register without UI changes).
- `YokaiCameo`: local-only (trial-level detail, matches existing `Performance` policy).

## 14. Relationship to Canonical Spec

This spec extends, and does not override, `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md`. Specific interactions:

- **§7 Daily Session Flow** — A-day and C-day phases are unchanged. The RPG layer runs entirely as a SwiftUI overlay consuming `OrchestratorEvent`s.
- **§9 Multi-L1 Architecture** — Locked with a new sibling invariant: **mono-L2, English forever**. Yokai cast + voices are L2-scoped, not L1-scoped. L1 affects only UI strings and mnemonic scaffolds around the layer, not the yokai themselves.
- **§11 Assessment & Adaptive Plan** — Unchanged. The Friendship Meter is a downstream, deterministic function of `Performance` records; it does not feed back into curriculum selection.
- **§12 Parent Experience** — Unchanged. No new Parent-Mode views. `YokaiEncounter` and `BestiaryEntry` sync so existing Parent-Mode session detail views can optionally surface them later, but that is not in scope for this spec.
- **§14 Error Handling** — The existing ASR false-negative mitigations apply directly. The RPG layer specifically refuses to introduce any new punishment surface.
- **§15 Testing Strategy** — A new layer of pedagogy tests ("meter floor guarantee", "never subtracts on miss", "Friday always befriends") adds to the existing pyramid.

## 15. Testing Strategy

### Unit

- `YokaiOrchestrator` meter math: +2% / correct, +5% / session, day cap 25%, no decrement on miss.
- `YokaiOrchestrator` state machine: `.upcoming` → `.active` → `.befriended` or `.carryover`.
- `YokaiCatalogLoader` JSON parsing & resource URL resolution.
- `YokaiStore` protocol conformance via in-memory fake.

### Integration

- Golden session: five-session week with fixed trial outcomes → deterministic final meter = 100%, `BestiaryEntry` created.
- Under-performing week: missing many trials → Friday floor-boost kicks in, meter still reaches 100%.
- Pathological week: every trial missed → encounter transitions to `.carryover`, next Monday re-uses same yokai.
- SRS cameo: previously-befriended yokai reappears during review word, 1-second staging does not affect current meter.

### Pedagogy

- Every bundled yokai has non-empty `phoneme`, three `example_N` clips, and a `friday_acknowledge` clip.
- Every example word is decodable under the yokai's grapheme + previously-taught set.
- Every yokai is assigned exactly one grapheme; no grapheme has two yokai.
- Voice-clip language: all clips classified as English (automatable via ASR round-trip).

### Field

- α testing with the son: confirm that after each week, the child can name the yokai, reproduce the sound gesture, and recall at least one example word.
- Qualitative: does the yokai become a mnemonic that the child uses on subsequent reads? (interview-level signal)
- Time budget: average per-session RPG overhead stays under 15 s.

## 16. Implementation Phasing

Five PRs, each producing a shippable milestone. Swift and asset-generation tracks run in parallel.

### Swift track

| Phase | Effort | Scope | Merge criterion |
|---|---|---|---|
| R1 — Yokai core | 4–6 d | Data model, `YokaiOrchestrator`, catalog loader, fakes, unit tests | All unit + integration tests green; no UI |
| R2 — UI shell | 2–3 d | `YokaiLayerView`, `BestiaryView`, placeholder art + Apple TTS fallback | Session renders the layer end-to-end with placeholders |
| R5 — Polish | 2–3 d | Cutscene staging, accessibility, haptics, carryover path | Reduce Motion audited; full pedagogy test suite green |

### Asset track (Ubuntu RTX 5090)

| Phase | Effort | Scope | Hand-off |
|---|---|---|---|
| R3 — Pipeline bootstrap | 2–3 d | ComfyUI + Flux install; prompt library; Style LoRA training data bootstrap | Trained Style LoRA checkpoint |
| R4 — First 5 yokai | 2–3 d | Portrait curation; voice synthesis; catalog JSON | LFS-bundled assets PR |

### Dependency graph

```
R1 ──────────────────┐
                     ├──► R2 ──► R5
R3 ──► R4 ───────────┘
```

R3 and R4 can start before R1 merges. R5 is the only phase that requires all prior phases to have landed.

### Timeline

```
Week 0   R1 (core engine)                    4–6 d
Week 1   R2 (UI shell)       |    R3 (bootstrap)     2–3 d
Week 2   R4 (assets)         |    R5 (polish)        2–3 d
───────────────────────────────────────────────────────
Total    12–18 days, 2–3 calendar weeks
```

## 17. Future Work (out of scope for v1)

- Expand yokai cast from 5 → full OG L2+L3 coverage (24–32 yokai).
- Talking-mouth animation (blendshape or 2-frame swap).
- Character LoRAs for per-yokai pose variants.
- Sound-Friend Register "friendship level" (replay-count based visual enhancements).
- Seasonal / birthday / special-event yokai.
- Yokai memory review mini-game (flashcard quiz using Register cards).
- Parent Mode RPG surfaces (deferred from §14 locking decision; can revisit if qualitative feedback shows parents want them).
- Second-L2 expansion (e.g. Spanish yokai cast) — explicitly deferred by the mono-L2-English invariant for now; would require a completely new spec.

## 18. Open Questions

1. **Yokai naming.** Should each yokai have a proper name (e.g., katakana-styled like "Shushi" for `sh`) or remain grapheme-keyed ("the sh yokai")? Defer to asset-generation phase; can be added to `YokaiDefinition` as an optional `displayName` without schema rework.
2. **Friday ElevenLabs usage.** Is local Fish Speech + Bark emotional range sufficient for the Friday hero line, or should ElevenLabs v3 be used for those 5 clips? Evaluate after first local synthesis pass.
3. **SRS cameo voice lines.** Does a cameo reuse `greet` / `encourage`, or does each yokai need a distinct short cameo line? Lean on reusing existing clips for v1; revisit after field testing.
4. **Bestiary tutorial.** Does the child need an in-app tutorial for the Register, or is the Friday fly-in self-explanatory? Decide during α testing.
5. **Week skip policy.** If the child misses several days in a row (school illness), how does the encounter state evolve? For v1: session-count-based progression (skipped days don't advance meter); explicit week-roll only happens on the configured weekly boundary.
