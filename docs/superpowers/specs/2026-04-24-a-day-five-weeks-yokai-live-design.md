# A-Day Five Weeks + Yokai Live — Design Spec

- **Date:** 2026-04-24
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Project:** `mora`
- **Relates to:**
  - `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md` (canonical product spec)
  - `docs/superpowers/specs/2026-04-23-rpg-shell-yokai-design.md` (yokai RPG shell spec)
- **Scope:** Realign the v1 skill ladder to the bundled yokai cast, drive a real weekly rotation through five A-day weeks, and wire the dormant `YokaiOrchestrator` into live sessions. No C-day work, no Parent Mode, no new SwiftData entities.

---

## 1. Overview

The v1 alpha is currently stuck on a single hard-coded decoding week (`sh`). Every session loads `bundledShWeek1()`, every warmup asks "which one says /ʃ/?", and the `YokaiOrchestrator` — despite R1–R5 having shipped engine, UI, and assets — is never constructed from `SessionContainerView`. Meanwhile the bundled yokai cast (`sh, th, f, r, short_a`) and the v1 L3 skill ladder (`sh, ch, th, ck`) do not overlap, so even if we wired yokai up today only `sh` and `th` would have a character. Three of the yokai assets are dead weight and two curriculum weeks have no character support.

This spec realigns the pieces so a single weekly cadence drives everything. The v1 ladder becomes the yokai cast in narrative order (`sh → th → f → r → short_a`). Four new decoding-content JSON files cover the remaining four weeks. `YokaiEncounterEntity` becomes the authoritative source for "which week is the learner on". `SessionContainerView.bootstrap` resolves the active encounter, picks the matching skill, builds both orchestrators, and passes the yokai into the session. Monday-intro and Friday-befriend cutscenes fire on session-count milestones, not on calendar days, so the learner can skip a day without breaking the arc.

The work lands as two PRs on top of `main`:

- **PR 1 — Curriculum Spine** realigns the ladder, adds per-skill warmup candidates and yokai IDs, authors four new content JSONs, and adds the week-rotation driver. It does not touch yokai UI; `YokaiOrchestrator` stays `nil` at the session boundary.
- **PR 2 — Yokai Live Wiring** constructs `YokaiOrchestrator` in bootstrap, wires Monday intro / Friday befriend flows, implements the floor guarantee, and hands off to the bestiary on befriending.

A side branch handles adult-proxy fixture recordings and `PhonemeThresholds` calibration in parallel. The MLX warmup gate shipped in PR #71 (`73e0d6e`, 2026-04-24) and is already on `main`; this spec's PR 1 is written assuming `MLXWarmupState` and the gated "はじめる" CTA are present.

## 2. Motivation & Context

The child has been using the sh-week content alone for long enough that engagement is fraying. The canonical product spec (§4) says explicitly "A-only would likely bore the child within weeks", and even within A-day the current single-target loop compresses that timeline further: five consecutive sessions ask the same question, decode the same words, and play the same three sentences. Narrative variety is the cheapest lever available — we already own five yokai with portraits and voice clips, and four usable weeks of phoneme targets that the learner needs for L1-interference reasons (`th/f/r/æ`). Putting those into the weekly rotation is a two-PR job.

It also unblocks a pile of tests and dogfooding that is currently gated on there being more than one week. The `SystematicPrincipleTests` that the canonical spec §15 calls for — "no session contains two different targets" — cannot be meaningfully written until rotation exists. `BestiaryView` has no entry path except through R5 unit tests. The `Skill` domain type still has no warmup-candidate field, so `SessionContainerView.bootstrap` hardcodes `[s, sh, ch]` as an inline literal.

Finally, the MLX warmup gate and WarmupView full prompt TTS (PR #71) merged to `main` on 2026-04-24. That work and this work are independent and additive; PR 1 is authored against post-#71 main directly, not rebased.

## 3. Goals & Non-Goals

### Goals

- G1: v1 alpha ladder aligned 1-to-1 with bundled yokai cast: `[sh_onset, th_voiceless, f_onset, r_onset, short_a]`.
- G2: Weekly rotation driven by `YokaiEncounterEntity` (authoritative), advancing on session-count milestones.
- G3: Four new bundled decoding-content JSONs (`th_week.json`, `f_week.json`, `r_week.json`, `short_a_week.json`).
- G4: `YokaiOrchestrator` constructed in live sessions; Monday intro + Friday befriend cutscenes visible; bestiary card earned at `.befriended` transition.
- G5: Friday floor-guarantee: final-session correct trials ramp the friendship meter to exactly 100% regardless of prior pace (spec §6.1 requirement).
- G6: Systematic-principle regression test prevents future cross-target drift.

### Non-Goals (this spec)

- C-day Reading Adventure (Story Library, discrimination drills, word callouts). Deferred to a later plan.
- AdaptivePlanEngine / SkillState transitions / SRS intervals.
- Parent Mode, CloudKit, APNs, escalation ladder.
- L1 phonemic-awareness initial diagnostic.
- Adding new SwiftData entities or migrations.
- LLMVocabularyExpander (v1.5).
- Wild yokai cameos during SRS reviews (`YokaiCameoEntity` stays inactive).
- Rewriting the tile-board scaffold or assessment evaluators.
- PR #71's content (MLX warmup gate + warmup TTS). That merges independently; this spec only rebases on top of it.

### Success Criteria

- **C1 (Rotation)**: With no prior encounter in the store, bootstrap creates an `sh_onset` encounter and the session renders as the `sh` week. After five completed sessions, the encounter transitions to `.befriended` and the next bootstrap loads the `th_voiceless` week.
- **C2 (Monday intro)**: `sessionCompletionCount == 0` on an active encounter triggers the Monday intro cutscene exactly once per encounter. Launching the app twice on the same day before the first session does not replay it twice.
- **C3 (Friday befriend)**: `sessionCompletionCount == 4` at session start surfaces the Friday befriend framing; session completion brings the meter to 100% regardless of earlier pace, inserts a `BestiaryEntryEntity`, and inserts the next encounter.
- **C4 (Curriculum end)**: After session 5 of the fifth yokai (`short_a`), the app reaches a "curriculum complete" terminal screen and does not crash on next launch. (Minimal screen; re-entry is a later plan.)
- **C5 (Tests)**: `swift test` across all packages passes. New `SystematicPrincipleTests` fails if a session ever mixes targets. New `WeekRotationTests` covers first-launch, mid-week, and end-of-curriculum cases. `WordDecodabilityTests` passes on all four new JSONs.

## 4. Approach — Curriculum Spine First, Yokai Narrative Second

Three shapes were considered:

- **One big PR**: realign ladder, add content, rotate weeks, wire yokai — all together. Rejected because the diff would be ~1500 LOC across curriculum, content, and UI, and a single regression (e.g. broken cutscene trigger) would stall the whole PR.
- **Five layered PRs**: ladder → content → rotation → yokai wiring → befriend/bestiary. Rejected because the stack management overhead dominates the work at this size, and several intermediate states leave the app in a worse place than main (e.g. a PR that advances rotation but has not authored the next week's content).
- **Two PRs — curriculum spine, then yokai narrative**: chosen. PR 1 leaves the app in a strictly-better state (five real weeks, yokai still off). PR 2 adds the narrative overlay on top. The boundary between PRs is crisp: PR 1 does not touch any yokai UI code, PR 2 does not add or modify content or the ladder.

This split also matches review concerns. PR 1 is load-bearing on curriculum correctness and wants tight pedagogy tests (systematic principle, decodability). PR 2 is largely UI plumbing and cutscene triggers, whose review shape is "does it look and feel right on device".

## 5. Scope Split

### PR 1 — Curriculum Spine (~900–1100 LOC)

Directly edits:
- `Packages/MoraCore/Sources/MoraCore/Skill.swift` — add `warmupCandidates: [Grapheme]` and `yokaiID: String?` to `Skill`.
- `Packages/MoraEngines/Sources/MoraEngines/CurriculumEngine.swift` — `defaultV1Ladder()` returns the realigned 5-skill ladder with warmup candidates and yokai IDs filled in. Levels: `sh_onset` and `th_voiceless` stay `.l3` (digraphs). `f_onset`, `r_onset`, `short_a` are `.l2` (single-letter, L1-interference). This reflects the L2/L3 distinction accurately per canonical spec §5.
- `Packages/MoraEngines/Sources/MoraEngines/ScriptedContentProvider.swift` — add `bundled(for: SkillCode)` factory that resolves the appropriate resource file.
- `Packages/MoraEngines/Sources/MoraEngines/Resources/` — four new JSONs: `th_week.json`, `f_week.json`, `r_week.json`, `short_a_week.json`. Same shape as `sh_week1.json`.
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — `bootstrap()` queries `YokaiEncounterEntity`, resolves the active skill, loads the corresponding content, and hardcodes the warmup options from `skill.warmupCandidates`. `SessionOrchestrator` is still constructed with `yokai: nil`.
- Tests per §11.

Does not touch:
- `YokaiOrchestrator`, `YokaiLayerView`, `YokaiCutsceneOverlay`, `BestiaryView`, or any file under `Packages/*/Yokai/`.
- `HomeView` (except possibly changing the hero target display so it reads from the active encounter's skill; this is the smallest edit that keeps the home screen aligned with the session).

### PR 2 — Yokai Live Wiring (~300–500 LOC)

Directly edits:
- `Packages/MoraEngines/Sources/MoraEngines/Yokai/YokaiOrchestrator.swift` — add `resume(encounter:)` for mid-week restart, add `isFridaySession: Bool` flag dispatching `recordTrialOutcome` to the existing Friday-math path, and insert the next encounter on befriend via a `YokaiProgressionSource`.
- `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — construct `YokaiOrchestrator` after resolving the active encounter, pass into `SessionOrchestrator`.
- `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift` — show the active yokai portrait corner (if encounter exists) via the existing `YokaiPortraitCorner`.
- On session complete: if `sessionCompletionCount` reached 5, transition encounter state, insert bestiary entry, insert next encounter. If no next skill, surface a minimal "curriculum complete" destination.
- Tests per §11.

### P2 — Adult-Proxy Fixtures + Calibration (Side Branch)

Unrelated to the rotation/narrative work above; tracked here for visibility.

- User runs `recorder/MoraFixtureRecorder/` on device, captures the 12 adult-proxy fixtures (already unblocked by #58).
- Drops into `~/mora-fixtures-adult/` and runs `dev-tools/pronunciation-bench/`.
- Unskips `FeatureBasedEvaluatorFixtureTests` and tunes `PhonemeThresholds` for child-approximated audio.
- Two small PRs: one to unskip tests, one to adjust thresholds.

## 6. Curriculum Ladder Realignment

```swift
public static func defaultV1Ladder() -> CurriculumEngine {
    let l2Alphabet: Set<Grapheme> = Set(
        "abcdefghijklmnopqrstuvwxyz".map { Grapheme(letters: String($0)) }
    )

    let skills: [Skill] = [
        Skill(
            code: "sh_onset", level: .l3, displayName: "sh digraph",
            graphemePhoneme: .init(grapheme: .init(letters: "sh"), phoneme: .init(ipa: "ʃ")),
            warmupCandidates: [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")],
            yokaiID: "sh"
        ),
        Skill(
            code: "th_voiceless", level: .l3, displayName: "voiceless th",
            graphemePhoneme: .init(grapheme: .init(letters: "th"), phoneme: .init(ipa: "θ")),
            warmupCandidates: [.init(letters: "t"), .init(letters: "th"), .init(letters: "s")],
            yokaiID: "th"
        ),
        Skill(
            code: "f_onset", level: .l2, displayName: "f sound",
            graphemePhoneme: .init(grapheme: .init(letters: "f"), phoneme: .init(ipa: "f")),
            warmupCandidates: [.init(letters: "f"), .init(letters: "h"), .init(letters: "v")],
            yokaiID: "f"
        ),
        Skill(
            code: "r_onset", level: .l2, displayName: "r sound",
            graphemePhoneme: .init(grapheme: .init(letters: "r"), phoneme: .init(ipa: "r")),
            warmupCandidates: [.init(letters: "r"), .init(letters: "l"), .init(letters: "w")],
            yokaiID: "r"
        ),
        Skill(
            code: "short_a", level: .l2, displayName: "short a",
            graphemePhoneme: .init(grapheme: .init(letters: "a"), phoneme: .init(ipa: "æ")),
            warmupCandidates: [.init(letters: "a"), .init(letters: "u"), .init(letters: "e")],
            yokaiID: "short_a"
        ),
    ]

    return CurriculumEngine(skills: skills, baselineTaughtGraphemes: l2Alphabet)
}
```

Warmup distractor selection follows the L1 interference pairs from `JapaneseL1Profile`:
- `sh` → `s` (JP /s/ substitution) + `ch` (digraph confusable).
- `th` → `t` (JP /t/ substitution per §5 interference pair) + `s` (alternative substitution).
- `f` → `h` (JP /f/→/h/ substitution) + `v` (same-place confusable).
- `r` → `l` (JP r/l swap) + `w` (approximant confusable).
- `short_a` → `u` (JP æ/ʌ confusion) + `e` (JP æ/ɛ confusion).

This keeps the warmup pedagogically useful across the full ladder, not just for `sh`.

## 7. Week Rotation Model

`YokaiEncounterEntity` is the authoritative source. No calendar date logic — the spec §6 "Mon/Tue/Wed/Thu/Fri" framing maps to `sessionCompletionCount ∈ 0..4` on the active encounter.

### Bootstrap flow

```swift
@MainActor
private func resolveActiveSkill(
    context: ModelContext,
    ladder: CurriculumEngine,
    clock: () -> Date = Date.init
) throws -> (Skill, YokaiEncounterEntity) {
    var descriptor = FetchDescriptor<YokaiEncounterEntity>(
        predicate: #Predicate { $0.stateRaw == YokaiEncounterState.active.rawValue },
        sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
    )
    descriptor.fetchLimit = 1
    let active = try context.fetch(descriptor).first

    if let enc = active,
       let skill = ladder.skills.first(where: { $0.yokaiID == enc.yokaiID })
    {
        return (skill, enc)
    }

    // First launch or corrupt state: start at the first skill.
    let first = ladder.skills[0]
    let enc = YokaiEncounterEntity(
        yokaiID: first.yokaiID!,
        weekStart: clock(),
        state: .active,
        friendshipPercent: 0
    )
    context.insert(enc)
    try context.save()
    return (first, enc)
}
```

### Advance flow (PR 2 only)

At session completion (in `SessionOrchestrator`'s completion phase, routed via `CompletionView.persistSummary`), the yokai orchestrator already increments `encounter.sessionCompletionCount`. We extend that path:

```swift
if encounter.sessionCompletionCount >= 5 {
    encounter.state = .befriended
    let bestiary = BestiaryEntryEntity(yokaiID: encounter.yokaiID, befriendedAt: clock())
    context.insert(bestiary)

    if let nextSkill = ladder.nextSkill(after: currentSkill) {
        let next = YokaiEncounterEntity(
            yokaiID: nextSkill.yokaiID!,
            weekStart: clock(),
            state: .active,
            friendshipPercent: 0
        )
        context.insert(next)
    }
    try context.save()
}
```

`CurriculumEngine.nextSkill(after:)` is a new helper returning `nil` when the current skill is the last in the ladder.

### Why session-count, not calendar days

- The spec §6 timeline was written assuming a 5-sessions-per-week cadence, one per weekday. The child's actual cadence is noisier (weekend practice, skipped school days). Hardcoding calendar-day logic would either penalize skipped days (advancement stalls) or double-advance on catch-up days. Counting completed sessions is monotonic, matches what the child observes, and reads cleanly from one persisted field.
- The "Monday intro is the first session; Friday befriend is the fifth" framing stays intact visually. Per-day labels in `MoraStrings` can still read "Today is Monday with `sh`" on `sessionCompletionCount == 0` if we want that affect; not in scope for this spec.

## 8. Data Model Changes

### `Skill` (MoraCore value type)

Add:
```swift
public let warmupCandidates: [Grapheme]   // length 3, must include graphemePhoneme.grapheme
public let yokaiID: String?               // nil for skills without a bundled yokai
```

No SwiftData migration (value type). Existing `Skill(...)` call sites that omit the new fields continue to work because the new fields take default values (`[]` and `nil`). v1 ladder skills populate both fields.

### `YokaiEncounterEntity`

No changes. Existing fields (`yokaiID`, `weekStart`, `stateRaw`, `friendshipPercent`, `correctReadCount`, `sessionCompletionCount`) already cover the rotation model.

### Other entities

No changes to `BestiaryEntryEntity`, `SessionSummaryEntity`, `LearnerProfile`, `DailyStreak`, `PronunciationTrialLog`, or `YokaiCameoEntity`. PR 1 touches no `@Model` types; PR 2 reads/writes existing ones through existing fields.

### Migration impact

Zero. `MoraModelContainer.schema` is unchanged. Existing users (the child's device) preserve their `DailyStreak` and any in-flight encounters on upgrade.

## 9. Content JSON Requirements

Each new file mirrors `sh_week1.json` shape:

```json
{
  "target": { "letters": "<grapheme>", "phoneme": "<ipa>" },
  "l2_taught_graphemes": [ "a", "b", ... "z" ],
  "decode_words": [
    { "surface": "<word>", "graphemes": [...], "phonemes": [...], "note": "<onset|coda>" },
    ... 10 entries total
  ],
  "sentences": [
    { "text": "<sentence>", "words": [ { surface, graphemes, phonemes }, ... ] },
    ... 3 entries total
  ]
}
```

### Per-week composition

- `th_week.json` — target `{th, θ}`, taught = L2 alphabet + `sh` (from completed week). Candidate decode words: `thin, thud, thick, bath, math, path, moth, thump, thug, with`. Sentences: 3, each containing at least one target-bearing word.
- `f_week.json` — target `{f, f}`, taught = L2 alphabet + `sh` + `th`. Candidates: `fan, fig, fog, fat, fit, fun, if, off, puff, cuff`. Simple CVC and CVCC with `f` in onset or coda.
- `r_week.json` — target `{r, r}`, taught = L2 alphabet + `sh` + `th` + `f`. Candidates: `run, red, rat, rag, rib, rot, rub, rip, ram, rig`. Avoid /r/-colored vowels (too complex for L2) and avoid digraphs we haven't taught.
- `short_a_week.json` — target `{a, æ}`, taught = L2 alphabet + `sh` + `th` + `f` + `r`. Candidates: `cat, bat, rat, fan, ran, map, mad, bad, pat, sat`. The target here is the phoneme /æ/, so all words feature a short-a medial position.

Authoring mechanism: each file is drafted by Claude/GPT with the allowed-grapheme constraint, passes the `WordDecodabilityTests` audit, then is proof-read by Yutaka in PR review.

### Decodability invariant

A `Word` is decodable at week N if every grapheme in `Word.graphemes` is contained in `ladder.taughtGraphemes(beforeWeekIndex: N) ∪ {currentTarget}`. `WordDecodabilityTests` already enforces this for `sh_week1.json`; PR 1 extends it to all four new fixtures.

## 10. Yokai Live Wiring (PR 2 Detail)

### Construction

```swift
@MainActor
private func bootstrap() async {
    // ...permission + TTS priming as today...

    do {
        let ladder = CurriculumEngine.sharedV1
        let (skill, encounter) = try resolveActiveSkill(context: context, ladder: ladder)
        let target = Target(weekStart: encounter.weekStart, skill: skill)
        let taught = ladder.taughtGraphemes(beforeWeekIndex: ladder.indexOf(code: skill.code) ?? 0)
        guard let targetGrapheme = target.grapheme else { /* bootError */ return }

        let provider = try ScriptedContentProvider.bundled(for: skill.code)
        let sentences = try provider.decodeSentences(
            ContentRequest(target: targetGrapheme, taughtGraphemes: taught, interests: [], count: 2)
        )

        let yokaiOrchestrator = YokaiOrchestrator(store: try BundledYokaiStore(), modelContext: context)
        if encounter.sessionCompletionCount == 0 {
            try yokaiOrchestrator.startWeek(yokaiID: encounter.yokaiID, weekStart: encounter.weekStart)
        } else {
            yokaiOrchestrator.resume(encounter: encounter)
        }

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
    } catch {
        bootError = String(describing: error)
    }
}
```

### `YokaiOrchestrator.resume(encounter:)`

New method; mirrors `startWeek` but does not insert a new encounter. Sets `currentEncounter`, `currentYokai`, resets `dayGainSoFar` to 0, and does not fire the Monday intro cutscene:

```swift
public func resume(encounter: YokaiEncounterEntity) {
    currentEncounter = encounter
    currentYokai = store.catalog().first(where: { $0.id == encounter.yokaiID })
    activeCutscene = nil
    dayGainSoFar = 0
}
```

### Friday floor-guarantee

`YokaiOrchestrator` already ships `beginFridaySession(trialsPlanned:)`, `recordFridayFinalTrial(correct:)`, and `FriendshipMeterMath.floorBoostWeight`. PR 2 adds an `isFridaySession: Bool` flag that `recordTrialOutcome(correct:)` checks and dispatches through `recordFridayFinalTrial` when set. `beginFridaySession` sets the flag; `beginDay` clears it. This keeps `SessionOrchestrator`'s existing three `yokai?.recordTrialOutcome(correct: ...)` call sites unchanged.

### Befriend + bestiary handoff

`finalizeFridayIfNeeded()` already inserts the `BestiaryEntryEntity`. PR 2 extends it to ask a pluggable `YokaiProgressionSource` for the next yokai and insert a fresh active encounter when one exists. The v1 call site wires this source to `CurriculumEngine.sharedV1.nextSkill(after:).yokaiID`.

### Curriculum-complete screen

When `nextSkill(after:)` returns `nil` on the final befriend, no new encounter is inserted. Bootstrap's `resolveActiveSkill` then finds no active encounter. Rather than auto-restart, bootstrap surfaces a minimal "You befriended all five sound-friends!" terminal view with a link to `BestiaryView`. Re-engagement logic (review weeks, SRS cameos) is out of scope for this spec.

### HomeView integration

Minimal: `HomeView` already shows the current target via `CurriculumEngine.sharedV1.currentTarget(forWeekIndex: 0)`. Change to read the active encounter's yokaiID → skill → target. Show the yokai portrait corner if an encounter is active. Do not modify the `NavigationLink(value: "session")` CTA.

## 11. Testing Strategy

### PR 1 — Curriculum Spine

Package: MoraCore
- `SkillTests` — new cases confirming `warmupCandidates` length ≥ 3 and contains the target grapheme; `yokaiID` is non-nil for v1 ladder skills.

Package: MoraEngines
- `CurriculumEngineTests` — assert 5 skills in `defaultV1Ladder()` in the expected order and with aligned `yokaiID`s. Assert `taughtGraphemes(beforeWeekIndex:)` grows correctly across weeks.
- `ScriptedContentProviderTests` — `bundled(for: SkillCode)` returns non-empty content for all five skill codes. Each week's decode words include the target phoneme.
- `BundledWeekDecodabilityTests` (new) — every word decodable using `taught ∪ {target}` for all five JSONs.
- `SystematicPrincipleTests` (new) — construct sessions for each week, assert every `TrialAssessment.expected` in `SessionOrchestrator.trials` uses the week's target phoneme. Parametrized over all five skills.
- `WeekRotationTests` (new) — five cases: (a) empty store → bootstrap creates `sh_onset` encounter, (b) active encounter → bootstrap resolves the matching skill, (c) last yokai befriended → `nil`, (d) some befriended no active → creates next, (e) carryover resumes same yokai.

Integration via `SessionOrchestratorFullTests` — add parameterized runs for each of the 5 weeks, asserting the full phase progression completes without error.

### PR 2 — Yokai Live Wiring

Package: MoraEngines
- `YokaiOrchestratorResumeTests` (new) — `resume(encounter:)` restores state from an encounter at session counts 0, 2, 4; asserts no Monday cutscene auto-plays.
- `YokaiOrchestratorNextEncounterTests` (new) — on Friday finalization at 100%, inserts bestiary entry + next encounter; no next-encounter insertion when `nextYokaiID` returns nil; normal-mode trial math unchanged; Friday-mode trial math uses floor boost.
- `YokaiGoldenWeekTests` — extended from the 1-week fixture to all 5 weeks + handoff chain.
- `YokaiOrchestratorMeterTests` — existing tests adjusted for the new Friday-dispatch semantics (default preserves prior behavior).

Package: MoraUI
- `SessionContainerBootstrapTests` (new, integration) — harness that drives `SessionContainerView.bootstrap` via an in-memory model container; asserts `orchestrator.yokai != nil` and `orchestrator.target.skill.yokaiID == encounter.yokaiID`.

### Test fixtures kept working

All existing tests that construct `Skill(...)` directly continue to work because the new fields default to `[]` / `nil`. v1 ladder skills populate both fields explicitly.

## 12. Risks and Dependencies

### Risks

| Risk | Trigger | Mitigation |
|---|---|---|
| PR 1 modifies `HomeView` hero to read active encounter, but `HomeView` was just edited by #71 for the MLX warmup gate | Two consecutive HomeView diffs complicate review but no semantic overlap — #71 gates the CTA on `MLXWarmupState`; this spec swaps the target source from `forWeekIndex: 0` to the active encounter. | Leave #71's gating logic untouched. Change only the lines that resolve the displayed target. Run the UI tests post-change. |
| Content quality regression in auto-drafted JSONs | Generated word lists include orthographic or phonological edge cases (silent letters, /r/-colored vowels, etc.). | `WordDecodabilityTests` rejects untaught-grapheme words at CI time. Yutaka reviews each JSON in PR 1 diff with focus on naturalness. Two-pass author: first draft → decodability audit → refine. |
| `YokaiOrchestrator.resume` state drift | A crash mid-session leaves `dayGainSoFar` stale. Restart re-zeros it, which could let the day cap be exceeded on the first correct trial after resume. | Acceptable v1 behavior — day cap is a safeguard, not a hard limit, and over-fill is in the learner's favor. Note in code comment. |
| Friday floor-guarantee over-ramps and finishes early | A well-performing learner hits 100% at trial 3 of session 5, then trials 4–10 do nothing. | Acceptable: meter caps at 1.0, the learner sees the befriend cutscene at session end, and the extra trials are still useful practice. If the UX feels flat, a later polish PR can add a "bonus claps" micro-reward when already at 100%. |
| Curriculum-complete state traps the learner | The child completes all 5 yokai in 5 weeks with no re-entry path. | Minimal terminal screen linking to `BestiaryView`. SRS cameos (§Non-Goals) are the proper re-engagement vehicle and land in a later plan. |

### Dependencies

- **PR #71** — merged on `main` (`73e0d6e`). PR 1 authors against post-#71 main and does not touch `MLXWarmupState` or the gating logic.
- **Adult-proxy fixture recordings (P2 side branch)** — independent. The Engine B shadow path continues with synthetic-based thresholds; child UX is not affected either way.
- **Existing yokai assets** — all 5 portraits + 8 voice clips per yokai already bundled (PRs #63, #66). No further asset work.

## 13. Out of Scope

Explicitly deferred to later plans:

- C-day Reading Adventure, Story Library, discrimination drills.
- AdaptivePlanEngine, skill state transitions (`.new / .learning / .mastered / .shaky`), SRS intervals.
- Parent Mode, CloudKit, APNs, escalation ladder L2–L4.
- L1 phonemic-awareness first-launch diagnostic.
- Wild yokai cameos during SRS reviews.
- LLMVocabularyExpander (v1.5 MLX work).
- Curriculum re-entry after all 5 yokai befriended (review mode, maintenance weeks).
- ASR false-negative "it heard me wrong" button.
- MLX warmup gate (shipped separately via PR #71, already on `main`).

## 14. Open Questions

1. **Per-day labeling of the session.** Should `MoraStrings` render "Today is Monday — meet `sh`!" based on `sessionCompletionCount`, or stay generic? Current inclination: generic for now, add warmth in a later polish pass once real usage feedback is in.
2. **Curriculum-complete screen copy.** What does it say? Placeholder in this spec; real copy decided in PR 2 implementation.
3. **Home screen hero when no encounter is active (post-completion).** Show a "review" affordance? A congratulations state? For v1 alpha, we render the bestiary CTA and a static "All befriended" label. Revisit with SRS work.
4. **Next-skill lookup from `YokaiOrchestrator`.** `CurriculumEngine` and `YokaiOrchestrator` are both in MoraEngines, so the dependency direction is fine, but `YokaiOrchestrator` has historically been curriculum-agnostic. Three options: (a) inject a lightweight `YokaiProgression` protocol, (b) take a `(String) -> String?` closure, (c) move the bestiary+next-encounter insert into the session orchestrator's completion path. Final shape decided in PR 2 implementation based on what minimizes call-site churn. The plan starts with option (a).
