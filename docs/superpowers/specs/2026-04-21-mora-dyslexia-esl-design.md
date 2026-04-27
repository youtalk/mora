# mora — iPad-first Dyslexia + ESL App Design Spec

- **Date:** 2026-04-21
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Project:** `mora` — a name taken from the linguistic *mora*, a sub-syllabic sound unit central to phonology

---

## 1. Overview

mora is an iPad-first, on-device learning app that helps children with dyslexia learn English as a second language. It is grounded in Orton-Gillingham (OG) methodology, inspired by resources from LearnUp Centers and the Barton Reading & Spelling System. The first target user is an 8-year-old Japanese L1 child who has been diagnosed with dyslexia and whose English reading is currently at a US-kindergarten level despite six years of international-school exposure.

The app delivers a 15–20 minute daily "quest" that alternates between two session types:

- **A days: Core Decoder** — structured drill of the week's target grapheme (e.g., `sh`).
- **C days: Reading Adventure** — interest-based decodable passage reading using the same week's target.

Content is generated through a combination of a pre-authored story library (50 stories, built at development time using Claude/GPT and hand-curated by Yutaka) and a runtime template engine. A v1.5 upgrade introduces on-device LLM-assisted vocabulary expansion while keeping template-driven decodability guarantees.

The learning loop is fully offline. Cross-device parent access (iPad, iPhone, Mac Catalyst) is provided via Apple's CloudKit private database — the only cloud dependency, with no custom backend.

## 2. Motivation & Context

The target user's family recently moved from Japan to the United States. The child was diagnosed with dyslexia in Japan, but the impact is more severe in English because of the orthographic depth of English compared to the phonologically shallow Japanese writing system.

The local US school has enrolled them in ESL and states that an IEP can only begin after ESL completes. From the family's perspective this delays structured dyslexia support by approximately one year. Barton-certified tutoring is financially out of reach.

mora is being built so that Yutaka can provide structured, multisensory phonics instruction to a child close to him without waiting for an IEP and without paying for private tutoring. The architecture is intentionally designed so that once the Japanese-L1 prototype is validated, the same codebase can serve learners of other L1s (Korean, Mandarin, Spanish, etc.).

## 3. Goals and Non-Goals

### Goals

- Deliver a daily, semi-autonomous learning loop that a dyslexic 8-year-old can use independently for 15–20 minutes.
- Target the L2 (CVC) and L3 (digraphs, blends, closed syllables) bands of an OG-style curriculum in v1, with light L1 (phonemic awareness) diagnostics and L4 previews.
- Keep the learning loop fully on-device. No raw audio, transcripts, or per-trial details leave the device.
- Provide a Parent Mode in the same app on iPad, iPhone, and Mac Catalyst so parents on any Apple device can review progress and receive actionable notifications.
- Build on Apple-native frameworks (SwiftUI, SwiftData, Speech, AVFoundation, CloudKit) with no custom backend.
- Keep the software architecture ready for additional L1 profiles from day one, even though v1 bundles only Japanese.

### Non-Goals (for v1)

- Not a general-purpose early-literacy app. mora targets dyslexic L2 English learners specifically.
- Not a replacement for IEP evaluation or certified tutoring. It is a daily practice environment.
- Not a content-authoring platform for third-party tutors.
- Not a multi-L1 launch. v1 ships with a `JapaneseL1Profile` only.
- Not a handwriting / spelling product in v1. Spelling via dictation and Apple Pencil handwriting are deferred to v2.
- Not a cloud LLM product. No request ever leaves the device for content generation or assessment at runtime.

## 4. Approach: Balanced Foundation

Three phasing strategies were considered (see brainstorming session): "Child-First Sprint" (fastest to the child, A only in v1), "Balanced Foundation" (A+C rotation from v1, LLM deferred), and "Full Stack v1" (on-device LLM in v1). Balanced Foundation was chosen because:

- **A-only would likely bore the child within weeks.** The interest-based story payoff of C is essential for sustained daily use.
- **On-device LLM in v1 would extend delivery to 4–6 months.** The family is already losing time while ESL is pending; a 2–3 month v1 is worth more than a 6-month v1.
- **Template + library content is pedagogically sound.** Decodability can be guaranteed, and Yutaka can hand-curate the initial library in a one-time 6–10 hour investment.

### Phasing

| Phase | Scope | Estimated effort |
|---|---|---|
| v1 | A+C daily rotation, pre-authored story library, template engine, Apple Speech, Parent Mode with CloudKit sync, Japanese L1 profile only | 8–12 weeks |
| v1.5 | On-device LLM vocabulary expander (Apple Intelligence Foundation Models or MLX + Gemma 2 2B), adaptive plan refinements | +6 weeks |
| v2 | Spelling/dictation, Apple Pencil handwriting, a second L1 profile to validate the abstraction, optional parental cloud dashboard | +3 months |

## 5. Pedagogy Model

mora follows OG principles:

- **Systematic:** Skills introduced in a fixed order (L1 → L2 → L3 → L4). Nothing is skipped.
- **Cumulative:** New patterns use only previously taught graphemes. Decodable texts are filtered against the learner's mastered set plus the current target.
- **Explicit:** Every rule is explained in words; the L1 profile supplies an auxiliary explanation in the learner's native language.
- **Multisensory:** Every activity combines at least two of: see (visual text), hear (TTS), say (ASR-assessed reading), point (tap).
- **L1-aware:** Confusion pairs known to affect the learner's L1 population are explicitly discriminated early and often.

### Curriculum Ladder (OG-inspired, Barton-aligned)

| Level | Content | v1 treatment |
|---|---|---|
| L1 | Phonemic awareness | Used in the first-run diagnostic and as a warmup; not the main event. |
| L2 | Consonants + short vowels (CVC) | v1 **core** — roughly 10–15 rules. |
| L3 | Blends, digraphs, closed syllables | v1 **core** — roughly 10–15 rules. |
| L4 | Multisyllabic / syllable division | v1 **preview** — simple compound words appear late in v1. |
| L5–L7 | Long vowels, vowel teams, silent-e | v2. |
| L8+ | Morphology, roots, vocabulary | v3+. |

### Japanese L1 Interference Pairs (v1 priority monitoring)

These are the pairs the assessment engine watches for explicitly when classifying ASR errors:

- `/r/ ↔ /l/` (e.g., light / right, rock / lock)
- `/f/ → /h/` (fat / hat)
- `/v/ → /b/` (vat / bat)
- `/θ/ → /s/` or `/t/` (thin / sin / tin)
- `/æ/ ↔ /ʌ/` or `/ɛ/` (cat / cut / ket)
- Consonant-cluster epenthesis (stop → "sutoppu")

These pairs live on `JapaneseL1Profile.interferencePairs` and are not hardcoded in the engine. A Korean or Mandarin profile would declare its own set.

## 6. V1 Curriculum Scope Summary

- **Core bands:** L2 + L3, roughly 20–30 rules total.
- **Initial diagnostic:** 3–5 minute L1 (phonemic awareness) screen at first launch to seed the adaptive plan.
- **Preview:** a small handful of L4 simple multisyllable words (sunset, picnic, hotdog) late in v1 to hint at progression.
- **Discrimination drills:** up to 6 high-priority pairs from the active L1 profile.
- **Target cadence:** one target grapheme per week; the whole OG Systematic principle is that the target does not change mid-day or mid-session.

## 7. Daily Session Flow

Each day the app picks A or C based on the week's rotation (Mon = intro, Tue = A, Wed = C, Thu = A, Fri = C; weekends off by default).

### A Day — Core Decoder (~16–17 minutes)

1. **Warmup (2 min)** — Quick review of the prior session's sound. TTS plays the sound, child taps the correct grapheme among three candidates.
2. **New Rule (3 min)** — Explicit introduction of the week's target (e.g., "sh is two letters that make one soft `/ʃ/` sound"). Child hears, repeats into ASR, and sees a worked example.
3. **Decoding (6 min)** — 15 words containing the target. Child reads aloud; ASR assesses; misses immediately fall into a scaffolded prompt ladder.
4. **Short Sentences (4 min)** — 3 to 5 short interest-based sentences from the template engine, each containing the target.
5. **Completion (1–2 min)** — Streak animation, XP awarded, tomorrow teased.

### C Day — Reading Adventure (~17–19 minutes)

1. **Warmup (2 min)** — Timed re-read of 5 words from the A day.
2. **Discrimination Drill (3 min)** — Minimal-pair discrimination on the current L1 interference set (e.g., `ship` vs `chip`).
3. **Story (8 min, the main event)** — A pre-authored decodable passage from `StoryLibrary`, chosen by theme match to the learner's interests and containing the week's target. Read sentence by sentence with ASR; failures trigger TTS prompts and fall back to echo-reading.
4. **Word Callouts (2 min)** — Five words extracted from the passage, re-read for fluency.
5. **Completion (1–2 min)** — Streak + "next chapter unlocked" framing for episodic stories.

### Scaffolding When Stuck

- 2 seconds of silence → TTS offers the target sound as a hint.
- 2 consecutive misses → app plays the correct word and switches to "repeat after me" echo mode.
- 5 consecutive misses on the same target within a session → app asks the child if they'd like an adult to come look; a Parent Mode notification is sent.

### Dyslexia-Friendly UX

- Fonts: OpenDyslexic or Lexie Readable (toggleable; default OpenDyslexic).
- Generous line spacing and letter spacing.
- Warm off-white background rather than pure white; never pure-black text on pure-white.
- Large touch targets, no time pressure on first-look reads.

## 8. System Architecture

### Layered Decomposition

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Presentation (SwiftUI)                                   │
│   SessionView · DecodeActivityView · StoryActivityView      │
│   DrillView · StreakView · ParentView                       │
├─────────────────────────────────────────────────────────────┤
│ 2. Orchestration (Domain, pure Swift)                       │
│   SessionOrchestrator · ActivityEngine · CurriculumEngine   │
│   AssessmentEngine · AdaptivePlanEngine · EscalationManager │
├─────────────────────────────────────────────────────────────┤
│ 3. Services                                                 │
│   ContentProvider (protocol) · TemplateEngine · StoryLibrary│
│   LLMVocabularyExpander [v1.5] · InterestCapture            │
├─────────────────────────────────────────────────────────────┤
│ 4. On-Device AI (Apple frameworks)                          │
│   SFSpeechRecognizer · AVSpeechSynthesizer                  │
│   Core ML + MLX [v1.5] · Foundation Models [v1.5]           │
├─────────────────────────────────────────────────────────────┤
│ 5. Persistence (local)                                      │
│   SwiftData · FileStorage · Keychain                        │
├─────────────────────────────────────────────────────────────┤
│ 6. Cloud (CloudKit private DB only)                         │
│   Family pairing · Summary sync · Push notifications        │
└─────────────────────────────────────────────────────────────┘
```

### Platform Targets

- **iPadOS 17+** — Primary platform for Child Mode and Parent Mode.
- **iOS 17+** — Parent Mode fully supported; Child Mode works but is not layout-optimized (small screen is not ideal for reading practice). Useful for travel.
- **macOS 14+ via Mac Catalyst** — Parent Mode fully supported (weekly review, PDF export, wider-screen skill map). Child Mode technically runs but is not a target use case.
- **iOS 18+** — Required to enable v1.5 LLM features through Apple Intelligence Foundation Models. v1 runs on iOS 17 without them.

Delivered as a single Universal app target with SwiftUI layouts that adapt via `@Environment(\.horizontalSizeClass)` and Mac Catalyst idiom checks.

### Offline-First Learning Loop

Every runtime dependency of the learning loop is local:

- ASR via on-device `SFSpeechRecognizer` (iOS 13+ supports on-device recognition; `supportsOnDeviceRecognition` is required).
- TTS via `AVSpeechSynthesizer` with pre-downloaded enhanced voices.
- Content via `TemplateEngine` + bundled `StoryLibrary`.
- Storage via `SwiftData`.

CloudKit is used only for Parent Mode sync and parent notifications. A failed CloudKit operation never blocks the child's daily session.

### Data Flow — A Single Activity

```
SessionOrchestrator
  → CurriculumEngine.nextTarget()             // "sh"
  → ContentProvider.decodeWords(              // concrete implementor
        target: "sh",
        level: 3,
        interests: [.pokemon]
     )
  → DecodeActivityView renders the list
  → Child speaks; SFSpeechRecognizer transcribes
  → AssessmentEngine.score(
        expected: "ship",
        heard: "sip",
        l1Profile: JapaneseL1Profile.current
     )
     → { correct: false, error: .substitution("sh", "s"), l1Tag: nil }
  → AdaptivePlanEngine.record(skill: "sh_onset", result: .miss)
  → SwiftData persist
  → EscalationManager.check()                 // may trigger parent notification
```

## 9. Multi-L1 Architecture Principle

v1 bundles only Japanese, but no L1-specific logic is hardcoded in the engine layer. All L1-dependent behavior flows through the `L1Profile` abstraction:

```swift
protocol L1Profile {
    var identifier: String { get }            // "ja", "ko", "zh", "es", ...
    var uiStrings: LocalizedBundle { get }
    var explanatoryAudio: AudioBundle { get } // native-language "this sound is..." clips
    var interferencePairs: [PhonemeConfusionPair] { get }
    var discriminationDrills: [DrillSet] { get }
    var interestCategories: [InterestCategory] { get }
    var scaffoldMessages: ScaffoldMessageBundle { get }
    var characterSystem: CharacterSystem { get } // alphabetic / logographic / mixed
}

struct JapaneseL1Profile: L1Profile { ... }  // v1
// struct KoreanL1Profile: L1Profile { ... } // v2+
// struct MandarinL1Profile: L1Profile { ... } // v2+
```

Rules:

- No `if locale == "ja"` branches anywhere in app code.
- All human-visible text routes through `currentL1Profile.uiStrings`.
- The assessment engine consults `currentL1Profile.interferencePairs` to tag errors.
- Interest icon sets are L1 profile–provided (a Mandarin profile may include 武侠; a Korean profile may include K-pop).
- Adding a new L1 in v2 requires adding a profile struct, audio assets, and localized strings — no engine code changes.

## 10. Content Generation Pipeline

### Development-Time: Story Library Construction

Built once before v1 ships, and expanded opportunistically later:

1. For each (level, target, theme) triple in a planning matrix, prompt Claude or GPT with strict constraints:
   - Allowed graphemes (based on what is "taught" up to and including the target).
   - Theme nouns/vocabulary.
   - Length (3–8 short sentences).
   - Episodic arc if part of a series.
2. Automated decodability verification rejects drafts using untaught graphemes.
3. Yutaka proofs and lightly edits accepted drafts.
4. Approved stories are serialized as bundled JSON.

**Target for v1:** ~50 stories across ~6 universal themes (animals, dinosaurs, sports, space, vehicles, robots). Estimated investment: 6–10 hours, one-time.

Character- or franchise-specific content (Pokémon, Splatoon, Kimetsu no Yaiba, etc.) is intentionally **not** in the bundled library for licensing and freshness reasons. Those flavors appear at runtime via the template engine using parent-configured interest vocabularies.

### Runtime: Template Engine

Deterministic composition, no LLM dependency:

- 15–20 sentence skeletons, each with typed slots (`{subject}`, `{verb}`, `{noun}`, `{adjective}`).
- Per-interest-category vocabularies (~30 words each), each tagged with pedagogy metadata (which graphemes they use).
- Slot filling picks only vocabulary whose graphemes are already mastered or match the current target.
- Decodability filter is the final gate. Any candidate sentence that fails is discarded and re-rolled.

Example:

```
skeleton:   "The {subject} can {verb}. It has a {noun}."
slots: {
  subject ∈ [shark, dog, Pikachu, T-Rex],
  verb    ∈ [run, hop, sit, dash],
  noun    ∈ [shell, bat, hat, ship]
}
→ "The Pikachu can dash. It has a ship."
```

### Runtime: StoryLibrary Selection

For C days, the 8-minute story slot is drawn from the bundled library. Selection criteria:

- Contains the current week's target grapheme.
- Matches at least one of the learner's declared interests.
- Not read within the last N sessions (freshness window).
- Or, if it **is** a repeat, is flagged for intentional fluency re-read.

Stories can be episodic (`Rex Ch. 1`, `Rex Ch. 2`) to support continuity framing.

### Runtime: LLMVocabularyExpander (v1.5)

Added in v1.5 without restructuring anything:

- Only expands `{subject}` / `{noun}` slots for interests where the bundled vocabulary is thin.
- Model candidates: Apple Intelligence Foundation Models (iOS 18+) first; MLX-hosted Gemma 2 2B as a fallback on earlier OS.
- LLM output is treated as untrusted and runs through the decodability filter before slot binding.
- If LLM output does not yield any valid candidate within a budget, fall back to the static vocabulary — the session never stalls.

### Interest Capture

- **Initial setup:** The child picks 3–5 interests from a visual icon grid (12–18 icons provided by the current `L1Profile.interestCategories`).
- **Parent-authored additions:** Inside Parent Mode, parents can type free-form interest names (e.g., "Splatoon", "Kimetsu no Yaiba"), which become vocabulary cards usable by the template engine.
- **Lightweight online learning:** At session close, the child taps a "did you like today's story?" face. Results feed an in-app interest weight.

## 11. Assessment & Adaptive Plan

### Skill State Machine

Each skill (phoneme / grapheme / pattern) moves through:

```
New --(introduced)--> Learning --(≥85% over 20 trials)--> Mastered
                          ↑                                  ↓
                          └────(SRS review failure)─────── Shaky
```

Spaced-repetition review intervals for Mastered items: **1 day → 3 days → 7 days → 14 days**, then monthly maintenance.

### Assessment Pipeline

1. `SFSpeechRecognizer` returns a transcript and confidence.
2. `AssessmentEngine` compares transcript to expected word using both orthographic and phoneme-level edit distance.
3. Each error is classified as `substitution`, `omission`, `insertion`, or `none`.
4. Errors are then checked against `currentL1Profile.interferencePairs`. A match tags the trial (e.g., `l1InterferenceTag: "r_l_swap"`).
5. A moving-average accuracy per skill is updated.
6. Weekly (not daily) the `AdaptivePlanEngine` picks the next target, preferring (a) weak skills, (b) due SRS reviews, (c) next OG step.

### Why Weekly Plan Updates

Daily retargeting would violate the OG Systematic principle. A child immersed in this week's `sh` should not see `th` sneak in on Wednesday. Weekly cadence also makes it possible for the parent to track "this week we are on `sh`."

### Parent Escalation Ladder

| Rung | Trigger | Response |
|---|---|---|
| L1: Auto recovery | 2 seconds of silence; 2 consecutive misses | TTS hint; switch to echo-repeat mode |
| L2: Session flag | 5 consecutive misses | In-session "let's take a breath" + swap to lighter activity |
| L3: In-session parent call | 10+ misses on the same target within one session | "Should we ask an adult?" prompt; if accepted, parent device receives a high-priority push; app surfaces a parent-facing explanation card |
| L4: Weekly alert | Same skill goes Shaky across three consecutive sessions | Flagged in the weekly report as an "attention item" |

## 12. Parent Experience

Parent Mode runs inside the **same binary** across iPad, iPhone, and Mac Catalyst. Parents install the app on any of these devices.

### Pairing

- First-run on the child device displays a QR code encoding a CloudKit share URL.
- The parent opens the app on their device and either scans the QR code or pastes a short text code.
- If both accounts are already in the same iCloud Family, the share can be auto-proposed without the QR step.
- On Mac Catalyst, the "scan QR" path falls back to a paste-the-code flow.

### What Parent Mode Shows

- **Dashboard:** Today's streak, current week's target, session status, 7-day accuracy trend.
- **Skill Map:** Visual OG ladder showing which skills are New / Learning / Mastered / Shaky with per-skill accuracy bars.
- **Session Detail:** A summary of the most recent session — which words were missed, which were nailed. Raw audio is *not* synced; parents only see summaries.
- **Weekly Report:** Autogenerated every Saturday morning; highlights mastered items, attention items, and interest signals.
- **Settings:** Interest management, notification preferences, escalation thresholds, NG-word list, ASR strictness.
- **Assist Panel:** When an L3 escalation fires, the parent sees a card with the specific skill, the words that failed, and a short Barton-style script for helping.

### Notifications (APNs via CloudKit Subscriptions)

| Category | Default | Purpose |
|---|---|---|
| Daily complete | OFF | "Finished today's quest; 7-day streak" |
| Weekly report | ON (Sat AM) | "This week's report is ready" |
| Shaky alert | ON | "`th` mastery has slipped; weekend review recommended" |
| Help request | ON | "Your child is asking for help right now" |

All categories are individually toggleable in Parent Mode settings.

### Mac Catalyst Specifics

- Parent Mode gets a proper sidebar navigation when running as a Catalyst app.
- PDF export of weekly reports is first-class on macOS.
- Skill Map takes advantage of wider screens for a more detailed phoneme grid.

## 13. Data Model

Defined with SwiftData. Models flagged "local-only" are never written to the CloudKit container.

```swift
@Model final class Learner {
    var id: UUID
    var displayName: String
    var birthYear: Int
    var l1Identifier: String           // "ja"
    var interests: [InterestCategory]
    var createdAt: Date
    var familyShareID: String?         // for CloudKit pairing
}

@Model final class Skill {
    var code: String                   // "sh_onset", "short_a", ...
    var level: Int                     // 1..8
    var state: SkillState              // enum: .new .learning .mastered .shaky
    var accuracy: Double               // moving average 0..1
    var trialCount: Int
    var lastReviewedAt: Date?
    var nextReviewDue: Date?
}

@Model final class SessionSummary {
    var id: UUID
    var date: Date
    var sessionType: SessionType       // .coreDecoder(A) .readingAdventure(C)
    var targetSkillCode: String
    var durationSec: Int
    var trialsTotal: Int
    var trialsCorrect: Int
    var struggledSkillCodes: [String]
    var escalated: Bool
}

// Local-only. Never synced. Provides detail for Parent Mode's "Session Detail".
@Model final class Performance {
    var id: UUID
    var sessionId: UUID
    var skillCode: String
    var expected: String
    var heard: String?
    var correct: Bool
    var l1InterferenceTag: String?
    var timestamp: Date
}

@Model final class EscalationEvent {
    var id: UUID
    var timestamp: Date
    var level: Int                     // 1..4
    var skillCode: String
    var notified: Bool
}

@Model final class WeeklyRollup {
    var id: UUID
    var weekStart: Date
    var summary: String
    var attentionItemSkillCodes: [String]
    var masteredSkillCodes: [String]
}

@Model final class InterestCategory {
    var key: String                    // "pokemon", "dinosaurs"
    var displayName: String
    var enabled: Bool
    var parentAuthored: Bool
}
```

### CloudKit Sync Policy

Synced record types: `Learner`, `Skill` (aggregate fields only), `SessionSummary`, `EscalationEvent`, `WeeklyRollup`, `InterestCategory`.

Never synced: `Performance`, raw audio files, interest interaction logs.

Raw audio is retained locally for 24 hours to support parent review of disputed trials, then auto-deleted.

## 14. Error Handling

Technical errors are handled such that the child's session never breaks visibly. Pedagogical correctness concerns (especially ASR false negatives) get their own treatment.

| Error | Severity | Response | UX |
|---|---|---|---|
| ASR silence timeout | Low | TTS hint; switch to echo-repeat mode | "Let's listen again" |
| ASR recognition failure | Medium | Auto-retry once, then L1 scaffold | "One more try" — no miss counted yet |
| Microphone denied | High | Degrade to tap-only activities | "Today we'll do this with taps" |
| TTS voice missing | Medium | First-run prompts enhanced voice download | Handled in setup |
| CloudKit sync failure | Low | Retry queue; learning unaffected | Parent side shows "last sync: 2h ago" |
| Content shortage | High | Fallback chain: Library → Template → review drill | Invisible to child |
| LLM inference failure (v1.5) | Low | Feature flag off; template-only path | Invisible to child |
| SwiftData corruption | High | Attempt CloudKit restore; else clean reset | Parent Mode shows "repairing data" |

### Special Case: ASR False Negatives

Falsely counting a correctly-spoken word as wrong is the most motivation-damaging error mode. Mitigations:

- **Leniency scaling:** newly-introduced words use a looser edit-distance threshold; mastered words tighten.
- **Parent override:** Parent Mode provides "this trial was actually correct" to retroactively flip a recorded miss.
- **Adaptive relaxation:** three identical misses on the same word within a session dynamically loosen the threshold (it may be the child's idiolect).
- **24-hour audio retention:** local-only retention window lets parents sanity-check disputed trials.

## 15. Testing Strategy

### Layer 1: Unit (Swift code tests)

- `CurriculumEngine` target selection under varied learner states.
- `AssessmentEngine` scoring against canned ASR transcripts.
- `AdaptivePlanEngine` state-machine transitions.
- `TemplateEngine` slot filling and decodability filtering.
- `JapaneseL1Profile` interference-pair detection.

### Layer 2: Integration (flow tests)

- Full A day walkthrough: warmup → decode → sentences → streak.
- Full C day walkthrough: warmup → drill → story → recap.
- Mock CloudKit sync round-trip.
- Escalation L1 → L2 → L3 transitions.
- Content shortage fallback chain.

### Layer 3: Pedagogy (content and methodology)

- **Decodability audit.** Every story in the library and every template output, across every allowed interest set, uses only graphemes present in the target's "taught or being taught" set.
- **Golden sessions.** A corpus of 30–50 (learner state, expected next lesson) pairs codified and run in CI. A change that breaks a golden session requires explicit justification.
- **Systematic principle.** No session contains two different targets.
- **L1 interference detection.** Simulated mispronunciations get classified correctly.
- **SRS interval compliance.** Mastered skills re-appear at 1 / 3 / 7 / 14 day intervals ± tolerance.

### Layer 4: User (field validation)

- **Weekly retrospective with the child.** Actual usage logs reviewed in Parent Mode.
- **TestFlight α** with family only, minimum two weeks.
- **TestFlight β** (if feasible) with 3–5 families of Japanese L1 dyslexic learners.
- **ASR false-negative rate** counted weekly; goal < 5% per session.
- **Story preference tap data** drives interest weight adjustment.
- **Visibility A/B** on font (OpenDyslexic vs Lexie Readable) and background color.
- **Parent Mode cross-platform** verification: the same sync event is received on iPad, iPhone, and Mac Catalyst within acceptable latency.

### Release Gates

- **α → β:** All unit + integration + pedagogy tests green. Decodability audit 100%. One human-used week with no daily-session-breaking bugs.
- **β → App Store:** ASR false negatives < 5% per session on β user logs. Golden sessions all green. No outstanding High-severity errors in the taxonomy.

## 16. Roadmap

### v1 (8–12 weeks)

- SwiftUI Universal app scaffolding (iPad / iPhone / Mac Catalyst).
- `SessionOrchestrator` + A-day and C-day flows.
- `CurriculumEngine`, `AssessmentEngine`, `AdaptivePlanEngine` (weekly cadence).
- `ContentProvider` protocol with `TemplateEngine` + `StoryLibrary` implementations.
- Pre-authored story library (~50 stories, 6 themes).
- `SFSpeechRecognizer` + `AVSpeechSynthesizer` integration.
- `JapaneseL1Profile` with interference pair handling.
- `EscalationManager` with four-rung ladder.
- SwiftData data model.
- CloudKit private DB sync + APNs push for Parent Mode.
- Parent Mode on iPad / iPhone / Mac Catalyst.
- Pedagogy test layer including decodability audit and golden sessions.

### v1.5 (+6 weeks)

- `LLMVocabularyExpander` (Apple Intelligence Foundation Models; MLX+Gemma fallback).
- Adaptive plan refinements based on real usage data.
- More stories authored; more themes.
- Mac Catalyst UX polish (sidebar, PDF export of weekly reports).

### v2 (+3 months after v1.5)

- Spelling / dictation activity (typed and Apple Pencil handwriting).
- A second `L1Profile` implementation (Korean or Mandarin) to stress-test the abstraction.
- Deeper analytics for parents (skill-chain views).
- Optional richer cloud dashboard (opt-in; still Apple-native).

## 17. Open Questions

The following are not resolved by this spec and should be addressed during planning or early implementation:

1. **Story-library authoring tooling.** Will Yutaka author stories inside a dedicated Mac tool, or edit JSON directly with a decodability linter? The former is more pleasant and could itself ship as part of v1.5 Parent Mode.
2. **Voice selection for TTS.** `en-US` enhanced voices differ across iPadOS versions. Which specific voice IDs to prefer, and what fallback order?
3. **Session scheduling on school days.** Should the app require daily use to maintain a streak, or offer "rest days" so that missing a day does not break motivation?
4. **Handwriting placement.** Apple Pencil handwriting is v2, but if it turns out to be motivationally important during α testing with the child, we may need to promote a minimal "trace the letter" activity into v1.5 rather than v2.
5. **CloudKit Family Sharing UX details.** iCloud Family can automatically propose shares, but not all families are configured that way. The QR/code pairing flow must be robust without it.
6. **ASR availability on older iPads.** `SFSpeechRecognizer.supportsOnDeviceRecognition` is locale- and hardware-dependent. The target device list should be tested before v1 release.
7. **Second-language UI strings.** `JapaneseL1Profile` supplies Japanese UI strings. Should English fallbacks be bundled in v1 (for when the parent navigates the app in English-language mode), or deferred to v2?
