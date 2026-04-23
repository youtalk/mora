# Tile-Board Decoding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the A-day Decoding list-read UI with a Barton-style tile-manipulation board that delivers three four-word mini-chains (Build head + three Change successors each) per six-minute phase.

**Architecture:** New `TileBoardEngine` state machine in MoraEngines drives a seven-state trial loop (preparing → listening → building → completed → speaking → feedback → transitioning). A `WordChainProvider` generates three chains per phase from the authored library and `TemplateEngine` under chain invariants. New SwiftUI views in `MoraUI/Session/TileBoard/` render tiles and slots with `.matchedGeometryEffect` flight and SwiftUI-native spring physics. `PerformanceEntity` gains per-trial scaffold telemetry via an additive SwiftData migration. `DecodeActivityView` is deleted outright.

**Tech Stack:** Swift 5.10+, SwiftUI, SwiftData, `@Observable`, XCTest, Apple Speech / AVFoundation (reused), OpenDyslexic (already bundled). No SpriteKit, no third-party animation or test-framework libraries.

**Spec:** `docs/superpowers/specs/2026-04-22-tile-board-decoding-design.md`.

---

## Conventions for the executing engineer

- All repo **governance artifacts are English**: markdown, identifiers, comments, commit messages. Japanese text appears only in `MoraStrings` values and per-locale profile string literals — no MoraStrings changes are expected in this plan.
- Commit messages may end with `Co-Authored-By: Claude <noreply@anthropic.com>` per repo policy (this repo opts out of the global rule that strips Claude attribution).
- `xcodegen generate` is required after **any** edit to `project.yml` and before `xcodebuild`. Most tasks in this plan do not edit `project.yml`; Task 29 runs the full regenerate + build cycle.
- `swift test` runs against each package independently. Run from inside the package directory (`cd Packages/MoraEngines && swift test`).
- `swift-format lint --strict` is the CI gate. Run `swift-format format --in-place --recursive Mora Packages/*/Sources Packages/*/Tests` before the final commit of a task if the diff is substantial.
- Prefer small, focused commits — one per task.

---

## Phase 1 — MoraCore foundations

### Task 1: Tile value type and kind classification

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/TileKind.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/Tile.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Tiles/TileKindTests.swift`

`TileKind` buckets a `Grapheme` into the three color classes used by the board palette (`consonant` = blue, `vowel` = orange, `multigrapheme` = green). Single-letter graphemes become consonant or vowel based on whether the letter is one of `{a, e, i, o, u}`. Two-letter and longer graphemes are all `.multigrapheme` — the board does not distinguish digraphs from blends visually.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Tiles/TileKindTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class TileKindTests: XCTestCase {
    func testSingleVowelLettersAreVowel() {
        for letter in ["a", "e", "i", "o", "u"] {
            XCTAssertEqual(TileKind(grapheme: Grapheme(letters: letter)), .vowel, "\(letter) should be vowel")
        }
    }

    func testSingleConsonantLettersAreConsonant() {
        for letter in ["b", "c", "d", "f", "s", "t", "z"] {
            XCTAssertEqual(TileKind(grapheme: Grapheme(letters: letter)), .consonant, "\(letter) should be consonant")
        }
    }

    func testDigraphsAndLongerAreMultigrapheme() {
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "sh")), .multigrapheme)
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "ch")), .multigrapheme)
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "str")), .multigrapheme)
    }

    func testUppercaseInputIsLowercasedByGrapheme() {
        XCTAssertEqual(TileKind(grapheme: Grapheme(letters: "A")), .vowel)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter TileKindTests)`
Expected: FAIL with "cannot find 'TileKind' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Packages/MoraCore/Sources/MoraCore/Tiles/TileKind.swift`:

```swift
import Foundation

public enum TileKind: String, Hashable, Codable, Sendable {
    case consonant
    case vowel
    case multigrapheme

    public init(grapheme: Grapheme) {
        if grapheme.letters.count == 1, "aeiou".contains(grapheme.letters) {
            self = .vowel
        } else if grapheme.letters.count == 1 {
            self = .consonant
        } else {
            self = .multigrapheme
        }
    }
}
```

Create `Packages/MoraCore/Sources/MoraCore/Tiles/Tile.swift`:

```swift
import Foundation

/// A single draggable tile on the decoding board. Identity is the grapheme —
/// two tiles with the same grapheme are the same tile for engine purposes.
public struct Tile: Hashable, Codable, Sendable, Identifiable {
    public let grapheme: Grapheme

    public var id: String { grapheme.letters }
    public var kind: TileKind { TileKind(grapheme: grapheme) }
    public var display: String { grapheme.letters }

    public init(grapheme: Grapheme) {
        self.grapheme = grapheme
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter TileKindTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Tiles/ Packages/MoraCore/Tests/MoraCoreTests/Tiles/
git commit -m "core: add Tile and TileKind value types"
```

---

### Task 2: BuildTarget and ChangeTarget

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/BuildTarget.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/ChangeTarget.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Tiles/ChainTargetTests.swift`

`BuildTarget` holds the canonical grapheme sequence of a Build head. `ChangeTarget` holds the predecessor-to-successor mapping for one Change trial, including the single changed slot index. Both are pure data — the `WordChain` validator in Task 3 enforces invariants across them.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Tiles/ChainTargetTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class ChainTargetTests: XCTestCase {
    private func w(_ surface: String, _ graphemes: [String]) -> Word {
        Word(
            surface: surface,
            graphemes: graphemes.map { Grapheme(letters: $0) },
            phonemes: []
        )
    }

    func testBuildTargetExposesSlotGraphemes() {
        let t = BuildTarget(word: w("ship", ["sh", "i", "p"]))
        XCTAssertEqual(t.slots.map(\.letters), ["sh", "i", "p"])
    }

    func testChangeTargetIdentifiesChangedIndex() {
        let pred = w("ship", ["sh", "i", "p"])
        let succ = w("shop", ["sh", "o", "p"])
        let t = ChangeTarget(predecessor: pred, successor: succ)
        XCTAssertEqual(t.changedIndex, 1)
        XCTAssertEqual(t.oldGrapheme.letters, "i")
        XCTAssertEqual(t.newGrapheme.letters, "o")
    }

    func testChangeTargetReturnsNilWhenLengthsDiffer() {
        let pred = w("ship", ["sh", "i", "p"])
        let succ = w("sip", ["s", "i", "p"])
        XCTAssertNil(ChangeTarget(predecessor: pred, successor: succ))
    }

    func testChangeTargetReturnsNilWhenMultiplePositionsDiffer() {
        let pred = w("cat", ["c", "a", "t"])
        let succ = w("dog", ["d", "o", "g"])
        XCTAssertNil(ChangeTarget(predecessor: pred, successor: succ))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter ChainTargetTests)`
Expected: FAIL with "cannot find 'BuildTarget' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Packages/MoraCore/Sources/MoraCore/Tiles/BuildTarget.swift`:

```swift
import Foundation

/// The head of a word chain: all slots empty, pool contains the word's
/// graphemes plus distractors.
public struct BuildTarget: Hashable, Codable, Sendable {
    public let word: Word

    public init(word: Word) {
        self.word = word
    }

    public var slots: [Grapheme] { word.graphemes }
}
```

Create `Packages/MoraCore/Sources/MoraCore/Tiles/ChangeTarget.swift`:

```swift
import Foundation

/// A successor in a word chain: exactly one slot differs from the
/// predecessor. `init` returns `nil` when that invariant does not hold.
public struct ChangeTarget: Hashable, Codable, Sendable {
    public let predecessor: Word
    public let successor: Word
    public let changedIndex: Int

    public init?(predecessor: Word, successor: Word) {
        let pre = predecessor.graphemes
        let suc = successor.graphemes
        guard pre.count == suc.count else { return nil }
        var diffs: [Int] = []
        for index in pre.indices where pre[index] != suc[index] {
            diffs.append(index)
            if diffs.count > 1 { return nil }
        }
        guard let only = diffs.first else { return nil }
        self.predecessor = predecessor
        self.successor = successor
        self.changedIndex = only
    }

    public var oldGrapheme: Grapheme { predecessor.graphemes[changedIndex] }
    public var newGrapheme: Grapheme { successor.graphemes[changedIndex] }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter ChainTargetTests)`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Tiles/ Packages/MoraCore/Tests/MoraCoreTests/Tiles/ChainTargetTests.swift
git commit -m "core: add BuildTarget and ChangeTarget"
```

---

### Task 3: WordChain with validator

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/ChainRole.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/WordChain.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Tiles/WordChainTests.swift`

`WordChain` is `ChainRole × BuildTarget × [ChangeTarget]`. Its failable initializer enforces spec §8.1–§8.3: decodability (graphemes must come from a permitted inventory), change-by-one, single-grapheme-delta. The decodability check takes the `inventory` (mastered set ∪ {target}) as a parameter so the caller controls what counts as permitted.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Tiles/WordChainTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class WordChainTests: XCTestCase {
    private func w(_ surface: String, _ gs: [String]) -> Word {
        Word(surface: surface, graphemes: gs.map { Grapheme(letters: $0) }, phonemes: [])
    }

    private let shInventory: Set<Grapheme> = Set(
        ["c", "s", "h", "i", "o", "p", "t", "sh"].map { Grapheme(letters: $0) }
    )

    func testValidChain() {
        let chain = WordChain(
            role: .targetIntro,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("shop", ["sh", "o", "p"]), w("shot", ["sh", "o", "t"])],
            inventory: shInventory
        )
        XCTAssertNotNil(chain)
        XCTAssertEqual(chain?.successors.count, 2)
        XCTAssertEqual(chain?.successors.first?.changedIndex, 1)
    }

    func testRejectsChainWithNondecodableWord() {
        let chain = WordChain(
            role: .warmup,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("shab", ["sh", "a", "b"])],  // 'a' and 'b' not in inventory
            inventory: shInventory
        )
        XCTAssertNil(chain)
    }

    func testRejectsChainWithTwoPositionDelta() {
        let chain = WordChain(
            role: .warmup,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("shot", ["sh", "o", "t"])],  // two positions differ
            inventory: shInventory
        )
        XCTAssertNil(chain)
    }

    func testRejectsChainHeadOutsideInventory() {
        let chain = WordChain(
            role: .warmup,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [],
            inventory: Set(["c", "a", "t"].map { Grapheme(letters: $0) })
        )
        XCTAssertNil(chain)
    }

    func testAllowsDigraphToDigraphReplacement() {
        let inv = Set(["sh", "ch", "i", "p"].map { Grapheme(letters: $0) })
        let chain = WordChain(
            role: .mixedApplication,
            head: BuildTarget(word: w("ship", ["sh", "i", "p"])),
            successorWords: [w("chip", ["ch", "i", "p"])],
            inventory: inv
        )
        XCTAssertNotNil(chain)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter WordChainTests)`
Expected: FAIL with "cannot find 'WordChain' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Packages/MoraCore/Sources/MoraCore/Tiles/ChainRole.swift`:

```swift
import Foundation

public enum ChainRole: String, Hashable, Codable, Sendable {
    case warmup
    case targetIntro
    case mixedApplication
}
```

Create `Packages/MoraCore/Sources/MoraCore/Tiles/WordChain.swift`:

```swift
import Foundation

/// One four-word mini-chain. Head is a Build; each successor is a Change
/// that differs from its predecessor by exactly one grapheme at one index.
/// All words must be decodable within `inventory`.
public struct WordChain: Hashable, Codable, Sendable {
    public let role: ChainRole
    public let head: BuildTarget
    public let successors: [ChangeTarget]

    public init?(
        role: ChainRole,
        head: BuildTarget,
        successorWords: [Word],
        inventory: Set<Grapheme>
    ) {
        guard Self.isDecodable(head.word, inventory: inventory) else { return nil }
        var built: [ChangeTarget] = []
        var previous = head.word
        for next in successorWords {
            guard Self.isDecodable(next, inventory: inventory) else { return nil }
            guard let change = ChangeTarget(predecessor: previous, successor: next) else { return nil }
            built.append(change)
            previous = next
        }
        self.role = role
        self.head = head
        self.successors = built
    }

    public var allWords: [Word] {
        [head.word] + successors.map(\.successor)
    }

    private static func isDecodable(_ word: Word, inventory: Set<Grapheme>) -> Bool {
        word.graphemes.allSatisfy { inventory.contains($0) }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter WordChainTests)`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Tiles/ChainRole.swift Packages/MoraCore/Sources/MoraCore/Tiles/WordChain.swift Packages/MoraCore/Tests/MoraCoreTests/Tiles/WordChainTests.swift
git commit -m "core: add WordChain with decodability and delta invariants"
```

---

### Task 4: BuildAttemptRecord and TileBoardMetrics

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/BuildAttemptRecord.swift`
- Create: `Packages/MoraCore/Sources/MoraCore/Tiles/TileBoardMetrics.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Tiles/TelemetryTests.swift`

Two codable records used by persistence (JSON blob columns) and the engine. Spec §9.2.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Tiles/TelemetryTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class TelemetryTests: XCTestCase {
    func testBuildAttemptRecordRoundTrips() throws {
        let r = BuildAttemptRecord(
            slotIndex: 1,
            tileDropped: Grapheme(letters: "i"),
            wasCorrect: false,
            timestampOffset: 1.25
        )
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(BuildAttemptRecord.self, from: data)
        XCTAssertEqual(r, back)
    }

    func testTileBoardMetricsDefaults() {
        let m = TileBoardMetrics()
        XCTAssertEqual(m.chainCount, 0)
        XCTAssertEqual(m.truncatedChainCount, 0)
        XCTAssertEqual(m.totalDropMisses, 0)
        XCTAssertEqual(m.autoFillCount, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter TelemetryTests)`
Expected: FAIL with "cannot find 'BuildAttemptRecord' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Packages/MoraCore/Sources/MoraCore/Tiles/BuildAttemptRecord.swift`:

```swift
import Foundation

/// One tile drop on a slot during a Build or Change trial.
public struct BuildAttemptRecord: Hashable, Codable, Sendable {
    public let slotIndex: Int
    public let tileDropped: Grapheme
    public let wasCorrect: Bool
    public let timestampOffset: TimeInterval

    public init(
        slotIndex: Int,
        tileDropped: Grapheme,
        wasCorrect: Bool,
        timestampOffset: TimeInterval
    ) {
        self.slotIndex = slotIndex
        self.tileDropped = tileDropped
        self.wasCorrect = wasCorrect
        self.timestampOffset = timestampOffset
    }
}
```

Create `Packages/MoraCore/Sources/MoraCore/Tiles/TileBoardMetrics.swift`:

```swift
import Foundation

/// Phase-level tile-board counters. Persisted in `SessionSummaryEntity`.
public struct TileBoardMetrics: Hashable, Codable, Sendable {
    public var chainCount: Int
    public var truncatedChainCount: Int
    public var totalDropMisses: Int
    public var autoFillCount: Int

    public init(
        chainCount: Int = 0,
        truncatedChainCount: Int = 0,
        totalDropMisses: Int = 0,
        autoFillCount: Int = 0
    ) {
        self.chainCount = chainCount
        self.truncatedChainCount = truncatedChainCount
        self.totalDropMisses = totalDropMisses
        self.autoFillCount = autoFillCount
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter TelemetryTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Tiles/BuildAttemptRecord.swift Packages/MoraCore/Sources/MoraCore/Tiles/TileBoardMetrics.swift Packages/MoraCore/Tests/MoraCoreTests/Tiles/TelemetryTests.swift
git commit -m "core: add BuildAttemptRecord and TileBoardMetrics"
```

---

### Task 5: Extend PerformanceEntity with scaffold fields

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/PerformanceEntity.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Persistence/PerformanceEntityTileBoardTests.swift`

Add five nullable / default-initialized fields to the per-trial row: `buildAttemptsJSON: Data?`, `scaffoldLevel: Int`, `ttsHintIssued: Bool`, `poolReducedToTwo: Bool`, `autoFilled: Bool`. All default to "nothing happened on this trial" so the migration is additive for every existing row.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Persistence/PerformanceEntityTileBoardTests.swift`:

```swift
import XCTest
import SwiftData
@testable import MoraCore

final class PerformanceEntityTileBoardTests: XCTestCase {
    func testDefaultsAreTileBoardNeutral() {
        let e = PerformanceEntity(
            sessionId: UUID(),
            skillCode: "L2.sh",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date()
        )
        XCTAssertNil(e.buildAttemptsJSON)
        XCTAssertEqual(e.scaffoldLevel, 0)
        XCTAssertFalse(e.ttsHintIssued)
        XCTAssertFalse(e.poolReducedToTwo)
        XCTAssertFalse(e.autoFilled)
    }

    func testTileBoardFieldsRoundTripViaDecodedJSON() throws {
        let attempts: [BuildAttemptRecord] = [
            BuildAttemptRecord(slotIndex: 0, tileDropped: Grapheme(letters: "s"), wasCorrect: false, timestampOffset: 0.5),
            BuildAttemptRecord(slotIndex: 0, tileDropped: Grapheme(letters: "sh"), wasCorrect: true, timestampOffset: 1.1),
        ]
        let data = try JSONEncoder().encode(attempts)
        let e = PerformanceEntity(
            sessionId: UUID(),
            skillCode: "L2.sh",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date(),
            buildAttemptsJSON: data,
            scaffoldLevel: 1,
            ttsHintIssued: true
        )
        XCTAssertEqual(e.scaffoldLevel, 1)
        XCTAssertTrue(e.ttsHintIssued)
        let decoded = try JSONDecoder().decode([BuildAttemptRecord].self, from: XCTUnwrap(e.buildAttemptsJSON))
        XCTAssertEqual(decoded.count, 2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter PerformanceEntityTileBoardTests)`
Expected: FAIL with "extra argument 'buildAttemptsJSON' in call".

- [ ] **Step 3: Extend the entity**

Replace the contents of `Packages/MoraCore/Sources/MoraCore/Persistence/PerformanceEntity.swift` with:

```swift
import Foundation
import SwiftData

@Model
public final class PerformanceEntity {
    public var id: UUID
    public var sessionId: UUID
    public var skillCode: String
    public var expected: String
    public var heard: String?
    public var correct: Bool
    public var l1InterferenceTag: String?
    public var timestamp: Date

    // Tile-board scaffold telemetry. All defaults represent "no tile-board
    // activity" so legacy rows migrate additively.
    public var buildAttemptsJSON: Data?
    public var scaffoldLevel: Int
    public var ttsHintIssued: Bool
    public var poolReducedToTwo: Bool
    public var autoFilled: Bool

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        skillCode: String,
        expected: String,
        heard: String?,
        correct: Bool,
        l1InterferenceTag: String?,
        timestamp: Date,
        buildAttemptsJSON: Data? = nil,
        scaffoldLevel: Int = 0,
        ttsHintIssued: Bool = false,
        poolReducedToTwo: Bool = false,
        autoFilled: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.skillCode = skillCode
        self.expected = expected
        self.heard = heard
        self.correct = correct
        self.l1InterferenceTag = l1InterferenceTag
        self.timestamp = timestamp
        self.buildAttemptsJSON = buildAttemptsJSON
        self.scaffoldLevel = scaffoldLevel
        self.ttsHintIssued = ttsHintIssued
        self.poolReducedToTwo = poolReducedToTwo
        self.autoFilled = autoFilled
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraCore && swift test --filter PerformanceEntityTileBoardTests)`
Expected: PASS. Also run the full MoraCore test suite to make sure nothing else broke: `(cd Packages/MoraCore && swift test)`.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Persistence/PerformanceEntity.swift Packages/MoraCore/Tests/MoraCoreTests/Persistence/PerformanceEntityTileBoardTests.swift
git commit -m "core: extend PerformanceEntity with tile-board scaffold fields"
```

---

### Task 6: Extend SessionSummaryEntity with tile-board metrics JSON

**Files:**
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/SessionSummaryEntity.swift`
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Persistence/SessionSummaryTileBoardTests.swift`

Analogous to Task 5: add `tileBoardMetricsJSON: Data?` as a nullable field.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Persistence/SessionSummaryTileBoardTests.swift`:

```swift
import XCTest
@testable import MoraCore

final class SessionSummaryTileBoardTests: XCTestCase {
    func testDefaultTileBoardMetricsIsNil() {
        let s = SessionSummaryEntity(
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "L2.sh",
            durationSec: 1000,
            trialsTotal: 12,
            trialsCorrect: 10,
            escalated: false
        )
        XCTAssertNil(s.tileBoardMetricsJSON)
    }

    func testTileBoardMetricsRoundTrip() throws {
        let metrics = TileBoardMetrics(chainCount: 3, truncatedChainCount: 0, totalDropMisses: 2, autoFillCount: 0)
        let data = try JSONEncoder().encode(metrics)
        let s = SessionSummaryEntity(
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "L2.sh",
            durationSec: 1000,
            trialsTotal: 12,
            trialsCorrect: 11,
            escalated: false,
            tileBoardMetricsJSON: data
        )
        let back = try JSONDecoder().decode(TileBoardMetrics.self, from: XCTUnwrap(s.tileBoardMetricsJSON))
        XCTAssertEqual(back, metrics)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraCore && swift test --filter SessionSummaryTileBoardTests)`
Expected: FAIL with "extra argument 'tileBoardMetricsJSON' in call".

- [ ] **Step 3: Extend the entity**

Replace `Packages/MoraCore/Sources/MoraCore/Persistence/SessionSummaryEntity.swift` with:

```swift
import Foundation
import SwiftData

@Model
public final class SessionSummaryEntity {
    public var id: UUID
    public var date: Date
    public var sessionType: String
    public var targetSkillCode: String
    public var durationSec: Int
    public var trialsTotal: Int
    public var trialsCorrect: Int
    public var escalated: Bool
    public var tileBoardMetricsJSON: Data?

    public init(
        id: UUID = UUID(),
        date: Date,
        sessionType: String,
        targetSkillCode: String,
        durationSec: Int,
        trialsTotal: Int,
        trialsCorrect: Int,
        escalated: Bool,
        tileBoardMetricsJSON: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.sessionType = sessionType
        self.targetSkillCode = targetSkillCode
        self.durationSec = durationSec
        self.trialsTotal = trialsTotal
        self.trialsCorrect = trialsCorrect
        self.escalated = escalated
        self.tileBoardMetricsJSON = tileBoardMetricsJSON
    }
}
```

- [ ] **Step 4: Run full MoraCore tests**

Run: `(cd Packages/MoraCore && swift test)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Persistence/SessionSummaryEntity.swift Packages/MoraCore/Tests/MoraCoreTests/Persistence/SessionSummaryTileBoardTests.swift
git commit -m "core: extend SessionSummaryEntity with tile-board metrics JSON"
```

---

### Task 7: Verify schema migration end-to-end

**Files:**
- Test: `Packages/MoraCore/Tests/MoraCoreTests/Persistence/SchemaMigrationTests.swift`

Add a test that opens an in-memory `MoraModelContainer`, inserts a row using only the pre-migration initializer arguments (no tile-board fields), and verifies the defaults. Catches regressions where someone adds a non-nullable field without a default.

- [ ] **Step 1: Write the test**

Create `Packages/MoraCore/Tests/MoraCoreTests/Persistence/SchemaMigrationTests.swift`:

```swift
import XCTest
import SwiftData
@testable import MoraCore

final class SchemaMigrationTests: XCTestCase {
    @MainActor
    func testInMemoryContainerAcceptsLegacyInsert() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = PerformanceEntity(
            sessionId: UUID(),
            skillCode: "L2.sh",
            expected: "ship",
            heard: "ship",
            correct: true,
            l1InterferenceTag: nil,
            timestamp: Date()
        )
        ctx.insert(row)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<PerformanceEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.scaffoldLevel, 0)
    }

    @MainActor
    func testSessionSummaryLegacyInsert() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = SessionSummaryEntity(
            date: Date(),
            sessionType: "coreDecoder",
            targetSkillCode: "L2.sh",
            durationSec: 1000,
            trialsTotal: 12,
            trialsCorrect: 10,
            escalated: false
        )
        ctx.insert(row)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<SessionSummaryEntity>())
        XCTAssertNil(fetched.first?.tileBoardMetricsJSON)
    }
}
```

- [ ] **Step 2: Run the test**

Run: `(cd Packages/MoraCore && swift test --filter SchemaMigrationTests)`
Expected: PASS. If it fails with "missing argument," the entity defaults are incomplete — fix the default values in Task 5 or Task 6 until it passes.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraCore/Tests/MoraCoreTests/Persistence/SchemaMigrationTests.swift
git commit -m "core: verify additive tile-board schema via in-memory container"
```

---

## Phase 2 — MoraEngines pure logic

### Task 8: TilePoolPolicy

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TilePoolPolicy.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TilePoolPolicyTests.swift`

Pool policy governs what tiles the engine places in the pool for a trial.

- [ ] **Step 1: Write the failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TilePoolPolicyTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class TilePoolPolicyTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testBuildFromWordReturnsWordTilesPlusDistractors() {
        let word = Word(
            surface: "ship",
            graphemes: [g("sh"), g("i"), g("p")],
            phonemes: []
        )
        let distractors: Set<Grapheme> = [g("t"), g("a"), g("ch")]
        let policy = TilePoolPolicy.buildFromWord(word: word, extraDistractors: 2)
        let tiles = policy.resolve(distractorsPool: distractors)
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("sh"))))
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("i"))))
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("p"))))
        XCTAssertEqual(tiles.count, 5)
    }

    func testChangeModeAllowsReplacementsOfCorrectKind() {
        let vowelDistractors: Set<Grapheme> = [g("a"), g("e"), g("o"), g("u")]
        let policy = TilePoolPolicy.changeSlot(
            correct: g("o"),
            kind: .vowel,
            extraDistractors: 3
        )
        let tiles = policy.resolve(distractorsPool: vowelDistractors)
        XCTAssertTrue(tiles.contains(Tile(grapheme: g("o"))))
        XCTAssertTrue(tiles.allSatisfy { $0.kind == .vowel })
    }

    func testReducedToTwoReturnsExactlyTwoTiles() {
        let policy = TilePoolPolicy.reducedToTwo(correct: g("o"), distractor: g("a"))
        let tiles = policy.resolve(distractorsPool: [])
        XCTAssertEqual(Set(tiles), [Tile(grapheme: g("o")), Tile(grapheme: g("a"))])
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter TilePoolPolicyTests)`
Expected: FAIL with "cannot find 'TilePoolPolicy' in scope".

- [ ] **Step 3: Implement**

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TilePoolPolicy.swift`:

```swift
import Foundation
import MoraCore

/// Describes how the engine should compose a tile pool for a trial.
public enum TilePoolPolicy: Hashable, Sendable {
    case buildFromWord(word: Word, extraDistractors: Int)
    case changeSlot(correct: Grapheme, kind: TileKind, extraDistractors: Int)
    case reducedToTwo(correct: Grapheme, distractor: Grapheme)

    /// Resolve the policy against a pool of candidate distractor graphemes.
    /// Duplicates and the correct tile(s) are filtered out of the distractors
    /// so `resolve` never returns a pool with duplicate grapheme ids.
    public func resolve(distractorsPool: Set<Grapheme>) -> [Tile] {
        switch self {
        case let .buildFromWord(word, extra):
            let required = Set(word.graphemes)
            let pool = distractorsPool.subtracting(required)
            let chosen = Array(pool.sorted { $0.letters < $1.letters }.prefix(extra))
            return (Array(required) + chosen).map(Tile.init)
        case let .changeSlot(correct, kind, extra):
            var candidates = distractorsPool
                .filter { TileKind(grapheme: $0) == kind && $0 != correct }
                .sorted { $0.letters < $1.letters }
            candidates = Array(candidates.prefix(extra))
            return ([correct] + candidates).map(Tile.init)
        case let .reducedToTwo(correct, distractor):
            return [correct, distractor].map(Tile.init)
        }
    }
}
```

- [ ] **Step 4: Run to verify passing**

Run: `(cd Packages/MoraEngines && swift test --filter TilePoolPolicyTests)`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/TilePoolPolicy.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TilePoolPolicyTests.swift
git commit -m "engines: add TilePoolPolicy for build/change/reduced pools"
```

---

### Task 9: ChainScaffoldLadder

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/ChainScaffoldLadder.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/ChainScaffoldLadderTests.swift`

Pure function: given (slotMissCount, currentPolicy, correct, distractor) returns the next intervention. Spec §7.

- [ ] **Step 1: Write failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/ChainScaffoldLadderTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class ChainScaffoldLadderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testFirstMissIsBounceBack() {
        let step = ChainScaffoldLadder.next(missCount: 1, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .bounceBack)
    }

    func testSecondMissIsTTSHint() {
        let step = ChainScaffoldLadder.next(missCount: 2, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .ttsHint)
    }

    func testThirdMissReducesPool() {
        let step = ChainScaffoldLadder.next(missCount: 3, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .reducePool(correct: g("sh"), distractor: g("ch")))
    }

    func testFourthMissAutoFills() {
        let step = ChainScaffoldLadder.next(missCount: 4, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .autoFill)
    }

    func testBeyondFourthStaysAutoFill() {
        let step = ChainScaffoldLadder.next(missCount: 10, correct: g("sh"), distractor: g("ch"))
        XCTAssertEqual(step, .autoFill)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter ChainScaffoldLadderTests)`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/ChainScaffoldLadder.swift`:

```swift
import Foundation
import MoraCore

public enum ScaffoldStep: Hashable, Sendable {
    case bounceBack
    case ttsHint
    case reducePool(correct: Grapheme, distractor: Grapheme)
    case autoFill
}

/// Pure ladder: `missCount` is the number of consecutive wrong drops on one
/// slot during one trial. Returns the intervention to apply *next*.
public enum ChainScaffoldLadder {
    public static func next(
        missCount: Int,
        correct: Grapheme,
        distractor: Grapheme
    ) -> ScaffoldStep {
        switch missCount {
        case ...1: return .bounceBack
        case 2: return .ttsHint
        case 3: return .reducePool(correct: correct, distractor: distractor)
        default: return .autoFill
        }
    }
}
```

- [ ] **Step 4: Run to verify**

Run: `(cd Packages/MoraEngines && swift test --filter ChainScaffoldLadderTests)`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/ChainScaffoldLadder.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/ChainScaffoldLadderTests.swift
git commit -m "engines: add ChainScaffoldLadder for mis-drop interventions"
```

---

### Task 10: TileBoardState and TileBoardEvent

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardState.swift`
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEvent.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardStateTests.swift`

The seven states of spec §5, plus a minimal event enum the engine consumes.

- [ ] **Step 1: Write failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardStateTests.swift`:

```swift
import XCTest
@testable import MoraEngines

final class TileBoardStateTests: XCTestCase {
    func testStatesAreExhaustive() {
        let all: [TileBoardState] = [
            .preparing, .listening, .building, .completed, .speaking, .feedback, .transitioning,
        ]
        XCTAssertEqual(Set(all.map(\.debugTag)).count, all.count)
    }

    func testEventsAreExhaustiveAndHashable() {
        let set: Set<TileBoardEvent> = [
            .preparationFinished,
            .promptFinished,
            .tileLifted(tileID: "sh"),
            .tileDropped(slotIndex: 0, tileID: "sh"),
            .completionAnimationFinished,
            .utteranceRecorded,
            .feedbackDismissed,
            .transitionFinished,
        ]
        XCTAssertEqual(set.count, 8)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardStateTests)`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardState.swift`:

```swift
import Foundation

public enum TileBoardState: Hashable, Sendable {
    case preparing
    case listening
    case building
    case completed
    case speaking
    case feedback
    case transitioning

    public var debugTag: String {
        switch self {
        case .preparing: return "preparing"
        case .listening: return "listening"
        case .building: return "building"
        case .completed: return "completed"
        case .speaking: return "speaking"
        case .feedback: return "feedback"
        case .transitioning: return "transitioning"
        }
    }
}
```

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEvent.swift`:

```swift
import Foundation

/// Inputs the engine consumes from the UI and the TTS/ASR adapters.
public enum TileBoardEvent: Hashable, Sendable {
    case preparationFinished
    case promptFinished
    case tileLifted(tileID: String)
    case tileDropped(slotIndex: Int, tileID: String)
    case completionAnimationFinished
    case utteranceRecorded
    case feedbackDismissed
    case transitionFinished
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardStateTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardState.swift Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEvent.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardStateTests.swift
git commit -m "engines: add TileBoardState and TileBoardEvent"
```

---

### Task 11: Extend TrialRecording with build telemetry

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/TrialRecording.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TrialRecordingBuildFieldsTests.swift`

Add `buildAttempts: [BuildAttemptRecord]` and `scaffoldLevel: Int` with defaults that preserve the existing three-argument initializer for every existing call site.

- [ ] **Step 1: Write failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TrialRecordingBuildFieldsTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class TrialRecordingBuildFieldsTests: XCTestCase {
    func testLegacyInitializerStillWorks() {
        let r = TrialRecording(asr: ASRResult(transcript: "ship", confidence: 0.9), audio: .empty)
        XCTAssertEqual(r.buildAttempts, [])
        XCTAssertEqual(r.scaffoldLevel, 0)
    }

    func testNewInitializerCarriesBuildTelemetry() {
        let attempt = BuildAttemptRecord(
            slotIndex: 0,
            tileDropped: Grapheme(letters: "s"),
            wasCorrect: false,
            timestampOffset: 0.4
        )
        let r = TrialRecording(
            asr: ASRResult(transcript: "ship", confidence: 0.9),
            audio: .empty,
            buildAttempts: [attempt],
            scaffoldLevel: 2
        )
        XCTAssertEqual(r.buildAttempts.count, 1)
        XCTAssertEqual(r.scaffoldLevel, 2)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter TrialRecordingBuildFieldsTests)`
Expected: FAIL with "extra argument 'buildAttempts' in call".

- [ ] **Step 3: Extend the type**

Replace `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/TrialRecording.swift` with:

```swift
import Foundation
import MoraCore

public struct TrialRecording: Sendable, Hashable, Codable {
    public let asr: ASRResult
    public let audio: AudioClip
    public let buildAttempts: [BuildAttemptRecord]
    public let scaffoldLevel: Int

    public init(
        asr: ASRResult,
        audio: AudioClip,
        buildAttempts: [BuildAttemptRecord] = [],
        scaffoldLevel: Int = 0
    ) {
        self.asr = asr
        self.audio = audio
        self.buildAttempts = buildAttempts
        self.scaffoldLevel = scaffoldLevel
    }
}
```

- [ ] **Step 4: Full MoraEngines test run**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS. Existing call sites of `TrialRecording(asr:audio:)` still compile because the two new parameters default.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/TrialRecording.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TrialRecordingBuildFieldsTests.swift
git commit -m "engines: extend TrialRecording with build telemetry fields"
```

---

## Phase 3 — MoraEngines state machine and providers

### Task 12: TileBoardEngine — preparing / listening

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardTrial.swift`
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEnginePreparingListeningTests.swift`

Engine initialized for a single trial. `.preparing` → `.listening` on `preparationFinished`. `.listening` → `.building` on `promptFinished`. Tests drive events directly; TTS integration is UI-level.

- [ ] **Step 1: Write failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEnginePreparingListeningTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class TileBoardEnginePreparingListeningTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    private func ship() -> Word {
        Word(surface: "ship", graphemes: [g("sh"), g("i"), g("p")], phonemes: [])
    }

    func testEngineStartsInPreparingForBuildTrial() {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
        ])
        let engine = TileBoardEngine(trial: trial)
        XCTAssertEqual(engine.state, .preparing)
    }

    func testPreparationFinishedAdvancesToListening() {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: [])
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        XCTAssertEqual(engine.state, .listening)
    }

    func testPromptFinishedAdvancesToBuilding() {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: [])
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        XCTAssertEqual(engine.state, .building)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardEnginePreparingListeningTests)`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardTrial.swift`:

```swift
import Foundation
import MoraCore

/// One trial's inputs: either a fresh Build head or a Change on top of
/// already-placed tiles.
public enum TileBoardTrial: Hashable, Sendable {
    case build(target: BuildTarget, pool: [Tile])
    case change(target: ChangeTarget, lockedSlots: [Grapheme], pool: [Tile])

    public var expectedSlots: [Grapheme] {
        switch self {
        case let .build(target, _): return target.slots
        case let .change(target, _, _): return target.successor.graphemes
        }
    }

    public var activeSlotIndex: Int? {
        switch self {
        case .build: return nil
        case let .change(target, _, _): return target.changedIndex
        }
    }

    public var pool: [Tile] {
        switch self {
        case let .build(_, pool): return pool
        case let .change(_, _, pool): return pool
        }
    }

    public var word: Word {
        switch self {
        case let .build(target, _): return target.word
        case let .change(target, _, _): return target.successor
        }
    }
}
```

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift`:

```swift
import Foundation
import MoraCore
import Observation

@Observable
@MainActor
public final class TileBoardEngine {
    public private(set) var state: TileBoardState = .preparing
    public let trial: TileBoardTrial
    public private(set) var filled: [Grapheme?]
    public private(set) var buildAttempts: [BuildAttemptRecord] = []

    private let clock: () -> Date
    private let start: Date

    public init(trial: TileBoardTrial, clock: @escaping () -> Date = Date.init) {
        self.trial = trial
        self.clock = clock
        self.start = clock()
        switch trial {
        case let .build(target, _):
            self.filled = Array(repeating: nil as Grapheme?, count: target.slots.count)
        case let .change(_, lockedSlots, _):
            self.filled = lockedSlots.map { Optional($0) }
            if let active = trial.activeSlotIndex { self.filled[active] = nil }
        }
    }

    public func apply(_ event: TileBoardEvent) {
        switch (state, event) {
        case (.preparing, .preparationFinished):
            state = .listening
        case (.listening, .promptFinished):
            state = .building
        default:
            break // later tasks expand this
        }
    }
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardEnginePreparingListeningTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardTrial.swift Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEnginePreparingListeningTests.swift
git commit -m "engines: TileBoardEngine preparing and listening states"
```

---

### Task 13: TileBoardEngine — building with scaffold ladder

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEngineBuildingTests.swift`

In `.building`, each `.tileDropped(slotIndex, tileID)` either locks the slot (correct) or increments a per-slot miss count and returns the intervention from `ChainScaffoldLadder`. The engine exposes the current pool (so Reduce-Pool actually narrows it) and current hint state so the UI can render.

- [ ] **Step 1: Write failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEngineBuildingTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class TileBoardEngineBuildingTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    private func ship() -> Word {
        Word(surface: "ship", graphemes: [g("sh"), g("i"), g("p")], phonemes: [])
    }

    private func primedEngine(pool: [Tile]) -> TileBoardEngine {
        let trial = TileBoardTrial.build(target: BuildTarget(word: ship()), pool: pool)
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        return engine
    }

    func testCorrectDropLocksSlotAndRecordsAttempt() {
        let engine = primedEngine(pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        XCTAssertEqual(engine.filled[0], g("sh"))
        XCTAssertEqual(engine.buildAttempts.last?.wasCorrect, true)
    }

    func testWrongDropLeavesSlotEmptyAndRecordsMiss() {
        let engine = primedEngine(pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "ch"))
        XCTAssertNil(engine.filled[0])
        XCTAssertEqual(engine.buildAttempts.last?.wasCorrect, false)
        XCTAssertEqual(engine.slotMissCount(for: 0), 1)
        XCTAssertEqual(engine.lastIntervention, .bounceBack)
    }

    func testSecondMissOnSameSlotRaisesTTSHint() {
        let engine = primedEngine(pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("t")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "ch"))
        engine.apply(.tileDropped(slotIndex: 0, tileID: "t"))
        XCTAssertEqual(engine.lastIntervention, .ttsHint)
        XCTAssertTrue(engine.ttsHintIssued)
    }

    func testFourthMissAutoFillsSlotAndRaisesScaffoldLevel() {
        let engine = primedEngine(pool: [
            Tile(grapheme: g("sh")), Tile(grapheme: g("ch")), Tile(grapheme: g("t")),
            Tile(grapheme: g("k")), Tile(grapheme: g("i")), Tile(grapheme: g("p")),
        ])
        for bad in ["ch", "t", "k", "ch"] {
            engine.apply(.tileDropped(slotIndex: 0, tileID: bad))
        }
        XCTAssertEqual(engine.filled[0], g("sh"))
        XCTAssertTrue(engine.autoFilled)
        XCTAssertEqual(engine.scaffoldLevel, 4)
    }

    func testCompletingAllSlotsAdvancesToCompleted() {
        let engine = primedEngine(pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))])
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        engine.apply(.tileDropped(slotIndex: 1, tileID: "i"))
        engine.apply(.tileDropped(slotIndex: 2, tileID: "p"))
        XCTAssertEqual(engine.state, .completed)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardEngineBuildingTests)`
Expected: FAIL (missing `slotMissCount`, `lastIntervention`, etc.).

- [ ] **Step 3: Extend engine**

Replace `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift` with:

```swift
import Foundation
import MoraCore
import Observation

@Observable
@MainActor
public final class TileBoardEngine {
    public private(set) var state: TileBoardState = .preparing
    public let trial: TileBoardTrial
    public private(set) var filled: [Grapheme?]
    public private(set) var buildAttempts: [BuildAttemptRecord] = []
    public private(set) var scaffoldLevel: Int = 0
    public private(set) var ttsHintIssued: Bool = false
    public private(set) var poolReducedToTwo: Bool = false
    public private(set) var autoFilled: Bool = false
    public private(set) var lastIntervention: ScaffoldStep?
    public private(set) var pool: [Tile]

    private var slotMisses: [Int: Int] = [:]
    private let clock: () -> Date
    private let start: Date

    public init(trial: TileBoardTrial, clock: @escaping () -> Date = Date.init) {
        self.trial = trial
        self.clock = clock
        self.start = clock()
        self.pool = trial.pool
        switch trial {
        case let .build(target, _):
            self.filled = Array(repeating: nil as Grapheme?, count: target.slots.count)
        case let .change(_, lockedSlots, _):
            self.filled = lockedSlots.map { Optional($0) }
            if let active = trial.activeSlotIndex { self.filled[active] = nil }
        }
    }

    public func slotMissCount(for slot: Int) -> Int { slotMisses[slot] ?? 0 }

    public func apply(_ event: TileBoardEvent) {
        switch (state, event) {
        case (.preparing, .preparationFinished):
            state = .listening
        case (.listening, .promptFinished):
            state = .building
        case (.building, let .tileDropped(slotIndex, tileID)):
            handleDrop(slotIndex: slotIndex, tileID: tileID)
        default:
            break
        }
    }

    private func handleDrop(slotIndex: Int, tileID: String) {
        guard filled.indices.contains(slotIndex), filled[slotIndex] == nil else { return }
        if let active = trial.activeSlotIndex, active != slotIndex { return }
        let expected = trial.expectedSlots[slotIndex]
        let dropped = Grapheme(letters: tileID)
        let offset = clock().timeIntervalSince(start)
        let correct = dropped == expected
        buildAttempts.append(BuildAttemptRecord(
            slotIndex: slotIndex,
            tileDropped: dropped,
            wasCorrect: correct,
            timestampOffset: offset
        ))
        if correct {
            filled[slotIndex] = expected
            lastIntervention = nil
            if filled.allSatisfy({ $0 != nil }) { state = .completed }
            return
        }
        let nextMisses = (slotMisses[slotIndex] ?? 0) + 1
        slotMisses[slotIndex] = nextMisses
        let distractor = pool.first(where: { $0.grapheme != expected })?.grapheme ?? expected
        let step = ChainScaffoldLadder.next(missCount: nextMisses, correct: expected, distractor: distractor)
        apply(step: step, slotIndex: slotIndex, expected: expected)
    }

    private func apply(step: ScaffoldStep, slotIndex: Int, expected: Grapheme) {
        lastIntervention = step
        scaffoldLevel = max(scaffoldLevel, Self.levelFor(step: step))
        switch step {
        case .bounceBack:
            break
        case .ttsHint:
            ttsHintIssued = true
        case let .reducePool(correct, distractor):
            poolReducedToTwo = true
            pool = [Tile(grapheme: correct), Tile(grapheme: distractor)]
        case .autoFill:
            autoFilled = true
            filled[slotIndex] = expected
            if filled.allSatisfy({ $0 != nil }) { state = .completed }
        }
    }

    private static func levelFor(step: ScaffoldStep) -> Int {
        switch step {
        case .bounceBack: return 1
        case .ttsHint: return 2
        case .reducePool: return 3
        case .autoFill: return 4
        }
    }
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardEngineBuildingTests)`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEngineBuildingTests.swift
git commit -m "engines: TileBoardEngine building, scaffold ladder, completion"
```

---

### Task 14: TileBoardEngine — tail states and trial result

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEngineTailStatesTests.swift`

`.completed` → `.speaking` on `.completionAnimationFinished`. `.speaking` → `.feedback` on `.utteranceRecorded`. `.feedback` → `.transitioning` on `.feedbackDismissed`. `.transitioning` emits a final `result()` that downstream can consume.

- [ ] **Step 1: Failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEngineTailStatesTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

@MainActor
final class TileBoardEngineTailStatesTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    private func completedEngine() -> TileBoardEngine {
        let word = Word(surface: "ship", graphemes: [g("sh"), g("i"), g("p")], phonemes: [])
        let trial = TileBoardTrial.build(
            target: BuildTarget(word: word),
            pool: [Tile(grapheme: g("sh")), Tile(grapheme: g("i")), Tile(grapheme: g("p"))]
        )
        let engine = TileBoardEngine(trial: trial)
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        engine.apply(.tileDropped(slotIndex: 0, tileID: "sh"))
        engine.apply(.tileDropped(slotIndex: 1, tileID: "i"))
        engine.apply(.tileDropped(slotIndex: 2, tileID: "p"))
        return engine
    }

    func testCompletionAnimationAdvancesToSpeaking() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        XCTAssertEqual(engine.state, .speaking)
    }

    func testUtteranceRecordedAdvancesToFeedback() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        engine.apply(.utteranceRecorded)
        XCTAssertEqual(engine.state, .feedback)
    }

    func testFeedbackDismissedAdvancesToTransitioning() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        engine.apply(.utteranceRecorded)
        engine.apply(.feedbackDismissed)
        XCTAssertEqual(engine.state, .transitioning)
    }

    func testResultAfterCleanRunHasZeroScaffold() {
        let engine = completedEngine()
        engine.apply(.completionAnimationFinished)
        engine.apply(.utteranceRecorded)
        engine.apply(.feedbackDismissed)
        let result = engine.result
        XCTAssertEqual(result.scaffoldLevel, 0)
        XCTAssertEqual(result.buildAttempts.count, 3)
        XCTAssertEqual(result.word.surface, "ship")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardEngineTailStatesTests)`
Expected: FAIL.

- [ ] **Step 3: Extend engine**

Append to `TileBoardEngine`'s `apply(_:)` switch and add a `result` computed property. Patch the file by replacing the `apply` method and adding `TileBoardTrialResult` + `result`:

```swift
    public func apply(_ event: TileBoardEvent) {
        switch (state, event) {
        case (.preparing, .preparationFinished):
            state = .listening
        case (.listening, .promptFinished):
            state = .building
        case (.building, let .tileDropped(slotIndex, tileID)):
            handleDrop(slotIndex: slotIndex, tileID: tileID)
        case (.completed, .completionAnimationFinished):
            state = .speaking
        case (.speaking, .utteranceRecorded):
            state = .feedback
        case (.feedback, .feedbackDismissed):
            state = .transitioning
        default:
            break
        }
    }

    public var result: TileBoardTrialResult {
        TileBoardTrialResult(
            word: trial.word,
            buildAttempts: buildAttempts,
            scaffoldLevel: scaffoldLevel,
            ttsHintIssued: ttsHintIssued,
            poolReducedToTwo: poolReducedToTwo,
            autoFilled: autoFilled
        )
    }
```

Then create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardTrialResult.swift`:

```swift
import Foundation
import MoraCore

public struct TileBoardTrialResult: Hashable, Sendable {
    public let word: Word
    public let buildAttempts: [BuildAttemptRecord]
    public let scaffoldLevel: Int
    public let ttsHintIssued: Bool
    public let poolReducedToTwo: Bool
    public let autoFilled: Bool
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter TileBoardEngineTailStatesTests)`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardEngine.swift Packages/MoraEngines/Sources/MoraEngines/TileBoard/TileBoardTrialResult.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/TileBoardEngineTailStatesTests.swift
git commit -m "engines: TileBoardEngine tail states and trial result"
```

---

### Task 15: WordChainProvider protocol and in-memory provider

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/WordChainProvider.swift`
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/InMemoryWordChainProvider.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/InMemoryWordChainProviderTests.swift`

A minimal in-memory provider for tests returns pre-built chains for a given `(target, masteredSet)`. The real `LibraryFirstWordChainProvider` follows in Task 16.

- [ ] **Step 1: Failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/InMemoryWordChainProviderTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class InMemoryWordChainProviderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testProviderReturnsInjectedPhase() throws {
        let inventory: Set<Grapheme> = Set(["c", "a", "t", "u", "h", "sh", "i", "p", "o", "f", "d", "w", "m", "s"].map { Grapheme(letters: $0) })
        let warmupHead = Word(surface: "cat", graphemes: [g("c"), g("a"), g("t")], phonemes: [])
        let warmup = try XCTUnwrap(WordChain(
            role: .warmup,
            head: BuildTarget(word: warmupHead),
            successorWords: [
                Word(surface: "cut", graphemes: [g("c"), g("u"), g("t")], phonemes: []),
                Word(surface: "hut", graphemes: [g("h"), g("u"), g("t")], phonemes: []),
                Word(surface: "hat", graphemes: [g("h"), g("a"), g("t")], phonemes: []),
            ],
            inventory: inventory
        ))
        let provider = InMemoryWordChainProvider(phase: [warmup, warmup, warmup])  // stubbed intro/mixed
        let phase = try provider.generatePhase(
            target: Grapheme(letters: "sh"),
            masteredSet: inventory
        )
        XCTAssertEqual(phase.count, 3)
    }

    func testProviderThrowsWhenUnderThreeChains() {
        let provider = InMemoryWordChainProvider(phase: [])
        XCTAssertThrowsError(try provider.generatePhase(
            target: Grapheme(letters: "sh"),
            masteredSet: []
        ))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter InMemoryWordChainProviderTests)`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/WordChainProvider.swift`:

```swift
import Foundation
import MoraCore

public struct WordChainProviderError: Error, Hashable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

public protocol WordChainProvider: Sendable {
    func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain]
}
```

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/InMemoryWordChainProvider.swift`:

```swift
import Foundation
import MoraCore

/// Test-only provider that returns a fixed phase regardless of inputs. Use
/// from MoraTesting fixtures and unit tests.
public struct InMemoryWordChainProvider: WordChainProvider {
    public let phase: [WordChain]

    public init(phase: [WordChain]) {
        self.phase = phase
    }

    public func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain] {
        guard phase.count == 3 else {
            throw WordChainProviderError("InMemoryWordChainProvider requires exactly 3 chains, has \(phase.count)")
        }
        return phase
    }
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter InMemoryWordChainProviderTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/WordChainProvider.swift Packages/MoraEngines/Sources/MoraEngines/TileBoard/InMemoryWordChainProvider.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/InMemoryWordChainProviderTests.swift
git commit -m "engines: add WordChainProvider protocol and in-memory impl"
```

---

### Task 16: LibraryFirstWordChainProvider

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/TileBoard/LibraryFirstWordChainProvider.swift`
- Create: `Packages/MoraEngines/Sources/MoraEngines/Resources/WordChainLibrary/sh.json`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/LibraryFirstWordChainProviderTests.swift`

Library-backed provider: reads a JSON library file per target, picks three chains (warmup, target-intro, mixed). If the library is under-populated, throws `WordChainProviderError` with a truncation note — template fallback is spec §14 open-question content, not in scope for v1's first merge.

- [ ] **Step 1: Create the library fixture**

Create `Packages/MoraEngines/Sources/MoraEngines/Resources/WordChainLibrary/sh.json`:

```json
{
  "target": "sh",
  "warmup": [
    {
      "head": { "surface": "cat", "graphemes": ["c", "a", "t"] },
      "successors": [
        { "surface": "cut", "graphemes": ["c", "u", "t"] },
        { "surface": "hut", "graphemes": ["h", "u", "t"] },
        { "surface": "hat", "graphemes": ["h", "a", "t"] }
      ]
    }
  ],
  "targetIntro": [
    {
      "head": { "surface": "ship", "graphemes": ["sh", "i", "p"] },
      "successors": [
        { "surface": "shop", "graphemes": ["sh", "o", "p"] },
        { "surface": "shot", "graphemes": ["sh", "o", "t"] },
        { "surface": "shut", "graphemes": ["sh", "u", "t"] }
      ]
    }
  ],
  "mixedApplication": [
    {
      "head": { "surface": "fish", "graphemes": ["f", "i", "sh"] },
      "successors": [
        { "surface": "dish", "graphemes": ["d", "i", "sh"] },
        { "surface": "wish", "graphemes": ["w", "i", "sh"] },
        { "surface": "wash", "graphemes": ["w", "a", "sh"] }
      ]
    }
  ]
}
```

Make sure `project.yml` already declares `Packages/MoraEngines/Sources/MoraEngines/Resources` as a resources directory (it does today — check `Packages/MoraEngines/Package.swift` for `resources: [.process("Resources")]`). No project changes needed.

- [ ] **Step 2: Write failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/LibraryFirstWordChainProviderTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class LibraryFirstWordChainProviderTests: XCTestCase {
    private func g(_ s: String) -> Grapheme { Grapheme(letters: s) }

    func testGenerateShPhaseFromBundledLibrary() throws {
        let inv = Set(["c", "a", "t", "u", "h", "sh", "i", "o", "p", "f", "d", "w", "m", "s"].map { Grapheme(letters: $0) })
        let provider = LibraryFirstWordChainProvider()
        let phase = try provider.generatePhase(target: g("sh"), masteredSet: inv)
        XCTAssertEqual(phase.count, 3)
        XCTAssertEqual(phase[0].role, .warmup)
        XCTAssertEqual(phase[1].role, .targetIntro)
        XCTAssertEqual(phase[2].role, .mixedApplication)
        XCTAssertEqual(phase[0].allWords.first?.surface, "cat")
        XCTAssertEqual(phase[1].allWords.first?.surface, "ship")
        XCTAssertEqual(phase[2].allWords.first?.surface, "fish")
    }

    func testMissingLibraryThrows() {
        let provider = LibraryFirstWordChainProvider()
        XCTAssertThrowsError(try provider.generatePhase(
            target: g("zz"),
            masteredSet: [g("zz")]
        ))
    }
}
```

- [ ] **Step 3: Implement the provider**

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/LibraryFirstWordChainProvider.swift`:

```swift
import Foundation
import MoraCore

public struct LibraryFirstWordChainProvider: WordChainProvider {
    private struct LibraryFile: Decodable {
        struct WordLit: Decodable {
            let surface: String
            let graphemes: [String]
            func toWord() -> Word {
                Word(
                    surface: surface,
                    graphemes: graphemes.map { Grapheme(letters: $0) },
                    phonemes: []
                )
            }
        }
        struct ChainLit: Decodable {
            let head: WordLit
            let successors: [WordLit]
        }
        let target: String
        let warmup: [ChainLit]
        let targetIntro: [ChainLit]
        let mixedApplication: [ChainLit]
    }

    private let bundle: Bundle

    public init(bundle: Bundle = .module) {
        self.bundle = bundle
    }

    public func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain] {
        guard let url = bundle.url(forResource: target.letters, withExtension: "json", subdirectory: "WordChainLibrary") else {
            throw WordChainProviderError("No chain library bundled for target '\(target.letters)'")
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(LibraryFile.self, from: data)
        let inventory = masteredSet.union([target])
        let warmup = try pickChain(file.warmup, role: .warmup, inventory: inventory, target: target)
        let intro = try pickChain(file.targetIntro, role: .targetIntro, inventory: inventory, target: target)
        let mixed = try pickChain(file.mixedApplication, role: .mixedApplication, inventory: inventory, target: target)
        return [warmup, intro, mixed]
    }

    private func pickChain(_ candidates: [LibraryFile.ChainLit], role: ChainRole, inventory: Set<Grapheme>, target: Grapheme) throws -> WordChain {
        for candidate in candidates {
            let chain = WordChain(
                role: role,
                head: BuildTarget(word: candidate.head.toWord()),
                successorWords: candidate.successors.map { $0.toWord() },
                inventory: inventory
            )
            if let chain { return chain }
        }
        throw WordChainProviderError("No valid \(role.rawValue) chain for target '\(target.letters)' in the library")
    }
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter LibraryFirstWordChainProviderTests)`
Expected: PASS (2 tests). If the test fails with "Bundle has no module," verify `Packages/MoraEngines/Package.swift` has `resources: [.process("Resources")]` on the MoraEngines target.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/TileBoard/LibraryFirstWordChainProvider.swift Packages/MoraEngines/Sources/MoraEngines/Resources/WordChainLibrary/sh.json Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/LibraryFirstWordChainProviderTests.swift
git commit -m "engines: add LibraryFirstWordChainProvider and sh.json fixture"
```

---

## Phase 4 — Orchestrator wiring

### Task 17: Extend OrchestratorEvent with tile-board trial completion

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/OrchestratorEventTileBoardShapeTests.swift`

Add `.tileBoardTrialCompleted(TrialRecording)`, `.chainFinished(ChainRole)`, `.phaseFinished(TileBoardMetrics)` to `OrchestratorEvent`. Keep existing cases intact.

- [ ] **Step 1: Failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/OrchestratorEventTileBoardShapeTests.swift`:

```swift
import XCTest
import MoraCore
@testable import MoraEngines

final class OrchestratorEventTileBoardShapeTests: XCTestCase {
    func testTileBoardEventsAreDistinct() {
        let recording = TrialRecording(asr: ASRResult(transcript: "ship", confidence: 0.9), audio: .empty)
        let events: Set<OrchestratorEvent> = [
            .tileBoardTrialCompleted(recording),
            .chainFinished(.warmup),
            .phaseFinished(TileBoardMetrics(chainCount: 3)),
        ]
        XCTAssertEqual(events.count, 3)
    }
}
```

- [ ] **Step 2: Run**

Run: `(cd Packages/MoraEngines && swift test --filter OrchestratorEventTileBoardShapeTests)`
Expected: FAIL.

- [ ] **Step 3: Extend `OrchestratorEvent`**

Open `Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift`. Add three cases to `OrchestratorEvent`:

```swift
    case tileBoardTrialCompleted(TrialRecording)
    case chainFinished(ChainRole)
    case phaseFinished(TileBoardMetrics)
```

Make sure the enum remains `Hashable`; `TileBoardMetrics` and `ChainRole` are both `Hashable` + `Sendable`, so this compiles.

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS across the full MoraEngines suite.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/OrchestratorEventTileBoardShapeTests.swift
git commit -m "engines: add tile-board events to OrchestratorEvent"
```

---

### Task 18a: Add WordChainProvider dependency to SessionOrchestrator

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorFullTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorPhasesTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FullADayIntegrationTests.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorPronunciationTests.swift`

Replace the `words: [DecodeWord]` initializer parameter with `chainProvider: any WordChainProvider`. The decoding phase still does nothing at the end of this task (it immediately jumps to `.shortSentences` because the chain loop isn't wired yet) — behavior change comes in 18b. The point of 18a is to land the API change, migrate every call site, and keep the full suite green in its migrated shape.

- [ ] **Step 1: Update `SessionOrchestrator.init`**

Open `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`. Replace the `public let words: [DecodeWord]` stored property and its init parameter with:

```swift
    public let chainProvider: any WordChainProvider
```

Update the initializer signature (remove `words:`, add `chainProvider:`):

```swift
    public init(
        target: Target,
        taughtGraphemes: Set<Grapheme>,
        warmupOptions: [Grapheme],
        chainProvider: any WordChainProvider,
        sentences: [DecodeSentence],
        assessment: AssessmentEngine,
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.target = target
        self.taughtGraphemes = taughtGraphemes
        self.warmupOptions = warmupOptions
        self.chainProvider = chainProvider
        self.sentences = sentences
        self.assessment = assessment
        self.clock = clock
    }
```

In `transitionTo(_:)`, replace the `case .decoding where words.isEmpty:` arm with:

```swift
        case .decoding:
            // 18b wires the chain-driven decoding. For now, immediately
            // advance so the orchestrator does not stall.
            transitionTo(.shortSentences)
```

Delete the `handleDecodingHeard(recording:)` and `handleDecodingManual(correct:)` bodies — their old content consumed `words[wordIndex]`, which no longer exists. Replace both with a single no-op that will be extended in 18b/18c:

```swift
    private func handleDecodingHeard(recording: TrialRecording) async {
        // Wired in 18b/18c.
    }

    private func handleDecodingManual(correct: Bool) {
        // Wired in 18b/18c.
    }
```

- [ ] **Step 2: Migrate every test call site**

Across `SessionOrchestratorFullTests.swift`, `SessionOrchestratorPhasesTests.swift`, `FullADayIntegrationTests.swift`, `SessionOrchestratorPronunciationTests.swift`, `AssessmentEngineRecordingTests.swift`, and any other file that constructs a `SessionOrchestrator`:

Replace:

```swift
            words: [
                dw("ship", graphemes: ["sh", "i", "p"], phonemes: ["ʃ", "ɪ", "p"]),
                // ...
            ],
```

with:

```swift
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
```

Delete any `dw` / `DecodeWord` helpers that are no longer referenced. (ShortSentences tests keep `ds` / `DecodeSentence` — those stay.)

Tests that drive the Decoding phase via `handle(.answerHeard(...))` / `handle(.answerManual(...))` will now see the phase skip past decoding to shortSentences (because 18b is not yet done). Mark those specific assertions `XCTSkip("Tile-board decoding wiring lands in 18b")` temporarily — they come back online at the end of 18c.

- [ ] **Step 3: Run full MoraEngines tests**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS. Skipped tests show as `SKIPPED`, not `FAILED`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "engines: replace SessionOrchestrator.words with WordChainProvider dependency"
```

---

### Task 18b: Load chains on .decoding entry

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/SessionOrchestratorChainLoadingTests.swift`

On entering `.decoding`, the orchestrator calls `chainProvider.generatePhase(...)` and stores the result. Expose `currentTileBoardEngine`, `currentChainRole`, `chainPipStates` so the UI can render. Decoding still advances to `.shortSentences` at the end — the actual trial loop is 18c.

- [ ] **Step 1: Failing test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/SessionOrchestratorChainLoadingTests.swift`:

```swift
import XCTest
import MoraCore
import MoraTesting
@testable import MoraEngines

@MainActor
final class SessionOrchestratorChainLoadingTests: XCTestCase {
    private func makeOrchestrator() -> SessionOrchestrator {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(grapheme: .init(letters: "sh"), phoneme: .init(ipa: "ʃ"))
        )
        return SessionOrchestrator(
            target: Target(weekStart: Date(), skill: skill),
            taughtGraphemes: FixtureWordChains.shInventory(),
            warmupOptions: [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")],
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
            sentences: [],
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
    }

    func testEnteringDecodingLoadsThreeChains() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .decoding)
        XCTAssertEqual(o.pendingChains.count, 3)
        XCTAssertEqual(o.currentChainRole, .warmup)
        XCTAssertNotNil(o.currentTileBoardEngine)
        XCTAssertEqual(o.chainPipStates.count, 12)
        XCTAssertTrue(o.chainPipStates.allSatisfy { $0 == .pending || $0 == .active })
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter SessionOrchestratorChainLoadingTests)`
Expected: FAIL — `pendingChains`, `currentChainRole`, etc. do not exist yet.

- [ ] **Step 3: Implement**

Add to `SessionOrchestrator`:

```swift
    public private(set) var pendingChains: [WordChain] = []
    public private(set) var completedTrialCount: Int = 0
    private var currentTrialInChain: Int = 0
    private var phaseMetrics: TileBoardMetrics = TileBoardMetrics()

    public var currentChainRole: ChainRole {
        pendingChains.first?.role ?? .mixedApplication
    }

    public var chainPipStates: [ChainPipStateOrchestratorValue] {
        // Returns 12 states, one per trial across the three chains.
        var states: [ChainPipStateOrchestratorValue] = []
        let done = completedTrialCount
        let activeIndex = done  // the pip currently being trialed
        for i in 0..<12 {
            if i < done { states.append(.done) }
            else if i == activeIndex { states.append(.active) }
            else { states.append(.pending) }
        }
        return states
    }

    public var currentTileBoardEngine: TileBoardEngine? {
        guard let chain = pendingChains.first else { return nil }
        return makeEngine(for: currentTrialInChain, in: chain)
    }

    private func makeEngine(for trialIndex: Int, in chain: WordChain) -> TileBoardEngine {
        if trialIndex == 0 {
            let pool = TilePoolPolicy.buildFromWord(word: chain.head.word, extraDistractors: 2)
                .resolve(distractorsPool: taughtGraphemes)
            return TileBoardEngine(trial: .build(target: chain.head, pool: pool))
        } else {
            let change = chain.successors[trialIndex - 1]
            let lockedSlots = change.predecessor.graphemes
            let pool = TilePoolPolicy
                .changeSlot(
                    correct: change.newGrapheme,
                    kind: TileKind(grapheme: change.newGrapheme),
                    extraDistractors: 3
                )
                .resolve(distractorsPool: taughtGraphemes)
            return TileBoardEngine(trial: .change(target: change, lockedSlots: lockedSlots, pool: pool))
        }
    }
```

Create `Packages/MoraEngines/Sources/MoraEngines/TileBoard/ChainPipStateOrchestratorValue.swift`:

```swift
import Foundation

/// Mirror of `ChainPipState` that lives in MoraUI — exposed from the engine
/// tier so the UI does not have to own its own computation. The two are
/// structurally identical; the duplication exists so MoraEngines does not
/// have to import SwiftUI.
public enum ChainPipStateOrchestratorValue: Hashable, Sendable {
    case pending
    case active
    case done
}
```

Update `transitionTo` so `.decoding` entry loads the chains:

```swift
        case .decoding:
            do {
                pendingChains = try chainProvider.generatePhase(
                    target: target.grapheme ?? Grapheme(letters: ""),
                    masteredSet: taughtGraphemes
                )
                phaseMetrics = TileBoardMetrics(chainCount: pendingChains.count)
                currentTrialInChain = 0
                completedTrialCount = 0
            } catch {
                // Content gap: fall through to shortSentences so the session
                // does not stall. Log via metrics.
                phaseMetrics.truncatedChainCount = 3
                transitionTo(.shortSentences)
            }
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraEngines && swift test --filter SessionOrchestratorChainLoadingTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "engines: load tile-board chains on .decoding entry"
```

---

### Task 18c: Consume tile-board trial results and advance the phase

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift`
- Test: `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/SessionOrchestratorTileBoardFlowTests.swift`

`consumeTileBoardTrial(_:)` records the trial, advances the chain pointer, emits `.chainFinished(role)` at chain boundaries, emits `.phaseFinished(metrics)` after the third chain, and transitions to `.shortSentences`. Un-skip the existing decoding tests that 18a skipped.

- [ ] **Step 1: Failing integration test**

Create `Packages/MoraEngines/Tests/MoraEnginesTests/TileBoard/SessionOrchestratorTileBoardFlowTests.swift`:

```swift
import XCTest
import MoraCore
import MoraTesting
@testable import MoraEngines

@MainActor
final class SessionOrchestratorTileBoardFlowTests: XCTestCase {
    private func makeOrchestrator() -> SessionOrchestrator {
        let skill = Skill(
            code: "sh_onset", level: .l3, displayName: "sh",
            graphemePhoneme: .init(grapheme: .init(letters: "sh"), phoneme: .init(ipa: "ʃ"))
        )
        return SessionOrchestrator(
            target: Target(weekStart: Date(), skill: skill),
            taughtGraphemes: FixtureWordChains.shInventory(),
            warmupOptions: [.init(letters: "s"), .init(letters: "sh"), .init(letters: "ch")],
            chainProvider: InMemoryWordChainProvider(phase: FixtureWordChains.shPhase()),
            sentences: [],
            assessment: AssessmentEngine(l1Profile: JapaneseL1Profile()),
            clock: { Date(timeIntervalSince1970: 0) }
        )
    }

    private func clean(_ word: Word) -> TileBoardTrialResult {
        TileBoardTrialResult(
            word: word,
            buildAttempts: [],
            scaffoldLevel: 0,
            ttsHintIssued: false,
            poolReducedToTwo: false,
            autoFilled: false
        )
    }

    func testTwelveCleanTrialsAdvanceToShortSentences() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        XCTAssertEqual(o.phase, .decoding)
        for chain in FixtureWordChains.shPhase() {
            for word in chain.allWords {
                o.consumeTileBoardTrial(clean(word))
            }
        }
        XCTAssertEqual(o.phase, .shortSentences)
        XCTAssertEqual(o.trials.count, 12)
        XCTAssertEqual(o.completedTrialCount, 12)
    }

    func testChainBoundaryEmitsChainFinished() async {
        let o = makeOrchestrator()
        await o.start()
        await o.handle(.warmupTap(.init(letters: "sh")))
        await o.handle(.advance)
        var observedEvents: [OrchestratorEvent] = []
        o.onTileBoardEvent = { event in observedEvents.append(event) }
        for word in FixtureWordChains.shPhase()[0].allWords {
            o.consumeTileBoardTrial(clean(word))
        }
        XCTAssertTrue(observedEvents.contains(.chainFinished(.warmup)))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter SessionOrchestratorTileBoardFlowTests)`
Expected: FAIL — `consumeTileBoardTrial` and `onTileBoardEvent` do not exist.

- [ ] **Step 3: Implement**

Add to `SessionOrchestrator`:

```swift
    /// Callback for tile-board phase events. Wired up by the UI so that
    /// chain-finished and phase-finished transitions can trigger scene
    /// transitions without polling state.
    public var onTileBoardEvent: ((OrchestratorEvent) -> Void)?

    public func consumeTileBoardTrial(_ result: TileBoardTrialResult) {
        guard let chain = pendingChains.first else { return }

        // Record a TrialAssessment using the existing AssessmentEngine shape.
        let assessmentRecording = TrialRecording(
            asr: ASRResult(transcript: result.word.surface, confidence: 1.0),
            audio: .empty,
            buildAttempts: result.buildAttempts,
            scaffoldLevel: result.scaffoldLevel
        )
        let trial = TrialAssessment(
            expected: result.word.surface,
            heard: result.word.surface,
            correct: true,
            confidence: assessmentRecording.asr.confidence,
            l1InterferenceTag: nil
        )
        trials.append(trial)
        phaseMetrics.totalDropMisses += result.buildAttempts.filter { !$0.wasCorrect }.count
        if result.autoFilled { phaseMetrics.autoFillCount += 1 }

        onTileBoardEvent?(.tileBoardTrialCompleted(assessmentRecording))
        completedTrialCount += 1
        currentTrialInChain += 1

        if currentTrialInChain > chain.successors.count {
            // Chain finished.
            onTileBoardEvent?(.chainFinished(chain.role))
            pendingChains.removeFirst()
            currentTrialInChain = 0
            if pendingChains.isEmpty {
                onTileBoardEvent?(.phaseFinished(phaseMetrics))
                transitionTo(.shortSentences)
            }
        }
    }
```

**Note:** the exact `TrialAssessment` field names above may differ from the actual type in the repo. Read `Packages/MoraEngines/Sources/MoraEngines/SessionOrchestrator.swift` for the canonical initializer (search `TrialAssessment(`) and match it. If the current type does not track `confidence` or `l1InterferenceTag`, drop those arguments. This mapping exists only to record a trial with the right `correct` / `expected` / `heard` values.

Remove the `transitionTo(.shortSentences)` fallback inside the `.decoding` branch of `transitionTo` so the normal path reaches `.shortSentences` only through `consumeTileBoardTrial`. Keep the truncation-fallback path on chain-generation error.

Finally, un-skip the tests that 18a skipped: in each `XCTSkip("Tile-board decoding wiring lands in 18b")`, migrate the test to use `consumeTileBoardTrial(_:)` or delete the assertion about old-style decoding trials. Confirm all tests that used to pass three `.answerManual(correct: true)` now pass 12 `consumeTileBoardTrial(clean(word))` calls (one per word from `FixtureWordChains.shPhase()`).

- [ ] **Step 4: Run full MoraEngines tests**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "engines: consume tile-board trials and advance through decoding"
```

---

## Phase 5 — MoraTesting

### Task 19: FakeTileBoardEngine and FixtureWordChains

**Files:**
- Create: `Packages/MoraTesting/Sources/MoraTesting/FakeTileBoardEngine.swift`
- Create: `Packages/MoraTesting/Sources/MoraTesting/FixtureWordChains.swift`
- Test: `Packages/MoraTesting/Tests/MoraTestingTests/FakeTileBoardEngineTests.swift`

`FakeTileBoardEngine` records events in order and lets tests assert the sequence. `FixtureWordChains` exposes one valid chain per role for target `sh` — used by UI tests and integration tests throughout the repo.

- [ ] **Step 1: Failing test**

Create `Packages/MoraTesting/Tests/MoraTestingTests/FakeTileBoardEngineTests.swift`:

```swift
import XCTest
import MoraCore
import MoraEngines
@testable import MoraTesting

@MainActor
final class FakeTileBoardEngineTests: XCTestCase {
    func testRecordsEventsInOrder() {
        let engine = FakeTileBoardEngine()
        engine.apply(.preparationFinished)
        engine.apply(.promptFinished)
        XCTAssertEqual(engine.recordedEvents, [.preparationFinished, .promptFinished])
    }

    func testShFixtureChainsHaveThreeValidChains() {
        let phase = FixtureWordChains.shPhase()
        XCTAssertEqual(phase.count, 3)
        XCTAssertEqual(phase[0].role, .warmup)
        XCTAssertEqual(phase[1].role, .targetIntro)
        XCTAssertEqual(phase[2].role, .mixedApplication)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraTesting && swift test --filter FakeTileBoardEngineTests)`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `Packages/MoraTesting/Sources/MoraTesting/FakeTileBoardEngine.swift`:

```swift
import Foundation
import MoraCore
import MoraEngines

@MainActor
public final class FakeTileBoardEngine {
    public private(set) var recordedEvents: [TileBoardEvent] = []
    public var preprogrammedResult: TileBoardTrialResult?

    public init(preprogrammedResult: TileBoardTrialResult? = nil) {
        self.preprogrammedResult = preprogrammedResult
    }

    public func apply(_ event: TileBoardEvent) {
        recordedEvents.append(event)
    }

    public var result: TileBoardTrialResult {
        preprogrammedResult ?? TileBoardTrialResult(
            word: Word(surface: "", graphemes: [], phonemes: []),
            buildAttempts: [],
            scaffoldLevel: 0,
            ttsHintIssued: false,
            poolReducedToTwo: false,
            autoFilled: false
        )
    }
}
```

Create `Packages/MoraTesting/Sources/MoraTesting/FixtureWordChains.swift`:

```swift
import Foundation
import MoraCore

public enum FixtureWordChains {
    private static func word(_ surface: String, _ gs: [String]) -> Word {
        Word(surface: surface, graphemes: gs.map { Grapheme(letters: $0) }, phonemes: [])
    }

    public static func shInventory() -> Set<Grapheme> {
        Set(["c", "a", "t", "u", "h", "sh", "i", "o", "p", "f", "d", "w", "m", "s"].map { Grapheme(letters: $0) })
    }

    public static func shPhase() -> [WordChain] {
        let inv = shInventory()
        return [
            WordChain(
                role: .warmup,
                head: BuildTarget(word: word("cat", ["c", "a", "t"])),
                successorWords: [
                    word("cut", ["c", "u", "t"]),
                    word("hut", ["h", "u", "t"]),
                    word("hat", ["h", "a", "t"]),
                ],
                inventory: inv
            )!,
            WordChain(
                role: .targetIntro,
                head: BuildTarget(word: word("ship", ["sh", "i", "p"])),
                successorWords: [
                    word("shop", ["sh", "o", "p"]),
                    word("shot", ["sh", "o", "t"]),
                    word("shut", ["sh", "u", "t"]),
                ],
                inventory: inv
            )!,
            WordChain(
                role: .mixedApplication,
                head: BuildTarget(word: word("fish", ["f", "i", "sh"])),
                successorWords: [
                    word("dish", ["d", "i", "sh"]),
                    word("wish", ["w", "i", "sh"]),
                    word("wash", ["w", "a", "sh"]),
                ],
                inventory: inv
            )!,
        ]
    }
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraTesting && swift test --filter FakeTileBoardEngineTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraTesting/Sources/MoraTesting/FakeTileBoardEngine.swift Packages/MoraTesting/Sources/MoraTesting/FixtureWordChains.swift Packages/MoraTesting/Tests/MoraTestingTests/FakeTileBoardEngineTests.swift
git commit -m "testing: add FakeTileBoardEngine and FixtureWordChains"
```

---

## Phase 6 — MoraUI

### Task 20: Tile design palette

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Design/TilePalette.swift`
- Test: `Packages/MoraUI/Tests/MoraUITests/Design/TilePaletteTests.swift`

A single source of truth for tile colors keyed on `TileKind` (spec §10.1). Views pull from the palette; colors are never hard-coded in views.

- [ ] **Step 1: Failing test**

Create `Packages/MoraUI/Tests/MoraUITests/Design/TilePaletteTests.swift`:

```swift
import XCTest
import MoraCore
import SwiftUI
@testable import MoraUI

final class TilePaletteTests: XCTestCase {
    func testAllKindsHaveDistinctFillColors() {
        let kinds: [TileKind] = [.consonant, .vowel, .multigrapheme]
        let fills = kinds.map { TilePalette.fill(for: $0) }
        XCTAssertEqual(Set(fills).count, kinds.count)
    }

    func testAllKindsHaveBorderAndText() {
        for kind in [TileKind.consonant, .vowel, .multigrapheme] {
            _ = TilePalette.border(for: kind)
            _ = TilePalette.text(for: kind)
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraUI && swift test --filter TilePaletteTests)`
Expected: FAIL.

- [ ] **Step 3: Implement**

Create `Packages/MoraUI/Sources/MoraUI/Design/TilePalette.swift`:

```swift
import MoraCore
import SwiftUI

public enum TilePalette {
    public static func fill(for kind: TileKind) -> Color {
        switch kind {
        case .consonant: return Color(red: 0.859, green: 0.922, blue: 0.996)   // #dbeafe
        case .vowel: return Color(red: 0.996, green: 0.843, blue: 0.678)       // #fed7aa
        case .multigrapheme: return Color(red: 0.851, green: 0.976, blue: 0.616) // #d9f99d
        }
    }

    public static func border(for kind: TileKind) -> Color {
        switch kind {
        case .consonant: return Color(red: 0.576, green: 0.773, blue: 0.953)   // #93c5fd
        case .vowel: return Color(red: 0.984, green: 0.620, blue: 0.251)       // #fb923c
        case .multigrapheme: return Color(red: 0.643, green: 0.902, blue: 0.208) // #a3e635
        }
    }

    public static func text(for kind: TileKind) -> Color {
        switch kind {
        case .consonant: return Color(red: 0.118, green: 0.227, blue: 0.541)   // #1e3a8a
        case .vowel: return Color(red: 0.604, green: 0.204, blue: 0.071)       // #9a3412
        case .multigrapheme: return Color(red: 0.247, green: 0.384, blue: 0.071) // #3f6212
        }
    }
}
```

- [ ] **Step 4: Run**

Run: `(cd Packages/MoraUI && swift test --filter TilePaletteTests)`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Design/TilePalette.swift Packages/MoraUI/Tests/MoraUITests/Design/TilePaletteTests.swift
git commit -m "ui: add tile color palette keyed on TileKind"
```

---

### Task 21: TileView

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TileView.swift`

SwiftUI view for one tile. Supports three visual states: `.idle`, `.lifted`, `.settling`. Uses OpenDyslexic (already present via `Typography`). Pickup animation is `.spring(response: 0.3, dampingFraction: 0.7)` with scale 1.12 and shadow. No drag gesture yet — that's wired by the pool view.

- [ ] **Step 1: Create the view**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TileView.swift`:

```swift
import MoraCore
import SwiftUI

public enum TileVisualState: Hashable, Sendable {
    case idle
    case lifted
    case settling
    case ghost  // used in auto-fill animations
}

public struct TileView: View {
    public let tile: Tile
    public let visual: TileVisualState
    public let size: CGFloat
    public var reduceMotion: Bool = false

    public init(tile: Tile, visual: TileVisualState = .idle, size: CGFloat = 64, reduceMotion: Bool = false) {
        self.tile = tile
        self.visual = visual
        self.size = size
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        let kind = tile.kind
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(TilePalette.fill(for: kind))
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(TilePalette.border(for: kind), lineWidth: 2)
            Text(tile.display)
                .font(.custom("OpenDyslexic-Bold", size: size * 0.5))
                .foregroundColor(TilePalette.text(for: kind))
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .rotationEffect(.degrees(rotation))
        .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
        .animation(animation, value: visual)
        .accessibilityLabel(Text(tile.display))
    }

    private var scale: CGFloat {
        switch visual {
        case .idle, .ghost: return 1.0
        case .lifted: return 1.12
        case .settling: return 1.04
        }
    }

    private var rotation: CGFloat {
        guard !reduceMotion else { return 0 }
        switch visual {
        case .idle, .ghost, .settling: return 0
        case .lifted: return 3
        }
    }

    private var shadowColor: Color {
        Color.black.opacity(visual == .lifted ? 0.18 : 0.08)
    }

    private var shadowRadius: CGFloat {
        visual == .lifted ? 12 : 3
    }

    private var shadowY: CGFloat {
        visual == .lifted ? 6 : 2
    }

    private var animation: Animation? {
        reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.3, dampingFraction: 0.7)
    }
}

#Preview {
    HStack {
        TileView(tile: Tile(grapheme: Grapheme(letters: "sh")))
        TileView(tile: Tile(grapheme: Grapheme(letters: "i")), visual: .lifted)
        TileView(tile: Tile(grapheme: Grapheme(letters: "p")))
    }
    .padding()
}
```

- [ ] **Step 2: Verify the package builds**

Run: `(cd Packages/MoraUI && swift build)`
Expected: BUILD SUCCEEDED. There's no test in this task because the content is purely visual; snapshots come in Task 28.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TileView.swift
git commit -m "ui: add TileView with idle/lifted/settling visual states"
```

---

### Task 22: SlotView

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/SlotView.swift`

One slot. Renders one of: empty-inactive, empty-active-pulse, filled, locked, auto-filled (with dashed outline per spec §7).

- [ ] **Step 1: Create**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/SlotView.swift`:

```swift
import MoraCore
import SwiftUI

public enum SlotState: Hashable, Sendable {
    case emptyInactive
    case emptyActive
    case filled(Tile)
    case locked(Tile)
    case autoFilled(Tile)
}

public struct SlotView: View {
    public let state: SlotState
    public let size: CGFloat
    public var reduceMotion: Bool

    public init(state: SlotState, size: CGFloat = 84, reduceMotion: Bool = false) {
        self.state = state
        self.size = size
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        ZStack {
            backgroundShape
            if let tile = tile {
                Text(tile.display)
                    .font(.custom("OpenDyslexic-Bold", size: size * 0.38))
                    .foregroundColor(TilePalette.text(for: tile.kind))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var backgroundShape: some View {
        switch state {
        case .emptyInactive:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .foregroundColor(.gray.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.05))
                )
        case .emptyActive:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(reduceMotion ? 0.3 : 0.4), lineWidth: 2)
                        .scaleEffect(reduceMotion ? 1 : 1.06)
                        .opacity(reduceMotion ? 0.6 : 0)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: reduceMotion
                        )
                )
        case let .filled(tile):
            RoundedRectangle(cornerRadius: 16)
                .fill(TilePalette.fill(for: tile.kind))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TilePalette.border(for: tile.kind), lineWidth: 2)
                )
        case let .locked(tile):
            RoundedRectangle(cornerRadius: 16)
                .fill(TilePalette.fill(for: tile.kind).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TilePalette.border(for: tile.kind).opacity(0.6), lineWidth: 2)
                )
        case let .autoFilled(tile):
            RoundedRectangle(cornerRadius: 16)
                .fill(TilePalette.fill(for: tile.kind).opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TilePalette.border(for: tile.kind), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                )
        }
    }

    private var tile: Tile? {
        switch state {
        case .emptyInactive, .emptyActive: return nil
        case let .filled(t), let .locked(t), let .autoFilled(t): return t
        }
    }

    private var accessibilityLabel: Text {
        switch state {
        case .emptyInactive: return Text("empty slot")
        case .emptyActive: return Text("active slot, empty")
        case let .filled(t): return Text("slot contains \(t.display)")
        case let .locked(t): return Text("locked slot, \(t.display)")
        case let .autoFilled(t): return Text("auto-filled slot, \(t.display)")
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/SlotView.swift
git commit -m "ui: add SlotView with five visual states"
```

---

### Task 23: TilePoolView with drag gesture

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TilePoolView.swift`

Laid-out pool of tiles with `.draggable` / drop-target wiring. When a tile is lifted the view notifies the caller; when dropped on a slot the caller receives `(slotIndex, tileID)`. The pool view itself does not know about validity — the engine decides.

- [ ] **Step 1: Create**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TilePoolView.swift`:

```swift
import MoraCore
import SwiftUI
import UniformTypeIdentifiers

public struct TilePoolView: View {
    public let tiles: [Tile]
    public let reduceMotion: Bool
    public var onLift: (String) -> Void = { _ in }

    public init(tiles: [Tile], reduceMotion: Bool = false, onLift: @escaping (String) -> Void = { _ in }) {
        self.tiles = tiles
        self.reduceMotion = reduceMotion
        self.onLift = onLift
    }

    public var body: some View {
        WrappingHStack(tiles) { tile in
            TileView(tile: tile, visual: .idle, reduceMotion: reduceMotion)
                .onDrag {
                    onLift(tile.id)
                    return NSItemProvider(object: tile.id as NSString)
                }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.15))
                )
        )
    }
}

/// Minimal flow-layout used by TilePoolView. Wraps children to new rows
/// when they exceed the available width. Kept in this file to avoid a
/// cross-view layout helper until the project actually needs one elsewhere.
public struct WrappingHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    public let data: Data
    public let content: (Data.Element) -> Content
    public var spacing: CGFloat = 10

    public init(_ data: Data, spacing: CGFloat = 10, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo.size)
        }
        .frame(minHeight: 80)
    }

    private func generateContent(in size: CGSize) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            ForEach(data) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > size.width {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if item.id == data.last?.id { width = 0 } else { width -= d.width }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item.id == data.last?.id { height = 0 }
                        return result
                    }
            }
        }
    }
}
```

Note on `UTType`: `NSItemProvider(object: NSString)` supplies a plain-text drag payload the slot view can interpret as a tile ID. No `UTType` registration is needed.

- [ ] **Step 2: Build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: BUILD SUCCEEDED. If SwiftUI reports that `WrappingHStack` is too ambitious, consider using the system `FlowLayout` on iOS 16+ (`Layout` protocol). For this task, the hand-written version is intentional — the project targets iPad and the one-line `Layout` API may be preferred later but is not required now.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TilePoolView.swift
git commit -m "ui: add TilePoolView with drag-source wiring and wrap layout"
```

---

### Task 24: ChainProgressRibbon

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainProgressRibbon.swift`

Twelve pips grouped 4-4-4 with vertical separators. Each pip is `.pending`, `.active`, or `.done`.

- [ ] **Step 1: Create**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainProgressRibbon.swift`:

```swift
import SwiftUI

public enum ChainPipState: Hashable, Sendable {
    case pending
    case active
    case done
}

public struct ChainProgressRibbon: View {
    public let states: [ChainPipState]  // expected count: 12

    public init(states: [ChainPipState]) {
        self.states = states
    }

    public var body: some View {
        HStack(spacing: 6) {
            group(Array(states.prefix(4)))
            separator
            group(Array(states.dropFirst(4).prefix(4)))
            separator
            group(Array(states.dropFirst(8).prefix(4)))
        }
    }

    private func group(_ slice: [ChainPipState]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(slice.enumerated()), id: \.offset) { _, state in
                pip(state)
            }
        }
    }

    private func pip(_ state: ChainPipState) -> some View {
        Circle()
            .fill(fill(state))
            .frame(width: 14, height: 14)
            .overlay(
                Circle().strokeBorder(halo(state), lineWidth: 2)
            )
            .animation(.easeOut(duration: 0.3), value: state)
    }

    private func fill(_ s: ChainPipState) -> Color {
        switch s {
        case .pending: return Color.gray.opacity(0.3)
        case .active: return Color.blue
        case .done: return Color.yellow
        }
    }

    private func halo(_ s: ChainPipState) -> Color {
        switch s {
        case .pending: return .clear
        case .active: return Color.blue.opacity(0.3)
        case .done: return Color.yellow.opacity(0.5)
        }
    }

    private var separator: some View {
        Rectangle().fill(Color.gray.opacity(0.4)).frame(width: 1, height: 16)
    }
}
```

- [ ] **Step 2: Build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainProgressRibbon.swift
git commit -m "ui: add ChainProgressRibbon for 12-pip phase progress"
```

---

### Task 25: ChainTransitionOverlay

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainTransitionOverlay.swift`

Background gradient crossfade + scale breath between chains. Parameterized by the *incoming* chain's role. Respects Reduce Motion.

- [ ] **Step 1: Create**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainTransitionOverlay.swift`:

```swift
import MoraCore
import SwiftUI

public struct ChainTransitionOverlay: View {
    public let incomingRole: ChainRole
    public var reduceMotion: Bool = false

    public init(incomingRole: ChainRole, reduceMotion: Bool = false) {
        self.incomingRole = incomingRole
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
            .opacity(0.9)
            .scaleEffect(reduceMotion ? 1 : 1.02)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: incomingRole)
            .transition(.opacity)
    }

    private var gradient: [Color] {
        switch incomingRole {
        case .warmup:
            return [Color(red: 0.91, green: 0.95, blue: 1.0), Color(red: 0.93, green: 0.92, blue: 1.0)]
        case .targetIntro:
            return [Color(red: 1.0, green: 0.97, blue: 0.85), Color(red: 1.0, green: 0.92, blue: 0.85)]
        case .mixedApplication:
            return [Color(red: 1.0, green: 0.92, blue: 0.85), Color(red: 1.0, green: 0.82, blue: 0.80)]
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainTransitionOverlay.swift
git commit -m "ui: add ChainTransitionOverlay with per-role gradient"
```

---

### Task 26: DecodeBoardView

**Files:**
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift`

Composes the pieces. Owns a `TileBoardEngine`, renders prompt + slot row + pool + progress ribbon, wires drag-drops to `engine.apply(.tileDropped(...))`, shows `ChainTransitionOverlay` between chains, and escalates the `.completed → .speaking` handoff to the existing `SpeechController` / `PronunciationFeedbackOverlay`.

Also implements the **β scaffold for the first Build of the session** (spec §5): when `isFirstTrialOfPhase == true` the target word is rendered in-place for 600 ms before `.preparationFinished` fires, giving the child a single orientation glance per day. This only runs once per day — the orchestrator sets the flag for the very first trial and clears it thereafter.

Spec §9.4, §11, §5 β variant.

- [ ] **Step 1: Create**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift`:

```swift
import MoraCore
import MoraEngines
import SwiftUI

public struct DecodeBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable public var engine: TileBoardEngine
    public let target: Target
    public let chainPipStates: [ChainPipState]
    public let incomingRole: ChainRole
    public let isFirstTrialOfPhase: Bool
    public var onTrialComplete: (TileBoardTrialResult) -> Void = { _ in }

    @State private var betaOverlayVisible: Bool = false

    public init(
        engine: TileBoardEngine,
        target: Target,
        chainPipStates: [ChainPipState],
        incomingRole: ChainRole,
        isFirstTrialOfPhase: Bool = false,
        onTrialComplete: @escaping (TileBoardTrialResult) -> Void = { _ in }
    ) {
        self.engine = engine
        self.target = target
        self.chainPipStates = chainPipStates
        self.incomingRole = incomingRole
        self.isFirstTrialOfPhase = isFirstTrialOfPhase
        self.onTrialComplete = onTrialComplete
    }

    public var body: some View {
        ZStack {
            ChainTransitionOverlay(incomingRole: incomingRole, reduceMotion: reduceMotion)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                ChainProgressRibbon(states: chainPipStates)
                prompt
                slotRow
                pool
            }
            .padding(.horizontal, 24)
            .onChange(of: engine.state) { oldValue, newValue in
                if newValue == .completed {
                    onTrialComplete(engine.result)
                }
            }
            if betaOverlayVisible {
                Text(engine.trial.word.surface)
                    .font(.custom("OpenDyslexic-Bold", size: 72))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            if isFirstTrialOfPhase {
                betaOverlayVisible = true
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await MainActor.run {
                        withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.35)) {
                            betaOverlayVisible = false
                        }
                        engine.apply(.preparationFinished)
                        engine.apply(.promptFinished)
                    }
                }
            } else {
                engine.apply(.preparationFinished)
                engine.apply(.promptFinished)
            }
        }
    }

    private var prompt: some View {
        Text(promptText)
            .font(.headline)
            .foregroundColor(.secondary)
            .accessibilityLabel(promptText)
    }

    private var slotRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(engine.trial.expectedSlots.enumerated()), id: \.offset) { index, expected in
                SlotView(state: slotState(at: index, expected: expected), reduceMotion: reduceMotion)
                    .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                        _ = providers.first?.loadObject(ofClass: NSString.self) { (text, _) in
                            guard let tileID = text as? String else { return }
                            Task { @MainActor in
                                engine.apply(.tileDropped(slotIndex: index, tileID: tileID))
                            }
                        }
                        return true
                    }
            }
        }
    }

    private func slotState(at index: Int, expected: Grapheme) -> SlotState {
        if let filled = engine.filled[index] {
            let tile = Tile(grapheme: filled)
            if engine.autoFilled { return .autoFilled(tile) }
            if case .change = engine.trial, index != engine.trial.activeSlotIndex { return .locked(tile) }
            return .filled(tile)
        }
        if engine.trial.activeSlotIndex == index { return .emptyActive }
        if case .build = engine.trial { return .emptyActive }  // Build mode: any empty slot is receptive
        return .emptyInactive
    }

    private var pool: some View {
        TilePoolView(tiles: engine.pool, reduceMotion: reduceMotion)
    }

    private var promptText: String {
        switch engine.trial {
        case .build: return "Listen and build the word"
        case let .change(target, _, _):
            return "Change \(target.oldGrapheme.letters) to \(target.newGrapheme.letters)"
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `(cd Packages/MoraUI && swift build)`
Expected: BUILD SUCCEEDED. Check that the `.onChange(of:)` call uses the iOS 17+ two-parameter closure (the project targets iPadOS 17+; verify in `project.yml` if unsure).

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift
git commit -m "ui: add DecodeBoardView composing tile board pieces"
```

---

### Task 27: Wire DecodeBoardView into SessionContainerView; delete DecodeActivityView

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift`
- Delete: `Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift`

Replace the `DecodeActivityView(...)` usage with a `DecodeBoardView` driven by the orchestrator's current `TileBoardEngine`. The orchestrator already owns the engine after Task 18 — `SessionContainerView` reads `orchestrator.currentTileBoardEngine`, `orchestrator.chainPipStates`, `orchestrator.currentChainRole`. If those properties don't exist yet on the orchestrator, add them here — they're simple `@Observable` derived getters.

- [ ] **Step 1: Open `SessionContainerView.swift`** and locate the `.decoding` branch of the phase switch. Today it reads roughly:

```swift
case .decoding:
    DecodeActivityView(
        orchestrator: orchestrator,
        ...
    )
```

- [ ] **Step 2: Bridge the orchestrator's pip-state vocabulary to the UI's**

`SessionOrchestrator.chainPipStates` returns `[ChainPipStateOrchestratorValue]` (from Task 18b). `DecodeBoardView` takes `[ChainPipState]` (from Task 24). Add a tiny mapper in the UI layer.

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/ChainPipStateBridge.swift`:

```swift
import MoraEngines

extension ChainPipState {
    init(_ value: ChainPipStateOrchestratorValue) {
        switch value {
        case .pending: self = .pending
        case .active: self = .active
        case .done: self = .done
        }
    }
}
```

- [ ] **Step 3: Expose `isFirstTrialOfPhase` on the orchestrator**

Add to `SessionOrchestrator`:

```swift
    public var isFirstTrialOfPhase: Bool {
        pendingChains.count == 3 && completedTrialCount == 0
    }
```

- [ ] **Step 4: Replace the decoding branch in `SessionContainerView`**

```swift
case .decoding:
    if let engine = orchestrator.currentTileBoardEngine {
        DecodeBoardView(
            engine: engine,
            target: orchestrator.target,
            chainPipStates: orchestrator.chainPipStates.map(ChainPipState.init),
            incomingRole: orchestrator.currentChainRole,
            isFirstTrialOfPhase: orchestrator.isFirstTrialOfPhase,
            onTrialComplete: { result in
                orchestrator.consumeTileBoardTrial(result)
            }
        )
        .id(orchestrator.completedTrialCount)  // force re-mount per trial so onAppear re-fires
    } else {
        Color.clear
    }
```

The `.id(orchestrator.completedTrialCount)` is important: SwiftUI reuses the same `DecodeBoardView` across trials otherwise, and `.onAppear` would not fire for trial 2+. Rebuilding on each trial is inexpensive — the engine is a small `@Observable`.

- [ ] **Step 5: Delete `DecodeActivityView.swift`**

```bash
rm Packages/MoraUI/Sources/MoraUI/Session/DecodeActivityView.swift
```

If `ShortSentencesView.swift` references `DecodeActivityView` in a comment only, leave the comment alone (it documents rationale); if there's a code reference, fix it. Grep to confirm:

```bash
grep -rn "DecodeActivityView" Packages/
```

Expected: only the comment in `ShortSentencesView.swift` and zero code references.

- [ ] **Step 6: Build and commit**

```bash
(cd Packages/MoraUI && swift build)
git add -A
git commit -m "ui: wire DecodeBoardView into decoding phase and delete legacy list view"
```

---

## Phase 7 — Integration and polish

### Task 28: Accessibility and preview snapshots

**Files:**
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/DecodeBoardView.swift`
- Create: `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TileBoardPreviews.swift`

Confirm VoiceOver labels (SlotView already exposes them; DecodeBoardView's prompt label is set). Confirm Reduce Motion branches are exercised via previews. Add a preview file with four previews: Build trial / Change trial / auto-filled slot / Reduce-Motion chain transition.

- [ ] **Step 1: Create previews**

Create `Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TileBoardPreviews.swift`:

```swift
import MoraCore
import MoraEngines
import MoraTesting
import SwiftUI

private func previewSkill() -> Skill {
    Skill(
        code: "sh_onset",
        level: .l3,
        displayName: "sh",
        graphemePhoneme: .init(
            grapheme: .init(letters: "sh"),
            phoneme: .init(ipa: "ʃ")
        )
    )
}

#Preview("Build trial") {
    let word = Word(surface: "ship", graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")], phonemes: [])
    let trial = TileBoardTrial.build(
        target: BuildTarget(word: word),
        pool: [Tile(grapheme: Grapheme(letters: "sh")), Tile(grapheme: Grapheme(letters: "i")), Tile(grapheme: Grapheme(letters: "p")), Tile(grapheme: Grapheme(letters: "ch"))]
    )
    return DecodeBoardView(
        engine: TileBoardEngine(trial: trial),
        target: Target(weekStart: .now, skill: previewSkill()),
        chainPipStates: Array(repeating: .pending, count: 12),
        incomingRole: .targetIntro
    )
}

#Preview("Change trial") {
    let pred = Word(surface: "ship", graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")], phonemes: [])
    let succ = Word(surface: "shop", graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "o"), Grapheme(letters: "p")], phonemes: [])
    let change = ChangeTarget(predecessor: pred, successor: succ)!
    let trial = TileBoardTrial.change(
        target: change,
        lockedSlots: pred.graphemes,
        pool: [Tile(grapheme: Grapheme(letters: "o")), Tile(grapheme: Grapheme(letters: "a")), Tile(grapheme: Grapheme(letters: "u"))]
    )
    return DecodeBoardView(
        engine: TileBoardEngine(trial: trial),
        target: Target(weekStart: .now, skill: previewSkill()),
        chainPipStates: Array(repeating: .done, count: 5) + [.active] + Array(repeating: .pending, count: 6),
        incomingRole: .targetIntro
    )
}
```

- [ ] **Step 2: Build previews**

Open the file in Xcode and render the two previews. Both should show the intended board at rest.

- [ ] **Step 3: Run VoiceOver audit**

Manually in the Simulator: turn on VoiceOver, tap each tile — hear "letters"; tap each slot — hear "position ... empty/contains ...". If a label misses, fix it in `SlotView` or `TileView`.

- [ ] **Step 4: Run Reduce-Motion audit**

In the Simulator Accessibility Inspector, enable "Reduce Motion". Confirm the pulsing slot halo is a static opacity flash, not a repeating breath; confirm the chain gradient does not scale-breathe.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/TileBoard/TileBoardPreviews.swift
git commit -m "ui: add preview snapshots for Build and Change trials"
```

---

### Task 29: Regenerate Xcode project, run full build, lint, and sign off

**Files:**
- No source changes.
- Run `xcodegen generate`, full `xcodebuild`, per-package `swift test`, `swift-format lint --strict`.

The `DEVELOPMENT_TEAM` injection step documented in the memory "xcodegen team injection" is local — do not commit it.

- [ ] **Step 1: Inject team id, regenerate, revert**

```bash
# Temporary team injection (do not commit the yml change)
yq -i '.targets.Mora.settings.base.DEVELOPMENT_TEAM = "7BT28X9TQ9"' project.yml || true
xcodegen generate
git checkout -- project.yml
```

If `yq` isn't available, edit `project.yml` manually to add `DEVELOPMENT_TEAM: 7BT28X9TQ9` under `targets.Mora.settings.base`, run `xcodegen generate`, then `git checkout -- project.yml`.

- [ ] **Step 2: Full xcodebuild**

```bash
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED. If the build fails for reasons unrelated to this plan, diagnose and fix inline.

- [ ] **Step 3: Full per-package swift test**

```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
```

Expected: all green.

- [ ] **Step 4: swift-format**

```bash
swift-format format --in-place --recursive Mora Packages/*/Sources Packages/*/Tests
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

If format edits any files, stage them and include in a fixup commit.

- [ ] **Step 5: Sign off with a final commit**

If there are format-only changes:

```bash
git add -A
git commit -m "chore: swift-format pass for tile-board decoding"
```

Print `git log --oneline -15` and eyeball the commit chain — each task should be one commit, plus optionally one `chore: swift-format` at the end.

---

## Self-review checklist (for the executing engineer)

- Every spec §1–§13 requirement maps to at least one task above. §14 open questions are content / playtest follow-ups and are intentionally not in this plan.
- `DecodeActivityView.swift` is gone; `grep -rn DecodeActivityView Packages/` returns zero code hits.
- `PerformanceEntity` and `SessionSummaryEntity` accept their pre-migration initializers unchanged.
- The full A-day flow still advances past `.decoding` into `.shortSentences` with 12 trials recorded.
- `swift-format lint --strict` returns zero warnings.
- CI `xcodebuild` invocation succeeds.
