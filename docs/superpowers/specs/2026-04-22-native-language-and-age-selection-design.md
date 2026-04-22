# mora — Native Language + Age Selection (alpha) Design Spec

- **Date:** 2026-04-22
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Follows:** `2026-04-22-mora-ipad-ux-speech-alpha.md` (PRs #17–24 merged)
- **Extends** the v1 surface in `2026-04-21-mora-dyslexia-esl-design.md` (§9 multi-L1, §17.7 second-language UI strings — both called for but unimplemented)
- **Supersedes nothing.**

---

## 1. Overview

The A-day alpha that landed in PR #17–24 ships a fully English UI chrome ("Today's quest", "▶ Start", "End quest", "Quest complete!", all phase labels and button text). The target learner is an 8-year-old Japanese-L1 child whose English reading is currently at US-kindergarten level — precisely the reason the app exists. A child who cannot yet read English cannot navigate the app itself: the onboarding screen asks "What should we call you?" in English, the Home hero says "Today's quest" in English, and so on. The UI chrome must speak the learner's first language, while the *learning content* (target graphemes, decodable words, sentences) remains English.

This plan introduces two onboarding steps (native-language picker, age picker) and wires a pre-authored Japanese UI chrome strings catalog keyed by learner age. It does **not** touch English learning content: targets like `sh`, words like `ship`, and sentences composed by `ScriptedContentProvider` stay English.

The spec is deliberately designed so that a future `LLMLocalizer` (v1.5) can slot in behind the same `L1Profile.uiStrings(forAgeYears:)` surface without breaking callers.

## 2. Motivation & Context

Two open items from the canonical product spec `2026-04-21-mora-dyslexia-esl-design.md` motivate this work:

- §9 (Multi-L1 Architecture Principle) declares `L1Profile.uiStrings: LocalizedBundle` as the mandated route for all human-visible text. The alpha shipped without implementing that route.
- §17 Open Question 7 asked whether English fallbacks should be bundled in v1. The answer for this plan is: **the primary UI chrome locale is the learner's native language, chosen at onboarding**. English fallbacks remain a separate (deferred) concern for a future Parent Mode navigating in English.

The CLAUDE.md language-policy constraint ("all content that lands in this repository is English") applies to prose, identifiers, comments, and commit messages. It does **not** apply to the *string literal data* that the Japanese UI renders — those Japanese strings are content, not prose, and live in Swift source as static `let` assignments inside `JapaneseL1Profile`.

## 3. Goals and Non-Goals

### Goals

- A language picker in onboarding, rendered with each language in its own script, with Japanese as the only active option in alpha. Korean, Chinese, and English appear as "Coming soon" disabled rows.
- An age picker in onboarding that captures the learner's integer age (4–12 plus a `13+` option). The integer is stored as-is.
- A `MoraStrings` catalog covering every human-visible UI string in the app today, fully authored for Japanese at ages 8–9 (the alpha target range) and falling back to that bucket for other ages.
- All existing UI call sites route through the catalog; no English UI chrome literal remains in any view.
- Existing dev installations (with `onboarded == true` but no `ageYears`) are re-prompted only for language and age on next launch, without disturbing their name, interests, or permission grants.
- The `L1Profile.uiStrings(forAgeYears:)` surface is shaped so a future on-device LLM translator can either replace or cache in front of it without call-site changes.

### Non-Goals

- Implementation of Korean / Chinese / English L1 profiles. Only the picker entries and "Coming soon" disabled state ship; no actual profile struct lands.
- Full authoring of the `preschool`, `early`, `late` Japanese string buckets. Alpha ships `mid` fully (ages 8–9) and every other internal bucket falls back to `mid`.
- An LLM-driven localizer. The v1.5 `LLMLocalizer` is named in §5.5 as a forward hook but is not built here.
- A Settings screen for later re-editing of language or age. Deferred to a future Settings plan along with the existing font / interests / escalation-threshold deferred items.
- Japanese TTS narration of rule explanations or scaffolding. The `AVSpeechSynthesizer` path stays English-only (target-word pronunciation and scaffolds).
- Runtime kanji→hiragana conversion. All age variants are pre-authored; no MeCab / kakasi / similar dependency is introduced.
- UD Digi Kyokasho font integration. System `.rounded` design plus iOS's automatic Japanese fallback (Hiragino Maru Gothic ProN) is accepted as the alpha baseline.
- Furigana rendering. Avoided by constraining the alpha `mid` bucket to kanji at or below JP grade 2 (Japanese elementary 2nd-year) configured kanji only.
- Changes to English learning content: `sh_week1.json`, `ScriptedContentProvider`, `CurriculumEngine`, and `AssessmentEngine` are untouched by this plan.

## 4. Design Decisions

| Axis | Decision | Reason |
|---|---|---|
| Catalog abstraction | Extend `L1Profile` protocol with `uiStrings(forAgeYears:)` returning a typed `MoraStrings` struct. Not Apple `Localizable.strings`. | The product spec §9 already mandates `L1Profile.uiStrings`. Age-variance is orthogonal to Apple locale codes; a typed struct avoids the "missing key" class of runtime bug. |
| Public surface type for age | Raw `Int` (years). No public `AgeBucket` / `AgeRange` enum. | Keeps the public API language-neutral. A future `LLMLocalizer` keyed on `(lang, years)` can slot in without an enum churn; bucketing is an implementation detail of each L1Profile. |
| Age input UI | Integer tile grid (4–12 plus `13+`). | Scannable and tap-sized on iPad. Stepper requires fine motor control; grade picker leaks JP-specific vocabulary into a multi-L1-intended UI. |
| Language picker UI | Single-select list. Active row: `にほんご`. Disabled rows: `한국어` / `中文` / `English` with `(Coming soon)` suffix. | Shows multi-L1 ambition without shipping it. Native-script labels avoid the i18n chicken-and-egg. |
| Language picker title | Multilingual `Language / 言語 / 语言 / 언어` single-line header. | Universally recognizable by any parent regardless of which language they're picking. |
| Migration of existing installs | New `UserDefaults` flag `tech.reenable.Mora.languageAgeOnboarded`, independent of the existing `tech.reenable.Mora.onboarded`. On re-entry, runs only the two new screens; existing profile's name / interests / permissions are preserved. | The only existing user (the dev) should not lose the streak counter or have to re-pick interests. |
| JP default age bucket | `mid` (ages 8–9), JP elementary grade 2 kanji set ceiling. | Matches the declared alpha target learner. Other ages fall back to this bucket. |
| JP font | SwiftUI `.rounded` design; iOS auto-falls-back to Hiragino Maru Gothic ProN for JP glyphs. | Zero dependency cost. UD Digi Kyokasho upgrade is a later plan. |
| JP TTS | Not added. English TTS only. | Scope isolation; target words are still English. |
| JP interest category names | Localized via a new `L1Profile.interestCategoryDisplayName(key:forAgeYears:)` method. | Interests are persisted by `key`, so display text must be late-bound. Keeps `InterestCategory` model free of display concerns. |

## 5. Architecture

### 5.1 `L1Profile` extension

```swift
// MoraCore/L1Profile.swift

public protocol L1Profile {
    // existing members unchanged:
    var identifier: String { get }
    var characterSystem: CharacterSystem { get }
    var interferencePairs: [PhonemeConfusionPair] { get }
    var interestCategories: [InterestCategory] { get }
    func exemplars(for phoneme: Phoneme) -> [String]
    func matchInterference(expected: Phoneme, heard: Phoneme) -> PhonemeConfusionPair?

    // new:
    func uiStrings(forAgeYears years: Int) -> MoraStrings
    func interestCategoryDisplayName(key: String, forAgeYears years: Int) -> String
}
```

No existing call sites break because both additions are new requirements on a protocol that has exactly one conforming type today (`JapaneseL1Profile`).

### 5.2 `MoraStrings` catalog

```swift
// MoraCore/MoraStrings.swift  (new file)

public struct MoraStrings: Sendable, Equatable {
    // Language + age onboarding (rendered in the chosen language)
    public let ageOnboardingPrompt: String
    public let ageOnboardingCTA: String

    // Existing onboarding screens
    public let welcomeTitle: String
    public let welcomeCTA: String
    public let namePrompt: String
    public let nameSkip: String
    public let nameCTA: String
    public let interestPrompt: String
    public let interestCTA: String
    public let permissionTitle: String
    public let permissionBody: String
    public let permissionAllow: String
    public let permissionNotNow: String

    // Home
    public let homeTodayQuest: String
    public let homeStart: String
    public let homeDurationPill: (Int) -> String      // minutes → "16ふん"
    public let homeWordsPill: (Int) -> String         // count → "5もじ"
    public let homeSentencesPill: (Int) -> String     // count → "2ぶん"
    public let homeBetterVoiceChip: String

    // Session chrome
    public let sessionCloseTitle: String
    public let sessionCloseMessage: String
    public let sessionCloseKeepGoing: String
    public let sessionCloseEnd: String
    public let sessionWordCounter: (Int, Int) -> String   // (current, total)
    public let sessionSentenceCounter: (Int, Int) -> String

    // Per-phase helpers
    public let warmupListenAgain: String
    public let newRuleGotIt: String
    public let decodingLongPressHint: String
    public let sentencesLongPressHint: String
    public let feedbackCorrect: String
    public let feedbackTryAgain: String

    // Mic UI
    public let micIdlePrompt: String
    public let micListening: String
    public let micAssessing: String
    public let micDeniedBanner: String

    // Completion
    public let completionTitle: String
    public let completionScore: (Int, Int) -> String
    public let completionComeBack: String

    // Accessibility labels (VoiceOver)
    public let a11yCloseSession: String
    public let a11yMicButton: String
    public let a11yStreakChip: (Int) -> String
}
```

Closures for plural-like keys (`(Int) -> String`) keep the formatting pure Swift and avoid pulling in `NumberFormatter` or `.stringsdict` files for alpha.

### 5.3 Environment injection

```swift
// MoraUI/Design/MoraStringsEnvironment.swift  (new file)

private struct MoraStringsKey: EnvironmentKey {
    static let defaultValue: MoraStrings = JapaneseL1Profile().uiStrings(forAgeYears: 8)
}

public extension EnvironmentValues {
    var moraStrings: MoraStrings {
        get { self[MoraStringsKey.self] }
        set { self[MoraStringsKey.self] = newValue }
    }
}
```

`RootView` resolves `moraStrings` from the current `LearnerProfile` once per body evaluation and injects via `.environment(\.moraStrings, strings)`. The default value exists so previews and test harnesses without an injected context render correctly.

### 5.4 Persistence — `LearnerProfile.ageYears`

```swift
@Model public final class LearnerProfile {
    public var id: UUID
    public var displayName: String
    public var l1Identifier: String
    public var ageYears: Int?                   // NEW
    public var interests: [String]
    public var preferredFontKey: String
    public var createdAt: Date
}
```

- `Int?` rather than `Int` so SwiftData lightweight migration of existing rows leaves the field `nil`, triggering the re-prompt flow.
- No new `@Model` type is introduced.
- `MoraModelContainer.onDisk()` / `inMemory()` pick up the new property automatically; no migration plan is required for this shape change (adding an optional field is SwiftData-lightweight).

### 5.5 Navigation — three-way `RootView`

```
RootView
├── !UserDefaults.bool("tech.reenable.Mora.languageAgeOnboarded")
│        → LanguageAgeFlow  (Step 1 Language → Step 2 Age)
│          on finish:
│            · upsert LearnerProfile.l1Identifier + ageYears
│            · UserDefaults.set(true, forKey: ".languageAgeOnboarded")
│            · fall through to the next condition
│
├── !UserDefaults.bool("tech.reenable.Mora.onboarded")
│        → OnboardingFlow    (existing: Welcome → Name → Interests → Permission)
│
└── NavigationStack
        ├── HomeView
        └── push → SessionContainerView
```

Both flags live in `UserDefaults` rather than SwiftData because they gate a boot-time UI branch, not a domain object — consistent with the existing `.onboarded` convention.

### 5.6 Forward-looking hook — `LLMLocalizer` (v1.5)

The `uiStrings(forAgeYears:)` surface takes a raw integer and returns a fully materialized `MoraStrings`. A future on-device `LLMLocalizer` (living in `MoraMLX`) could:

- Wrap the L1Profile behind a memoizing actor that calls the LLM once per `(language, ageBucket)` and caches the result as a pre-built `MoraStrings`, OR
- Take over entirely for languages whose pre-authored catalog is empty.

Either way, no v1 call site needs to change. This is a note, not a design — the MLX path is a separate spec.

### 5.7 Japanese kanji level registry

The alpha JP strings (§7.2) are constrained to the 240 kanji of JP elementary grades 1+2. To make that constraint enforceable rather than editorial, a new file `Packages/MoraCore/Sources/MoraCore/JPKanjiLevel.swift` ships the canonical sets as `Set<Character>`:

```swift
public enum JPKanjiLevel {
    /// 80 kanji. Source: MEXT 学習指導要領 小学校 別表 学年別漢字配当表
    /// (2017 告示 / 2020 全面実施; G1 unchanged in that revision).
    public static let grade1: Set<Character> = [
        "一", "右", "雨", "円", "王", "音", /* ... 80 chars ... */
    ]
    /// 160 kanji. Same source as above; G2 unchanged in the 2017 revision.
    public static let grade2: Set<Character> = [
        "引", "羽", "雲", "園", "遠", "何", /* ... 160 chars ... */
    ]
    public static let grade1And2: Set<Character> = grade1.union(grade2)
}
```

A unit test in `MoraCoreTests/JPKanjiLevelTests.swift` asserts every rendered JP string in `JapaneseL1Profile().uiStrings(forAgeYears: 8)` contains only characters drawn from hiragana (U+3040..U+309F), katakana (U+30A0..U+30FF), Latin digits, whitespace, `、`, `。`, `？`, `！`, `…`, `›`, `▶`, `🔊`, or `JPKanjiLevel.grade1And2`. Any edit that introduces an out-of-budget kanji fails CI.

This registry lives in MoraCore rather than inside `JapaneseL1Profile.swift` so any future JP-specific content (story passages, template vocabulary) can reuse the same set — and so the test can assert the invariant without importing the profile's private bucketing enum.

## 6. Language + Age Onboarding

### 6.1 Step 1 — Language picker

Rendered in a language-neutral shell (multilingual title, no other chrome prose).

- Title (fixed, no translation): `Language / 言語 / 语言 / 언어`
- 2×2 tile grid or single column list of selectable rows. Each row shows only the language name in its own script.
- Row states:
  - `にほんご` — selectable, default highlighted
  - `한국어` — disabled with trailing `(Coming soon)`
  - `中文` — disabled with trailing `(Coming soon)`
  - `English` — disabled with trailing `(Coming soon)`
- Bottom CTA: `▶` (icon only, no text). Disabled until a row is selected; `にほんご` is pre-selected on entry so CTA is active immediately.

Selection persists to the in-flight `LanguageAgeFlow` state; `LearnerProfile.l1Identifier` is written only when Step 2 completes. The stored identifier is the string `"ja"`, matching `JapaneseL1Profile.identifier`; future language profiles will use their own ISO-639-style codes (`"ko"`, `"zh"`, `"en"`).

### 6.2 Step 2 — Age picker

Rendered in the language chosen in Step 1 (Japanese for alpha).

- Title: `moraStrings.ageOnboardingPrompt` → e.g. `なんさい？`
- Tile grid, 3 columns, ages 4, 5, 6, 7, 8, 9, 10, 11, 12 (rows 1–3) plus a trailing `13+` tile on the fourth row. `13+` stores `13` as the raw integer.
- Each tile: large numeral in SF Rounded Heavy, subtle cream background, orange outline and peach fill on selection.
- CTA: `moraStrings.ageOnboardingCTA` → e.g. `▶ はじめる`. Disabled until a tile is selected. Age `8` is pre-selected for the alpha target user's convenience.

### 6.3 Completion

`LanguageAgeFlow` reads existing profiles via a `@Query(sort: \LearnerProfile.createdAt, order: .forward)` and picks `.first` (consistent with `HomeView`). On completion it upserts, not replaces:

```swift
@MainActor
func finishLanguageAgePrompt(existingProfile: LearnerProfile?) async {
    let profile = existingProfile ?? LearnerProfile(
        id: UUID(), displayName: "", l1Identifier: pickedLanguageID,
        ageYears: pickedAge, interests: [],
        preferredFontKey: "openDyslexic", createdAt: Date()
    )
    profile.l1Identifier = pickedLanguageID
    profile.ageYears = pickedAge
    if existingProfile == nil { modelContext.insert(profile) }
    try? modelContext.save()
    UserDefaults.standard.set(true, forKey: "tech.reenable.Mora.languageAgeOnboarded")
}
```

If an existing profile is found, its `displayName` / `interests` / `preferredFontKey` / `createdAt` are left intact. If no profile exists (first run), a shell profile is created; the subsequent `OnboardingFlow` screens fill in name / interests and the existing completion hook at that flow's end persists interests via the same profile row.

### 6.4 Migration — existing installs

Sole existing case: dev iPad with `onboarded == true`, a `LearnerProfile`, and no `ageYears`.

- On launch, `RootView` sees `languageAgeOnboarded == false` and routes to `LanguageAgeFlow`.
- `LanguageAgeFlow` detects the existing profile and routes its completion to the "update existing" branch.
- After completion, `onboarded` is still true, so `OnboardingFlow` is skipped and the user lands on Home.
- The existing `DailyStreak` row is untouched.

No destructive branch (resetting `onboarded`) is needed.

## 7. Japanese Strings Content (alpha scope)

### 7.1 Internal bucketing inside `JapaneseL1Profile`

```swift
private enum JPBucket { case preschool, early, mid, late }

private static func bucket(forAge years: Int) -> JPBucket {
    switch years {
    case ..<6:    return .preschool
    case 6...7:   return .early
    case 8...9:   return .mid
    default:      return .late
    }
}

public func uiStrings(forAgeYears years: Int) -> MoraStrings {
    // alpha: every bucket returns the mid-authored table.
    // next plan authors the other three tables and flips the switch.
    return Self.stringsMid
}

public func interestCategoryDisplayName(
    key: String, forAgeYears years: Int
) -> String {
    switch key {
    case "animals":   return "どうぶつ"
    case "dinosaurs": return "きょうりゅう"
    case "vehicles":  return "のりもの"
    case "space":     return "うちゅう"
    case "sports":    return "スポーツ"
    case "robots":    return "ロボット"
    default:          return key
    }
}
```

### 7.2 `stringsMid` authoring rules (JP, ages 8–9)

- **Authority**: The kanji budget is the cumulative JP elementary grade 1 + grade 2 set (80 + 160 = 240 characters) per the MEXT 学習指導要領 小学校 別表 学年別漢字配当表. The current edition was告示 in 2017 and has been in force since 2020-04-01; G1–G3 assignments were unchanged in that revision. The canonical set lives in code at `JPKanjiLevel.grade1And2` (§5.7).
- **Base register**: kid-facing plain form (`〜だよ` / `〜ね`), not `です/ます`. Matches the tone of JP elementary-2 textbooks.
- **Kanji usage**: a word renders in kanji when *every* component character is in `grade1And2`; otherwise the whole word renders in hiragana (or a paraphrase). Partial-kanji mixing (e.g. `聞きとる` for `聞き取る` where `取` is G3) is avoided — pick either full-kanji or full-hiragana.
- **Katakana**: loanwords stay katakana (`クエスト`, `マイク`, `スキップ`, `ボタン`, `チェック`).
- **Line breaks**: insert at meaning boundaries per children's-book convention.
- **Punctuation**: `、` for mid-phrase pauses. Omit terminal `。` on UI labels.
- **Numbers**: half-width digits (`16分`, `5文字`, `3/5`).
- **Mechanical audit**: the `JPKanjiLevelTests` test (§5.7 + §11.1) fails CI on any kanji outside `grade1And2`.

Draft content (subject to proof review in PR 1):

| Key | Value | In-budget kanji |
|---|---|---|
| `ageOnboardingPrompt` | `なんさい？` | — (才 G2 available but hira reads friendlier here) |
| `ageOnboardingCTA` | `▶ はじめる` | — (始 G3) |
| `welcomeTitle` | `えいごの 音を いっしょに` | 音 G1 |
| `welcomeCTA` | `はじめる` | — (始 G3) |
| `namePrompt` | `名前を 教えてね` | 名 G1 · 前 G2 · 教 G2 |
| `nameSkip` | `スキップ` | — |
| `nameCTA` | `つぎへ` | — (次 G3) |
| `interestPrompt` | `すきな ものを 3つ えらんでね` | — (好 / 選 G4) |
| `interestCTA` | `つぎへ` | — (次 G3) |
| `permissionTitle` | `声を 聞くよ` | 声 G2 · 聞 G2 |
| `permissionBody` | `きみが 読んだ ことばを 聞いて、正しいか しらべるよ` | 読 G2 · 聞 G2 · 正 G1 (調 G3 → しらべる; 葉 G3 → ことば) |
| `permissionAllow` | `ゆるす` | — (許 G5) |
| `permissionNotNow` | `後で` | 後 G2 |
| `homeTodayQuest` | `今日の クエスト` | 今 G2 · 日 G1 |
| `homeStart` | `▶ はじめる` | — (始 G3) |
| `homeDurationPill(16)` | `16分` | 分 G2 |
| `homeWordsPill(5)` | `5文字` | 文 G1 · 字 G1 |
| `homeSentencesPill(2)` | `2文` | 文 G1 |
| `homeBetterVoiceChip` | `もっと きれいな 声 ›` | 声 G2 (綺麗 not 常用 → きれい hira) |
| `sessionCloseTitle` | `今日の クエストを おわる？` | 今 G2 · 日 G1 (終 G3 → おわる) |
| `sessionCloseMessage` | `ここまでの きろくは のこるよ` | — (録 G4 → きろく; 残 G4 → のこる) |
| `sessionCloseKeepGoing` | `つづける` | — (続 G4) |
| `sessionCloseEnd` | `おわる` | — (終 G3) |
| `sessionWordCounter(3, 5)` | `3/5` | — |
| `sessionSentenceCounter(1, 2)` | `1/2` | — |
| `warmupListenAgain` | `🔊 もういちど` | — (度 G3 → いちど) |
| `newRuleGotIt` | `分かった` | 分 G2 |
| `decodingLongPressHint` | `ながおしで もういちど 聞けるよ` | 聞 G2 (押 G3 → ながおし; 度 G3 → いちど) |
| `sentencesLongPressHint` | `ながおしで もういちど 聞けるよ` | same |
| `feedbackCorrect` | `せいかい！` | — (解 G5 → せいかい, all-hira for visual consistency) |
| `feedbackTryAgain` | `もう一回` | 一 G1 · 回 G2 |
| `micIdlePrompt` | `マイクを タップして 読んでね` | 読 G2 |
| `micListening` | `聞いてるよ…` | 聞 G2 |
| `micAssessing` | `チェック中…` | 中 G1 |
| `micDeniedBanner` | `マイクが つかえないので ボタンで 答えてね` | 答 G2 |
| `completionTitle` | `できた！` | — (出来 mixed — modern usage favors hira for kids) |
| `completionScore(6, 7)` | `6/7` | — |
| `completionComeBack` | `明日も またね` | 明 G2 · 日 G1 |
| `a11yCloseSession` | `クエストを おわる` | — |
| `a11yMicButton` | `マイク` | — |
| `a11yStreakChip(5)` | `5日 れんぞく` | 日 G1 (連 G4 + 続 G4 → れんぞく) |

Proof pass: Yutaka walks through the table in PR 1 and edits in place; the kanji-audit test guards against any revision that would slip a G3+ character back in.

### 7.3 Interest category localization

`InterestPickView` currently reads `category.displayName` from the `InterestCategory` model. After this plan, it reads `l1Profile.interestCategoryDisplayName(key: category.key, forAgeYears: profile.ageYears ?? 8)`. The `InterestCategory.displayName` property remains on the model (seeded to the English value for compatibility) but is no longer displayed to the child.

## 8. Typography

- **English hero target (grapheme)** — unchanged. `MoraType.hero(_:)` = SF Pro Rounded Heavy; not used for JP.
- **English reading content (words, sentences)** — unchanged. OpenDyslexic Regular via `MoraType.bodyReading()`.
- **Japanese UI chrome** — rendered with SwiftUI's `.rounded` design. iOS automatically falls back to Hiragino Maru Gothic ProN for JP Unicode ranges. No explicit font registration.
- **Numerals inside JP labels** (e.g. `16ふん`) — SF Rounded; JP glyphs around them fall back to Hiragino. The resulting mixed-run rendering is the native SwiftUI behavior and needs no special handling.

UD Digi Kyokasho NK-R / NP-R (iOS-bundled starting iPadOS 18) is a later-plan upgrade.

## 9. Call-site Migration

Files that currently contain English string literals in UI chrome and must switch to `@Environment(\.moraStrings)`:

| File | Literal to migrate |
|---|---|
| `MoraUI/Onboarding/WelcomeView.swift` | Title, CTA |
| `MoraUI/Onboarding/NameView.swift` | Prompt, skip, CTA |
| `MoraUI/Onboarding/InterestPickView.swift` | Prompt, CTA, tile display names |
| `MoraUI/Onboarding/PermissionRequestView.swift` | Title, body, allow, not-now |
| `MoraUI/Home/HomeView.swift` | Wordmark (stays `mora`), "Today's quest", IPA subline (keep English since it references target), Start CTA, pills, better-voice chip |
| `MoraUI/Session/SessionContainerView.swift` | Close alert title / message / buttons |
| `MoraUI/Session/WarmupView.swift` | Listen-again button |
| `MoraUI/Session/NewRuleView.swift` | "Got it" CTA |
| `MoraUI/Session/DecodeActivityView.swift` | Word counter, long-press hint |
| `MoraUI/Session/ShortSentencesView.swift` | Sentence counter, long-press hint |
| `MoraUI/Session/CompletionView.swift` | Title, score, come-back line |
| `MoraUI/Design/Components/MicButton.swift` | Idle prompt, listening label (if rendered inline) |
| `MoraUI/Design/Components/FeedbackOverlay.swift` | Accessibility label |

The "IPA subline" on `HomeView` (`"/ʃ/ · as in ship, shop, fish"`) intentionally remains in English because its content — IPA plus English exemplars — is a direct teaching reference and localization would defeat the purpose.

`Mora/MoraApp.swift` is not touched. The app boot path stays identical.

## 10. Phase Plan

Four stacked PRs, each green on `swift test` + `xcodebuild build` (CI command).

| PR | Branch | Deliverable |
|---|---|---|
| 1 | `feat/mora-ja-l10n/01-strings` | `MoraStrings` struct + `L1Profile` protocol additions + `JPKanjiLevel` registry (§5.7) + `JapaneseL1Profile.stringsMid` populated from the table in §7.2 + `interestCategoryDisplayName` impl + env key + unit tests (including kanji audit). No UI wiring yet; existing screens still render English. |
| 2 | `feat/mora-ja-l10n/02-flow` | `LearnerProfile.ageYears` field + `languageAgeOnboarded` UserDefaults flag + `LanguageAgeFlow` (two screens) + `RootView` 3-way branch + migration path. Env key now injected from the chosen profile. Existing UI still English because call sites haven't migrated yet, but the flow runs. |
| 3 | `feat/mora-ja-l10n/03-localize-views` | Every file in §9 migrated to `@Environment(\.moraStrings)`. `InterestPickView` uses `interestCategoryDisplayName`. Visual walk-through in iPad simulator, screenshots attached to PR. |
| 4 | `feat/mora-ja-l10n/04-quality` | Test additions (§11), on-device smoke on a real iPad with Japanese keyboard, review of `sh_week1.json` content pairing with JP chrome, spec open-question closeouts. |

Approximately 12–14 tasks across 4 PRs. The previous alpha plan's stacked PR convention (base each on its predecessor) is reused.

## 11. Testing Strategy

### 11.1 Unit (`swift test`)

- `MoraCore`:
  - `JapaneseL1Profile().uiStrings(forAgeYears: y)` returns non-empty values for every field of `MoraStrings` at `y ∈ {4, 7, 8, 9, 12, 15}`.
  - All `uiStrings` calls at different ages return the same `mid` table in alpha (invariant that cleans up when other buckets are authored).
  - `interestCategoryDisplayName(key:forAgeYears:)` returns Japanese for the six seeded keys and the key itself for an unknown key.
  - **Kanji audit** (`JPKanjiLevelTests`): iterate every string field of `stringsMid` (including closure-produced variants at representative arguments), character by character; each codepoint must match hiragana / katakana / digits / whitespace / the allowed punctuation and symbol set, or be a member of `JPKanjiLevel.grade1And2`. A single out-of-set character fails the test.
  - `JPKanjiLevel.grade1.count == 80` and `.grade2.count == 160` and the two sets are disjoint (sanity checks against accidental typos in the literal).
  - `LearnerProfile` with `ageYears == nil` persists and loads cleanly; setting `ageYears = 8` and reloading returns `8`.

- `MoraUI`:
  - `LanguageAgeFlow` state transitions: language pre-selected at `.ja`, CTA enabled; tapping a disabled language row does not change state; age tile selection enables the age CTA; completion writes both `LearnerProfile.l1Identifier` and `ageYears`; the UserDefaults flag flips to true.
  - Environment fallback: a view rendered without an injected `moraStrings` sees the default JapaneseL1Profile at age 8 (smoke test of the env default).

- `MoraTesting`: no additions.

### 11.2 Integration

No new integration tests. The existing `FullADayIntegrationTests` in `MoraEngines` is not affected (engines don't consume `MoraStrings`).

### 11.3 Device smoke (manual)

- PR 2 end: simulator walk-through of fresh install → LanguageAgeFlow → OnboardingFlow → Home. Screenshot each screen.
- PR 3 end: same walk-through on a real iPad (the target device) with Japanese keyboard set as the system default. Verify that `NameView`'s text field opens the JP keyboard. Verify Hiragino fallback renders cleanly at all `MoraType` sizes.
- PR 4 end: the existing dev install on the iPad upgrades cleanly (LanguageAgeFlow runs once, then the app returns to Home with the prior streak intact).

### 11.4 What is not tested

- SwiftUI snapshot diffs (same rationale as prior alpha plan: no existing harness, brittle).
- LLM translation correctness (no LLM code in this plan).
- Korean / Chinese / English UI (no profiles exist to exercise).

## 12. Error & Boundary Handling

| Scenario | Handling |
|---|---|
| User taps a disabled language row | No state change; row stays disabled with the `(Coming soon)` suffix. No banner, no toast. |
| User reaches age picker, backs out, returns | Previously-picked age stays selected; CTA stays active. |
| App is force-quit mid-LanguageAgeFlow | Neither `l1Identifier` nor `ageYears` is persisted until Step 2 completes; flow re-runs from Step 1 on next launch. |
| `LearnerProfile` has `ageYears == 0` (impossible via UI, but possible via a future migration bug) | `JapaneseL1Profile.bucket(forAge: 0)` returns `.preschool` → falls back to `.mid` table in alpha. No crash. |
| System language is switched at runtime | Not re-queried. Native-language choice is made once at LanguageAgeFlow and does not follow the OS language. |
| SwiftData migration adding `ageYears` fails | Existing on-disk → in-memory fallback in `MoraApp` catches this; learner lands in a fresh-install flow. Non-destructive (SwiftData lightweight migration should not fail, but the safety net handles it). |

## 13. Out of Scope

Explicitly deferred, with a pointer to where each belongs:

- Other-age buckets (`preschool`, `early`, `late`) authored in full — separate follow-up plan; likely combined with a Settings-to-edit-age plan.
- Korean / Chinese / English `L1Profile` implementations — v2 spec §16.
- `LLMLocalizer` (on-device LLM translation of English templates) — v1.5 spec; lives under `MoraMLX`.
- Japanese TTS for rule explanation and scaffolding — future plan, blocked on voice-quality evaluation.
- Settings screen for re-editing language / age / font / interests — future plan.
- UD Digi Kyokasho font integration — future typography plan.
- Furigana rendering — avoided here by constraining the kanji budget.

## 14. Open Questions

1. **Draft Japanese copy proofing** — the table in §7.2 is a first draft. Yutaka hand-edits in PR 1 before merge. The spec will be updated with post-proof wording if any lines change materially.
2. **`13+` tile label** — plain `13+` vs `13さいいじょう`. Leaning toward `13+` (one tile, universal). Will revisit after device smoke with a 13+ tester (non-alpha).
3. **`NameView` skip affordance location** — skip is currently top-right in the existing view. With JP `スキップ` being shorter than English `Skip`, visual weight changes; may move inline with CTA. Decide during PR 3.
4. **Interest display name age variance** — alpha makes display name age-invariant. A preschool bucket might prefer `わんわん` over `どうぶつ`. Revisit when authoring the `preschool` bucket.
5. **Home IPA subline** — kept in English per §9. Some parents may prefer JP exemplars (`/ʃ/ · ship, shop, fish のおと`). Defer decision to field test.

## 15. References

- Primary product spec: `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md` (§9 Multi-L1 Architecture, §17 Open Questions)
- SPM-layout design: `docs/superpowers/specs/2026-04-21-mora-design.md`
- Immediate predecessor: `docs/superpowers/specs/2026-04-22-mora-ipad-ux-speech-alpha-design.md`
- Predecessor plan: `docs/superpowers/plans/2026-04-22-mora-ipad-ux-speech-alpha.md`
- Project-wide language policy: `CLAUDE.md` §Language policy (this spec complies: prose is English; Japanese literals are data)
- Kanji curriculum authority: MEXT 学習指導要領 小学校 別表 学年別漢字配当表 (2017 告示, 2020-04-01 全面実施) — the 80 + 160 = 240 G1+G2 characters used in `JPKanjiLevel.grade1And2`. Canonical listing: https://ja.wikipedia.org/wiki/学年別漢字配当表 (mirrors the MEXT table verbatim)
