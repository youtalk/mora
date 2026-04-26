# Multi-L1 i18n + Age-Driven Difficulty Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the alpha's age-keyed `uiStrings(forAgeYears:)` API with a unified `LearnerLevel { entry, core, advanced }` enum consumed by every L1 profile; ship JP three-tier authoring, KO and EN profiles, age picker narrowed to 6/7/8, and an in-app Home language switch.

**Architecture:** Three stacked PRs. PR 1 lands the API rewrite + JP three-tier authoring without behavioral change for the existing dev install. PR 2 lands KO and EN profiles end-to-end and activates them in the picker. PR 3 narrows the age picker visually and adds the Home globe-button → `LanguageSwitchSheet` re-edit affordance.

**Tech Stack:** Swift 6 with `.swiftLanguageMode(.v5)` pinned in each package's `Package.swift` (mora repo convention to keep CI green against SwiftData/CoreML strict-concurrency types — verify the pin is present after any `Package.swift` edit), SwiftData (lightweight migration handles `LearnerProfile.levelOverride: String?` additively), SwiftUI, XCTest, swift-format `--strict`, XcodeGen + xcodebuild for the iOS app target.

**Spec:** `docs/superpowers/specs/2026-04-26-i18n-and-age-difficulty-design.md` (commit `800bce1`).

---

## Per-PR git ritual

Every PR in this stack uses the same open/retarget ritual.

**Open PR N (from branch `feat/mora-i18n/NN-<slug>`):**

```bash
git push -u origin feat/mora-i18n/NN-<slug>
gh pr create \
  --base <previous-branch-or-main> \
  --title "<short title>" \
  --body "$(cat <<'EOF'
## Summary
- <what this PR delivers>
- <key architectural decision>

Part of the multi-L1 i18n stack. See `docs/superpowers/plans/2026-04-26-i18n-and-age-difficulty.md` and `docs/superpowers/specs/2026-04-26-i18n-and-age-difficulty-design.md` §<relevant sections>.

## Test plan
- [ ] `swift test` in each touched package (MoraCore, MoraEngines, MoraUI, MoraTesting)
- [ ] `xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO`
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests`
- [ ] Simulator/dev-iPad smoke per PR description

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Retarget to `main` after previous PR merges:**

```bash
gh pr edit <this-pr-number> --base main
git fetch origin
git rebase origin/main
git push --force-with-lease
```

`--force-with-lease` is safe in this single-author stack.

---

## File Structure

Files created or modified after all three PRs land (unchanged pieces omitted):

```
docs/superpowers/
├── specs/2026-04-26-i18n-and-age-difficulty-design.md            # already committed (PR 0 = brainstorming)
└── plans/2026-04-26-i18n-and-age-difficulty.md                   # this file

Packages/MoraCore/Sources/MoraCore/
├── LearnerLevel.swift                          # PR 1 NEW — public enum + age→level mapping
├── L1Profile.swift                             # PR 1 — protocol surface replaced
├── L1ProfileResolver.swift                     # PR 1 NEW — single dispatch point
├── JapaneseL1Profile.swift                     # PR 1 — 3-tier authoring + allowedScriptBudget
├── JPKanjiLevel.swift                          # PR 1 — adds .empty
├── MoraStrings.swift                           # PR 1 (previewDefault), PR 3 (new fields)
├── KoreanL1Profile.swift                       # PR 2 NEW
├── EnglishL1Profile.swift                      # PR 2 NEW
└── Persistence/LearnerProfile.swift            # PR 1 — adds levelOverride + resolvedLevel

Packages/MoraCore/Tests/MoraCoreTests/
├── LearnerLevelTests.swift                     # PR 1 NEW
├── JPKanjiLevelTests.swift                     # PR 1 — adds .empty assertion
├── LocaleScriptBudgetTests.swift               # PR 1 NEW
├── JapaneseL1ProfileTests.swift                # PR 1 — 3-tier coverage
├── KoreanL1ProfileTests.swift                  # PR 2 NEW
├── EnglishL1ProfileTests.swift                 # PR 2 NEW
├── L1ProfileResolverTests.swift                # PR 1 NEW (JP fallback), PR 2 (ko/en)
├── L1ProfileProtocolTests.swift                # PR 1 — mock signature update
├── InterferenceMatchTests.swift                # PR 1 — mock signature update
├── LearnerProfileLevelTests.swift              # PR 1 NEW
└── MoraStringsTests.swift                      # PR 1 — kanji-audit block extracted

Packages/MoraUI/Sources/MoraUI/
├── Design/MoraStringsEnvironment.swift         # PR 1 — adds currentL1Profile env key + previewDefault default
├── RootView.swift                              # PR 1 — uses L1ProfileResolver + resolvedLevel
├── LanguageAge/LanguageAgeFlow.swift           # PR 1 (forAgeYears: → at:), PR 2 (ko/en active + locale default), PR 3 (3-tile age)
├── LanguageAge/LanguagePicker.swift            # PR 3 NEW — extracted from LanguageAgeFlow Step 1
├── LanguageAge/LanguageSwitchSheet.swift       # PR 3 NEW
├── Onboarding/InterestPickView.swift           # PR 1 — uses currentL1Profile env
├── Home/HomeView.swift                         # PR 3 — globe button + sheet integration
└── (9 #Preview-bearing files)                  # PR 1 — collapse to MoraStrings.previewDefault

Packages/MoraUI/Tests/MoraUITests/
├── LanguageAgeFlowTests.swift                  # PR 1 (signature), PR 2 (active rows + locale default), PR 3 (3-tile)
├── LanguageSwitchSheetTests.swift              # PR 3 NEW
├── HomeViewLanguageSwitchTests.swift           # PR 3 NEW (smoke)
├── PronunciationFeedbackOverlayTests.swift     # PR 1 — signature
└── YokaiIntroPanel2AudioTests.swift            # PR 1 — signature
```

---

# PR 1: Foundation + JP Three-Tier Authoring

Branch: `feat/mora-i18n/01-foundation-and-jp-tiers`. Estimated 700 LOC.

**Behavior at PR-merge time:** Dev iPad (`l1=ja, ageYears=8, levelOverride=nil`) renders identically to pre-merge (resolves to `.advanced` = renamed `stringsMid`). Fresh installs that pick age 6 or 7 see the new hira-shifted JP tables. KO/EN picker rows still `(Coming soon)`.

## Task 1.1 — Create `LearnerLevel.swift`

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/LearnerLevel.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/LearnerLevelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/LearnerLevelTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class LearnerLevelTests: XCTestCase {
    func test_from_years_below7_returnsEntry() {
        XCTAssertEqual(LearnerLevel.from(years: 0), .entry)
        XCTAssertEqual(LearnerLevel.from(years: 5), .entry)
        XCTAssertEqual(LearnerLevel.from(years: 6), .entry)
    }

    func test_from_years_7_returnsCore() {
        XCTAssertEqual(LearnerLevel.from(years: 7), .core)
    }

    func test_from_years_8OrAbove_returnsAdvanced() {
        XCTAssertEqual(LearnerLevel.from(years: 8), .advanced)
        XCTAssertEqual(LearnerLevel.from(years: 11), .advanced)
        XCTAssertEqual(LearnerLevel.from(years: 99), .advanced)
    }

    func test_rawValues() {
        XCTAssertEqual(LearnerLevel.entry.rawValue, "entry")
        XCTAssertEqual(LearnerLevel.core.rawValue, "core")
        XCTAssertEqual(LearnerLevel.advanced.rawValue, "advanced")
    }

    func test_allCases_count_is3() {
        XCTAssertEqual(LearnerLevel.allCases.count, 3)
    }

    func test_codable_roundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for level in LearnerLevel.allCases {
            let data = try encoder.encode(level)
            let decoded = try decoder.decode(LearnerLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter LearnerLevelTests)`
Expected: FAIL — `cannot find type 'LearnerLevel' in scope`.

- [ ] **Step 3: Write the minimal implementation**

Create `Packages/MoraCore/Sources/MoraCore/LearnerLevel.swift`:

```swift
import Foundation

/// Difficulty tier consumed by every L1 profile. Each profile interprets
/// the cases according to its own pedagogy:
///
/// - `JapaneseL1Profile`:
///     - `.entry`    → hiragana only, no kanji
///     - `.core`     → hiragana + JP elementary G1 kanji (80)
///     - `.advanced` → hiragana + G1 + G2 kanji (240)
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

- [ ] **Step 4: Run to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter LearnerLevelTests)`
Expected: 6 tests, all PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/LearnerLevel.swift \
        Packages/MoraCore/Tests/MoraCoreTests/LearnerLevelTests.swift
git commit -m "core: add LearnerLevel enum with age→level mapping"
```

## Task 1.2 — Add `JPKanjiLevel.empty`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/JPKanjiLevel.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/JPKanjiLevelTests.swift`

- [ ] **Step 1: Write the failing test (extend existing)**

Append to `Packages/MoraCore/Tests/MoraCoreTests/JPKanjiLevelTests.swift`:

```swift
    func test_empty_isEmptySet() {
        XCTAssertTrue(JPKanjiLevel.empty.isEmpty)
        XCTAssertEqual(JPKanjiLevel.empty.count, 0)
    }

    func test_grade1_isSubset_of_grade1And2() {
        XCTAssertTrue(JPKanjiLevel.grade1.isSubset(of: JPKanjiLevel.grade1And2))
    }
```

- [ ] **Step 2: Run to verify the new test fails**

Run: `(cd Packages/MoraCore && swift test --filter JPKanjiLevelTests/test_empty)`
Expected: FAIL — `Type 'JPKanjiLevel' has no member 'empty'`.

- [ ] **Step 3: Add the constant**

Append to `Packages/MoraCore/Sources/MoraCore/JPKanjiLevel.swift` (inside the `JPKanjiLevel` enum):

```swift
    /// Empty kanji set — used by `LearnerLevel.entry` to assert "hiragana only".
    public static let empty: Set<Character> = []
```

- [ ] **Step 4: Run to verify all JPKanjiLevel tests pass**

Run: `(cd Packages/MoraCore && swift test --filter JPKanjiLevelTests)`
Expected: all PASS (existing 80/160/240/intersect/contains + new 2 = ~7 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/JPKanjiLevel.swift \
        Packages/MoraCore/Tests/MoraCoreTests/JPKanjiLevelTests.swift
git commit -m "core: add JPKanjiLevel.empty for hiragana-only learner level"
```

## Task 1.3 — Add `LearnerProfile.levelOverride` + `resolvedLevel`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileLevelTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileLevelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import MoraCore

@MainActor
final class LearnerProfileLevelTests: XCTestCase {
    func test_resolvedLevel_levelOverride_nil_age8_returnsAdvanced() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 8, levelOverride: nil,
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .advanced)
    }

    func test_resolvedLevel_levelOverride_core_age8_returnsCore() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 8, levelOverride: "core",
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .core)
    }

    func test_resolvedLevel_invalidOverride_fallsBackToAge() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 6, levelOverride: "fictional",
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .entry)
    }

    func test_resolvedLevel_nilAgeAndOverride_returnsAdvanced() {
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: nil, levelOverride: nil,
            interests: [], preferredFontKey: "openDyslexic"
        )
        XCTAssertEqual(p.resolvedLevel, .advanced)
    }

    func test_persistence_levelOverride_roundTrip() throws {
        let container = try MoraModelContainer.inMemory()
        let context = ModelContext(container)
        let p = LearnerProfile(
            displayName: "test", l1Identifier: "ja",
            ageYears: 7, levelOverride: "entry",
            interests: [], preferredFontKey: "openDyslexic"
        )
        context.insert(p)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<LearnerProfile>()).first
        XCTAssertEqual(fetched?.levelOverride, "entry")
        XCTAssertEqual(fetched?.resolvedLevel, .entry)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter LearnerProfileLevelTests)`
Expected: FAIL — `extra argument 'levelOverride' in call` (constructor doesn't accept it yet).

- [ ] **Step 3: Update `LearnerProfile.swift`**

Replace contents of `Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class LearnerProfile {
    public var id: UUID
    public var displayName: String
    public var l1Identifier: String
    /// Learner's age in raw years. `nil` on profiles created before
    /// `LanguageAgeFlow` shipped — those rows re-run language+age
    /// onboarding on next launch and this field is filled in.
    public var ageYears: Int?
    /// Optional difficulty override. Stored as the raw value of
    /// `LearnerLevel` so SwiftData lightweight migration handles it as
    /// a plain optional `String` column. `nil` means "derive from age".
    /// See spec §5.3 / §7.5.
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
    ) {
        self.id = id
        self.displayName = displayName
        self.l1Identifier = l1Identifier
        self.ageYears = ageYears
        self.levelOverride = levelOverride
        self.interests = interests
        self.preferredFontKey = preferredFontKey
        self.createdAt = createdAt
    }

    /// Resolved difficulty level for this learner. When `levelOverride` is
    /// set to a valid `LearnerLevel.rawValue`, that wins. Otherwise the
    /// level is derived from `ageYears` (defaulting to 8 → `.advanced` if
    /// age is also nil — defensive, never reached in onboarded paths).
    public var resolvedLevel: LearnerLevel {
        if let raw = levelOverride, let level = LearnerLevel(rawValue: raw) {
            return level
        }
        return LearnerLevel.from(years: ageYears ?? 8)
    }
}
```

- [ ] **Step 4: Run to verify the tests pass**

Run: `(cd Packages/MoraCore && swift test --filter LearnerProfileLevelTests)`
Expected: 5 tests, all PASS.

Also run the existing `LearnerProfileAgeTests` and `LearnerProfileTests` to verify the `init` change didn't break them:

Run: `(cd Packages/MoraCore && swift test --filter LearnerProfile)`
Expected: all PASS (existing tests use named-argument syntax that is forward-compatible because `levelOverride` defaults to `nil`).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Persistence/LearnerProfile.swift \
        Packages/MoraCore/Tests/MoraCoreTests/LearnerProfileLevelTests.swift
git commit -m "core: add LearnerProfile.levelOverride + resolvedLevel"
```

## Task 1.4 — Replace `L1Profile` protocol surface

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/L1Profile.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/L1ProfileProtocolTests.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/InterferenceMatchTests.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift`

This task replaces the protocol shape and updates JP impl + all test mocks in lockstep so the package compiles after the change. The new tier tables are stubs that all return the renamed `stringsAdvancedG1G2` — Tasks 1.5 and 1.6 will fill them in.

- [ ] **Step 1: Write/update tests reflecting the new shape**

Edit `Packages/MoraCore/Tests/MoraCoreTests/L1ProfileProtocolTests.swift` line 9, replacing the mock's `uiStrings` method:

```swift
    func uiStrings(at level: LearnerLevel) -> MoraStrings {
        JapaneseL1Profile().uiStrings(at: level)
    }
```

Edit `Packages/MoraCore/Tests/MoraCoreTests/InterferenceMatchTests.swift` line 18, same pattern:

```swift
    func uiStrings(at level: LearnerLevel) -> MoraStrings {
        JapaneseL1Profile().uiStrings(at: level)
    }
```

Edit `Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift` — search-replace all `forAgeYears: 8` to `at: .advanced` (no other arg combinations exist).

Edit `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift`:
- Line 12: `let tables = ageReps.map { profile.uiStrings(forAgeYears: $0) }` → `let tables = LearnerLevel.allCases.map { profile.uiStrings(at: $0) }` and rename `ageReps` → `_` (unused) or delete the local.
- Line 24, 122, 137, 153, 173: `forAgeYears: 8` → `at: .advanced`.
- Lines 106, 114: `forAgeYears: 8` → `at: .advanced` for `interestCategoryDisplayName` calls.

The kanji-audit block (lines around 129 and 190) inside `MoraStringsTests` is **left in place for now**; Task 1.7 extracts it to `LocaleScriptBudgetTests`.

- [ ] **Step 2: Run to verify the suite fails to compile**

Run: `(cd Packages/MoraCore && swift test 2>&1 | head -40)`
Expected: compile errors complaining about `LearnerLevel` not in scope or method signature mismatch — protocol still uses `forAgeYears:`.

- [ ] **Step 3: Replace `L1Profile` protocol**

Replace contents of `Packages/MoraCore/Sources/MoraCore/L1Profile.swift`:

```swift
// Packages/MoraCore/Sources/MoraCore/L1Profile.swift
import Foundation

public protocol L1Profile: Sendable {
    var identifier: String { get }
    var characterSystem: CharacterSystem { get }
    var interferencePairs: [PhonemeConfusionPair] { get }
    var interestCategories: [InterestCategory] { get }

    /// Example words that clearly demonstrate a phoneme. Returns an empty
    /// array when the phoneme is not in the curriculum.
    func exemplars(for phoneme: Phoneme) -> [String]

    /// Pre-authored UI-chrome strings at this difficulty level.
    /// Implementations choose how to interpret the level — JP varies its
    /// kanji budget; KO and EN return a single level-invariant table.
    /// See docs/superpowers/specs/2026-04-26-i18n-and-age-difficulty-design.md §5.2.
    func uiStrings(at level: LearnerLevel) -> MoraStrings

    /// Localized display name for an `InterestCategory` key. Separated from
    /// `uiStrings` so existing seed data on `LearnerProfile.interests` (which
    /// stores category keys) can be rendered at read time.
    func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String

    /// Per-level character budget for `LocaleScriptBudgetTests`. `nil` means
    /// the profile has no script ladder — the validator skips it. JP returns
    /// kanji-budget sets; KO and EN return `nil`.
    func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>?
}

extension L1Profile {
    /// Default: empty exemplars. JP overrides.
    public func exemplars(for phoneme: Phoneme) -> [String] { [] }

    /// Default: no script ladder. JP overrides; KO / EN inherit nil.
    public func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>? { nil }

    /// Default: return the key itself. Profiles localize per their own table.
    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
        key
    }

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

- [ ] **Step 4: Update `JapaneseL1Profile.swift`**

Edit `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`:

1. Delete lines 88–97 (the `JPStringBucket` enum and `bucket(forAgeYears:)` helper).
2. Replace lines 99–106 (`uiStrings(forAgeYears:)`) with:

```swift
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
```

3. Replace lines 108–118 (`interestCategoryDisplayName(...forAgeYears:)`):

```swift
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
```

4. Rename `private static let stringsMid = MoraStrings(` (currently line 134) to `private static let stringsAdvancedG1G2 = MoraStrings(`. Content unchanged.
5. Add two stub tables **immediately above** `stringsAdvancedG1G2`:

```swift
    /// PR 1 stub — Task 1.5 fills in the hira-down-shifted authoring.
    private static let stringsCoreG1 = stringsAdvancedG1G2

    /// PR 1 stub — Task 1.6 fills in the all-hira authoring.
    private static let stringsEntryHiraOnly = stringsAdvancedG1G2
```

This stubbing keeps PR 1's git history bisectable: the protocol surface change is isolated from the JP authoring deltas.

- [ ] **Step 5: Run the test suite**

Run: `(cd Packages/MoraCore && swift test)`
Expected: all PASS, including `JapaneseL1ProfileTests`, `MoraStringsTests`, `L1ProfileProtocolTests`, `InterferenceMatchTests`, `LearnerLevelTests`, `LearnerProfileLevelTests`. The kanji-audit block inside `MoraStringsTests` still passes because `stringsCoreG1` and `stringsEntryHiraOnly` currently return `stringsAdvancedG1G2`, which is already kanji-audited.

- [ ] **Step 6: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/L1Profile.swift \
        Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift \
        Packages/MoraCore/Tests/MoraCoreTests/L1ProfileProtocolTests.swift \
        Packages/MoraCore/Tests/MoraCoreTests/InterferenceMatchTests.swift \
        Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift \
        Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift
git commit -m "core: replace L1Profile API with LearnerLevel-keyed shape"
```

## Task 1.5 — Author `JapaneseL1Profile.stringsCoreG1`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`

The `core` table renders ages 7 (1st-grade-finished) — kanji G1 only (80 chars). Mechanically derived from `stringsAdvancedG1G2` by replacing every G2 kanji with its hiragana reading. After mechanical transformation, polish for naturalness.

**Spec reference:** §6.1.1 authoring rules; §6.1.2 sample row table for the diff.

- [ ] **Step 1: Author the table**

Edit `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`. Replace the stub:

```swift
    private static let stringsCoreG1 = stringsAdvancedG1G2
```

with a full `MoraStrings(...)` literal. The complete table is in `stringsAdvancedG1G2` immediately below; copy that initializer call and apply these row-by-row substitutions (rows not listed are unchanged because they contain no G2 kanji):

| Field | `stringsAdvancedG1G2` value | `stringsCoreG1` value |
|---|---|---|
| `welcomeTitle` | `えいごの 音を いっしょに` | `えいごの 音を いっしょに` (`音` is G1, kept) |
| `namePrompt` | `名前を 教えてね` | `なまえを おしえてね` (`名` G1, but `前` G2 + `教` G2 → all-hira) |
| `permissionTitle` | `声を 聞くよ` | `こえを きくよ` (`声` G2, `聞` G2) |
| `permissionBody` | `きみが 読んだ ことばを 聞いて、正しいか しらべるよ` | `きみが よんだ ことばを きいて、正しいか しらべるよ` (`正` is G1, kept; `読` `聞` G2) |
| `permissionNotNow` | `後で` | `あとで` (`後` G2) |
| `homeTodayQuest` | `今日の クエスト` | `きょうの クエスト` (`今` G2) |
| `homeDurationPill(16)` | `\(minutes)分` | `\(minutes)ぷん` (`分` G2) |
| `homeWordsPill(5)` | `\(count)文字` | `\(count)文字` (`文` G1, `字` G1 — both in budget, kept) |
| `homeBetterVoiceChip` | `もっと きれいな 声 ›` | `もっと きれいな こえ ›` (`声` G2) |
| `voiceGateTitle` | `英語の 声を ダウンロードしてください` | `えいごの こえを ダウンロードしてください` (`英` G2, `語` G2, `声` G2) |
| `voiceGateBody` | (multi-line, contains `英語` `設定` `読み上げ と 発話` `声` `言語` `表示` `下の 順`) | Replace `英語`→`えいご`, `設定`→`せってい`, `読み上げ`→`よみあげ`, `発話`→`はつわ`, `声`→`こえ`, `言語`→`ことば`, `表示`→`ひょうじ`, `下の 順`→`下の じゅん` (`下` G1 keep; `順` G4 → hira). Full replacement text below. |
| `voiceGateOpenSettings` | `設定を 開く` | `せっていを ひらく` (`設` `定` `開` all G3+) |
| `voiceGateRecheck` | `もう一度 たしかめる` | `もういちど たしかめる` (`一` G1 keep; `度` G3 — partial-mix forbidden by §6.1.1 rule, so all-hira) |
| `voiceGateInstalledVoicesTitle` | `インストール済みの 英語 voice` | `インストールずみの えいご voice` (`済` G6, `英` G2, `語` G2) |
| `sessionCloseTitle` | `今日の クエストを おわる？` | `きょうの クエストを おわる？` (`今` G2) |
| `sessionCloseMessage` | `ここまでの きろくは のこるよ` | (no kanji — unchanged) |
| `warmupListenAgain` | `🔊 もういちど` | (no kanji — unchanged) |
| `newRuleGotIt` | `分かった` | `わかった` (`分` G2) |
| `newRuleListenAgain` | `🔊 もういちど` | (unchanged) |
| `decodingLongPressHint` | `ながおしで もういちど 聞けるよ` | `ながおしで もういちど きけるよ` (`聞` G2) |
| `tileTutorialSlotBody` | `ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。` | `ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。` (`音` G1 keep — unchanged) |
| `tileTutorialAudioTitle` | `聞いた 音を つくろう` | `きいた 音を つくろう` (`聞` G2, `音` G1 keep) |
| `tileTutorialAudioBody` | `はじめに 🔊 が 音を 聞かせる。きいた 音と 同じに なるよう、タイルを ならべよう。聞きなおすときは「もういちど きく」を タップ。` | `はじめに 🔊 が 音を きかせる。きいた 音と おなじに なるよう、タイルを ならべよう。きこえなおすときは「もういちど きく」を タップ。` (`聞` G2, `同` G2) |
| `decodingHelpLabel` | `あそびかたを 見る` | `あそびかたを 見る` (`見` G1, kept) |
| `feedbackTryAgain` | `もう一回` | `もういちど` (`一` G1 + `回` G2 — partial-mix forbidden, all-hira) |
| `micIdlePrompt` | `マイクを タップして 読んでね` | `マイクを タップして よんでね` (`読` G2) |
| `micListening` | `聞いてるよ…` | `きいてるよ…` (`聞` G2) |
| `micAssessing` | `チェック中…` | `チェック中…` (`中` G1, kept) |
| `micDeniedBanner` | `マイクが つかえないので ボタンで 答えてね` | `マイクが つかえないので ボタンで こたえてね` (`答` G2) |
| `completionComeBack` | `明日も またね` | `あしたも またね` (`明` G2 + `日` G1 → all-hira per partial-mix rule) |
| `bestiaryLinkLabel` | `ともだち ずかん` | (no kanji — unchanged) |
| `bestiaryPlayGreeting` | `🔊 あいさつ` | (unchanged) |
| `bestiaryBefriendedOn` (closure) | `なかよくなった日 \(...)` | `なかよくなった日 \(...)` (`日` G1, kept) |
| `homeRecapLink` | `あそびかた` | (unchanged) |
| `a11yStreakChip(5)` | `\(days)日 れんぞく` | `\(days)日 れんぞく` (`日` G1, kept) |
| `homeChangeLanguageButton` | `ことばを かえる` | (unchanged — no kanji) |
| `languageSwitchSheetTitle` | `ことばを えらぶ` | (unchanged) |
| `languageSwitchSheetCancel` | `キャンセル` | (unchanged) |
| `languageSwitchSheetConfirm` | `OK` | (unchanged) |
| `coachingShSubS` and other coaching scaffolds | (already hira-only in advanced) | (unchanged) |

For `voiceGateBody` specifically, the full `core` rendering:

```swift
voiceGateBody:
    "Moraで つかう きれいな こえが iPadに 入っていません。\n"
    + "せっていアプリを ひらき、下の じゅんで ひらいてください:\n\n"
    + "  せってい (Settings)\n"
    + "  → アクセシビリティ (Accessibility)\n"
    + "  → よみあげ と はつわ (Read & Speak)\n"
    + "  → こえ (Voices) → えいご (English)\n\n"
    + "その中から Premium または Enhanced の こえ (Ava / Samantha / Siri など) を\n"
    + "ダウンロードしてください。\n"
    + "(iPadOS 26より まえは Read & Speak の かわりに\n"
    + " Spoken Content / よみあげコンテンツ と ひょうじされます。\n"
    + " OSの ことばが えいごの ばあいは カッコ内の ひょうきで ひょうじされます。)",
```

(`入` is G1, `中` is G1 — both kept. `前` G2 → hira `まえ`. `内` G2 → hira `ない`. `表示` G3 + G2 → all-hira. `言語` G2 + G2 → `ことば`. `場合` G2 + G2 → `ばあい`.)

The complete `stringsCoreG1` initializer is `stringsAdvancedG1G2` with the substitutions above. Use the existing `MoraStrings(/* ... */)` argument list as the structural template.

- [ ] **Step 2: Run the suite**

Run: `(cd Packages/MoraCore && swift test --filter MoraStringsTests)`
Expected: PASS — the existing `kanji-audit` block in `MoraStringsTests` checks `stringsAdvancedG1G2` which is unchanged; `stringsCoreG1` doesn't have a budget test of its own yet (Task 1.7 adds it).

- [ ] **Step 3: Eyeball-verify the table compiles to expected content**

Run: `(cd Packages/MoraCore && swift test --filter JapaneseL1ProfileTests)`
Expected: PASS — but no per-row content assertion exists yet for the core table. Task 1.7 adds enforcement.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift
git commit -m "core: author JapaneseL1Profile.stringsCoreG1 (G1 kanji budget)"
```

## Task 1.6 — Author `JapaneseL1Profile.stringsEntryHiraOnly`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`

Mechanically derive from `stringsCoreG1` (Task 1.5 output) by collapsing every remaining G1 kanji to hiragana.

- [ ] **Step 1: Author the table**

Replace the stub:

```swift
    private static let stringsEntryHiraOnly = stringsAdvancedG1G2
```

with a full `MoraStrings(...)` literal that is `stringsCoreG1` with these additional substitutions (rows that contained G1 kanji in core):

| Field | `stringsCoreG1` value | `stringsEntryHiraOnly` value |
|---|---|---|
| `welcomeTitle` | `えいごの 音を いっしょに` | `えいごの おとを いっしょに` (`音` → `おと`) |
| `permissionBody` | `きみが よんだ ことばを きいて、正しいか しらべるよ` | `きみが よんだ ことばを きいて、ただしいか しらべるよ` (`正` → `ただ`) |
| `homeWordsPill(5)` | `\(count)文字` | `\(count)もじ` (entry budget is empty — every kanji collapses to hira) |
| `homeSentencesPill(2)` | `\(count)文` | `\(count)ぶん` (`文` → `ぶん`) |
| `tileTutorialSlotBody` | `ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。` | `ます 1つは おと 1つ。タイルを ながおしして、ますへ ドラッグしよう。` |
| `tileTutorialAudioTitle` | `きいた 音を つくろう` | `きいた おとを つくろう` |
| `tileTutorialAudioBody` | `はじめに 🔊 が 音を きかせる。…` | `はじめに 🔊 が おとを きかせる。きいた おとと おなじに なるよう、タイルを ならべよう。きこえなおすときは「もういちど きく」を タップ。` |
| `decodingHelpLabel` | `あそびかたを みる` | (no G1 kanji left — unchanged) |
| `voiceGateBody` | `Moraで つかう きれいな こえが iPadに 入っていません。\n…` | `Moraで つかう きれいな こえが iPadに はいっていません。\n…` (`入` → `はい`, `中` → `なか`) |
| `micAssessing` | `チェック中…` | `チェック なか…` — actually `チェック` followed by `中` is awkward in hira. Render as `チェックちゅう…` (using on'yomi) |
| `bestiaryBefriendedOn` (closure) | `なかよくなった日 \(...)` | `なかよくなったひ \(...)` (`日` → `ひ`) |
| `a11yStreakChip(5)` | `\(days)日 れんぞく` | `\(days)にち れんぞく` (`日` → `にち`) |

For `voiceGateBody` entry rendering:

```swift
voiceGateBody:
    "Moraで つかう きれいな こえが iPadに はいっていません。\n"
    + "せっていアプリを ひらき、したの じゅんで ひらいてください:\n\n"
    + "  せってい (Settings)\n"
    + "  → アクセシビリティ (Accessibility)\n"
    + "  → よみあげ と はつわ (Read & Speak)\n"
    + "  → こえ (Voices) → えいご (English)\n\n"
    + "その なかから Premium または Enhanced の こえ (Ava / Samantha / Siri など) を\n"
    + "ダウンロードしてください。\n"
    + "(iPadOS 26より まえは Read & Speak の かわりに\n"
    + " Spoken Content / よみあげコンテンツ と ひょうじされます。\n"
    + " OSの ことばが えいごの ばあいは カッコ ないの ひょうきで ひょうじされます。)",
```

- [ ] **Step 2: Run the suite**

Run: `(cd Packages/MoraCore && swift test --filter JapaneseL1ProfileTests)`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift
git commit -m "core: author JapaneseL1Profile.stringsEntryHiraOnly (no kanji)"
```

## Task 1.7 — Add `LocaleScriptBudgetTests`

**Files:**
- Create: `Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift` (delete the kanji-audit block)

This test asserts every JP table at every level stays within its declared budget. The validator iterates `(profile × level)` for all profiles in scope (currently just JP — KO and EN are added in PR 2 but the existing protocol default returns `nil` so they auto-skip).

- [ ] **Step 1: Create the budget test**

Create `Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class LocaleScriptBudgetTests: XCTestCase {
    /// Iterates every (profile, level) pair and asserts every rendered
    /// string field stays within the declared script budget. Profiles
    /// that return `nil` from `allowedScriptBudget(at:)` are skipped.
    func test_all_profile_level_combinations_respect_script_budget() {
        let profiles: [any L1Profile] = [
            JapaneseL1Profile(),
            // PR 2 will append KoreanL1Profile() and EnglishL1Profile()
        ]

        for profile in profiles {
            for level in LearnerLevel.allCases {
                let strings = profile.uiStrings(at: level)
                guard let budget = profile.allowedScriptBudget(at: level) else {
                    continue  // no script ladder applies
                }
                for (fieldName, value) in EveryStringField(strings) {
                    for char in value {
                        XCTAssertTrue(
                            isAllowed(char, budget: budget),
                            "[\(profile.identifier) @ \(level.rawValue)] '\(fieldName)' contains '\(char)' (U+\(char.unicodeScalars.first.map { String($0.value, radix: 16, uppercase: true) } ?? "?")) outside the budget"
                        )
                    }
                }
            }
        }
    }

    private func isAllowed(_ char: Character, budget: Set<Character>) -> Bool {
        if budget.contains(char) { return true }
        for scalar in char.unicodeScalars {
            switch scalar.value {
            case 0x3040...0x309F: continue       // Hiragana
            case 0x30A0...0x30FF: continue       // Katakana
            case 0x0030...0x0039: continue       // ASCII digits
            case 0x0041...0x005A: continue       // ASCII A-Z
            case 0x0061...0x007A: continue       // ASCII a-z
            case 0x0020, 0x000A, 0x000D: continue // whitespace, newline, CR
            case 0x0021, 0x0022, 0x0028, 0x0029: continue  // ! " ( )
            case 0x002C, 0x002E, 0x002F: continue  // , . /
            case 0x003A, 0x003F, 0x005F: continue  // : ? _
            case 0x3001, 0x3002, 0x300C, 0x300D: continue  // 、 。 「 」
            case 0xFF01, 0xFF1F: continue          // ！ ？ (fullwidth, e.g. なんさい？ せいかい！)
            case 0x2026, 0x203A, 0x25B6: continue  // … › ▶
            case 0x1F50A: continue                  // 🔊
            default: return false
            }
        }
        return true
    }
}

/// Hand-enumerated key-path list with closure-valued fields invoked at
/// representative arguments. Memory-stable: changes to MoraStrings's field
/// list require explicit edits here, surfacing accidental field additions
/// in code review.
func EveryStringField(_ s: MoraStrings) -> [(name: String, value: String)] {
    [
        ("ageOnboardingPrompt", s.ageOnboardingPrompt),
        ("ageOnboardingCTA", s.ageOnboardingCTA),
        ("welcomeTitle", s.welcomeTitle),
        ("welcomeCTA", s.welcomeCTA),
        ("namePrompt", s.namePrompt),
        ("nameSkip", s.nameSkip),
        ("nameCTA", s.nameCTA),
        ("interestPrompt", s.interestPrompt),
        ("interestCTA", s.interestCTA),
        ("permissionTitle", s.permissionTitle),
        ("permissionBody", s.permissionBody),
        ("permissionAllow", s.permissionAllow),
        ("permissionNotNow", s.permissionNotNow),
        ("yokaiIntroConceptTitle", s.yokaiIntroConceptTitle),
        ("yokaiIntroConceptBody", s.yokaiIntroConceptBody),
        ("yokaiIntroTodayTitle", s.yokaiIntroTodayTitle),
        ("yokaiIntroTodayBody", s.yokaiIntroTodayBody),
        ("yokaiIntroSessionTitle", s.yokaiIntroSessionTitle),
        ("yokaiIntroSessionBody", s.yokaiIntroSessionBody),
        ("yokaiIntroSessionStep1", s.yokaiIntroSessionStep1),
        ("yokaiIntroSessionStep2", s.yokaiIntroSessionStep2),
        ("yokaiIntroSessionStep3", s.yokaiIntroSessionStep3),
        ("yokaiIntroProgressTitle", s.yokaiIntroProgressTitle),
        ("yokaiIntroProgressBody", s.yokaiIntroProgressBody),
        ("yokaiIntroNext", s.yokaiIntroNext),
        ("yokaiIntroBegin", s.yokaiIntroBegin),
        ("yokaiIntroClose", s.yokaiIntroClose),
        ("homeTodayQuest", s.homeTodayQuest),
        ("homeStart", s.homeStart),
        ("homeDurationPill(16)", s.homeDurationPill(16)),
        ("homeWordsPill(5)", s.homeWordsPill(5)),
        ("homeSentencesPill(2)", s.homeSentencesPill(2)),
        ("bestiaryLinkLabel", s.bestiaryLinkLabel),
        ("bestiaryPlayGreeting", s.bestiaryPlayGreeting),
        ("bestiaryBefriendedOn", s.bestiaryBefriendedOn(Date(timeIntervalSince1970: 1761475200))),
        ("homeRecapLink", s.homeRecapLink),
        ("voiceGateTitle", s.voiceGateTitle),
        ("voiceGateBody", s.voiceGateBody),
        ("voiceGateOpenSettings", s.voiceGateOpenSettings),
        ("voiceGateRecheck", s.voiceGateRecheck),
        ("voiceGateInstalledVoicesTitle", s.voiceGateInstalledVoicesTitle),
        ("voiceGateNoVoicesPlaceholder", s.voiceGateNoVoicesPlaceholder),
        ("sessionCloseTitle", s.sessionCloseTitle),
        ("sessionCloseMessage", s.sessionCloseMessage),
        ("sessionCloseKeepGoing", s.sessionCloseKeepGoing),
        ("sessionCloseEnd", s.sessionCloseEnd),
        ("sessionWordCounter(3,5)", s.sessionWordCounter(3, 5)),
        ("sessionSentenceCounter(1,2)", s.sessionSentenceCounter(1, 2)),
        ("warmupListenAgain", s.warmupListenAgain),
        ("newRuleGotIt", s.newRuleGotIt),
        ("newRuleListenAgain", s.newRuleListenAgain),
        ("decodingLongPressHint", s.decodingLongPressHint),
        ("decodingBuildPrompt", s.decodingBuildPrompt),
        ("decodingListenAgain", s.decodingListenAgain),
        ("tileTutorialSlotTitle", s.tileTutorialSlotTitle),
        ("tileTutorialSlotBody", s.tileTutorialSlotBody),
        ("tileTutorialAudioTitle", s.tileTutorialAudioTitle),
        ("tileTutorialAudioBody", s.tileTutorialAudioBody),
        ("tileTutorialNext", s.tileTutorialNext),
        ("tileTutorialTry", s.tileTutorialTry),
        ("decodingHelpLabel", s.decodingHelpLabel),
        ("sentencesLongPressHint", s.sentencesLongPressHint),
        ("feedbackCorrect", s.feedbackCorrect),
        ("feedbackTryAgain", s.feedbackTryAgain),
        ("micIdlePrompt", s.micIdlePrompt),
        ("micListening", s.micListening),
        ("micAssessing", s.micAssessing),
        ("micDeniedBanner", s.micDeniedBanner),
        ("coachingShSubS", s.coachingShSubS),
        ("coachingShDrift", s.coachingShDrift),
        ("coachingRSubL", s.coachingRSubL),
        ("coachingLSubR", s.coachingLSubR),
        ("coachingFSubH", s.coachingFSubH),
        ("coachingVSubB", s.coachingVSubB),
        ("coachingThVoicelessSubS", s.coachingThVoicelessSubS),
        ("coachingThVoicelessSubT", s.coachingThVoicelessSubT),
        ("coachingTSubThVoiceless", s.coachingTSubThVoiceless),
        ("coachingAeSubSchwa", s.coachingAeSubSchwa),
        ("categorySubstitutionBanner", s.categorySubstitutionBanner("sh", "s")),
        ("categoryDriftBanner", s.categoryDriftBanner("sh")),
        ("completionTitle", s.completionTitle),
        ("completionScore(6,7)", s.completionScore(6, 7)),
        ("completionComeBack", s.completionComeBack),
        ("a11yCloseSession", s.a11yCloseSession),
        ("a11yMicButton", s.a11yMicButton),
        ("a11yStreakChip(5)", s.a11yStreakChip(5)),
    ]
}
```

- [ ] **Step 2: Delete the kanji-audit block from MoraStringsTests**

Edit `Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift`. Delete the existing kanji-audit blocks (around lines 122–135 and 173–195 — the two functions that iterate `JapaneseL1Profile().uiStrings(...)` field-by-field and assert against `JPKanjiLevel.grade1And2`). The replacement test in `LocaleScriptBudgetTests` covers the same surface across all 3 levels.

The remaining `MoraStringsTests` should retain only:
- The smoke test that `uiStrings(at:)` returns non-empty values for every field.
- The `interestCategoryDisplayName` localization test.
- `previewDefault` smoke (added later in Task 1.10).

- [ ] **Step 3: Run all MoraCore tests**

Run: `(cd Packages/MoraCore && swift test)`
Expected: all PASS, including the new `LocaleScriptBudgetTests` (1 grid test = 80+ field assertions × 3 levels = ~240 assertions for JP). KO/EN are not yet in the profiles array so the loop skips them; PR 2 appends them.

If `LocaleScriptBudgetTests` fails on a specific row, that row's authoring in Task 1.5 or 1.6 needs polishing — go back and fix.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift \
        Packages/MoraCore/Tests/MoraCoreTests/MoraStringsTests.swift
git commit -m "core: extract kanji audit into LocaleScriptBudgetTests grid"
```

## Task 1.8 — Add `L1ProfileResolver`

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/L1ProfileResolverTests.swift`

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/L1ProfileResolverTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class L1ProfileResolverTests: XCTestCase {
    func test_profile_for_ja_returnsJapaneseProfile() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "ja").identifier, "ja")
    }

    func test_profile_for_unknown_fallsBackToJapanese() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "").identifier, "ja")
        XCTAssertEqual(L1ProfileResolver.profile(for: "zh").identifier, "ja")
        XCTAssertEqual(L1ProfileResolver.profile(for: "xx").identifier, "ja")
    }

    // PR 2 adds: profile_for_ko, profile_for_en
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter L1ProfileResolverTests)`
Expected: FAIL — `cannot find 'L1ProfileResolver' in scope`.

- [ ] **Step 3: Create the resolver**

Create `Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift`:

```swift
// Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift
import Foundation

/// Single dispatch point from a stored `LearnerProfile.l1Identifier` to a
/// concrete `L1Profile` instance. Unknown identifiers fall back to
/// `JapaneseL1Profile` — the alpha originator. This is the only legitimate
/// place to switch on `l1Identifier`; per canonical product spec §9, no
/// other site may branch on locale.
public enum L1ProfileResolver {
    public static func profile(for identifier: String) -> any L1Profile {
        switch identifier {
        case "ja": return JapaneseL1Profile()
        // PR 2 will add cases "ko" → KoreanL1Profile(), "en" → EnglishL1Profile()
        default:   return JapaneseL1Profile()
        }
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter L1ProfileResolverTests)`
Expected: 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift \
        Packages/MoraCore/Tests/MoraCoreTests/L1ProfileResolverTests.swift
git commit -m "core: add L1ProfileResolver with JP fallback"
```

## Task 1.9 — Add `MoraStrings.previewDefault` + env keys

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Design/MoraStringsEnvironment.swift`

- [ ] **Step 1: Add `previewDefault` extension to MoraStrings**

Append to `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`:

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

- [ ] **Step 2: Update `MoraStringsEnvironment.swift`**

Replace contents of `Packages/MoraUI/Sources/MoraUI/Design/MoraStringsEnvironment.swift`:

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

- [ ] **Step 3: Run MoraUI tests**

Run: `(cd Packages/MoraUI && swift test)`
Expected: PASS — env-key changes don't break anything; existing tests inject `\.moraStrings` explicitly.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/MoraStrings.swift \
        Packages/MoraUI/Sources/MoraUI/Design/MoraStringsEnvironment.swift
git commit -m "ui+core: add MoraStrings.previewDefault and currentL1Profile env"
```

## Task 1.10 — Migrate MoraUI call sites + collapse `#Preview` blocks

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/RootView.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/Onboarding/InterestPickView.swift`
- Modify: 9 files with `#Preview` blocks (see file structure)
- Modify: `Packages/MoraUI/Tests/MoraUITests/PronunciationFeedbackOverlayTests.swift`
- Modify: `Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift`

This task converts every site that called `uiStrings(forAgeYears:)` or `interestCategoryDisplayName(...forAgeYears:)` to the new API. It also routes `\.currentL1Profile` injection from `RootView`.

- [ ] **Step 1: Update `RootView.swift`**

Edit `Packages/MoraUI/Sources/MoraUI/RootView.swift`. Replace the `resolvedStrings(for:)` method (around line 60–66) and update its callers:

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

Wherever `RootView`'s body currently calls `resolvedStrings(for: ...)`, change to:

```swift
let (strings, l1) = resolved(profile: profile)
// ...
.environment(\.moraStrings, strings)
.environment(\.currentL1Profile, l1)
```

- [ ] **Step 2: Update `LanguageAgeFlow.swift` line 103**

Search-replace the line:

```swift
forAgeYears: state.selectedAge ?? 8
```

with:

```swift
at: LearnerLevel.from(years: state.selectedAge ?? 7)
```

(The `?? 7` change vs `?? 8` reflects the new picker default; PR 3 narrows the picker UX to actually show 6/7/8.)

- [ ] **Step 3: Update `InterestPickView.swift` line 66**

The current code:

```swift
key: cat.key, forAgeYears: ageYears
```

becomes (assuming `cat.key` is in scope and the view has access to `\.currentL1Profile`):

```swift
key: cat.key, at: profile.resolvedLevel
```

where `profile` is the `LearnerProfile` already in scope. Also add at the top of the view:

```swift
@Environment(\.currentL1Profile) private var currentL1Profile
```

and replace `JapaneseL1Profile()` references with `currentL1Profile`.

- [ ] **Step 4: Update 9 `#Preview` blocks**

For each of the following files, replace `JapaneseL1Profile().uiStrings(forAgeYears: 8)` with `MoraStrings.previewDefault`:

- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntroFlow.swift` (×2)
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/SessionShapePanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/TodaysYokaiPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodingTutorialOverlay.swift` (×2)
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/SlotMeaningPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiConceptPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/ProgressPanel.swift`
- `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/Tutorial/AudioLinkPanel.swift`

Each replacement is a single-line edit:

```swift
// before
.environment(\.moraStrings, JapaneseL1Profile().uiStrings(forAgeYears: 8))
// after
.environment(\.moraStrings, MoraStrings.previewDefault)
```

- [ ] **Step 5: Update test files**

Edit `Packages/MoraUI/Tests/MoraUITests/PronunciationFeedbackOverlayTests.swift` line 10:
`JapaneseL1Profile().uiStrings(forAgeYears: 8)` → `JapaneseL1Profile().uiStrings(at: .advanced)`.

Edit `Packages/MoraUI/Tests/MoraUITests/YokaiIntroPanel2AudioTests.swift` lines 54 and 85: same substitution.

- [ ] **Step 6: Run all MoraUI tests + xcodebuild**

Run:
```sh
(cd Packages/MoraUI && swift test)
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```
Expected: all PASS, build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Packages/MoraUI/
git commit -m "ui: migrate call sites to LearnerLevel-keyed L1Profile API"
```

## Task 1.11 — Extend `JapaneseL1ProfileTests` for 3-tier coverage

**Files:**
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift`

- [ ] **Step 1: Write the additional tests**

Append to `JapaneseL1ProfileTests`:

```swift
    func test_uiStrings_advanced_isCurrentMidContent() {
        // Sanity check: stringsAdvancedG1G2 is the predecessor's stringsMid renamed.
        // Specific row from the predecessor spec §7.2 table.
        let s = JapaneseL1Profile().uiStrings(at: .advanced)
        XCTAssertEqual(s.homeTodayQuest, "今日の クエスト")
        XCTAssertEqual(s.feedbackTryAgain, "もう一回")
        XCTAssertEqual(s.permissionTitle, "声を 聞くよ")
    }

    func test_uiStrings_core_collapsesG2KanjiToHira() {
        let s = JapaneseL1Profile().uiStrings(at: .core)
        XCTAssertEqual(s.homeTodayQuest, "きょうの クエスト")  // 今 G2 → きょう
        XCTAssertEqual(s.feedbackTryAgain, "もういちど")        // 一回 → all-hira
        XCTAssertEqual(s.permissionTitle, "こえを きくよ")      // 声 G2, 聞 G2 → hira
    }

    func test_uiStrings_entry_collapsesAllKanjiToHira() {
        let s = JapaneseL1Profile().uiStrings(at: .entry)
        XCTAssertEqual(s.welcomeTitle, "えいごの おとを いっしょに")  // 音 G1 → おと
        XCTAssertEqual(s.homeTodayQuest, "きょうの クエスト")
    }

    func test_allowedScriptBudget_perLevel() {
        let p = JapaneseL1Profile()
        XCTAssertEqual(p.allowedScriptBudget(at: .entry), JPKanjiLevel.empty)
        XCTAssertEqual(p.allowedScriptBudget(at: .core), JPKanjiLevel.grade1)
        XCTAssertEqual(p.allowedScriptBudget(at: .advanced), JPKanjiLevel.grade1And2)
    }

    func test_interestCategoryDisplayName_isLevelInvariant() {
        let p = JapaneseL1Profile()
        for level in LearnerLevel.allCases {
            XCTAssertEqual(p.interestCategoryDisplayName(key: "animals", at: level), "どうぶつ")
            XCTAssertEqual(p.interestCategoryDisplayName(key: "robots", at: level), "ロボット")
            XCTAssertEqual(p.interestCategoryDisplayName(key: "unknown_key", at: level), "unknown_key")
        }
    }
```

- [ ] **Step 2: Run all MoraCore tests**

Run: `(cd Packages/MoraCore && swift test)`
Expected: all PASS. If any of the row-content assertions fail, the authoring in Task 1.5 or 1.6 needs polish — go back and fix.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Tests/MoraCoreTests/JapaneseL1ProfileTests.swift
git commit -m "core: extend JapaneseL1ProfileTests for 3-tier coverage"
```

## Task 1.12 — PR 1 final verification

- [ ] **Step 1: Run the full test matrix**

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```
Expected: all PASS.

- [ ] **Step 2: Run xcodebuild**

```sh
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run swift-format**

```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests 2>&1 | head -30
```
Expected: no output (no lint violations).

- [ ] **Step 4: Manual smoke on dev iPad**

Install over the existing build.
- Verify the app launches without re-prompting onboarding.
- Verify Home renders identically to pre-upgrade (Today's quest = `今日の クエスト`).
- Verify streak count and yokai cameos are preserved.
- Complete one A-day session to verify the chrome flows correctly.

- [ ] **Step 5: Open PR 1**

Follow the per-PR ritual at the top of this plan.

PR base: `main`. Branch: `feat/mora-i18n/01-foundation-and-jp-tiers`.

PR body summary:
> - Replace `uiStrings(forAgeYears:)` API with unified `LearnerLevel { entry, core, advanced }` enum
> - Author JP three-tier strings (entry hira-only / core +G1 / advanced +G1+G2)
> - Add `L1ProfileResolver` (single dispatch point) and `LearnerProfile.levelOverride` (parental override schema)
> - 27-line mechanical call-site migration; 9 `#Preview` blocks collapse to `MoraStrings.previewDefault`
> - `LocaleScriptBudgetTests` generalizes the existing kanji audit to the `(profile × level)` grid
> - **Behavior unchanged** for the existing dev install (resolves to `.advanced` = renamed `stringsMid`)

---

# PR 2: KO and EN Profiles + Picker Activation

Branch: `feat/mora-i18n/02-ko-and-en-profiles`. Base: `feat/mora-i18n/01-foundation-and-jp-tiers`. Estimated 700 LOC.

**Behavior at PR-merge time:** New installs can pick Korean or English; the chrome renders in the chosen language across all screens. System locale `ja_JP` pre-selects Japanese, `ko_KR` pre-selects Korean, anything else pre-selects English. Dev iPad continues to render exactly as before.

## Task 2.1 — Author `KoreanL1Profile.swift`

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/KoreanL1Profile.swift`

This task creates the full struct with `stringsKidKo` table, 8 interferencePairs, English exemplars, KO interest display names, and KO bestiary date formatter. The full string table follows the spec §6.2 authoring rules and example rows.

- [ ] **Step 1: Create the profile**

Create `Packages/MoraCore/Sources/MoraCore/KoreanL1Profile.swift`:

```swift
// Packages/MoraCore/Sources/MoraCore/KoreanL1Profile.swift
import Foundation

/// Korean L1 profile. Single level-invariant `MoraStrings` table —
/// at primary grade 1–2 ages (target 6–8), Korean has no script-difficulty
/// ladder analogous to JP's kanji ladder. See spec §6.2.
public struct KoreanL1Profile: L1Profile {
    public let identifier = "ko"
    public let characterSystem: CharacterSystem = .alphabetic
    public let interferencePairs: [PhonemeConfusionPair] = Self.koInterference
    public let interestCategories: [InterestCategory] = JapaneseL1Profile().interestCategories

    public init() {}

    public func exemplars(for phoneme: Phoneme) -> [String] {
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

    /// KO L1 → EN L2 phonological transfer pairs. See spec §6.4 for sources
    /// (Ko 2009, Cho & Park 2006, Yang 1996).
    private static let koInterference: [PhonemeConfusionPair] = [
        PhonemeConfusionPair(
            tag: "ko_f_p_sub",
            from: Phoneme(ipa: "f"), to: Phoneme(ipa: "p"),
            examples: ["fan/pan", "fox/pox", "fish/pish"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_v_b_sub",
            from: Phoneme(ipa: "v"), to: Phoneme(ipa: "b"),
            examples: ["vat/bat", "very/berry", "van/ban"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_th_voiceless_s_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "s"),
            examples: ["thin/sin", "thick/sick"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_th_voiceless_t_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "t"),
            examples: ["thin/tin", "three/tree"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_z_dz_sub",
            from: Phoneme(ipa: "z"), to: Phoneme(ipa: "dʒ"),
            examples: ["zoo/Jew", "zip/Jip"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_r_l_swap",
            from: Phoneme(ipa: "r"), to: Phoneme(ipa: "l"),
            examples: ["right/light", "rock/lock"], bidirectional: true),
        PhonemeConfusionPair(
            tag: "ko_ae_e_conflate",
            from: Phoneme(ipa: "æ"), to: Phoneme(ipa: "ɛ"),
            examples: ["bad/bed", "cat/ket"], bidirectional: true),
        PhonemeConfusionPair(
            tag: "ko_sh_drift_target",
            from: Phoneme(ipa: "ʃ"), to: Phoneme(ipa: "ʃ"),
            examples: ["ship", "shop", "fish"], bidirectional: false),
    ]

    /// Bestiary date formatter — Korean locale, gregorian calendar.
    /// Renders e.g. "2026년 4월 26일" at `.long` style.
    private static let bestiaryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateStyle = .long
        return f
    }()

    /// Single level-invariant table — KO has no script ladder at this age range.
    /// Authoring rules: simple-vocab register from 한국 초등 1–2학년 교과서,
    /// 반말 informal kid-directed form, 한자 not used. See spec §6.2.1.
    private static let stringsKidKo = MoraStrings(
        ageOnboardingPrompt: "몇 살이야?",
        ageOnboardingCTA: "▶ 시작하기",
        welcomeTitle: "영어 소리, 같이 배워요",
        welcomeCTA: "시작하기",
        namePrompt: "이름이 뭐야?",
        nameSkip: "건너뛰기",
        nameCTA: "다음",
        interestPrompt: "좋아하는 것 3개 골라봐",
        interestCTA: "다음",
        permissionTitle: "목소리를 들을게",
        permissionBody: "네가 읽은 말을 듣고, 맞는지 확인해.",
        permissionAllow: "허락하기",
        permissionNotNow: "나중에",
        yokaiIntroConceptTitle: "소리에는 친구가 있어",
        yokaiIntroConceptBody:
            "영어의 소리 하나하나에 Yokai가 살고 있어. "
            + "친해지려면 그 소리를 잘 듣고 말로 만들어 보자.",
        yokaiIntroTodayTitle: "이번 주의 친구",
        yokaiIntroTodayBody: "이번 주는 이 소리를 같이 연습하자.",
        yokaiIntroSessionTitle: "한 번의 진행 방법",
        yokaiIntroSessionBody: "한 번에 약 10분.",
        yokaiIntroSessionStep1: "듣기",
        yokaiIntroSessionStep2: "맞추기",
        yokaiIntroSessionStep3: "말하기",
        yokaiIntroProgressTitle: "5번이면 친구가 돼",
        yokaiIntroProgressBody:
            "Yokai와 5번 연습하면 친해질 수 있어. "
            + "하루 한 번이라도 좋아.",
        yokaiIntroNext: "다음",
        yokaiIntroBegin: "▶ 시작하기",
        yokaiIntroClose: "닫기",
        homeTodayQuest: "오늘의 퀘스트",
        homeStart: "▶ 시작하기",
        homeDurationPill: { minutes in "\(minutes)분" },
        homeWordsPill: { count in "\(count)글자" },
        homeSentencesPill: { count in "\(count)문장" },
        bestiaryLinkLabel: "친구 도감",
        bestiaryPlayGreeting: "🔊 인사",
        bestiaryBefriendedOn: { date in
            "친해진 날 \(Self.bestiaryDateFormatter.string(from: date))"
        },
        homeRecapLink: "노는 법",
        voiceGateTitle: "영어 목소리를 받아주세요",
        voiceGateBody:
            "Mora에서 쓸 깨끗한 목소리가 iPad에 없어요.\n"
            + "설정 앱을 열고, 아래 순서로 들어가세요:\n\n"
            + "  설정 (Settings)\n"
            + "  → 손쉬운 사용 (Accessibility)\n"
            + "  → 읽기 및 말하기 (Read & Speak)\n"
            + "  → 음성 (Voices) → 영어 (English)\n\n"
            + "그중에서 Premium 또는 Enhanced 음성 (Ava / Samantha / Siri 등) 을\n"
            + "다운로드해 주세요.\n"
            + "(iPadOS 26 이전에는 Read & Speak 대신\n"
            + " Spoken Content / 발화 콘텐츠 라고 표시됩니다.\n"
            + " OS 언어가 영어인 경우 괄호 안의 표기로 표시됩니다.)",
        voiceGateOpenSettings: "설정 열기",
        voiceGateRecheck: "다시 확인하기",
        voiceGateInstalledVoicesTitle: "설치된 영어 voice",
        voiceGateNoVoicesPlaceholder: "(없음)",
        sessionCloseTitle: "오늘의 퀘스트를 끝낼까?",
        sessionCloseMessage: "여기까지의 기록은 남아.",
        sessionCloseKeepGoing: "계속하기",
        sessionCloseEnd: "끝내기",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 한 번 더",
        newRuleGotIt: "알았어",
        newRuleListenAgain: "🔊 한 번 더",
        decodingLongPressHint: "길게 누르면 다시 들을 수 있어.",
        decodingBuildPrompt: "잘 듣고 맞춰보자",
        decodingListenAgain: "🔊 한 번 더",
        tileTutorialSlotTitle: "글자를 칸에 넣어 말을 만들어",
        tileTutorialSlotBody:
            "칸 하나는 소리 하나. 타일을 길게 눌러 칸으로 끌어다 놔.",
        tileTutorialAudioTitle: "들은 소리를 만들자",
        tileTutorialAudioBody:
            "처음에 🔊가 소리를 들려줘. 들은 소리와 같아지도록 "
            + "타일을 맞춰. 다시 듣고 싶으면 \"한 번 더 듣기\"를 눌러.",
        tileTutorialNext: "다음",
        tileTutorialTry: "▶ 해보기",
        decodingHelpLabel: "노는 법 보기",
        sentencesLongPressHint: "길게 누르면 다시 들을 수 있어.",
        feedbackCorrect: "정답!",
        feedbackTryAgain: "한 번 더",
        micIdlePrompt: "마이크를 누르고 읽어봐",
        micListening: "듣고 있어…",
        micAssessing: "확인 중…",
        micDeniedBanner: "마이크를 못 써서 버튼으로 대답해 줘.",
        coachingShSubS: "입술을 둥글게 하고 혀 안쪽을 올려서 \"sh\".",
        coachingShDrift: "입을 좀 더 둥글게 하고 길게 \"shhhh\".",
        coachingRSubL: "혀끝은 어디에도 닿지 않게, 안쪽만 살짝 올려서 \"r\".",
        coachingLSubR: "혀끝을 윗니 뒤에 대고 그대로 \"l\".",
        coachingFSubH: "윗니로 아랫입술을 살짝 누르고 \"fff\".",
        coachingVSubB: "윗니로 아랫입술을 누르고 목을 떨려서 \"vvv\".",
        coachingThVoicelessSubS: "혀끝을 이 사이에 살짝 내고 \"thhh\".",
        coachingThVoicelessSubT: "혀끝을 이 사이에 살짝 내고 멈추지 말고 \"thhh\".",
        coachingTSubThVoiceless: "혀끝을 윗니 뒤에 딱 붙였다가 바로 떼서 \"t\".",
        coachingAeSubSchwa: "입을 옆으로 벌리고 턱을 내려서 \"æ\".",
        categorySubstitutionBanner: { target, substitute in
            "지금의 \(target)는 \(substitute) 쪽이었어"
        },
        categoryDriftBanner: { target in
            "조금 더 \(target)다운 소리에 가까워지자"
        },
        completionTitle: "잘했어!",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "내일 또 만나요",
        a11yCloseSession: "퀘스트를 끝내기",
        a11yMicButton: "마이크",
        a11yStreakChip: { days in "\(days)일 연속" },
        // PR 3 will append:
        // homeChangeLanguageButton, languageSwitchSheetTitle, languageSwitchSheetCancel, languageSwitchSheetConfirm
    )
}
```

**Note:** The `// PR 3 will append` comment marks the four new fields that PR 3 introduces to `MoraStrings`. Until PR 3 lands, `MoraStrings.init` doesn't have those parameters; do NOT add them in PR 2.

- [ ] **Step 2: Run a quick compile check**

Run: `(cd Packages/MoraCore && swift build)`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/KoreanL1Profile.swift
git commit -m "core: add KoreanL1Profile with kid-Hangul level-invariant strings"
```

## Task 2.2 — Author `EnglishL1Profile.swift`

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/EnglishL1Profile.swift`

- [ ] **Step 1: Create the profile**

Create `Packages/MoraCore/Sources/MoraCore/EnglishL1Profile.swift`:

```swift
// Packages/MoraCore/Sources/MoraCore/EnglishL1Profile.swift
import Foundation

/// English L1 profile. L1 == L2, so `interferencePairs == []` (no L1-driven
/// substitution patterns apply). UI strings flow from the existing English
/// literals in MoraUI. See spec §6.3.
public struct EnglishL1Profile: L1Profile {
    public let identifier = "en"
    public let characterSystem: CharacterSystem = .alphabetic
    public let interferencePairs: [PhonemeConfusionPair] = []
    public let interestCategories: [InterestCategory] = JapaneseL1Profile().interestCategories

    public init() {}

    public func exemplars(for phoneme: Phoneme) -> [String] {
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

    private static let bestiaryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateStyle = .long
        return f
    }()

    /// Authoring rules: Dolch first 100 sight words primarily; ≤8 words per
    /// phrase; concrete kid words; warm encouraging tone. See spec §6.3.1.
    /// Coaching scaffolds are dead-code paths (interferencePairs is empty)
    /// but authored for `MoraStrings` constructor completeness.
    private static let stringsKidEn = MoraStrings(
        ageOnboardingPrompt: "How old are you?",
        ageOnboardingCTA: "▶ Start",
        welcomeTitle: "Let's learn English sounds together",
        welcomeCTA: "Start",
        namePrompt: "What's your name?",
        nameSkip: "Skip",
        nameCTA: "Next",
        interestPrompt: "Pick 3 things you like",
        interestCTA: "Next",
        permissionTitle: "I'll listen to your voice",
        permissionBody: "I'll hear what you read and check if it's right.",
        permissionAllow: "Allow",
        permissionNotNow: "Not now",
        yokaiIntroConceptTitle: "Sounds have friends",
        yokaiIntroConceptBody:
            "A Yokai lives in every English sound. "
            + "Listen well and say it out loud to make friends.",
        yokaiIntroTodayTitle: "This week's friend",
        yokaiIntroTodayBody: "Let's practice this sound this week.",
        yokaiIntroSessionTitle: "How one round goes",
        yokaiIntroSessionBody: "About 10 minutes per round.",
        yokaiIntroSessionStep1: "Listen",
        yokaiIntroSessionStep2: "Build",
        yokaiIntroSessionStep3: "Say",
        yokaiIntroProgressTitle: "5 rounds and you're friends",
        yokaiIntroProgressBody:
            "Practice with the Yokai 5 times to become friends. "
            + "Once a day is enough.",
        yokaiIntroNext: "Next",
        yokaiIntroBegin: "▶ Start",
        yokaiIntroClose: "Close",
        homeTodayQuest: "Today's quest",
        homeStart: "▶ Start",
        homeDurationPill: { minutes in "\(minutes) min" },
        homeWordsPill: { count in "\(count) words" },
        homeSentencesPill: { count in "\(count) sentences" },
        bestiaryLinkLabel: "Friends book",
        bestiaryPlayGreeting: "🔊 Greet",
        bestiaryBefriendedOn: { date in
            "Friends since \(Self.bestiaryDateFormatter.string(from: date))"
        },
        homeRecapLink: "How to play",
        voiceGateTitle: "Please download an English voice",
        voiceGateBody:
            "Mora needs a clear voice that isn't on this iPad yet.\n"
            + "Open the Settings app and follow this path:\n\n"
            + "  Settings\n"
            + "  → Accessibility\n"
            + "  → Read & Speak\n"
            + "  → Voices → English\n\n"
            + "Then download a Premium or Enhanced voice\n"
            + "(Ava / Samantha / Siri etc.).\n"
            + "(Before iPadOS 26, Read & Speak appears as Spoken Content.)",
        voiceGateOpenSettings: "Open Settings",
        voiceGateRecheck: "Check again",
        voiceGateInstalledVoicesTitle: "Installed English voices",
        voiceGateNoVoicesPlaceholder: "(none)",
        sessionCloseTitle: "End today's quest?",
        sessionCloseMessage: "Your progress so far is saved.",
        sessionCloseKeepGoing: "Keep going",
        sessionCloseEnd: "End",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 Again",
        newRuleGotIt: "Got it",
        newRuleListenAgain: "🔊 Again",
        decodingLongPressHint: "Long-press to hear it again.",
        decodingBuildPrompt: "Listen well and build it",
        decodingListenAgain: "🔊 Again",
        tileTutorialSlotTitle: "Put letters in slots to make a word",
        tileTutorialSlotBody:
            "One slot, one sound. Long-press a tile and drag it to a slot.",
        tileTutorialAudioTitle: "Make the sound you heard",
        tileTutorialAudioBody:
            "First 🔊 plays the sound. Build tiles to match it. "
            + "Tap \"Listen again\" if you need to hear it once more.",
        tileTutorialNext: "Next",
        tileTutorialTry: "▶ Try it",
        decodingHelpLabel: "How to play",
        sentencesLongPressHint: "Long-press to hear it again.",
        feedbackCorrect: "Correct!",
        feedbackTryAgain: "Try again",
        micIdlePrompt: "Tap the mic and read it",
        micListening: "Listening…",
        micAssessing: "Checking…",
        micDeniedBanner: "The mic is off — answer with the buttons.",
        coachingShSubS: "Round your lips and lift the back of your tongue. Say \"sh\".",
        coachingShDrift: "Round your mouth a little more and stretch it long. \"shhhh\".",
        coachingRSubL: "Don't touch the tip of your tongue. Lift the back a little. \"r\".",
        coachingLSubR: "Touch the tip to behind your top teeth and stay there. \"l\".",
        coachingFSubH: "Press your top teeth on your bottom lip. Say \"fff\".",
        coachingVSubB: "Press your top teeth on your bottom lip and buzz your throat. \"vvv\".",
        coachingThVoicelessSubS: "Stick your tongue tip out a little and blow. \"thhh\".",
        coachingThVoicelessSubT: "Stick your tongue tip out and don't stop. \"thhh\".",
        coachingTSubThVoiceless: "Tap the tip of your tongue behind your top teeth. \"t\".",
        coachingAeSubSchwa: "Open your mouth wide and drop your jaw. \"æ\".",
        categorySubstitutionBanner: { target, substitute in
            "That \(target) was leaning toward \(substitute)"
        },
        categoryDriftBanner: { target in
            "Get a little closer to a clean \(target)"
        },
        completionTitle: "You did it!",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "See you tomorrow!",
        a11yCloseSession: "End the quest",
        a11yMicButton: "Mic",
        a11yStreakChip: { days in "\(days)-day streak" }
        // PR 3 will append the four language-switch fields.
    )
}
```

- [ ] **Step 2: Quick compile check**

Run: `(cd Packages/MoraCore && swift build)`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/EnglishL1Profile.swift
git commit -m "core: add EnglishL1Profile with kid-English level-invariant strings"
```

## Task 2.3 — Add KO and EN cases to `L1ProfileResolver`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/L1ProfileResolverTests.swift`

- [ ] **Step 1: Extend the test**

Append to `L1ProfileResolverTests`:

```swift
    func test_profile_for_ko_returnsKoreanProfile() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "ko").identifier, "ko")
    }

    func test_profile_for_en_returnsEnglishProfile() {
        XCTAssertEqual(L1ProfileResolver.profile(for: "en").identifier, "en")
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter L1ProfileResolverTests)`
Expected: FAIL — the new tests fail because the resolver still returns JP fallback for unknown identifiers.

- [ ] **Step 3: Update the resolver**

Edit `Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift`:

```swift
public enum L1ProfileResolver {
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

- [ ] **Step 4: Run to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter L1ProfileResolverTests)`
Expected: 4 tests, all PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/L1ProfileResolver.swift \
        Packages/MoraCore/Tests/MoraCoreTests/L1ProfileResolverTests.swift
git commit -m "core: dispatch ko and en identifiers in L1ProfileResolver"
```

## Task 2.4 — Add `KoreanL1ProfileTests` (with Hangul-purity sweep)

**Files:**
- Create: `Packages/MoraCore/Tests/MoraCoreTests/KoreanL1ProfileTests.swift`

- [ ] **Step 1: Create the test file**

Create `Packages/MoraCore/Tests/MoraCoreTests/KoreanL1ProfileTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class KoreanL1ProfileTests: XCTestCase {
    func test_identifier_is_ko() {
        XCTAssertEqual(KoreanL1Profile().identifier, "ko")
    }

    func test_characterSystem_is_alphabetic() {
        XCTAssertEqual(KoreanL1Profile().characterSystem, .alphabetic)
    }

    func test_uiStrings_is_levelInvariant() {
        let p = KoreanL1Profile()
        let entryStrings = p.uiStrings(at: .entry)
        let coreStrings = p.uiStrings(at: .core)
        let advStrings = p.uiStrings(at: .advanced)
        XCTAssertEqual(entryStrings.homeTodayQuest, coreStrings.homeTodayQuest)
        XCTAssertEqual(coreStrings.homeTodayQuest, advStrings.homeTodayQuest)
        XCTAssertEqual(entryStrings.homeTodayQuest, "오늘의 퀘스트")
    }

    func test_interestCategoryDisplayName_returnsKorean() {
        let p = KoreanL1Profile()
        XCTAssertEqual(p.interestCategoryDisplayName(key: "animals", at: .core), "동물")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "dinosaurs", at: .core), "공룡")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "vehicles", at: .core), "탈것")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "space", at: .core), "우주")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "sports", at: .core), "스포츠")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "robots", at: .core), "로봇")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "unknown", at: .core), "unknown")
    }

    func test_allowedScriptBudget_isNil_atAllLevels() {
        let p = KoreanL1Profile()
        for level in LearnerLevel.allCases {
            XCTAssertNil(p.allowedScriptBudget(at: level))
        }
    }

    func test_interferencePairs_count_is8() {
        XCTAssertEqual(KoreanL1Profile().interferencePairs.count, 8)
    }

    func test_interferencePairs_allHaveKoPrefix() {
        for pair in KoreanL1Profile().interferencePairs {
            XCTAssertTrue(pair.tag.hasPrefix("ko_"), "pair \(pair.tag) does not have ko_ prefix")
        }
    }

    func test_interferencePairs_includesKnownTransfers() {
        let tags = Set(KoreanL1Profile().interferencePairs.map(\.tag))
        XCTAssertTrue(tags.contains("ko_f_p_sub"))
        XCTAssertTrue(tags.contains("ko_v_b_sub"))
        XCTAssertTrue(tags.contains("ko_th_voiceless_s_sub"))
        XCTAssertTrue(tags.contains("ko_r_l_swap"))
        XCTAssertTrue(tags.contains("ko_ae_e_conflate"))
    }

    /// Hangul-purity: every field is verified to contain no CJK Unified
    /// Ideographs (U+4E00..U+9FFF) or CJK Compatibility Ideographs
    /// (U+F900..U+FAFF). KO kid texts should be 순한글 — Hanja insertion
    /// is a regression.
    func test_stringsKidKo_containsNoCJKIdeographs() {
        let strings = KoreanL1Profile().uiStrings(at: .core)
        for (fieldName, value) in EveryStringField(strings) {
            for char in value {
                for scalar in char.unicodeScalars {
                    let v = scalar.value
                    XCTAssertFalse(
                        (0x4E00...0x9FFF).contains(v) || (0xF900...0xFAFF).contains(v),
                        "[ko] '\(fieldName)' contains CJK ideograph U+\(String(v, radix: 16, uppercase: true))"
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `(cd Packages/MoraCore && swift test --filter KoreanL1ProfileTests)`
Expected: 9 tests, all PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Tests/MoraCoreTests/KoreanL1ProfileTests.swift
git commit -m "core: add KoreanL1ProfileTests with Hangul-purity sweep"
```

## Task 2.5 — Add `EnglishL1ProfileTests`

**Files:**
- Create: `Packages/MoraCore/Tests/MoraCoreTests/EnglishL1ProfileTests.swift`

- [ ] **Step 1: Create the test file**

Create `Packages/MoraCore/Tests/MoraCoreTests/EnglishL1ProfileTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class EnglishL1ProfileTests: XCTestCase {
    func test_identifier_is_en() {
        XCTAssertEqual(EnglishL1Profile().identifier, "en")
    }

    func test_characterSystem_is_alphabetic() {
        XCTAssertEqual(EnglishL1Profile().characterSystem, .alphabetic)
    }

    func test_interferencePairs_isEmpty() {
        XCTAssertTrue(EnglishL1Profile().interferencePairs.isEmpty)
    }

    func test_uiStrings_is_levelInvariant() {
        let p = EnglishL1Profile()
        XCTAssertEqual(p.uiStrings(at: .entry).homeTodayQuest,
                       p.uiStrings(at: .core).homeTodayQuest)
        XCTAssertEqual(p.uiStrings(at: .core).homeTodayQuest,
                       p.uiStrings(at: .advanced).homeTodayQuest)
        XCTAssertEqual(p.uiStrings(at: .core).homeTodayQuest, "Today's quest")
    }

    func test_interestCategoryDisplayName_returnsEnglish() {
        let p = EnglishL1Profile()
        XCTAssertEqual(p.interestCategoryDisplayName(key: "animals", at: .core), "Animals")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "dinosaurs", at: .core), "Dinosaurs")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "vehicles", at: .core), "Vehicles")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "space", at: .core), "Space")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "sports", at: .core), "Sports")
        XCTAssertEqual(p.interestCategoryDisplayName(key: "robots", at: .core), "Robots")
    }

    func test_allowedScriptBudget_isNil_atAllLevels() {
        let p = EnglishL1Profile()
        for level in LearnerLevel.allCases {
            XCTAssertNil(p.allowedScriptBudget(at: level))
        }
    }

    /// Smoke: every rendered field uses only ASCII letters / digits /
    /// punctuation / whitespace + ▶ / 🔊. Catches accidental locale leakage
    /// (e.g. Japanese punctuation slipping into the EN table).
    func test_stringsKidEn_isAsciiPlusEmojiOnly() {
        let strings = EnglishL1Profile().uiStrings(at: .core)
        for (fieldName, value) in EveryStringField(strings) {
            for char in value {
                for scalar in char.unicodeScalars {
                    let v = scalar.value
                    let ok =
                        (0x0020...0x007E).contains(v) ||         // printable ASCII
                        v == 0x000A || v == 0x000D ||             // newline / CR
                        v == 0x25B6 ||                            // ▶
                        v == 0x1F50A ||                           // 🔊
                        v == 0x2026                                // …
                    XCTAssertTrue(
                        ok,
                        "[en] '\(fieldName)' contains non-ASCII U+\(String(v, radix: 16, uppercase: true))"
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `(cd Packages/MoraCore && swift test --filter EnglishL1ProfileTests)`
Expected: 7 tests, all PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Tests/MoraCoreTests/EnglishL1ProfileTests.swift
git commit -m "core: add EnglishL1ProfileTests with ASCII-purity smoke"
```

## Task 2.6 — Activate KO/EN rows + system-locale default in `LanguageAgeFlow`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift`
- Modify: `Packages/MoraUI/Tests/MoraUITests/LanguageAgeFlowTests.swift`

- [ ] **Step 1: Add tests for active rows + system-locale default**

Append to `LanguageAgeFlowTests`:

```swift
    func test_pickerRows_areActive_forJaKoEn() {
        // Specific assertions depend on the existing test harness for LanguageAgeFlow.
        // Confirm: 4 rows shown; ja/ko/en are tap-enabled; zh is disabled with "Coming soon".
        let activeIDs = LanguageAgeFlow.activeLanguageIdentifiers
        XCTAssertEqual(Set(activeIDs), Set(["ja", "ko", "en"]))
        let disabledIDs = LanguageAgeFlow.comingSoonLanguageIdentifiers
        XCTAssertEqual(Set(disabledIDs), Set(["zh"]))
    }

    func test_defaultLanguageID_followsSystemLocale() {
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "ja_JP")), "ja")
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "ko_KR")), "ko")
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "en_US")), "en")
    }

    func test_defaultLanguageID_unsupportedLocale_fallsBackToEnglish() {
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "zh_CN")), "en")
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "es_ES")), "en")
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "vi_VN")), "en")
        XCTAssertEqual(LanguageAgeFlow.defaultLanguageID(for: Locale(identifier: "")), "en")
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraUI && swift test --filter LanguageAgeFlowTests)`
Expected: FAIL — `activeLanguageIdentifiers` / `defaultLanguageID(for:)` not yet implemented.

- [ ] **Step 3: Update `LanguageAgeFlow.swift`**

Add to `LanguageAgeFlow`:

```swift
    /// Identifiers of language rows that are tap-enabled.
    public static let activeLanguageIdentifiers: [String] = ["ja", "ko", "en"]

    /// Identifiers of language rows that render with `(Coming soon)` and are disabled.
    public static let comingSoonLanguageIdentifiers: [String] = ["zh"]

    /// Default language identifier given a system locale. `ja_JP` → `"ja"`,
    /// `ko_KR` → `"ko"`, `en_*` → `"en"`, anything else → `"en"`
    /// (international fallback). See spec §7.4.
    public static func defaultLanguageID(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "ja": return "ja"
        case "ko": return "ko"
        default:   return "en"
        }
    }
```

Update the existing initial-state setup of `LanguageAgeFlow` to use `defaultLanguageID(for: Locale.current)` for the picker pre-selection (replace whatever hard-coded `"ja"` default exists in the current implementation).

In the row-rendering code, source the row enable/disable state from `activeLanguageIdentifiers` / `comingSoonLanguageIdentifiers` (replace the hard-coded "only ja active" branching from the predecessor implementation).

- [ ] **Step 4: Run tests**

Run: `(cd Packages/MoraUI && swift test --filter LanguageAgeFlowTests)`
Expected: PASS — including the new 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift \
        Packages/MoraUI/Tests/MoraUITests/LanguageAgeFlowTests.swift
git commit -m "ui: activate ko/en picker rows + system-locale default"
```

## Task 2.7 — Add KO and EN profiles to `LocaleScriptBudgetTests`

**Files:**
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift`

- [ ] **Step 1: Add KO and EN to the profiles array**

Edit `LocaleScriptBudgetTests`. The `profiles` array now includes all three:

```swift
let profiles: [any L1Profile] = [
    JapaneseL1Profile(),
    KoreanL1Profile(),
    EnglishL1Profile(),
]
```

(KO and EN return `nil` from `allowedScriptBudget(at:)` so the inner loop simply continues for their cells; the test still walks all 9 grid cells but only asserts on JP × 3.)

- [ ] **Step 2: Run all MoraCore tests**

Run: `(cd Packages/MoraCore && swift test)`
Expected: all PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift
git commit -m "core: include KO and EN profiles in script-budget grid (no-op for nil budgets)"
```

## Task 2.8 — PR 2 final verification + manual smoke

- [ ] **Step 1: Full test matrix**

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```

- [ ] **Step 2: xcodebuild + lint**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 3: Simulator smoke — Korean**

Boot iPad simulator with system locale set to `ko_KR` (Settings → General → Language & Region → Korean).
- Fresh-install Mora.
- Expect Step 1 picker to pre-select `한국어`.
- Pick age 7 → Step 2 → onboarding.
- Verify Home renders entirely in Korean (`오늘의 퀘스트` etc.).
- Complete one A-day session.
- Verify bestiary date displays as `2026년 4월 26일` format.

- [ ] **Step 4: Simulator smoke — English (via unsupported locale fallback)**

Boot iPad simulator with system locale `vi_VN` (or any unsupported locale).
- Fresh-install.
- Expect Step 1 picker to pre-select `English`.
- Pick age 6 → Step 2 → onboarding.
- Verify Home renders in English.
- Complete one A-day session.

- [ ] **Step 5: Open PR 2**

PR base: `feat/mora-i18n/01-foundation-and-jp-tiers` (or `main` if PR 1 has merged).
Branch: `feat/mora-i18n/02-ko-and-en-profiles`.

PR body summary:
> - Add `KoreanL1Profile` (single level-invariant Hangul table + 8 KO L1→EN L2 interference pairs)
> - Add `EnglishL1Profile` (single level-invariant table; empty interference set since L1==L2)
> - `L1ProfileResolver` dispatches `ko` and `en` identifiers
> - `LanguageAgeFlow` activates 한국어 / English rows; system-locale default → `ja`/`ko` direct, else English fallback
> - `LocaleScriptBudgetTests` extends to (3 profiles × 3 levels) grid (KO/EN auto-skip via nil budget)
> - `KoreanL1ProfileTests` includes Hangul-purity sweep (no CJK ideographs)
> - `EnglishL1ProfileTests` includes ASCII-purity smoke

---

# PR 3: Age Picker Narrow + In-App Language Switch

Branch: `feat/mora-i18n/03-age-narrow-and-language-switch`. Base: `feat/mora-i18n/02-ko-and-en-profiles`. Estimated 200 LOC.

**Behavior at PR-merge time:** Age picker is now a 3-tile row (6/7/8) defaulting to 7. Home renders a globe button next to the wordmark; tapping it presents `LanguageSwitchSheet` allowing language re-pick without state loss.

## Task 3.1 — Add 4 new fields to `MoraStrings`

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/KoreanL1Profile.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/EnglishL1Profile.swift`
- Modify: `Packages/MoraCore/Tests/MoraCoreTests/LocaleScriptBudgetTests.swift` (add new fields to `EveryStringField`)

- [ ] **Step 1: Add fields to `MoraStrings` struct**

Edit `Packages/MoraCore/Sources/MoraCore/MoraStrings.swift`. Add four `let`s alongside the accessibility-labels group, near the end of the property list:

```swift
    // In-app language switch (Home globe button + sheet)
    public let homeChangeLanguageButton: String
    public let languageSwitchSheetTitle: String
    public let languageSwitchSheetCancel: String
    public let languageSwitchSheetConfirm: String
```

Update the `init(...)` signature to accept these 4 new parameters (insert in the same position):

```swift
        a11yStreakChip: @escaping @Sendable (Int) -> String,
        homeChangeLanguageButton: String,
        languageSwitchSheetTitle: String,
        languageSwitchSheetCancel: String,
        languageSwitchSheetConfirm: String
```

And the assignments:

```swift
        self.a11yStreakChip = a11yStreakChip
        self.homeChangeLanguageButton = homeChangeLanguageButton
        self.languageSwitchSheetTitle = languageSwitchSheetTitle
        self.languageSwitchSheetCancel = languageSwitchSheetCancel
        self.languageSwitchSheetConfirm = languageSwitchSheetConfirm
```

- [ ] **Step 2: Author values in JP three tables**

In `JapaneseL1Profile.swift`, add to **all three** static tables (`stringsAdvancedG1G2`, `stringsCoreG1`, `stringsEntryHiraOnly`):

```swift
        homeChangeLanguageButton: "ことばを かえる",
        languageSwitchSheetTitle: "ことばを えらぶ",
        languageSwitchSheetCancel: "キャンセル",
        languageSwitchSheetConfirm: "OK"
```

(All three JP tiers use identical values because none of these contain G2-or-higher kanji — `言葉` would, but the partial-mix rule §6.1.1 forbids `言`+`葉` mixing, so the all-hira version is shipped to every tier.)

- [ ] **Step 3: Author values in KO**

In `KoreanL1Profile.swift`'s `stringsKidKo`:

```swift
        homeChangeLanguageButton: "언어 바꾸기",
        languageSwitchSheetTitle: "언어 선택",
        languageSwitchSheetCancel: "취소",
        languageSwitchSheetConfirm: "확인"
```

- [ ] **Step 4: Author values in EN**

In `EnglishL1Profile.swift`'s `stringsKidEn`:

```swift
        homeChangeLanguageButton: "Change language",
        languageSwitchSheetTitle: "Pick a language",
        languageSwitchSheetCancel: "Cancel",
        languageSwitchSheetConfirm: "Done"
```

- [ ] **Step 5: Update `EveryStringField` in `LocaleScriptBudgetTests`**

Append to the array literal in `EveryStringField(_:)`:

```swift
    ("homeChangeLanguageButton", s.homeChangeLanguageButton),
    ("languageSwitchSheetTitle", s.languageSwitchSheetTitle),
    ("languageSwitchSheetCancel", s.languageSwitchSheetCancel),
    ("languageSwitchSheetConfirm", s.languageSwitchSheetConfirm),
```

- [ ] **Step 6: Run all MoraCore tests**

Run: `(cd Packages/MoraCore && swift test)`
Expected: all PASS, including all 4 budget audits (JP × 3 levels) and the KO/EN purity tests.

- [ ] **Step 7: Commit**

```bash
git add Packages/MoraCore/
git commit -m "core: add 4 MoraStrings fields for in-app language switch"
```

## Task 3.2 — Narrow age picker to 6/7/8 (3 tiles)

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift`
- Modify: `Packages/MoraUI/Tests/MoraUITests/LanguageAgeFlowTests.swift`

- [ ] **Step 1: Update tests**

Append to `LanguageAgeFlowTests`:

```swift
    func test_agePicker_showsThreeTiles_for6_7_8() {
        let ages = LanguageAgeFlow.ageOptions
        XCTAssertEqual(ages, [6, 7, 8])
    }

    func test_agePicker_defaultSelection_is7() {
        XCTAssertEqual(LanguageAgeFlow.defaultAge, 7)
    }
```

- [ ] **Step 2: Update LanguageAgeFlow**

Replace the existing age-tile array (currently 4–12 plus 13+, possibly stored as `[Int]`):

```swift
    /// Age tiles shown in Step 2. Narrowed in PR 3 to the dyslexia
    /// intervention window (6–8 = JP 小学校低学年). See spec §7.2.
    public static let ageOptions: [Int] = [6, 7, 8]

    /// Default selected age in Step 2 — middle of the target range.
    public static let defaultAge: Int = 7
```

In the body that lays out the age picker, change the grid from 3×4 to 1×3 (or whatever single-row treatment matches the existing tile component) and use `ageOptions`. Increase the tile numeric size if the existing implementation uses a font modifier; the spec recommends scaling from ≈80pt to ≈120pt.

Update the existing initial-state seed of `state.selectedAge` to `defaultAge`.

- [ ] **Step 3: Run the tests**

Run: `(cd Packages/MoraUI && swift test --filter LanguageAgeFlowTests)`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift \
        Packages/MoraUI/Tests/MoraUITests/LanguageAgeFlowTests.swift
git commit -m "ui: narrow age picker to 6/7/8 tiles"
```

## Task 3.3 — Extract `LanguagePicker` view component

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguagePicker.swift`
- Modify: `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift`

`LanguageAgeFlow`'s Step 1 view becomes a reusable component so `LanguageSwitchSheet` (Task 3.4) can embed it without copy-paste.

- [ ] **Step 1: Create `LanguagePicker.swift`**

Create `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguagePicker.swift`. Move the row-rendering logic from `LanguageAgeFlow.swift`'s Step 1 here:

```swift
// Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguagePicker.swift
import MoraCore
import SwiftUI

/// Reusable language-row picker used by both onboarding Step 1 and the
/// in-app `LanguageSwitchSheet`. Rows: ja / ko / en (active) and zh
/// (disabled with `(Coming soon)`).
public struct LanguagePicker: View {
    @Binding public var selection: String

    public init(selection: Binding<String>) {
        self._selection = selection
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Language / 言語 / 语言 / 언어")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(allRows, id: \.identifier) { row in
                Button {
                    if row.isActive { selection = row.identifier }
                } label: {
                    HStack {
                        Text(row.label)
                            .font(.title2)
                        Spacer()
                        if !row.isActive {
                            Text("(Coming soon)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: selection == row.identifier ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(row.isActive ? .accentColor : .secondary)
                    }
                    .padding()
                    .background(selection == row.identifier ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .disabled(!row.isActive)
                .opacity(row.isActive ? 1.0 : 0.5)
            }
        }
    }

    private struct Row {
        let identifier: String
        let label: String
        let isActive: Bool
    }

    private var allRows: [Row] {
        [
            Row(identifier: "ja", label: "にほんご", isActive: true),
            Row(identifier: "ko", label: "한국어",   isActive: true),
            Row(identifier: "en", label: "English", isActive: true),
            Row(identifier: "zh", label: "中文",     isActive: false),
        ]
    }
}
```

The header `Language / 言語 / 语言 / 언어` is a fixed-string locale-neutral header (per spec §4 design table) and stays untranslated.

- [ ] **Step 2: Update `LanguageAgeFlow.swift` Step 1**

Replace the inline Step 1 view body with `LanguagePicker(selection: $state.languageID)` (or whatever the state binding is).

- [ ] **Step 3: Run all MoraUI tests**

Run: `(cd Packages/MoraUI && swift test)`
Expected: PASS (no regressions).

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguagePicker.swift \
        Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift
git commit -m "ui: extract LanguagePicker for reuse in switch sheet"
```

## Task 3.4 — Implement `LanguageSwitchSheet`

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageSwitchSheet.swift`
- Create: `Packages/MoraUI/Tests/MoraUITests/LanguageSwitchSheetTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Packages/MoraUI/Tests/MoraUITests/LanguageSwitchSheetTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraUI

@MainActor
final class LanguageSwitchSheetTests: XCTestCase {
    func test_onCommit_calledWithPickedID_whenConfirmTapped() {
        var committed: String?
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { committed = $0 },
            onCancel: { }
        )
        sheet.simulateSelect(identifier: "ko")
        sheet.simulateConfirm()
        XCTAssertEqual(committed, "ko")
    }

    func test_onCancel_called_whenCancelTapped() {
        var cancelled = false
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in },
            onCancel: { cancelled = true }
        )
        sheet.simulateCancel()
        XCTAssertTrue(cancelled)
    }

    func test_confirmDisabled_whenSelectionEqualsCurrent() {
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in XCTFail("should not commit") },
            onCancel: { }
        )
        // Initial state: pickedID == currentIdentifier → confirm is disabled.
        XCTAssertEqual(sheet.pickedID, "ja")
        XCTAssertTrue(sheet.isConfirmDisabled)
    }

    func test_confirmEnabled_whenSelectionDiffersFromCurrent() {
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in },
            onCancel: { }
        )
        sheet.simulateSelect(identifier: "en")
        XCTAssertEqual(sheet.pickedID, "en")
        XCTAssertFalse(sheet.isConfirmDisabled)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraUI && swift test --filter LanguageSwitchSheetTests)`
Expected: FAIL — `cannot find 'LanguageSwitchSheet' in scope`.

- [ ] **Step 3: Create `LanguageSwitchSheet.swift`**

Create `Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageSwitchSheet.swift`:

```swift
// Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageSwitchSheet.swift
import MoraCore
import SwiftUI

/// Sheet that lets the user re-pick the L1 from Home, without re-running
/// onboarding. Reuses `LanguagePicker`. Writes only `LearnerProfile.l1Identifier`;
/// age / level / interests / font are not touched. See spec §7.3.
@MainActor
public final class LanguageSwitchSheet: ObservableObject {
    public let currentIdentifier: String
    private let onCommit: (String) -> Void
    private let onCancel: () -> Void

    @Published public var pickedID: String

    public init(
        currentIdentifier: String,
        onCommit: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentIdentifier = currentIdentifier
        self.onCommit = onCommit
        self.onCancel = onCancel
        self.pickedID = currentIdentifier
    }

    public var isConfirmDisabled: Bool {
        pickedID == currentIdentifier
    }

    public func simulateSelect(identifier: String) {
        pickedID = identifier
    }

    public func simulateConfirm() {
        guard !isConfirmDisabled else { return }
        onCommit(pickedID)
    }

    public func simulateCancel() {
        onCancel()
    }
}

/// SwiftUI rendering of the sheet model. Hosted as a `.sheet` from `HomeView`.
public struct LanguageSwitchSheetView: View {
    @ObservedObject var model: LanguageSwitchSheet
    @Environment(\.moraStrings) private var strings

    public init(model: LanguageSwitchSheet) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            LanguagePicker(selection: $model.pickedID)
                .padding()
                .navigationTitle(strings.languageSwitchSheetTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(strings.languageSwitchSheetCancel) {
                            model.simulateCancel()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(strings.languageSwitchSheetConfirm) {
                            model.simulateConfirm()
                        }
                        .disabled(model.isConfirmDisabled)
                    }
                }
        }
    }
}
```

- [ ] **Step 4: Run to verify the tests pass**

Run: `(cd Packages/MoraUI && swift test --filter LanguageSwitchSheetTests)`
Expected: 4 tests, all PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageSwitchSheet.swift \
        Packages/MoraUI/Tests/MoraUITests/LanguageSwitchSheetTests.swift
git commit -m "ui: add LanguageSwitchSheet model + view"
```

## Task 3.5 — Wire the globe button into `HomeView`

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift`
- Create: `Packages/MoraUI/Tests/MoraUITests/HomeViewLanguageSwitchTests.swift`

- [ ] **Step 1: Add HomeView smoke test**

Create `Packages/MoraUI/Tests/MoraUITests/HomeViewLanguageSwitchTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraUI

@MainActor
final class HomeViewLanguageSwitchTests: XCTestCase {
    func test_globe_a11yLabel_matchesMoraStrings() {
        let strings = JapaneseL1Profile().uiStrings(at: .advanced)
        XCTAssertEqual(strings.homeChangeLanguageButton, "ことばを かえる")
    }

    // Full SwiftUI render harness for sheet presentation is out of scope;
    // the sheet's behavior is covered by LanguageSwitchSheetTests.
}
```

- [ ] **Step 2: Update `HomeView.swift`**

In `HomeView.swift`, add state for the sheet and a globe button. Locate the wordmark `mora` rendering and add the globe button next to it (the exact layout depends on the existing HomeView structure — place it at the trailing edge of whatever container holds the wordmark):

```swift
@State private var languageSheet: LanguageSwitchSheet?

// inside body where the wordmark is rendered:
HStack {
    Text("mora")
        .font(/* existing wordmark font */)
    Spacer()
    Button {
        guard let p = profile else { return }
        languageSheet = LanguageSwitchSheet(
            currentIdentifier: p.l1Identifier,
            onCommit: { newID in
                p.l1Identifier = newID
                try? modelContext.save()
                languageSheet = nil
            },
            onCancel: {
                languageSheet = nil
            }
        )
    } label: {
        Image(systemName: "globe")
            .foregroundStyle(.secondary)
    }
    .accessibilityLabel(strings.homeChangeLanguageButton)
}
.sheet(item: $languageSheet) { model in
    LanguageSwitchSheetView(model: model)
        .environment(\.moraStrings, strings)
}
```

`LanguageSwitchSheet` needs to conform to `Identifiable` for `.sheet(item:)` — add to `LanguageSwitchSheet`:

```swift
extension LanguageSwitchSheet: Identifiable {
    public var id: String { currentIdentifier }
}
```

- [ ] **Step 3: Run all MoraUI tests**

Run: `(cd Packages/MoraUI && swift test)`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Home/HomeView.swift \
        Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageSwitchSheet.swift \
        Packages/MoraUI/Tests/MoraUITests/HomeViewLanguageSwitchTests.swift
git commit -m "ui: wire globe language-switch button into HomeView"
```

## Task 3.6 — PR 3 final verification + dev iPad smoke

- [ ] **Step 1: Full test matrix**

```sh
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```

- [ ] **Step 2: xcodebuild + lint**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 3: Dev iPad smoke — language switch**

Install over the existing dev install.
- Verify Home renders identically to pre-upgrade.
- Verify the globe button is visible next to the wordmark.
- Tap globe → sheet appears, with `にほんご` pre-selected.
- Tap `한국어` → confirm button enables.
- Tap confirm → sheet dismisses → Home re-renders entirely in Korean.
- Verify streak count and yokai cameos preserved.
- Tap globe again → switch back to `にほんご` → sheet dismisses → Home back in Japanese.
- Verify no state lost.

- [ ] **Step 4: Simulator smoke — narrowed age picker**

Boot fresh simulator install (any locale).
- LanguageAgeFlow Step 1 → pick a language.
- Step 2 → verify exactly 3 age tiles (6 / 7 / 8) and `7` is pre-selected.
- Tap 6 → confirm Onboarding completes → Home renders the appropriate level (entry table for JP).

- [ ] **Step 5: Open PR 3**

PR base: `feat/mora-i18n/02-ko-and-en-profiles` (or `main` if PR 2 has merged).
Branch: `feat/mora-i18n/03-age-narrow-and-language-switch`.

PR body summary:
> - Narrow Step 2 age picker to 3 tiles (6 / 7 / 8), default 7
> - Add 4 new `MoraStrings` fields (`homeChangeLanguageButton`, `languageSwitchSheetTitle`, `languageSwitchSheetCancel`, `languageSwitchSheetConfirm`) authored across all five tables (JP entry / core / advanced + KO + EN)
> - Extract `LanguagePicker` view component for reuse
> - Add `LanguageSwitchSheet` (model + view) with confirm-disabled-when-unchanged guard
> - Wire globe button into `HomeView`; tap presents sheet, commit writes `LearnerProfile.l1Identifier` and dismisses

---

## Summary

After all 3 PRs merge, the `MoraStrings` env on every screen resolves through:

```
LearnerProfile.l1Identifier  →  L1ProfileResolver  →  any L1Profile
LearnerProfile.resolvedLevel →  (.entry / .core / .advanced)
                               →  L1Profile.uiStrings(at:)
                               →  MoraStrings
```

Every L1 profile implements the same uniform protocol surface. JP varies its
table by level (kanji budget). KO and EN return one level-invariant table.
Adding ZH (Mandarin) — or any other L1 — is purely additive: a new struct
that implements `L1Profile`, a new case in `L1ProfileResolver`, and a new
row in the `LanguagePicker` activation list. No engine code changes; no
content JSON touched.
