# mora — Multi-L1 i18n + Age-Driven Difficulty Design Spec

- **Date:** 2026-04-26
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Supersedes:** `2026-04-22-native-language-and-age-selection-design.md` — that spec's
  `L1Profile.uiStrings(forAgeYears:)` API and `JPStringBucket` private bucketing are
  removed by this spec; the `LearnerProfile.ageYears` field and `LanguageAgeFlow`
  shipped by that plan are retained and extended.
- **Extends:** `2026-04-21-mora-dyslexia-esl-design.md` §9 (Multi-L1 Architecture
  Principle), §17 Open Question 7 (Second-language UI strings).

---

## 1. Overview

The alpha release supports a single L1 profile (`JapaneseL1Profile`) and renders one
authored UI-strings table for every age in the 4–12+ picker. This spec opens the door
to additional L1s and to per-learner difficulty variation by:

1. Replacing the age-keyed `uiStrings(forAgeYears:)` API with a typed
   `LearnerLevel { entry, core, advanced }` enum that every `L1Profile` consumes
   uniformly. Per-L1 semantic interpretation lives inside the profile.
2. Authoring three Japanese UI-strings tables — `stringsEntryHiraOnly`,
   `stringsCoreG1`, `stringsAdvancedG1G2` — keyed off `LearnerLevel` and budgeted
   against the JP elementary kanji curriculum (empty / G1 / G1+G2).
3. Shipping two new L1 profiles end-to-end: `KoreanL1Profile` and `EnglishL1Profile`.
   Both use a single `MoraStrings` table that is level-invariant (no script ladder
   applies) and ship simple-vocab register content suitable for primary grade 1–2
   readers.
4. Narrowing the onboarding age picker to ages 6 / 7 / 8 (Japanese 小学校低学年, the
   pedagogically most actionable window for dyslexia intervention).
5. Adding a small in-app affordance on Home that lets the user re-pick the L1
   without re-running the whole onboarding flow — for users whose OS system language
   does not match the language they actually speak with the child.
6. Generalizing the existing JP-only kanji audit into a `(profile × level)` grid
   validator.

Existing content JSON files (`*_week.json`, `SentenceLibrary/**/*.json`,
`WordChainLibrary/**/*.json`, `YokaiCatalog.json`, all `.m4a` and `.png` assets)
are not touched.

## 2. Motivation & Context

The predecessor spec (2026-04-22) shipped a Japanese-only UI chrome for ages 8–9
and reserved hooks for additional ages and L1s. Two pieces of follow-through are
overdue:

- **Multi-L1.** The canonical product spec §9 mandates that all human-visible text
  flow through `L1Profile.uiStrings`. The alpha shipped only one conforming type.
  Adding a second consumer flushes out abstraction issues that a single profile can
  hide.
- **Age-driven script-difficulty for JP.** The alpha's `mid` table assumed a learner
  reading at the end of JP elementary grade 2 (kanji G1+G2 = 240 characters). A
  6-year-old in early grade 1 cannot read most of those characters; a 7-year-old in
  late grade 1 has G1 (80) but not G2. Forcing every age to render the G2 table is
  pedagogically wrong for the younger end of the target audience.

The product target audience is being narrowed to ages 6–8 (Japanese 小学校低学年)
because that is the window where dyslexia intervention has the largest
return — Barton/OG-grounded structured literacy curricula consistently target
this range. Older learners outside this window remain implicitly supported (the
runtime resolves out-of-range ages gracefully) but the marketed picker exposes
only the target ages.

The `CLAUDE.md` language-policy constraint applies: prose, identifiers, comments,
and commit messages are English. Per-locale string literals authored inside
`L1Profile` implementations and locale-specific registries (like `JPKanjiLevel`)
are explicitly allowed as data. This spec follows that precedent.

## 3. Goals and Non-Goals

### Goals

- A `LearnerLevel { entry, core, advanced }` enum exposed by `MoraCore`, consumed
  uniformly by every `L1Profile`. Stored as raw `String` for SwiftData compatibility.
- A rewritten `L1Profile` protocol whose method signatures all take
  `at level: LearnerLevel` (not `forAgeYears: Int`). The old API is deleted.
- Three `MoraStrings` tables on `JapaneseL1Profile`:
  - `stringsAdvancedG1G2` — rename of the existing `stringsMid`. No content change.
  - `stringsCoreG1` — new authoring; G2 kanji collapse to hiragana; G1 kanji retained.
  - `stringsEntryHiraOnly` — new authoring; all kanji collapse to hiragana.
  All three pass `LocaleScriptBudgetTests` against the corresponding `JPKanjiLevel` set.
- One `MoraStrings` table on `KoreanL1Profile` (`stringsKidKo`) and one on
  `EnglishL1Profile` (`stringsKidEn`). Both are level-invariant.
- `KoreanL1Profile.interferencePairs` authored from KO L1 → EN L2 phonological
  transfer literature (initial set: 8 pairs).
- `EnglishL1Profile.interferencePairs == []` (L1 == L2; no L1 interference applies).
- Onboarding language picker activates Japanese, Korean, and English rows. The
  Mandarin (`中文`) row remains disabled with `(Coming soon)`.
- Onboarding age picker narrows to 6 / 7 / 8 tiles, default-selected to 7.
- Onboarding language picker pre-selects based on `Locale.current.language.languageCode`:
  `ja` → Japanese, `ko` → Korean, anything else → English (international fallback).
- A new `LearnerProfile.levelOverride: String?` field allows decoupling chronological
  age from rendered difficulty (essential for dyslexia, where reading lag is normal).
  Schema migration is SwiftData-lightweight (additive nullable property).
- A globe button on the Home screen opens a `LanguageSwitchSheet` reusing the Step 1
  language picker. It writes only `LearnerProfile.l1Identifier` and dismisses;
  age / level / interests / font are untouched.
- A `LocaleScriptBudgetTests` CI guard iterates `(profile × level)` and asserts
  every rendered string stays within `profile.allowedScriptBudget(at:)`. Profiles
  with no script ladder return `nil` and are skipped.
- `KoreanL1Profile` ships an additional CJK-Unified-Ideographs sweep test to catch
  accidental Hanja insertion that the global budget validator cannot detect.

### Non-Goals

- Korean / English authoring at multiple difficulty levels. Both ship one
  level-invariant table.
- ZH (Mandarin), ES, VI, HI, etc. The picker `中文` row stays disabled. Adding
  these is additive future work that this spec's framework supports.
- A Settings page for editing age, level, interests, font, or streak after
  onboarding. Only the L1 is in-app re-editable; all other fields require
  re-onboarding. Settings UI is deferred to a future plan.
- A user-facing UI for setting `levelOverride`. The schema field exists; the dev
  can manipulate it via a SwiftData console for ad-hoc testing.
- LLM-driven localizer. The architecture leaves the door open (any L1 profile can
  wrap an LLM behind `uiStrings(at:)`) but no MLX code lands here.
- L1-specific TTS narration. Apple TTS continues English-only.
- Per-L1 yokai catalog or voice clips. `YokaiCatalog.json` and all `.m4a` voice
  clips remain L1-agnostic and English-fixed (per project memory).
- Per-L1 interest categories. The 6-key set
  (`animals` / `dinosaurs` / `vehicles` / `space` / `sports` / `robots`) is shared
  across the three L1s; only display names are localized. Culturally-specific
  interests (e.g. KO K-pop, ZH 武侠) are out of scope.
- Furigana rendering. Avoided by capping JP `entry` at hira-only and `core` at G1.
- Custom dyslexia fonts beyond the existing OpenDyslexic + SF Rounded chrome.
- Changes to English learning content (`*_week.json`, sentence library cells,
  word chain library, yokai catalog).

### Success criteria

- Fresh install + Korean + age 7 → all chrome screens render Korean; one A-day
  session completes; bestiary date renders as `2026년 4월 26일`.
- Fresh install + English + age 6 → all chrome screens render English; the English
  literals previously hard-coded in MoraUI now flow through `MoraStrings`.
- JP profile renders zero kanji at `.entry`, only G1 kanji at `.core`, and only
  G1+G2 kanji at `.advanced`. CI fails on regression.
- Existing dev install (`l1=ja`, `ageYears=8`, `levelOverride=nil`) upgrades cleanly
  with zero visible change and full state retention.
- A user on Home can tap the globe button, pick a different L1, and immediately
  see the entire UI re-render in the new language without losing streak or yokai
  cameo state.

## 4. Design Decisions

| Axis | Decision | Reason |
|---|---|---|
| Difficulty axis type | `LearnerLevel { entry, core, advanced }` enum, raw `String` | Type-safe, decouplable from age, SwiftData-friendly, semantically neutral across L1s |
| API shape | `uiStrings(at:)`, `interestCategoryDisplayName(key:at:)`, `allowedScriptBudget(at:)`. The `forAgeYears: Int` shape is deleted | No external SDK consumers; mechanical churn (~27 internal call sites) is small; eliminates per-profile bucketing leakage |
| Number of levels | 3 | Matches JP's maximum demand (entry / core / advanced map to JP kanji budgets empty / G1 / G1+G2). KO and EN return identical content for all three; that's a constant function, not wasted authoring |
| Age → level mapping | `LearnerLevel.from(years:)` clamps `..<7 → .entry`, `7 → .core`, `else → .advanced` | Conservative for dyslexic readers; out-of-range ages clamp without crash |
| Per-L1 script budget | Optional protocol method `allowedScriptBudget(at:) -> Set<Character>?`, default `nil` | KO / EN have no script ladder; forcing a uniform return type would over-abstract. CI test skips `nil` returns, audits `Set` returns |
| `JPKanjiLevel.empty` | New constant `static let empty: Set<Character> = []` | Names the "no kanji allowed" budget for `.entry`; better than passing a bare `[]` literal |
| `LearnerProfile.levelOverride` | New `String?` (raw `LearnerLevel`); nil = derive from age | SwiftData-lightweight migration (additive nullable). String raw value avoids a typed-enum SwiftData column |
| Onboarding age picker | 3 tiles: 6 / 7 / 8, default 7 | Marketed audience clarity; the alpha's 4–12+ range was aspirational and never authored beyond age 8 |
| Onboarding language default | Pre-select from `Locale.current.language.languageCode`; unsupported → English | Ergonomics for multi-L1 households; English is a familiar fallback regardless of OS locale |
| Mandarin (`中文`) row | Disabled `(Coming soon)` | ZH character ladder is a separate large authoring effort; defer to its own spec |
| In-app L1 switch | Home globe button → `LanguageSwitchSheet` reusing Step 1 | OS system language ≠ child's daily language is a real case; minimum viable Settings affordance |
| L1 dispatch | Single `L1ProfileResolver.profile(for:)` switch on `l1Identifier` | Concentrates the only place "if locale == 'ja'" logic legitimately lives, satisfying the §9 invariant elsewhere |
| Coaching scaffolds | Required `String` fields on `MoraStrings` for all L1s; EN authors no-op-quality content (dead path at runtime since `interferencePairs == []`) | Optional fields would force `??`-everywhere at call sites; the trivial authoring cost for EN is acceptable |
| Interest category set | 3 L1s share the same 6 keys; only display names are localized | Avoids per-L1 content branching at the engine layer |
| Existing `AgeBand` | Untouched | `SentenceLibrary` content selection axis is orthogonal to UI-string difficulty; keeping them decoupled prevents difficulty-leakage into content |
| Existing content JSON | Untouched | This is a UI-chrome and L1-abstraction refactor; sentence-library and yokai assets are L2 (English) content with their own freshness rules |

## 5. Architecture

### 5.1 New: `MoraCore/LearnerLevel.swift`

```swift
import Foundation

/// Difficulty tier consumed by every L1 profile. Each profile interprets
/// the cases according to its own pedagogy:
///
/// - `JapaneseL1Profile`:
///     - `.entry`    → hiragana only, no kanji
///     - `.core`     → hiragana + JP elementary G1 kanji (80)
///     - `.advanced` → hiragana + G1 + G2 kanji (240; the existing `stringsMid`)
/// - `KoreanL1Profile`, `EnglishL1Profile`: every level returns the same
///   table — no script ladder applies at this age range.
///
/// Resolved from `LearnerProfile.ageYears` by `LearnerLevel.from(years:)`,
/// or read from `LearnerProfile.levelOverride` when a parental override is set.
public enum LearnerLevel: String, Sendable, Hashable, Codable, CaseIterable {
    case entry, core, advanced

    public static func from(years: Int) -> LearnerLevel {
        switch years {
        case ..<7: .entry
        case 7:    .core
        default:   .advanced
        }
    }
}
```

### 5.2 Replaced: `MoraCore/L1Profile.swift`

```swift
import Foundation

public protocol L1Profile: Sendable {
    var identifier: String { get }
    var characterSystem: CharacterSystem { get }
    var interferencePairs: [PhonemeConfusionPair] { get }
    var interestCategories: [InterestCategory] { get }

    func exemplars(for phoneme: Phoneme) -> [String]
    func uiStrings(at level: LearnerLevel) -> MoraStrings
    func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String

    /// Profiles with a script-difficulty ladder (currently only `JapaneseL1Profile`)
    /// override this to declare the set of "non-trivial" characters allowed at
    /// each level. `nil` means no script ladder applies — the profile is free
    /// to emit any character, and `LocaleScriptBudgetTests` skips it.
    func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>?
}

extension L1Profile {
    public func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>? { nil }
    public func exemplars(for phoneme: Phoneme) -> [String] { [] }
    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String { key }

    public func matchInterference(expected: Phoneme, heard: Phoneme) -> PhonemeConfusionPair? {
        guard expected != heard else { return nil }
        for pair in interferencePairs where pair.from != pair.to {
            if pair.from == expected && pair.to == heard { return pair }
            if pair.bidirectional && pair.from == heard && pair.to == expected {
                return pair
            }
        }
        return nil
    }
}
```

The default implementation of `interestCategoryDisplayName` falls back to the key
itself so a profile that forgets to localize a category still renders something
recognizable. Existing tests already assert that `JapaneseL1Profile` overrides
every seeded key.

### 5.3 Modified: `MoraCore/Persistence/LearnerProfile.swift`

```swift
@Model public final class LearnerProfile {
    public var id: UUID
    public var displayName: String
    public var l1Identifier: String
    public var ageYears: Int?
    /// Optional difficulty override. Stored as the raw value of
    /// `LearnerLevel` so SwiftData lightweight migration handles it as
    /// a plain optional `String` column. `nil` means "derive from age".
    public var levelOverride: String?
    public var interests: [String]
    public var preferredFontKey: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        l1Identifier: String,
        ageYears: Int? = nil,
        levelOverride: String? = nil,
        interests: [String],
        preferredFontKey: String,
        createdAt: Date = Date()
    ) { /* ... */ }

    public var resolvedLevel: LearnerLevel {
        if let raw = levelOverride, let level = LearnerLevel(rawValue: raw) {
            return level
        }
        return LearnerLevel.from(years: ageYears ?? 8)
    }
}
```

`Int?` continues to be the persistence type for `ageYears`. The `?? 8` fallback in
`resolvedLevel` is a defensive default that fires only if some future code path
constructs a profile without an age and without an override; the LanguageAgeFlow
guarantees both are populated at onboarding completion.

### 5.4 New: `MoraCore/L1ProfileResolver.swift`

```swift
import Foundation

public enum L1ProfileResolver {
    /// Returns the L1Profile for a stored `LearnerProfile.l1Identifier`. Unknown
    /// identifiers fall back to `JapaneseL1Profile` — the alpha originator. This
    /// is the single dispatch point; do not switch on `l1Identifier` anywhere
    /// else (per canonical product spec §9 "no `if locale == 'ja'` branches").
    public static func profile(for identifier: String) -> any L1Profile {
        switch identifier {
        case "ja": return JapaneseL1Profile()
        case "ko": return KoreanL1Profile()
        case "en": return EnglishL1Profile()
        default:   return JapaneseL1Profile()
        }
    }
}
```

### 5.5 Modified: `MoraUI/Design/MoraStringsEnvironment.swift`

```swift
import MoraCore
import SwiftUI

private struct MoraStringsKey: EnvironmentKey {
    static let defaultValue: MoraStrings = MoraStrings.previewDefault
}

public extension EnvironmentValues {
    var moraStrings: MoraStrings {
        get { self[MoraStringsKey.self] }
        set { self[MoraStringsKey.self] = newValue }
    }
}

private struct CurrentL1ProfileKey: EnvironmentKey {
    static let defaultValue: any L1Profile = JapaneseL1Profile()
}

public extension EnvironmentValues {
    var currentL1Profile: any L1Profile {
        get { self[CurrentL1ProfileKey.self] }
        set { self[CurrentL1ProfileKey.self] = newValue }
    }
}
```

`MoraStrings.previewDefault` (defined in `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`):

```swift
extension MoraStrings {
    /// Convenience for SwiftUI #Preview blocks. Always returns the JP
    /// advanced table — runtime resolution happens in RootView via
    /// L1ProfileResolver. Preview-only; not used in production paths.
    public static var previewDefault: MoraStrings {
        JapaneseL1Profile().uiStrings(at: .advanced)
    }
}
```

### 5.6 Modified: `MoraUI/RootView.swift` resolution path

```swift
private func resolved(profile: LearnerProfile?) -> (strings: MoraStrings, l1: any L1Profile) {
    guard let p = profile else {
        let fallback = JapaneseL1Profile()
        return (fallback.uiStrings(at: .advanced), fallback)
    }
    let l1 = L1ProfileResolver.profile(for: p.l1Identifier)
    return (l1.uiStrings(at: p.resolvedLevel), l1)
}
```

The `(strings, l1)` tuple is injected into the environment as both `\.moraStrings`
and `\.currentL1Profile`. Callers that need only strings observe the former;
`InterestPickView`, which calls `interestCategoryDisplayName`, observes the latter.

## 6. Per-L1 Authoring Contracts

### 6.1 `JapaneseL1Profile` — three tables

```swift
public struct JapaneseL1Profile: L1Profile {
    public let identifier = "ja"
    public let characterSystem: CharacterSystem = .mixed
    public let interferencePairs: [PhonemeConfusionPair] = [/* unchanged */]
    public let interestCategories: [InterestCategory] = [/* unchanged */]

    public func exemplars(for phoneme: Phoneme) -> [String] { /* unchanged */ }

    public func uiStrings(at level: LearnerLevel) -> MoraStrings {
        switch level {
        case .entry:    return Self.stringsEntryHiraOnly
        case .core:     return Self.stringsCoreG1
        case .advanced: return Self.stringsAdvancedG1G2
        }
    }

    public func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>? {
        switch level {
        case .entry:    return JPKanjiLevel.empty
        case .core:     return JPKanjiLevel.grade1
        case .advanced: return JPKanjiLevel.grade1And2
        }
    }

    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
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

    private static let stringsAdvancedG1G2 = MoraStrings(/* renamed from stringsMid; content unchanged */)
    private static let stringsCoreG1       = MoraStrings(/* G2 kanji collapsed to hiragana */)
    private static let stringsEntryHiraOnly = MoraStrings(/* all kanji collapsed to hiragana */)
}

public extension JPKanjiLevel {
    static let empty: Set<Character> = []
}
```

#### 6.1.1 Authoring rules

- **Authority for kanji budget**: cumulative MEXT 学習指導要領 小学校 別表 学年別漢字配当表
  (2017 告示 / 2020 全面実施). `JPKanjiLevel.grade1` (80 chars) and `.grade2` (160) are
  already shipped; `.empty` is added.
- **Base register**: kid-facing plain form (`〜だよ` / `〜ね`), not `です/ます`.
- **Kanji usage rule**: a word renders in kanji only when *every* component
  character is in the level's budget. Partial-kanji mixing
  (e.g. `聞きとる` for `聞き取る` where `取` is G3 but `聞` is G2) is avoided —
  pick either full-kanji or full-hiragana.
- **Katakana**: loanwords stay katakana
  (`クエスト`, `マイク`, `スキップ`, `ボタン`, `チェック`). Always.
- **Numbers**: half-width digits (`16分`, `5文字`, `3/5`).
- **Punctuation**: `、` for mid-phrase pauses. Omit terminal `。` on UI labels.
- **Mechanical authoring → polish**: the `core` and `entry` tables are produced
  by mechanically transforming the `advanced` table — at `.core`, every kanji
  not in `JPKanjiLevel.grade1` is replaced with its hiragana reading; at `.entry`,
  every kanji is replaced with its hiragana reading. After mechanical
  transformation, Yutaka proof-passes each row in PR 1 review.
- **Audit**: `LocaleScriptBudgetTests` (§10.2) iterates every field of every JP
  table and fails CI on any character outside the corresponding level's budget,
  hiragana / katakana ranges, ASCII digits, the allowed punctuation set
  (`、 。 ？ ！ … › ▶ 🔊`), or whitespace.

#### 6.1.2 Sample rows across the three levels

| Field | `.advanced` (G1+G2) | `.core` (G1) | `.entry` (hira) |
|---|---|---|---|
| `homeTodayQuest` | `今日の クエスト` | `きょうの クエスト` | `きょうの クエスト` |
| `permissionTitle` | `声を 聞くよ` | `こえを きくよ` | `こえを きくよ` |
| `feedbackTryAgain` | `もう一回` | `もういちど` | `もういちど` |
| `homeDurationPill(16)` | `16分` | `16ぷん` | `16ぷん` |
| `homeWordsPill(5)` | `5文字` | `5もじ` | `5もじ` |
| `completionComeBack` | `明日も またね` | `あしたも またね` | `あしたも またね` |
| `bestiaryLinkLabel` | `ともだち ずかん` | `ともだち ずかん` | `ともだち ずかん` |
| `voiceGateTitle` | `英語の 声を ダウンロードしてください` | `えいごの こえを ダウンロードしてください` | (same as core) |
| `homeChangeLanguageButton` | `ことばを かえる` | `ことばを かえる` | `ことばを かえる` |
| `languageSwitchSheetTitle` | `ことばを えらぶ` | `ことばを えらぶ` | `ことばを えらぶ` |
| `languageSwitchSheetCancel` | `キャンセル` | `キャンセル` | `キャンセル` |
| `languageSwitchSheetConfirm` | `OK` | `OK` | `OK` |
| `coachingShSubS` | `くちびるをまるめて、したのおくをもちあげてみよう。「sh」。` | (same — already hira-only in advanced) | (same) |

Many rows already use no kanji in `.advanced` (because the `MoraStrings` constructor
parameters `coachingShSubS`, `bestiaryLinkLabel`, etc. are written in kid-friendly
hiragana already), so the actual new authoring at `.core` is roughly **30 rows**
and at `.entry` is roughly **50 rows**.

`JPStringBucket` (the private `enum { preschool, early, mid, late }` shipped in
the predecessor spec) is deleted. `LearnerLevel` is the only difficulty-axis type
in the system.

### 6.2 `KoreanL1Profile` — single level-invariant table

```swift
public struct KoreanL1Profile: L1Profile {
    public let identifier = "ko"
    public let characterSystem: CharacterSystem = .alphabetic
    public let interferencePairs: [PhonemeConfusionPair] = Self.koInterference
    public let interestCategories: [InterestCategory] = JapaneseL1Profile().interestCategories

    public func exemplars(for phoneme: Phoneme) -> [String] {
        // English exemplars — identical to JP since L2 is English
        switch phoneme.ipa {
        case "ʃ": return ["ship", "shop", "fish"]
        case "tʃ": return ["chop", "chin", "rich"]
        case "θ": return ["thin", "thick", "math"]
        case "f": return ["fan", "fox", "fun"]
        case "r": return ["red", "rat", "run"]
        case "æ": return ["cat", "hat", "bat"]
        case "k": return ["duck", "back", "rock"]
        default: return []
        }
    }

    public func uiStrings(at level: LearnerLevel) -> MoraStrings { Self.stringsKidKo }

    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
        switch key {
        case "animals":   return "동물"
        case "dinosaurs": return "공룡"
        case "vehicles":  return "탈것"
        case "space":     return "우주"
        case "sports":    return "스포츠"
        case "robots":    return "로봇"
        default:          return key
        }
    }

    // allowedScriptBudget: defaults to nil (no script ladder)

    private static let stringsKidKo = MoraStrings(/* ~250 lines */)
}
```

#### 6.2.1 Authoring rules (KO, primary grade 1–2, simple-vocab)

- **Vocabulary level**: 한국 초등 1–2학년 교과서 어휘. Reference: 국립국어원
  한국어 학습용 어휘 목록 (2003), filter to the lowest-frequency tier acceptable
  for a 6-year-old reader.
- **Register**: 반말 (informal), kid-directed. `-요` and `-합니다` honorific forms
  are not used.
- **Sentence length**: target ≤ 8 음절 per phrase. Avoid complex 받침 clusters
  (e.g. `읽었습니다` is too long; prefer `읽었어`).
- **Hanja (한자)**: not used. Korean kid texts are 순한글.
- **Numbers**: half-width (`16분`, `5글자`).
- **Punctuation**: `.` `?` `!` `…`. Omit terminal `.` on UI labels (matches JP convention).
- **Loanwords**: 표준 외래어 표기법 (`퀘스트`, `마이크`, `로봇`).
- **Line breaks**: at meaning boundaries (Korean kid-book convention).

#### 6.2.2 Sample rows

| Field | Value |
|---|---|
| `ageOnboardingPrompt` | `몇 살이야?` |
| `ageOnboardingCTA` | `▶ 시작하기` |
| `welcomeTitle` | `영어 소리, 같이 배워요` |
| `welcomeCTA` | `시작하기` |
| `namePrompt` | `이름이 뭐야?` |
| `homeTodayQuest` | `오늘의 퀘스트` |
| `homeStart` | `▶ 시작하기` |
| `homeDurationPill(16)` | `16분` |
| `homeWordsPill(5)` | `5글자` |
| `homeSentencesPill(2)` | `2문장` |
| `feedbackCorrect` | `정답!` |
| `feedbackTryAgain` | `한 번 더` |
| `completionComeBack` | `내일 또 만나요` |
| `homeChangeLanguageButton` | `언어 바꾸기` |
| `languageSwitchSheetTitle` | `언어 선택` |
| `languageSwitchSheetCancel` | `취소` |
| `languageSwitchSheetConfirm` | `확인` |
| `bestiaryLinkLabel` | `친구 도감` |
| `coachingFSubH` | `윗니로 아랫입술을 살짝 누르고 "fff".` |

### 6.3 `EnglishL1Profile` — single level-invariant table

```swift
public struct EnglishL1Profile: L1Profile {
    public let identifier = "en"
    public let characterSystem: CharacterSystem = .alphabetic
    public let interferencePairs: [PhonemeConfusionPair] = []  // L1 == L2
    public let interestCategories: [InterestCategory] = JapaneseL1Profile().interestCategories

    public func exemplars(for phoneme: Phoneme) -> [String] { /* same as KO */ }

    public func uiStrings(at level: LearnerLevel) -> MoraStrings { Self.stringsKidEn }

    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
        switch key {
        case "animals":   return "Animals"
        case "dinosaurs": return "Dinosaurs"
        case "vehicles":  return "Vehicles"
        case "space":     return "Space"
        case "sports":    return "Sports"
        case "robots":    return "Robots"
        default:          return key
        }
    }

    private static let stringsKidEn = MoraStrings(/* ~250 lines */)
}
```

#### 6.3.1 Authoring rules (EN, primary grade 1–2, simple-vocab)

- **Vocabulary level**: Dolch first 100 sight words primarily; Dolch second 100
  occasionally. Reading level target ≈ late kindergarten / early 1st grade
  (~Lexile 50–200L).
- **Sentence length**: ≤ 8 words per phrase. Avoid embedded clauses.
- **Tone**: warm, encouraging, kid-directed. "you", "let's", "we" are fine.
- **Concrete vs abstract**: prefer concrete kid words (`see`, `go`, `find`,
  `play`) over abstract ones (`acknowledge`, `proceed`, `verify`).
- **Numbers**: half-width (`16 min`, `5 words`).
- **Punctuation**: ASCII; omit terminal `.` on UI labels.
- **Existing English literals in MoraUI** (e.g. `"Today's quest"`, `"Start"`,
  `"Got it"`) are migrated as-is into `stringsKidEn` where they already meet
  these rules. New authoring is roughly **20–30 fields** that previously had
  only a Japanese counterpart.

#### 6.3.2 Sample rows

| Field | Value |
|---|---|
| `ageOnboardingPrompt` | `How old are you?` |
| `ageOnboardingCTA` | `▶ Start` |
| `welcomeTitle` | `Let's learn English sounds together` |
| `welcomeCTA` | `Start` |
| `namePrompt` | `What's your name?` |
| `homeTodayQuest` | `Today's quest` |
| `homeStart` | `▶ Start` |
| `homeDurationPill(16)` | `16 min` |
| `homeWordsPill(5)` | `5 words` |
| `homeSentencesPill(2)` | `2 sentences` |
| `feedbackCorrect` | `Correct!` |
| `feedbackTryAgain` | `Try again` |
| `completionComeBack` | `See you tomorrow!` |
| `homeChangeLanguageButton` | `Change language` |
| `languageSwitchSheetTitle` | `Pick a language` |
| `languageSwitchSheetCancel` | `Cancel` |
| `languageSwitchSheetConfirm` | `Done` |
| `bestiaryLinkLabel` | `Friends book` |
| `coachingFSubH` | `Press your top teeth on your bottom lip. Say "fff".` |

### 6.4 KO `interferencePairs` initial set

Authored from KO L1 → EN L2 phonological transfer literature
(Ko 2009; Cho & Park 2006; Yang 1996). All tags are prefixed `ko_` so the
assessment engine can distinguish KO-attributed substitutions from JP-attributed
ones in trial logs.

| tag | from | to | bidirectional | examples | rationale |
|---|---|---|---|---|---|
| `ko_f_p_sub` | `f` | `p` | false | fan/pan, fox/pox | KO has `ㅍ` /pʰ/ but no /f/ |
| `ko_v_b_sub` | `v` | `b` | false | vat/bat, very/berry | KO has `ㅂ` /p, b/ but no /v/ |
| `ko_th_voiceless_s_sub` | `θ` | `s` | false | thin/sin, thick/sick | TH not in KO inventory |
| `ko_th_voiceless_t_sub` | `θ` | `t` | false | thin/tin, three/tree | alternate TH realization |
| `ko_z_dz_sub` | `z` | `dʒ` | false | zoo/Jew, zip/Jip | KO `ㅈ` is affricate; absorbs /z/ |
| `ko_r_l_swap` | `r` | `l` | true | right/light, rock/lock | KO `ㄹ` realizes [r] medially, [l] in coda |
| `ko_ae_e_conflate` | `æ` | `ɛ` | true | bad/bed, cat/ket | KO has `애` [ɛ] but `æ` is novel |
| `ko_sh_drift_target` | `ʃ` | `ʃ` | false | ship, shop, fish | drift sentinel (same shape as JP); evaluator scores within-phoneme drift |

The set is "best-effort initial" — Yutaka is not a KO native speaker. The
pronunciation-bench infrastructure (`docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md`)
can later validate against real KO-L1 recordings if fixtures become available;
that's a separate spec.

### 6.5 Coaching scaffolds per L1

`MoraStrings` includes 10 coaching-banner fields
(`coachingShSubS`, `coachingShDrift`, `coachingRSubL`, `coachingLSubR`,
`coachingFSubH`, `coachingVSubB`, `coachingThVoicelessSubS`,
`coachingThVoicelessSubT`, `coachingTSubThVoiceless`, `coachingAeSubSchwa`).

| L1 | Authoring needed |
|---|---|
| JP | All 10 already shipped; identical content across the three levels (no kanji to budget) |
| KO | All 10 newly authored in 한국어, mapped to KO interferences (e.g. `coachingFSubH` reads `윗니로 아랫입술을 살짝 누르고 "fff".`) |
| EN | All 10 newly authored in English. **Dead path at runtime** because `EnglishL1Profile.interferencePairs == []`, so the assessment engine never matches a substitution that would surface a coaching banner. Authored as ordinary English coaching strings (e.g. `coachingShSubS` = `"Round your lips and lift the back of your tongue. Say 'sh'."`) so the `MoraStrings` constructor is fully populated and the field never displays an obviously placeholder value if a future code path renders it directly. |

### 6.6 Bestiary date formatters per L1

JP currently uses `Calendar(identifier: .gregorian)` with `Locale("ja_JP")` to
keep date strings within the G1+G2 kanji budget (a Japanese imperial-era
formatter would emit `令和`, which is G4 and out of budget). KO and EN each ship
their own analogous formatter as a private static on the profile struct:

```swift
// KoreanL1Profile.swift
private static let bestiaryDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ko_KR")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateStyle = .long  // → "2026년 4월 26일"
    return f
}()

// EnglishL1Profile.swift
private static let bestiaryDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateStyle = .long  // → "April 26, 2026"
    return f
}()
```

Both are referenced by the `bestiaryBefriendedOn` closure inside their respective
`stringsKidKo` / `stringsKidEn` initializers.

### 6.7 Authoring volume

| Component | New Swift LOC (approx.) |
|---|---|
| `LearnerLevel.swift` | 30 |
| `L1ProfileResolver.swift` | 25 |
| `JapaneseL1Profile` 3-tier authoring (delta) | 200 |
| `KoreanL1Profile.swift` (struct + `stringsKidKo` + interference + display + formatter) | 300 |
| `EnglishL1Profile.swift` (struct + `stringsKidEn` + display + formatter) | 250 |
| `JPKanjiLevel.empty` | 1 |
| `LearnerProfile.levelOverride` + `resolvedLevel` | 20 |
| `MoraStringsEnvironment` env keys | 20 |
| `RootView` resolution path | 20 |
| `LanguageAgeFlow` activation + system locale default + 3-tile age picker | 50 |
| `LanguageSwitchSheet.swift` | 80 |
| `HomeView` globe button + sheet integration | 15 |
| New `MoraStrings` fields (`homeChangeLanguageButton` / `languageSwitchSheetTitle` / `languageSwitchSheetCancel` / `languageSwitchSheetConfirm`) authored across 4 tables × 4 fields | 16 |
| Tests (unit + UI) | 500 |
| Mechanical call-site rewrites | 27 |
| **Total** | **~1,550 LOC** |

## 7. Onboarding & In-app Language Switch

### 7.1 Language picker UX

Two changes from the predecessor spec's Step 1:

1. **Active rows expand from 1 to 3.** Japanese, Korean, English are all selectable.
   Mandarin (`中文`) remains disabled with `(Coming soon)`.

   | Row | Label | State |
   |---|---|---|
   | 1 | `にほんご` | active |
   | 2 | `한국어` | active (NEW) |
   | 3 | `English` | active (NEW) |
   | 4 | `中文` | disabled `(Coming soon)` |

2. **Default selection follows system locale.**
   `Locale.current.language.languageCode?.identifier` returns `"ja"` / `"ko"` /
   `"en"` / etc. The flow's pre-selected row is derived as:

   - `"ja"` → Japanese
   - `"ko"` → Korean
   - any other value (`"en"`, `"zh"`, `"es"`, `"vi"`, `nil`, …) → **English**

   English is the unsupported-locale fallback because (a) it is the L2 the app
   teaches and (b) parents whose system locale is unsupported are highly likely
   to read English (especially in mobile-first markets with Latin-script device
   configurations).

The header `Language / 言語 / 语言 / 언어` is unchanged — the four-script
multilingual header was already designed to recognize this set of L1s
including the deferred ZH.

### 7.2 Age picker UX

The 3 × 4 grid (ages 4–12 + `13+`) shrinks to a single row of three tiles
(`6` / `7` / `8`), default-selected to `7`. Tile numeric size scales up
(SF Rounded Heavy approx 80 → 120pt) to fill the freed vertical space and
present a confident "this app targets 6–8" message to the parent.

Existing copy (`moraStrings.ageOnboardingPrompt` = `なんさい？` / `몇 살이야?` /
`How old are you?`) is unchanged.

### 7.3 In-app language switch (Home globe button + `LanguageSwitchSheet`)

**Motivation.** OS system language and the language the family speaks at home
diverge for a real and growing population: Korean families in Japan with
JP-locale iPads, Japanese families in the US with EN-locale iPads, multilingual
households who left a previous device's language in place, etc. Onboarding-time
language choice is necessary but not sufficient — users need an in-app way to
revisit it.

**Surface.** Home renders a small globe `Image(systemName: "globe")` next to
the wordmark. Tap presents a sheet:

```swift
// MoraUI/LanguageAge/LanguageSwitchSheet.swift  (NEW)
public struct LanguageSwitchSheet: View {
    let currentIdentifier: String
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.moraStrings) private var strings
    @State private var pickedID: String

    public init(currentIdentifier: String, onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.currentIdentifier = currentIdentifier
        self.onCommit = onCommit
        self.onCancel = onCancel
        self._pickedID = State(initialValue: currentIdentifier)
    }

    public var body: some View {
        NavigationStack {
            // Reuses the LanguageRowView used by LanguageAgeFlow Step 1 — see
            // §8.3 for the file split that hoists it into a shared component.
            LanguagePicker(selection: $pickedID)
                .navigationTitle(strings.languageSwitchSheetTitle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(strings.languageSwitchSheetCancel) { onCancel() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(strings.languageSwitchSheetConfirm) {
                            onCommit(pickedID)
                        }
                        .disabled(pickedID == currentIdentifier)
                    }
                }
        }
    }
}
```

The sheet's confirmation button is disabled when the picked language equals the
current one — preventing a no-op write. The sheet does not pre-select based on
system locale (it preserves the user's current choice). Cancel dismisses
without writing.

**Persistence.** The sheet's `onCommit` closure (wired by `HomeView`) updates
`profile.l1Identifier`, calls `modelContext.save()`, dismisses the sheet, and
returns to Home. The `\.moraStrings` and `\.currentL1Profile` environments
re-resolve from the updated profile on the next render pass. There is no
imperative refresh — SwiftData publishes the change and SwiftUI invalidates.

**What is NOT touched by the switch:** `ageYears`, `levelOverride`, `interests`,
`preferredFontKey`, `displayName`, `createdAt`, the `tech.reenable.Mora.languageAgeOnboarded`
flag, the `tech.reenable.Mora.onboarded` flag. Streak counters, yokai cameos,
session history — all preserved.

**New `MoraStrings` fields** (authored in all four tables — JP entry / core /
advanced + KO + EN, see §6.1.2 / §6.2.2 / §6.3.2 for sample rows):

```swift
public let homeChangeLanguageButton: String    // a11y label for the globe icon
public let languageSwitchSheetTitle: String    // sheet navigation title
public let languageSwitchSheetCancel: String   // sheet cancel CTA
public let languageSwitchSheetConfirm: String  // sheet confirm CTA
```

The confirm CTA is its own field (rather than reusing `welcomeCTA`) because the
"start the app" verb is semantically different from the "commit a language
change" verb in every L1, and reusing the field would emit the wrong tone.

The JP three-tier `homeChangeLanguageButton` collapses to `ことばを かえる`
(hiragana-only) at all three levels because the natural phrasing (`言葉を 変える`)
contains G3 kanji `葉` and `変`, both out of every JP budget. The single
hiragana version is shipped to all three tiers — partial-kanji mixing is
disallowed by §6.1.1.

### 7.4 System-locale default rule

```swift
// LanguageAgeFlow.swift — initial selection helper
static func defaultLanguageID() -> String {
    let code = Locale.current.language.languageCode?.identifier
    switch code {
    case "ja": return "ja"
    case "ko": return "ko"
    default:   return "en"
    }
}
```

This rule fires only on **fresh install Step 1** (when the user has never picked
a language). It does **not** fire when the LanguageSwitchSheet is opened from
Home — that sheet preserves the existing `l1Identifier` as default.

### 7.5 Migration for existing dev install

The sole existing install: Yutaka's iPad. Stored state:
`l1Identifier == "ja"`, `ageYears == 8`, no `levelOverride` field (schema-old).

| Boot step | Behavior |
|---|---|
| App launches | SwiftData lightweight migration adds `levelOverride: nil` column |
| `RootView` reads UserDefaults | both `tech.reenable.Mora.languageAgeOnboarded` and `.onboarded` are true |
| Onboarding flows skipped | user lands directly on Home |
| Profile resolution | `L1ProfileResolver.profile(for: "ja") = JapaneseL1Profile()` |
| Level resolution | `levelOverride == nil` → `LearnerLevel.from(years: 8) = .advanced` |
| UI strings | `JapaneseL1Profile().uiStrings(at: .advanced) == stringsAdvancedG1G2` |

`stringsAdvancedG1G2` is a name change; its content is byte-identical to the
predecessor spec's `stringsMid`. The dev iPad sees the same Home, same chrome,
same yokai, same streak, same everything.

### 7.6 Out-of-range age behavior

The new picker exposes only ages 6 / 7 / 8, but `LearnerLevel.from(years:)` defines
behavior for any integer age:

| `ageYears` | `LearnerLevel` |
|---|---|
| less than 7 | `.entry` |
| 7 | `.core` |
| 7 or more | `.advanced` |

A learner who installed during the alpha and chose, e.g., age 5 retains that
value; on upgrade they resolve to `.entry`. A learner at age 11 resolves to
`.advanced`. This is graceful degradation — no crash, no re-prompt, but content
fit may be suboptimal at the edges. The dev iPad is the only known existing
install and is at age 8 (`.advanced`), so this case is theoretical.

## 8. Call-Site Migration

### 8.1 Mechanical churn (27 lines across 14 files)

| File | Change |
|---|---|
| `MoraCore/L1Profile.swift` | Protocol decl replaced |
| `MoraCore/JapaneseL1Profile.swift:99-106` | `uiStrings(forAgeYears:)` → `uiStrings(at:)`; switch on `LearnerLevel` |
| `MoraCore/JapaneseL1Profile.swift:88-90` | Delete `JPStringBucket` enum and `bucket(forAgeYears:)` |
| `MoraCore/JapaneseL1Profile.swift:108-118` | `interestCategoryDisplayName(...forAgeYears:)` → `(...at:)` |
| `MoraUI/Design/MoraStringsEnvironment.swift:12` | `defaultValue: JapaneseL1Profile().uiStrings(forAgeYears: 8)` → `MoraStrings.previewDefault` |
| `MoraUI/RootView.swift:64` | rewrite `resolvedStrings(for:)` to use `L1ProfileResolver` + `resolvedLevel` |
| `MoraUI/LanguageAge/LanguageAgeFlow.swift:103` | `forAgeYears: state.selectedAge ?? 8` → `at: LearnerLevel.from(years: state.selectedAge ?? 7)` (default 7 because that's the new midpoint) |
| `MoraUI/Onboarding/InterestPickView.swift:66` | `forAgeYears: ageYears` → `at: profile.resolvedLevel` (profile from `\.currentL1Profile` env) |
| 9 `#Preview` blocks | `JapaneseL1Profile().uiStrings(forAgeYears: 8)` → `MoraStrings.previewDefault` |
| `MoraCoreTests/InterferenceMatchTests.swift:18` | mock signature update |
| `MoraCoreTests/L1ProfileProtocolTests.swift:9` | mock signature update |
| `MoraCoreTests/MoraStringsTests.swift` (8 sites) | `forAgeYears: 8` → `at: .advanced`; existing kanji audit block extracted to `LocaleScriptBudgetTests` |
| `MoraUITests/PronunciationFeedbackOverlayTests.swift:10` | `forAgeYears: 8` → `at: .advanced` |
| `MoraUITests/YokaiIntroPanel2AudioTests.swift:54,85` | same |

### 8.2 `#Preview` block consolidation

Currently 9 `#Preview` blocks in `MoraUI` repeat the literal
`JapaneseL1Profile().uiStrings(forAgeYears: 8)`. After PR 1 they all become
`MoraStrings.previewDefault`. Future L1 additions never need to touch these
blocks.

Affected files:
`YokaiIntroFlow.swift` (×2), `SessionShapePanel.swift`, `TodaysYokaiPanel.swift`,
`DecodingTutorialOverlay.swift` (×2), `SlotMeaningPanel.swift`, `YokaiConceptPanel.swift`,
`ProgressPanel.swift`, `AudioLinkPanel.swift`.

### 8.3 New file inventory

```
Packages/MoraCore/Sources/MoraCore/
├── LearnerLevel.swift                                 (NEW, PR 1)
├── L1ProfileResolver.swift                            (NEW, PR 1)
├── KoreanL1Profile.swift                              (NEW, PR 2)
├── EnglishL1Profile.swift                             (NEW, PR 2)
└── (existing files modified in place)

Packages/MoraUI/Sources/MoraUI/
├── LanguageAge/LanguageSwitchSheet.swift              (NEW, PR 3)
└── LanguageAge/LanguagePicker.swift                   (NEW, PR 3)
                  — extracted from LanguageAgeFlow's Step 1 view
                    so the sheet can reuse it without copy-paste

Packages/MoraCore/Tests/MoraCoreTests/
├── LearnerLevelTests.swift                            (NEW, PR 1)
├── LocaleScriptBudgetTests.swift                      (NEW, PR 1)
├── L1ProfileResolverTests.swift                       (NEW, PR 1; expanded PR 2)
├── KoreanL1ProfileTests.swift                         (NEW, PR 2)
├── EnglishL1ProfileTests.swift                        (NEW, PR 2)
└── LearnerProfileLevelTests.swift                     (NEW, PR 1)

Packages/MoraUI/Tests/MoraUITests/
├── LanguageSwitchSheetTests.swift                     (NEW, PR 3)
└── (existing LanguageAgeFlowTests extended in PR 2 + PR 3)
```

## 9. Phase Plan

Three stacked PRs. Each must be green on `swift test` (all four package test
targets), `xcodebuild build` (the CI command in `CLAUDE.md`), and
`swift-format lint --strict`.

### PR 1 — Foundation + JP three-tier authoring

Branch: `feat/mora-i18n/01-foundation-and-jp-tiers`. Estimated 700 LOC.

**Deliverables.**
- `LearnerLevel`, `L1ProfileResolver`, `JPKanjiLevel.empty`, `MoraStrings.previewDefault`.
- `L1Profile` protocol rewrite + default extensions.
- `LearnerProfile.levelOverride` + `resolvedLevel`.
- `MoraStringsEnvironment` env-key additions.
- `RootView` resolution path rewrite.
- `JapaneseL1Profile` rewrite: `stringsMid` → `stringsAdvancedG1G2` rename,
  `stringsCoreG1` and `stringsEntryHiraOnly` authored, `allowedScriptBudget(at:)`
  implemented, `JPStringBucket` deleted.
- Mechanical call-site rewrites (27 lines + 9 previews).
- New tests: `LearnerLevelTests`, `LearnerProfileLevelTests`, `L1ProfileResolverTests`
  (JP fallback only), `LocaleScriptBudgetTests` (JP × 3 levels), extended
  `JapaneseL1ProfileTests`, extended `JPKanjiLevelTests`.

**Behavioral effect.** Dev iPad continues exactly as before (resolves to
`.advanced` via age 8). Fresh install with age 6 or 7 sees the new hira-shifted
tables. KO and EN rows in the picker are still `(Coming soon)`.

### PR 2 — KO and EN profiles + picker activation

Branch: `feat/mora-i18n/02-ko-and-en-profiles`. Estimated 700 LOC.

**Deliverables.**
- `KoreanL1Profile.swift` (struct + `stringsKidKo` + 8 interferencePairs + display).
- `EnglishL1Profile.swift` (struct + `stringsKidEn` + empty interferences + display).
- `L1ProfileResolver` extended to dispatch `"ko"` → `KoreanL1Profile()`,
  `"en"` → `EnglishL1Profile()`.
- `LanguageAgeFlow` activates the 한국어 and English rows; system-locale
  default-selection rule (§7.4) implemented.
- New tests: `KoreanL1ProfileTests` (with CJK Hangul-purity sweep),
  `EnglishL1ProfileTests`, expanded `L1ProfileResolverTests`,
  expanded `LanguageAgeFlowTests`.
- Manual smoke: simulator fresh install with each L1 (Korean / English),
  confirm full A-day session completes, bestiary date format correct.

**Behavioral effect.** New installs can pick Korean or English; the chrome
renders in the chosen language across all screens. Dev iPad unaffected.

### PR 3 — Age picker narrow + in-app language switch

Branch: `feat/mora-i18n/03-age-narrow-and-language-switch`. Estimated 200 LOC.

**Deliverables.**
- `LanguageAgeFlow`'s age picker narrows to 3 tiles (6 / 7 / 8), default 7;
  visual scale-up.
- `LanguagePicker.swift` extracted (a refactor of LanguageAgeFlow's existing
  Step 1 view into a reusable component).
- `LanguageSwitchSheet.swift` new, consuming `LanguagePicker`.
- `HomeView` adds the globe button next to the wordmark and presents the sheet.
- New `MoraStrings` fields (`homeChangeLanguageButton`, `languageSwitchSheetTitle`,
  `languageSwitchSheetCancel`) authored in all four tables.
- New tests: `LanguageSwitchSheetTests`, `HomeViewLanguageSwitchTests` (smoke).
- Manual smoke on dev iPad: open Home, tap globe, switch to Korean, observe
  immediate re-render of all chrome; switch back to Japanese, observe state
  preservation (streak, yokai cameos).

**Behavioral effect.** The age picker visibly narrows. A globe button appears
on Home; users can re-pick their language without losing state.

## 10. Testing Strategy

### 10.1 Unit tests (`swift test`)

`MoraCore`:

- `LearnerLevelTests`
  - `LearnerLevel.from(years: 6).rawValue == "entry"`, `7 → "core"`, `8 → "advanced"`,
    `5 → "entry"`, `15 → "advanced"`.
  - `Codable` round-trip via JSONEncoder/Decoder for each case.
  - `allCases.count == 3`.

- `JPKanjiLevelTests` (extended)
  - `JPKanjiLevel.empty.isEmpty == true`.
  - `JPKanjiLevel.grade1.isSubset(of: .grade1And2) == true`.
  - Existing 80 / 160 / 240 count assertions retained.

- `LocaleScriptBudgetTests` (NEW, replacing the kanji audit block previously
  embedded in `MoraStringsTests`). See §10.2.

- `JapaneseL1ProfileTests` (extended)
  - `uiStrings(at: .advanced)` content equals the predecessor spec's `stringsMid`
    (catches accidental authoring drift during the rename).
  - `uiStrings(at: .core)` and `(at: .entry)` are non-empty for every field.
  - `allowedScriptBudget(at: .entry).isEmpty`,
    `(at: .core) == JPKanjiLevel.grade1`,
    `(at: .advanced) == JPKanjiLevel.grade1And2`.
  - `interestCategoryDisplayName(key:at:)` returns Japanese for the six seeded
    keys at all three levels; identical across levels (interests are not
    age-varying, per predecessor spec §14 #4).

- `KoreanL1ProfileTests` (NEW)
  - Three levels return identical `MoraStrings` (single instance).
  - All `MoraStrings` fields non-empty.
  - `interferencePairs.count == 8`, each tag has `ko_` prefix, expected pairs
    present.
  - `interestCategoryDisplayName(key:at:)` returns Korean for all six seeded
    keys.
  - `allowedScriptBudget(at:)` is `nil` for all three levels.
  - **Hangul-purity sweep**: every character of every field is checked for
    absence of CJK Unified Ideographs (`U+4E00..U+9FFF`) and CJK Compatibility
    Ideographs (`U+F900..U+FAFF`). Fails on any Hanja insertion.

- `EnglishL1ProfileTests` (NEW)
  - Three levels return identical `MoraStrings`.
  - `interferencePairs.isEmpty`.
  - All field characters are ASCII letters / digits / punctuation /
    `▶` / `🔊`.
  - `interestCategoryDisplayName(key:at:)` returns English.

- `L1ProfileResolverTests` (NEW)
  - `profile(for: "ja").identifier == "ja"`, `"ko" → "ko"`, `"en" → "en"`.
  - `profile(for: "").identifier == "ja"`, `"zh" → "ja"`, `"xx" → "ja"`
    (fallback).

- `LearnerProfileLevelTests` (NEW)
  - `levelOverride == nil` & `ageYears == 8` → `resolvedLevel == .advanced`.
  - `levelOverride == "core"` & `ageYears == 8` → `resolvedLevel == .core`
    (override wins).
  - `levelOverride == "fictional"` (invalid raw) → `resolvedLevel ==
    LearnerLevel.from(years: ageYears ?? 8)` (graceful fallback).
  - `levelOverride == nil` & `ageYears == nil` → `.advanced` (defensive default).
  - Persistence round-trip: set `levelOverride = "entry"`, save, reload,
    `resolvedLevel == .entry`.
  - Migration smoke: open a SwiftData container against an in-memory schema
    that was created without the `levelOverride` field; verify lightweight
    migration adds the field as nil.

`MoraUI`:

- `LanguageAgeFlowTests` (extended)
  - Korean and English rows are enabled; Mandarin disabled.
  - Age picker shows exactly three tiles (6, 7, 8); default-selected is 7.
  - `defaultLanguageID()`: `Locale("ja_JP")` → `"ja"`; `"ko_KR"` → `"ko"`;
    `"en_US"` → `"en"`; `"zh_CN"` / `"es_ES"` / `"vi_VN"` / nil → `"en"`.
  - Completion writes both `l1Identifier` and `ageYears`; `levelOverride`
    untouched.

- `LanguageSwitchSheetTests` (NEW)
  - On open, the `currentIdentifier` row is pre-selected.
  - Tapping a different row enables the confirmation button.
  - Confirmation button stays disabled when picked == current.
  - Confirm callback receives the new identifier; cancel callback fires the
    cancellation closure.
  - All three active language transitions exercised (ja↔ko, ja↔en, ko↔en).

- `HomeViewLanguageSwitchTests` (NEW, smoke only)
  - Globe button is rendered when a profile exists.
  - Tap presents the sheet (state assertion only, not a full UI test).

`MoraTesting`: no additions.

### 10.2 `LocaleScriptBudgetTests` design

```swift
final class LocaleScriptBudgetTests: XCTestCase {
    func test_allProfileLevelCombinationsRespectScriptBudget() {
        let profiles: [any L1Profile] = [
            JapaneseL1Profile(),
            KoreanL1Profile(),
            EnglishL1Profile(),
        ]
        for profile in profiles {
            for level in LearnerLevel.allCases {
                let strings = profile.uiStrings(at: level)
                guard let budget = profile.allowedScriptBudget(at: level) else {
                    continue  // KO / EN — no script ladder applies
                }
                for (fieldName, value) in EveryStringField(strings) {
                    for char in value {
                        XCTAssertTrue(
                            isAllowed(char, budget: budget),
                            "[\(profile.identifier) @ \(level.rawValue)] '\(fieldName)' contains '\(char)' outside the budget"
                        )
                    }
                }
            }
        }
    }

    private func isAllowed(_ char: Character, budget: Set<Character>) -> Bool {
        if budget.contains(char) { return true }
        // Hiragana / Katakana / ASCII / common punctuation always allowed
        for scalar in char.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x309F: continue  // Hiragana
            case 0x30A0...0x30FF: continue  // Katakana
            case 0x0030...0x0039: continue  // ASCII digits
            case 0x0020, 0x000A, 0x000D: continue  // whitespace, newline, CR
            case 0x0021, 0x002C, 0x002E, 0x002F, 0x003A, 0x003F: continue  // ! , . / : ?
            case 0x3001, 0x3002, 0x300C, 0x300D, 0x2026, 0x203A, 0x25B6: continue  // 、。「」… › ▶
            case 0x1F50A: continue  // 🔊
            default: return false
            }
        }
        return true
    }
}

private func EveryStringField(_ strings: MoraStrings) -> [(name: String, value: String)] {
    // Hand-enumerated KeyPath list for memory stability. Closure-valued
    // fields are invoked at representative arguments (1, 5, 16, etc.) and
    // the resulting strings are included.
    [
        ("ageOnboardingPrompt", strings.ageOnboardingPrompt),
        ("welcomeTitle",       strings.welcomeTitle),
        // ... ~100 entries
        ("homeDurationPill(16)", strings.homeDurationPill(16)),
        ("homeWordsPill(5)",     strings.homeWordsPill(5)),
        ("homeChangeLanguageButton", strings.homeChangeLanguageButton),
        ("languageSwitchSheetTitle", strings.languageSwitchSheetTitle),
        ("languageSwitchSheetCancel", strings.languageSwitchSheetCancel),
        // ...
    ]
}
```

The grid runs 9 cells (3 profiles × 3 levels) but only 3 are non-skipped (JP × 3
levels). Well under one second total.

### 10.3 KO Hangul-purity sweep

`KoreanL1Profile` returns `nil` from `allowedScriptBudget(at:)`, so the global
budget validator does not catch accidental Hanja insertion. A locale-specific
sweep test guards this:

```swift
final class KoreanL1ProfileTests: XCTestCase {
    func test_stringsKidKo_containsNoCJKIdeographs() {
        let strings = KoreanL1Profile().uiStrings(at: .core)
        for (fieldName, value) in EveryStringField(strings) {
            for char in value {
                for scalar in char.unicodeScalars {
                    let v = scalar.value
                    XCTAssertFalse(
                        (0x4E00...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v),
                        "[ko @ core] '\(fieldName)' contains CJK ideograph U+\(String(v, radix: 16, uppercase: true))"
                    )
                }
            }
        }
    }
}
```

### 10.4 Manual / device smoke per PR

| PR | Smoke checklist |
|---|---|
| PR 1 | Dev iPad upgrade-over-existing → Home identical to pre-upgrade; streak / yokai cameos / interests preserved; complete one A-day session. |
| PR 2 | Simulator fresh install → 한국어 + age 7 → all chrome KO; complete one session. Repeat with English + age 6. Repeat with system locale set to `vi_VN` → English pre-selected. |
| PR 3 | Dev iPad: tap globe, switch ja → ko, observe instant re-render of all chrome; tap globe, switch back ko → ja. Streak count and yokai cameos remain unchanged. |

### 10.5 What is not tested

- SwiftUI snapshot diffs (no harness in the repo; brittle).
- Korean linguistic correctness beyond CJK-purity (no native KO reviewer in the
  loop yet).
- LLM-driven translation (no LLM code in this spec).
- ZH (Mandarin) — no profile exists.
- Pronunciation evaluator behavior with `EnglishL1Profile` (empty interference
  set). The existing `AssessmentEngine` logic handles `interferencePairs == []`
  by skipping interference matching; we do not add an integration test for this
  path because the behavior is exercised by `JapaneseL1Profile` substitution
  tests and the empty-array case is structurally trivial.

## 11. Error & Boundary Handling

| Scenario | Handling |
|---|---|
| User opens `LanguageSwitchSheet`, picks a different language, app force-quit before save | The save closure runs on the same actor as the sheet dismissal; `try? modelContext.save()` is awaited (or unblocked synchronously inline). On force-quit before persistence completes, the previous `l1Identifier` remains. Acceptable. |
| `LearnerProfile.l1Identifier` contains an unknown value (e.g. legacy data, future-spec rollback) | `L1ProfileResolver` falls back to `JapaneseL1Profile`. Tested in `L1ProfileResolverTests`. |
| `LearnerProfile.levelOverride` contains an invalid raw string | `LearnerLevel(rawValue:)` returns nil; `resolvedLevel` falls through to age-derive. Tested in `LearnerProfileLevelTests`. |
| `LearnerProfile.ageYears == nil` and `levelOverride == nil` | `resolvedLevel` returns `.advanced` (the defensive `?? 8` fallback). Should not occur in practice — onboarding requires age — but keeps `RootView` from crashing on stale rows. |
| User picks Korean, then switches to Japanese (or vice-versa) mid-session | Mid-session L1 switch is not a supported gesture: the globe button is on Home, not in `SessionContainerView`. If a future regression placed it inside session, the strings/profile environment would re-render but already-rendered word/sentence content (English) would not change — which is correct (the L2 content never localizes). No additional handling needed. |
| Korean user installs the app while OS locale is `pt_PT` (Portuguese) | Step 1 pre-selects English (international fallback); user manually picks Korean. One extra tap. Acceptable. |
| SwiftData lightweight migration of `levelOverride` fails | The on-disk → in-memory fallback in `MoraApp.init()` catches container creation failures; the user lands in a fresh-install flow. Non-destructive (the original data is on disk; the user can reinstall to recover). SwiftData lightweight migration of an additive nullable property has no documented failure mode, so this is a safety net only. |
| User long-presses globe button, expects context menu | No context menu is implemented; tap = open sheet, long-press = ignored. |
| Sheet open + globe button still tap-able (double-tap) | The sheet is presented modally; the underlying Home is non-interactive while the sheet is up. SwiftUI default behavior. |

## 12. Out of Scope

Explicitly deferred, with a pointer to where each belongs:

- ZH (Mandarin / 简体) `MandarinL1Profile` and the simplified-character grade
  ladder (`ZHCharacterLevel`) — separate spec, framework supports additively.
- Other major-language L1s (Spanish, Vietnamese, Hindi, Portuguese, Tagalog,
  …) — separate specs, same additive pattern.
- Settings page for editing age, level, interests, font, streak — future
  Settings spec.
- User-facing UI for setting `LearnerProfile.levelOverride`. Schema field
  ships; UI does not.
- LLMLocalizer (Apple Intelligence Foundation Models / MLX-hosted Gemma) — v1.5
  spec under `MoraMLX`.
- L1-specific TTS narration of rule explanations — future plan.
- Per-L1 yokai catalog (`YokaiCatalog.json`) and per-L1 voice clips (`.m4a`).
  Voice is fixed English per project memory.
- Per-L1 interest categories (e.g. KO K-pop, ZH 武侠) beyond the shared 6-key
  set.
- Furigana rendering — avoided here by capping JP `entry` at hira-only and
  `core` at G1.
- UD Digi Kyokasho / Hangul-optimized / English-dyslexia fonts — future
  typography plan.
- Korean linguistic review by a native KO ESL specialist — invitational, not
  blocking.

## 13. Open Questions

| # | Question | Plan |
|---|---|---|
| 1 | KO `interferencePairs` linguistic accuracy | Initial 8-pair set ships in PR 2. Yutaka invites a KO ESL contact for review when one becomes available; revision via a follow-up content-only PR. The bench infrastructure can validate against KO-L1 recordings if fixtures are provided (separate spec). |
| 2 | EN coaching scaffolds are dead-code paths but require authoring | Decision: keep `String` (non-optional) on `MoraStrings` to avoid `??`-everywhere at call sites. Author 10 reasonable English coaching strings; cost is negligible. |
| 3 | Will younger Korean kids (age 6) want a hira-equivalent simplification? | KO does not have a writing-system difficulty axis (kids learn 한글 by age 5). Vocabulary register is the only remaining axis, and the simple-vocab rule (§6.2.1) already targets the youngest end of 1-2학년. If real testing surfaces the need, a future spec adds `KoreanL1Profile.stringsEntry` analogous to JP. |
| 4 | Is the globe button on Home discoverable enough? | PR 3 dev-iPad smoke includes asking the kid to find it. If discovery fails, follow-up adds either (a) a one-time hint after onboarding completion, or (b) a wordmark long-press affordance. Not blocking PR 3 merge. |
| 5 | Will users confused by an English-fallback Step 1 (when system locale is unsupported) realize they can scroll to find their language? | The picker is a fixed list of four rows; there is no hidden scroll. The user sees `English` selected and three other options, and can re-tap. Acceptable. |
| 6 | Does shipping `levelOverride` in the schema without a UI lead to drift? | The dev iPad is the only existing install and remains at `nil`. When the Settings spec lands, the migration is "no-op" because all rows are already `nil`. Acceptable. |
| 7 | Should the `LanguageSwitchSheet` also expose the level override, given the schema field exists? | No — keep this sheet language-only. Mixing concerns risks accidentally changing a learner's difficulty when they meant to change language. The level override UI is part of the future Settings plan. |

## 14. References

- Predecessor spec (superseded API; retained schema): `docs/superpowers/specs/2026-04-22-native-language-and-age-selection-design.md`
- Canonical product spec: `docs/superpowers/specs/2026-04-21-mora-dyslexia-esl-design.md` §9 Multi-L1 Architecture, §17 Open Question 7
- SPM-layout design: `docs/superpowers/specs/2026-04-21-mora-design.md`
- Pronunciation bench design (for future KO interference validation): `docs/superpowers/specs/2026-04-22-pronunciation-bench-and-calibration-design.md`
- Project-wide language policy: `CLAUDE.md` § Language policy. This spec complies — prose is English; per-locale string literals (Japanese, Korean) appear only inside `L1Profile` implementations and as illustrative table values in the spec.
- Project memory: `feedback_mora_i18n_text_vs_voice.md` (voice fixed English, only text localizes)
- Kanji curriculum authority: MEXT 学習指導要領 小学校 別表 学年別漢字配当表 (2017 告示, 2020-04-01 全面実施)
- KO L1 → EN L2 phonological transfer: Ko, S. (2009) "Korean speakers' perception and production of English /f/ and /v/"; Cho, M. & Park, M. (2006) "A comparative study of Korean and English vowel systems"; Yang, B. (1996) "A comparative study of American English and Korean vowels"
- KO primary-grade vocabulary reference: 국립국어원 한국어 학습용 어휘 목록 (2003)
- Dolch sight word list: E. W. Dolch (1936) "A basic sight vocabulary"
