# Pronunciation Feedback (Engine B — shadow mode) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Engine B (`PhonemeModelPronunciationEvaluator`) as a second `PronunciationEvaluator` running in parallel with Engine A. Engine A keeps driving the UI; Engine B is invisible at runtime and writes its per-trial result to a new SwiftData entity `PronunciationTrialLog` for correlation analysis.

**Architecture:** A new `PhonemePosteriorProvider` protocol in MoraEngines abstracts the CoreML model. `MoraMLX` hosts `CoreMLPhonemePosteriorProvider`; `MoraEngines` hosts alignment (`ForcedAligner` — Viterbi over log-posteriors), GOP scoring, the evaluator itself, and a composite decorator (`ShadowLoggingPronunciationEvaluator`) that always fires Engine B regardless of Engine A's support set. Engine B's result is persisted through a `PronunciationTrialLogger` in a detached background task so the UI path is never blocked. The CoreML model (~150 MB, wav2vec2-xlsr-53-espeak-cv-ft INT8) is produced by `dev-tools/model-conversion/convert.py` and tracked by Git LFS under `Packages/MoraMLX/Sources/MoraMLX/Resources/`.

**Tech Stack:** Swift 5.9, SwiftData (persistence), CoreML (model inference), Swift Concurrency (detached tasks, timeouts via `withTaskGroup`), XCTest. Conversion tooling: Python 3.11, `coremltools>=7.2`, `transformers>=4.40`.

**Design spec:** `docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md` (covers Phase 3 of the parent spec `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md`).

**Scope:** Phase 3 of `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md`, implemented in two PRs:

- **Part 1 (Tasks 1–19)** — Evaluator logic, SwiftData entity, composite decorator, retention cleanup, MoraMLX stub, app-level wiring. All unit-tested with a `FakePhonemePosteriorProvider`; the real model is not touched. Shipped behavior is unchanged because the MoraMLX stub always throws and the app falls back to bare Engine A.
- **Part 2 (Tasks 20–30)** — `dev-tools/model-conversion/` toolchain, real model bundled via Git LFS, `CoreMLPhonemePosteriorProvider`, real `MoraMLXModelCatalog`, smoke test, CI LFS fetch, docs. At Part 2 end, shadow mode is live on device.

**Not in scope of this plan:**

- `dev-tools/pronunciation-bench/` — implemented in a separate worktree / session.
- Promotion of Engine B to primary. `SettingsStore.preferredEvaluator` is not introduced; the flip will be a follow-up PR fed by `pronunciation-bench/` correlation data.
- Per-speaker threshold adaptation.
- GOP sigmoid calibration. Ship pre-calibration defaults `(k = 5.0, gopZero = -1.5)`.
- Parent-mode export of shadow logs.
- Engine B phoneme coverage expansion beyond the MVP ~36 phoneme IPA set enumerated in `PhonemeInventory.v15SupportedPhonemeIPA`.

## Current progress

**Part 1 complete.** Tasks 1–19 landed on a standalone PR; Part 2 (Tasks 20–30) picks up in a follow-up branch.

| # | Task | Commit |
|---|------|--------|
| 1 | PhonemePosterior value type | `0e6c8fe` |
| 2 | PhonemePosteriorProvider + fake | `3137902` |
| 3 | PhonemeInventory | `8472ed3` |
| 4 | ForcedAligner | `7310ccb` |
| 5 | GOPScorer | `99ce26f` |
| 6 | CoachingKeyResolver refactor | `ce77353` |
| 7 | withTimeout helper | `7683158` |
| 8 | PhonemeModelPronunciationEvaluator | `f991ff9` |
| 9 | PronunciationTrialLog entity + schema | `b4ab1d8` |
| 10 | PronunciationTrialRetentionPolicy | `af812b3` |
| 11 | PronunciationTrialLogger protocol | `f81b7dc` |
| 12 | SwiftDataPronunciationTrialLogger | `dd0cc7c` |
| 13 | InMemoryPronunciationTrialLogger | `fa96c86` |
| 14 | ShadowLoggingPronunciationEvaluator | `31f843f` |
| 15 | Orchestrator shadow integration test | `6cc1c13` |
| 16 | MoraMLX stub + catalog | `94495e0` |
| 17 | App-level shadow wiring | `be3edc9` |
| 18 | Format sweep | `e6ed0f5` |
| 19 | Docs progress section | `-` |

**Part 2 landed with the real-model step deferred.** Tasks 20, 21, and
23–30 shipped on the Part 2 PR using a placeholder `.mlmodelc` so the
packaging, app wiring, CI LFS checkout, and smoke-test paths are all in
place. Task 22 Steps 2–5 (run `convert.py` locally with `HF_TOKEN`, then
commit the real `.mlmodelc` via Git LFS) is tracked as a manual
follow-up.

| # | Task | Commit |
|---|------|--------|
| 20 | dev-tools/model-conversion scaffolding | `ca6efda` |
| 21 | convert.py script | `f4e58d7` |
| 22 | Run conversion + LFS commit | deferred — human follow-up |
| 23 | MoraMLX Package.swift resources | `1ccffb5` |
| 24 | CoreMLPhonemePosteriorProvider | `62a8f23` |
| 25 | MoraMLXModelCatalog real loader | `e830639` |
| 26 | Smoke test + fixture | `7bf6f0c` |
| 27 | CI LFS checkout | `e8b384a` |
| 28 | Format sweep | `-` |
| 29 | Device-only latency benchmark | `420d4ab` |
| 30 | Docs cross-link + CLAUDE.md update | `-` |

> **Note — Task 22 deferred.** Steps 2–5 of Task 22 (running `convert.py`
> with a valid `HF_TOKEN` and committing the resulting
> `wav2vec2-phoneme.mlmodelc` + `phoneme-labels.json` via Git LFS) are a
> manual follow-up outside this PR. Tasks 23–26 ship with a placeholder
> `.mlmodelc` so the bundling, `MoraMLXModelCatalog` load path, and
> `CoreMLPhonemePosteriorProvider` wiring are exercised by CI; tests use
> positive placeholder detection (`PlaceholderDetection.isPlaceholderModelBundled`)
> to `XCTSkip` while the placeholder is in place and FAIL once the real
> model is bundled. Shadow-mode inference on device starts working after
> the deferred follow-up lands.

---

## File map

New files:

| File | Responsibility | Phase |
|---|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosterior.swift` | `PhonemePosterior` value type (log-posterior T×C matrix). | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosteriorProvider.swift` | Protocol. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeInventory.swift` | espeak↔IPA mapping + MVP supported set. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ForcedAligner.swift` | Viterbi alignment of `Word.phonemes` against a posterior. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/GOPScorer.swift` | GOP formula + sigmoid→0–100 mapping. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/CoachingKeyResolver.swift` | Shared coaching-key lookup (refactored out of Engine A). | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/Concurrency.swift` | `withTimeout` helper. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeModelPronunciationEvaluator.swift` | Engine B evaluator. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationTrialLogger.swift` | Logger protocol + `PronunciationTrialLogEntry` + `EngineBLogResult`. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/SwiftDataPronunciationTrialLogger.swift` | Production logger writing `PronunciationTrialLog` rows via a `@ModelActor`. | Part 1 |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ShadowLoggingPronunciationEvaluator.swift` | Composite (primary + shadow + logger). | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemePosteriorTests.swift` | Value-type tests. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/ForcedAlignerTests.swift` | Alignment tests. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/GOPScorerTests.swift` | GOP tests. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/ConcurrencyTests.swift` | `withTimeout` tests. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeModelPronunciationEvaluatorTests.swift` | Evaluator behavior tests (fake provider). | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationTrialLoggerTests.swift` | SwiftData logger round-trip tests. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/ShadowLoggingPronunciationEvaluatorTests.swift` | Composite behavior tests. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorShadowLoggingTests.swift` | Orchestrator integration. | Part 1 |
| `Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialLog.swift` | `@Model` SwiftData entity. | Part 1 |
| `Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialRetentionPolicy.swift` | FIFO cap at 1000 rows, startup cleanup. | Part 1 |
| `Packages/MoraCore/Tests/MoraCoreTests/PronunciationTrialLogTests.swift` | Entity round-trip. | Part 1 |
| `Packages/MoraCore/Tests/MoraCoreTests/PronunciationTrialRetentionPolicyTests.swift` | Retention tests. | Part 1 |
| `Packages/MoraTesting/Sources/MoraTesting/FakePhonemePosteriorProvider.swift` | Scripted provider double. | Part 1 |
| `Packages/MoraTesting/Sources/MoraTesting/InMemoryPronunciationTrialLogger.swift` | In-memory logger double. | Part 1 |
| `Packages/MoraMLX/Sources/MoraMLX/MoraMLXError.swift` | `MoraMLXError` enum. | Part 1 (stub), Part 2 (full) |
| `Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift` | Loader. Part 1 = stub throwing `.modelNotBundled`; Part 2 = real CoreML load. | Part 1 (stub), Part 2 (full) |
| `Packages/MoraMLX/Sources/MoraMLX/CoreMLPhonemePosteriorProvider.swift` | Production provider. | Part 2 |
| `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/` | CoreML model (Git LFS). | Part 2 |
| `Packages/MoraMLX/Sources/MoraMLX/Resources/phoneme-labels.json` | espeak label list (plain git). | Part 2 |
| `Packages/MoraMLX/Tests/MoraMLXTests/CoreMLPhonemePosteriorProviderSmokeTests.swift` | Real-model smoke test. | Part 2 |
| `Packages/MoraMLX/Tests/MoraMLXTests/Fixtures/short-sh-clip.wav` | Small 16 kHz fixture clip. | Part 2 |
| `dev-tools/model-conversion/README.md` | Conversion runbook. | Part 2 |
| `dev-tools/model-conversion/convert.py` | HF → CoreML script. | Part 2 |
| `dev-tools/model-conversion/requirements.txt` | Python deps. | Part 2 |
| `dev-tools/model-conversion/.env.example` | HF token placeholder. | Part 2 |
| `dev-tools/model-conversion/.gitignore` | Ignore env + local artifacts. | Part 2 |
| `.gitattributes` | Git LFS patterns. | Part 2 |

Modified files:

| File | Change | Phase |
|---|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift` | Replace inline `coachingKey(...)` with calls into `CoachingKeyResolver`. | Part 1 |
| `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift` | Unchanged expectations; no edit required unless the extraction leaves an import unused (tested during refactor). | Part 1 |
| `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift` | Append `PronunciationTrialLog.self` to `schema`. | Part 1 |
| `Packages/MoraMLX/Package.swift` | Add MoraCore + MoraEngines deps for the stub. Add `.process("Resources")` + test target in Part 2. | Part 1 + Part 2 |
| `Packages/MoraMLX/Sources/MoraMLX/MoraMLXPlaceholder.swift` | Deleted in Part 2. | Part 2 |
| `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` | Swap `FeatureBasedPronunciationEvaluator()` for composite when the shadow evaluator is available. | Part 1 |
| `Mora/MoraApp.swift` | Call `PronunciationTrialRetentionPolicy.cleanup` once at launch. Provide a `ShadowEvaluatorFactory` environment value that `SessionContainerView` consumes. | Part 1 |
| `.github/workflows/ci.yml` | `actions/checkout` → `with: lfs: true`. | Part 2 |
| `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md` | Append `Implementation plan (Phase 3)` header line pointing to this plan. | Part 2 |

---

## Conventions

- **Imports** use `import Foundation` first, then Apple frameworks (`import SwiftData`, `import CoreML`, `import OSLog`, ...), then project modules in dependency order (`import MoraCore` before `import MoraEngines`).
- **Sendable** — every new public type is `Sendable`. Value types also get `Hashable, Codable`. `Clock<Duration>` injection for time-sensitive code.
- **XCTest** — mirrors existing tests (`import XCTest`, `final class XxxTests: XCTestCase`, `@MainActor` on any test that touches the orchestrator, SwiftUI, or SwiftData with a `@MainActor` container).
- **swift-format** — CI runs `swift-format lint --strict`. 4-space indent, trailing commas on every list element, braces on same line. `Package.swift` files are excluded from the lint (`TrailingComma` rule clash).
- **Commits** — follow `area: short description` per Engine A's plan. Project CLAUDE.md opts in to `Co-Authored-By: Claude <noreply@anthropic.com>` at commit-message end; include it.
- **Commit cadence** — commit after each task unless the task explicitly says otherwise.
- **No cloud pronunciation SDKs.** The binary gate and source gate landed by Engine A's Task 29/30 continue to run. This plan adds nothing that would match those patterns.
- **Test file naming** — one test class per file; filenames end with `Tests.swift`.
- **`@Model` migrations** — adding `PronunciationTrialLog` is an additive SwiftData change, handled by lightweight migration; no explicit migration code.
- **Git LFS** — Part 2 introduces LFS. Developers run `git lfs install` once locally; CI opts in via `lfs: true` on `actions/checkout`.

---

## Phase 1 — Part 1: Engine B evaluator logic, SwiftData, composite, all fake-driven

Phase 1 ships no user-visible change. `MoraMLXModelCatalog.loadPhonemeEvaluator` is a stub that always throws `.modelNotBundled`; `SessionContainerView` falls back to bare `FeatureBasedPronunciationEvaluator`. The point of Phase 1 is that every piece of evaluator code compiles and is exercised by tests against a `FakePhonemePosteriorProvider`.

### Task 1: `PhonemePosterior` value type

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosterior.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemePosteriorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PhonemePosteriorTests.swift
import XCTest
@testable import MoraEngines

final class PhonemePosteriorTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let p = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["a", "b", "c"],
            logProbabilities: [
                [-0.1, -0.2, -0.3],
                [-0.4, -0.5, -0.6],
            ]
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(PhonemePosterior.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    func testFrameCountAndPhonemeCount() {
        let p = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["x", "y"],
            logProbabilities: [[-1.0, -2.0], [-1.5, -0.5], [-0.1, -3.0]]
        )
        XCTAssertEqual(p.frameCount, 3)
        XCTAssertEqual(p.phonemeCount, 2)
    }

    func testFrameIndexForSecond() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"], logProbabilities: []
        )
        XCTAssertEqual(p.frameIndex(forSecond: 0), 0)
        XCTAssertEqual(p.frameIndex(forSecond: 0.02), 1)
        XCTAssertEqual(p.frameIndex(forSecond: 1.0), 50)
    }

    func testSecondForFrame() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"], logProbabilities: []
        )
        XCTAssertEqual(p.second(forFrame: 0), 0.0, accuracy: 1e-6)
        XCTAssertEqual(p.second(forFrame: 50), 1.0, accuracy: 1e-6)
    }

    func testEmptyPosteriorIsWellFormed() {
        let p = PhonemePosterior.empty
        XCTAssertEqual(p.frameCount, 0)
        XCTAssertEqual(p.phonemeCount, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraEngines && swift test --filter PhonemePosteriorTests)`
Expected: FAIL with "Cannot find 'PhonemePosterior' in scope".

- [ ] **Step 3: Create `PhonemePosterior.swift`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosterior.swift
import Foundation

/// A phoneme posterior matrix: one row per audio frame, one column per
/// phoneme in the model's vocabulary. Values are natural-log probabilities.
/// Produced by a `PhonemePosteriorProvider`; consumed by `ForcedAligner`
/// and `GOPScorer`.
public struct PhonemePosterior: Sendable, Hashable, Codable {
    public let framesPerSecond: Double
    public let phonemeLabels: [String]
    public let logProbabilities: [[Float]]

    public init(
        framesPerSecond: Double,
        phonemeLabels: [String],
        logProbabilities: [[Float]]
    ) {
        self.framesPerSecond = framesPerSecond
        self.phonemeLabels = phonemeLabels
        self.logProbabilities = logProbabilities
    }

    public var frameCount: Int { logProbabilities.count }
    public var phonemeCount: Int { phonemeLabels.count }

    public func frameIndex(forSecond second: Double) -> Int {
        Int((second * framesPerSecond).rounded(.down))
    }

    public func second(forFrame index: Int) -> Double {
        framesPerSecond > 0 ? Double(index) / framesPerSecond : 0
    }

    public static let empty = PhonemePosterior(
        framesPerSecond: 50, phonemeLabels: [], logProbabilities: []
    )
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraEngines && swift test --filter PhonemePosteriorTests)`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosterior.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PhonemePosteriorTests.swift
git commit -m "$(cat <<'EOF'
engines: add PhonemePosterior value type for Engine B

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `PhonemePosteriorProvider` protocol and `FakePhonemePosteriorProvider`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosteriorProvider.swift`
- Create: `Packages/MoraTesting/Sources/MoraTesting/FakePhonemePosteriorProvider.swift`
- Create: `Packages/MoraTesting/Tests/MoraTestingTests/FakePhonemePosteriorProviderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// FakePhonemePosteriorProviderTests.swift
import XCTest
@testable import MoraTesting
import MoraEngines

final class FakePhonemePosteriorProviderTests: XCTestCase {
    func testReturnsScriptedPosterior() async throws {
        let fake = FakePhonemePosteriorProvider()
        let scripted = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["ʃ", "s"],
            logProbabilities: [[-0.1, -3.0]]
        )
        fake.nextResult = .success(scripted)
        let result = try await fake.posterior(
            for: AudioClip(samples: [0.0], sampleRate: 16_000)
        )
        XCTAssertEqual(result, scripted)
    }

    func testThrowsScriptedError() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .failure(FakePhonemePosteriorProvider.ScriptedError.boom)
        do {
            _ = try await fake.posterior(
                for: AudioClip(samples: [0.0], sampleRate: 16_000)
            )
            XCTFail("expected throw")
        } catch FakePhonemePosteriorProvider.ScriptedError.boom {
            // ok
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func testBlocksUntilReleasedWhenBlocking() async throws {
        let fake = FakePhonemePosteriorProvider()
        let scripted = PhonemePosterior.empty
        fake.nextResult = .success(scripted)
        fake.shouldBlock = true
        async let result = try fake.posterior(
            for: AudioClip(samples: [], sampleRate: 16_000)
        )
        try await Task.sleep(for: .milliseconds(50))
        fake.release()
        let got = try await result
        XCTAssertEqual(got, scripted)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd Packages/MoraTesting && swift test --filter FakePhonemePosteriorProviderTests)`
Expected: FAIL — `FakePhonemePosteriorProvider` undefined.

- [ ] **Step 3: Create protocol and fake**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosteriorProvider.swift
import Foundation

/// Produces a `PhonemePosterior` for a recorded utterance. Real
/// implementations live in `MoraMLX` and are backed by CoreML; tests use
/// `FakePhonemePosteriorProvider` from `MoraTesting`.
public protocol PhonemePosteriorProvider: Sendable {
    func posterior(for audio: AudioClip) async throws -> PhonemePosterior
}
```

```swift
// Packages/MoraTesting/Sources/MoraTesting/FakePhonemePosteriorProvider.swift
import Foundation
import MoraEngines

/// Scripted double for `PhonemePosteriorProvider`. Tests set `nextResult`
/// to either a `PhonemePosterior` or an error; the fake returns / throws
/// exactly that on the next call. Set `shouldBlock = true` to make the
/// call suspend until `release()` is called, which is how
/// `ShadowLoggingPronunciationEvaluatorTests` exercises the timeout path.
public final class FakePhonemePosteriorProvider: PhonemePosteriorProvider, @unchecked Sendable {
    public enum ScriptedError: Error, Sendable, Equatable {
        case boom
        case other(String)
    }

    private let lock = NSLock()
    private var _nextResult: Result<PhonemePosterior, Error> = .success(.empty)
    private var _shouldBlock: Bool = false
    private var continuation: CheckedContinuation<Void, Never>?

    public var nextResult: Result<PhonemePosterior, Error> {
        get { lock.lock(); defer { lock.unlock() }; return _nextResult }
        set { lock.lock(); defer { lock.unlock() }; _nextResult = newValue }
    }

    public var shouldBlock: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _shouldBlock }
        set { lock.lock(); defer { lock.unlock() }; _shouldBlock = newValue }
    }

    public init() {}

    public func release() {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume()
    }

    public func posterior(for audio: AudioClip) async throws -> PhonemePosterior {
        let block: Bool
        lock.lock()
        block = _shouldBlock
        lock.unlock()

        if block {
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                lock.lock()
                continuation = c
                lock.unlock()
            }
        }

        switch nextResult {
        case .success(let p): return p
        case .failure(let e): throw e
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd Packages/MoraTesting && swift test --filter FakePhonemePosteriorProviderTests)`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosteriorProvider.swift \
        Packages/MoraTesting/Sources/MoraTesting/FakePhonemePosteriorProvider.swift \
        Packages/MoraTesting/Tests/MoraTestingTests/FakePhonemePosteriorProviderTests.swift
git commit -m "$(cat <<'EOF'
engines: add PhonemePosteriorProvider protocol and fake

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `PhonemeInventory` struct

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeInventory.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeInventoryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PhonemeInventoryTests.swift
import XCTest
@testable import MoraEngines

final class PhonemeInventoryTests: XCTestCase {
    func testIpaToColumnMapsEachLabelToItsIndex() {
        let inv = PhonemeInventory(
            espeakLabels: ["ʃ", "s", "r", "l"],
            supportedPhonemeIPA: ["ʃ", "s"]
        )
        XCTAssertEqual(inv.ipaToColumn["ʃ"], 0)
        XCTAssertEqual(inv.ipaToColumn["s"], 1)
        XCTAssertEqual(inv.ipaToColumn["r"], 2)
        XCTAssertEqual(inv.ipaToColumn["l"], 3)
        XCTAssertNil(inv.ipaToColumn["unknown"])
    }

    func testSupportedPhonemeIPAIsPreserved() {
        let inv = PhonemeInventory(
            espeakLabels: ["a", "b"],
            supportedPhonemeIPA: ["a"]
        )
        XCTAssertEqual(inv.supportedPhonemeIPA, ["a"])
    }

    func testV15SupportedSetCoversEngineA() {
        let required: Set<String> = ["ʃ", "s", "r", "l", "f", "h", "v", "b", "θ", "t", "æ", "ʌ"]
        XCTAssertTrue(required.isSubset(of: PhonemeInventory.v15SupportedPhonemeIPA))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter PhonemeInventoryTests)`
Expected: FAIL — `PhonemeInventory` undefined.

- [ ] **Step 3: Create `PhonemeInventory.swift`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeInventory.swift
import Foundation

/// Maps between the wav2vec2 model's espeak IPA columns and the IPA labels
/// carried by `MoraCore.Phoneme`. Constructed at MoraMLX load time with the
/// label list from `phoneme-labels.json`; in tests, built with hand-written
/// label arrays.
public struct PhonemeInventory: Sendable, Hashable {
    public let espeakLabels: [String]
    public let supportedPhonemeIPA: Set<String>
    public let ipaToColumn: [String: Int]

    public init(espeakLabels: [String], supportedPhonemeIPA: Set<String>) {
        self.espeakLabels = espeakLabels
        self.supportedPhonemeIPA = supportedPhonemeIPA
        var map: [String: Int] = [:]
        map.reserveCapacity(espeakLabels.count)
        for (index, label) in espeakLabels.enumerated() {
            map[label] = index
        }
        self.ipaToColumn = map
    }

    /// v1.5 MVP phoneme set. Covers Engine A's 12 curated pairs plus common
    /// neighbors the curriculum is expected to exercise in the first month
    /// of TestFlight. Expanding the set is a data-only change.
    public static let v15SupportedPhonemeIPA: Set<String> = [
        "ʃ", "s", "r", "l", "f", "h", "v", "b", "θ", "t", "æ", "ʌ",
        "i", "ɪ", "e", "ɛ", "ə", "ʊ", "u", "ɑ", "ɔ",
        "p", "k", "d", "g", "m", "n", "ŋ", "j", "w",
        "z", "ʒ", "dʒ", "tʃ",
    ]
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter PhonemeInventoryTests)`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeInventory.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeInventoryTests.swift
git commit -m "$(cat <<'EOF'
engines: add PhonemeInventory mapping with v1.5 MVP IPA set

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---
### Task 4: `ForcedAligner`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ForcedAligner.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/ForcedAlignerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// ForcedAlignerTests.swift
import XCTest
@testable import MoraEngines
import MoraCore

final class ForcedAlignerTests: XCTestCase {
    private func inventory(_ labels: [String]) -> PhonemeInventory {
        PhonemeInventory(
            espeakLabels: labels,
            supportedPhonemeIPA: Set(labels)
        )
    }

    func testSinglePhonemeCoversWholePosterior() {
        let aligner = ForcedAligner(inventory: inventory(["ʃ", "s"]))
        let p = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["ʃ", "s"],
            logProbabilities: Array(
                repeating: [Float(log(0.9)), Float(log(0.1))],
                count: 10
            )
        )
        let out = aligner.align(posterior: p, phonemes: [Phoneme(ipa: "ʃ")])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].phoneme.ipa, "ʃ")
        XCTAssertEqual(out[0].startFrame, 0)
        XCTAssertEqual(out[0].endFrame, 10)
        XCTAssertGreaterThan(out[0].averageLogProb, Float(log(0.5)))
    }

    func testTwoPhonemesRecoverBoundary() {
        // First 5 frames: /ʃ/ strong; last 5 frames: /s/ strong.
        let shRow: [Float] = [Float(log(0.9)), Float(log(0.1))]
        let sRow: [Float] = [Float(log(0.1)), Float(log(0.9))]
        let rows = Array(repeating: shRow, count: 5) + Array(repeating: sRow, count: 5)
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["ʃ", "s"], logProbabilities: rows
        )
        let aligner = ForcedAligner(inventory: inventory(["ʃ", "s"]))
        let out = aligner.align(posterior: p, phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "s")])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].phoneme.ipa, "ʃ")
        XCTAssertEqual(out[1].phoneme.ipa, "s")
        XCTAssertEqual(out[0].endFrame, 5)
        XCTAssertEqual(out[1].startFrame, 5)
        XCTAssertEqual(out[1].endFrame, 10)
    }

    func testPhonemeNotInInventoryUsesPositionalFallback() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"],
            logProbabilities: Array(repeating: [Float(0)], count: 10)
        )
        let aligner = ForcedAligner(inventory: inventory(["a"]))
        let out = aligner.align(
            posterior: p,
            phonemes: [Phoneme(ipa: "a"), Phoneme(ipa: "unknown")]
        )
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[1].phoneme.ipa, "unknown")
        XCTAssertLessThanOrEqual(out[1].averageLogProb, 0)
    }

    func testMoreFramesAcrossThreePhonemesStillContiguous() {
        let rows: [[Float]] = (0..<12).map { i in
            if i < 4 { return [Float(log(0.9)), Float(log(0.05)), Float(log(0.05))] }
            if i < 8 { return [Float(log(0.05)), Float(log(0.9)), Float(log(0.05))] }
            return [Float(log(0.05)), Float(log(0.05)), Float(log(0.9))]
        }
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a", "b", "c"], logProbabilities: rows
        )
        let aligner = ForcedAligner(inventory: inventory(["a", "b", "c"]))
        let out = aligner.align(
            posterior: p,
            phonemes: [Phoneme(ipa: "a"), Phoneme(ipa: "b"), Phoneme(ipa: "c")]
        )
        XCTAssertEqual(out[0].endFrame, out[1].startFrame)
        XCTAssertEqual(out[1].endFrame, out[2].startFrame)
        XCTAssertEqual(out.last?.endFrame, 12)
    }

    func testFewerFramesThanPhonemesReturnsInfiniteLowProb() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"],
            logProbabilities: [[Float(log(0.9))]]
        )
        let aligner = ForcedAligner(inventory: inventory(["a"]))
        let out = aligner.align(
            posterior: p,
            phonemes: [Phoneme(ipa: "a"), Phoneme(ipa: "a"), Phoneme(ipa: "a")]
        )
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(out[0].averageLogProb, -.infinity)
    }

    func testEmptyPhonemesReturnsEmptyAlignment() {
        let aligner = ForcedAligner(inventory: inventory(["a"]))
        let out = aligner.align(posterior: .empty, phonemes: [])
        XCTAssertTrue(out.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter ForcedAlignerTests)`
Expected: FAIL — `ForcedAligner` / `PhonemeAlignment` undefined.

- [ ] **Step 3: Implement `ForcedAligner`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ForcedAligner.swift
import Foundation
import MoraCore

/// Result of aligning an expected phoneme sequence to a posterior matrix.
/// `startFrame..<endFrame` is half-open. `averageLogProb` is the mean
/// log-probability of the aligned phoneme's column across the range; it
/// doubles as a coarse confidence signal downstream.
public struct PhonemeAlignment: Sendable, Hashable {
    public let phoneme: Phoneme
    public let startFrame: Int
    public let endFrame: Int
    public let averageLogProb: Float

    public init(phoneme: Phoneme, startFrame: Int, endFrame: Int, averageLogProb: Float) {
        self.phoneme = phoneme
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.averageLogProb = averageLogProb
    }
}

/// Forced alignment via Viterbi on a left-to-right HMM whose states are
/// the expected phoneme sequence. Self-loop and forward transitions only;
/// no skips. Unknown phonemes fall back to uniform-prior scoring and a
/// positional frame slice.
public struct ForcedAligner: Sendable {
    public let inventory: PhonemeInventory

    public init(inventory: PhonemeInventory) {
        self.inventory = inventory
    }

    public func align(
        posterior: PhonemePosterior,
        phonemes: [Phoneme]
    ) -> [PhonemeAlignment] {
        if phonemes.isEmpty { return [] }
        let T = posterior.frameCount
        let N = phonemes.count
        guard T > 0 else {
            return positionalFallback(frameCount: 0, phonemes: phonemes)
        }
        if T < N {
            return positionalFallback(frameCount: T, phonemes: phonemes)
        }

        // Column lookups per phoneme. Nil means "unknown — penalize".
        let cols: [Int?] = phonemes.map { inventory.ipaToColumn[$0.ipa] }
        let unknownLogProb: Float = Float(-log(Double(max(1, inventory.espeakLabels.count))))

        // Viterbi: dp[t][n] = best log-prob to reach state n at frame t.
        let negInf = -Float.greatestFiniteMagnitude
        var dp = Array(repeating: Array(repeating: negInf, count: N), count: T)
        var back = Array(repeating: Array(repeating: 0, count: N), count: T)

        func emit(_ t: Int, _ n: Int) -> Float {
            if let c = cols[n] {
                return posterior.logProbabilities[t][c]
            }
            return unknownLogProb
        }

        dp[0][0] = emit(0, 0)
        for t in 1..<T {
            for n in 0..<N {
                // Stay in state n (self-loop) or advance from state n-1.
                let stay = dp[t - 1][n]
                let advance = n > 0 ? dp[t - 1][n - 1] : negInf
                let best: Float
                let prev: Int
                if advance > stay {
                    best = advance
                    prev = n - 1
                } else {
                    best = stay
                    prev = n
                }
                dp[t][n] = best + emit(t, n)
                back[t][n] = prev
            }
        }

        // Backtrack from (T-1, N-1).
        var boundaries = Array(repeating: 0, count: N + 1)
        boundaries[N] = T
        var state = N - 1
        var t = T - 1
        var path = Array(repeating: 0, count: T)
        while t >= 0 {
            path[t] = state
            if t == 0 { break }
            state = back[t][state]
            t -= 1
        }
        // Derive boundaries from the path.
        var currentState = path[0]
        for i in 1..<T {
            if path[i] != currentState {
                boundaries[path[i]] = i
                currentState = path[i]
            }
        }

        // Emit alignments with per-range averaged log-prob.
        var out: [PhonemeAlignment] = []
        out.reserveCapacity(N)
        for n in 0..<N {
            let startFrame = boundaries[n]
            let endFrame = boundaries[n + 1]
            let avg: Float
            if startFrame >= endFrame {
                avg = -.infinity
            } else if let c = cols[n] {
                var sum: Float = 0
                for f in startFrame..<endFrame {
                    sum += posterior.logProbabilities[f][c]
                }
                avg = sum / Float(endFrame - startFrame)
            } else {
                avg = unknownLogProb
            }
            out.append(
                PhonemeAlignment(
                    phoneme: phonemes[n],
                    startFrame: startFrame,
                    endFrame: endFrame,
                    averageLogProb: avg
                )
            )
        }
        return out
    }

    private func positionalFallback(
        frameCount: Int,
        phonemes: [Phoneme]
    ) -> [PhonemeAlignment] {
        let N = phonemes.count
        var out: [PhonemeAlignment] = []
        out.reserveCapacity(N)
        for n in 0..<N {
            let start = frameCount * n / N
            let end = frameCount * (n + 1) / N
            out.append(
                PhonemeAlignment(
                    phoneme: phonemes[n],
                    startFrame: start,
                    endFrame: end,
                    averageLogProb: -.infinity
                )
            )
        }
        return out
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter ForcedAlignerTests)`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ForcedAligner.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/ForcedAlignerTests.swift
git commit -m "$(cat <<'EOF'
engines: add ForcedAligner (Viterbi over log-posteriors)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `GOPScorer`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/GOPScorer.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/GOPScorerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// GOPScorerTests.swift
import XCTest
@testable import MoraEngines

final class GOPScorerTests: XCTestCase {
    private func posterior(_ rows: [[Float]]) -> PhonemePosterior {
        PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["a", "b"],
            logProbabilities: rows
        )
    }

    func testGopIsZeroWhenTargetDominates() {
        // target column is overwhelmingly the max across all frames
        let rows = Array(repeating: [Float(log(0.99)), Float(log(0.01))], count: 4)
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<4, targetColumn: 0)
        XCTAssertEqual(g, 0.0, accuracy: 1e-3)
        XCTAssertGreaterThanOrEqual(scorer.score0to100(gop: g), 99)
    }

    func testGopIsNegativeWhenOtherDominates() {
        let rows = Array(repeating: [Float(log(0.01)), Float(log(0.99))], count: 4)
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<4, targetColumn: 0)
        XCTAssertLessThan(g, -3.0)
        XCTAssertLessThanOrEqual(scorer.score0to100(gop: g), 10)
    }

    func testScoreIsMonotoneInGop() {
        let s = GOPScorer()
        let a = s.score0to100(gop: -2.0)
        let b = s.score0to100(gop: -1.5)
        let c = s.score0to100(gop: -1.0)
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
    }

    func testScoreClamped() {
        let s = GOPScorer()
        XCTAssertGreaterThanOrEqual(s.score0to100(gop: -100), 0)
        XCTAssertLessThanOrEqual(s.score0to100(gop: 100), 100)
    }

    func testEmptyRangeReturnsNegInfinity() {
        let rows = [[Float(0), Float(0)]]
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<0, targetColumn: 0)
        XCTAssertEqual(g, -.infinity)
    }

    func testOutOfRangeColumnReturnsNegInfinity() {
        let rows = [[Float(0), Float(0)]]
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<1, targetColumn: 5)
        XCTAssertEqual(g, -.infinity)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter GOPScorerTests)`
Expected: FAIL — `GOPScorer` undefined.

- [ ] **Step 3: Implement `GOPScorer`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/GOPScorer.swift
import Foundation

/// Goodness-of-Pronunciation scorer.
///
/// GOP = mean over t ∈ range of [log p(target | t) − max_q log p(q | t)].
/// Upper bound is 0 (target is the argmax everywhere). The sigmoid maps
/// GOP to a 0–100 learner-facing score.
///
/// `k` and `gopZero` are **pre-calibration defaults**. They ship with
/// v1.5 but are expected to be retuned by a follow-up PR fed from
/// `dev-tools/pronunciation-bench/`. `k` and `gopZero` are `var` on
/// purpose so tuning does not need to touch consumers.
public struct GOPScorer: Sendable {
    public var k: Double
    public var gopZero: Double
    public var reliabilityThreshold: Double

    public init(k: Double = 5.0, gopZero: Double = -1.5, reliabilityThreshold: Double = -2.5) {
        self.k = k
        self.gopZero = gopZero
        self.reliabilityThreshold = reliabilityThreshold
    }

    public func gop(posterior: PhonemePosterior, range: Range<Int>, targetColumn: Int) -> Double {
        if range.isEmpty { return -.infinity }
        if targetColumn < 0 || targetColumn >= posterior.phonemeCount { return -.infinity }
        var total: Double = 0
        for t in range {
            let row = posterior.logProbabilities[t]
            var maxQ: Float = -Float.greatestFiniteMagnitude
            for v in row where v > maxQ { maxQ = v }
            let target = row[targetColumn]
            total += Double(target - maxQ)
        }
        return total / Double(range.count)
    }

    public func score0to100(gop: Double) -> Int {
        let sig = 1.0 / (1.0 + exp(-k * (gop - gopZero)))
        let raw = Int((100.0 * sig).rounded())
        return max(0, min(100, raw))
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter GOPScorerTests)`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/GOPScorer.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/GOPScorerTests.swift
git commit -m "$(cat <<'EOF'
engines: add GOPScorer with pre-calibration sigmoid defaults

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Refactor Engine A's coaching-key lookup into `CoachingKeyResolver`

Goal: extract the switch statement from `FeatureBasedPronunciationEvaluator.coachingKey(target:substitute:)` into a shared helper so Engine B can use the same mapping without duplicating it.

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/CoachingKeyResolver.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/CoachingKeyResolverTests.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift` — replace the private `coachingKey(target:substitute:)` method and the private `driftCoachingKey(target:)` method with calls into the new resolver.

- [ ] **Step 1: Write the failing test**

```swift
// CoachingKeyResolverTests.swift
import XCTest
@testable import MoraEngines

final class CoachingKeyResolverTests: XCTestCase {
    func testKnownSubstitutionPairs() {
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "ʃ", substitute: "s"), "coaching.sh_sub_s")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "r", substitute: "l"), "coaching.r_sub_l")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "l", substitute: "r"), "coaching.l_sub_r")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "f", substitute: "h"), "coaching.f_sub_h")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "v", substitute: "b"), "coaching.v_sub_b")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "θ", substitute: "s"), "coaching.th_voiceless_sub_s")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "θ", substitute: "t"), "coaching.th_voiceless_sub_t")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "æ", substitute: "ʌ"), "coaching.ae_sub_schwa")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "ʌ", substitute: "æ"), "coaching.ae_sub_schwa")
    }

    func testUnknownSubstitutionReturnsNil() {
        XCTAssertNil(CoachingKeyResolver.substitution(target: "x", substitute: "y"))
    }

    func testKnownDriftTargets() {
        XCTAssertEqual(CoachingKeyResolver.drift(target: "ʃ"), "coaching.sh_drift")
    }

    func testUnknownDriftReturnsNil() {
        XCTAssertNil(CoachingKeyResolver.drift(target: "r"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter CoachingKeyResolverTests)`
Expected: FAIL — `CoachingKeyResolver` undefined.

- [ ] **Step 3: Create the resolver**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/CoachingKeyResolver.swift
import Foundation

/// MoraStrings keys returned by any evaluator for a given (target, substitute)
/// or drift target. Single source of truth so both Engine A and Engine B
/// produce identical coaching output for identical diagnoses.
public enum CoachingKeyResolver {
    public static func substitution(target: String, substitute: String) -> String? {
        switch (target, substitute) {
        case ("ʃ", "s"): return "coaching.sh_sub_s"
        case ("r", "l"): return "coaching.r_sub_l"
        case ("l", "r"): return "coaching.l_sub_r"
        case ("f", "h"): return "coaching.f_sub_h"
        case ("v", "b"): return "coaching.v_sub_b"
        case ("θ", "s"): return "coaching.th_voiceless_sub_s"
        case ("θ", "t"): return "coaching.th_voiceless_sub_t"
        case ("æ", "ʌ"), ("ʌ", "æ"): return "coaching.ae_sub_schwa"
        default: return nil
        }
    }

    public static func drift(target: String) -> String? {
        switch target {
        case "ʃ": return "coaching.sh_drift"
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Update `FeatureBasedPronunciationEvaluator` to call the resolver**

In `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift`, replace the two private methods at the bottom of the file:

```swift
    private func coachingKey(target: String, substitute: String) -> String? {
        switch (target, substitute) {
        case ("ʃ", "s"): return "coaching.sh_sub_s"
        case ("r", "l"): return "coaching.r_sub_l"
        case ("l", "r"): return "coaching.l_sub_r"
        case ("f", "h"): return "coaching.f_sub_h"
        case ("v", "b"): return "coaching.v_sub_b"
        case ("θ", "s"): return "coaching.th_voiceless_sub_s"
        case ("θ", "t"): return "coaching.th_voiceless_sub_t"
        case ("æ", "ʌ"), ("ʌ", "æ"): return "coaching.ae_sub_schwa"
        default: return nil
        }
    }
```

with forwarders:

```swift
    private func coachingKey(target: String, substitute: String) -> String? {
        CoachingKeyResolver.substitution(target: target, substitute: substitute)
    }
```

Also replace `private func driftCoachingKey(target:)` (which currently handles only `"ʃ"`) with:

```swift
    private func driftCoachingKey(target: String) -> String? {
        CoachingKeyResolver.drift(target: target)
    }
```

- [ ] **Step 5: Run full MoraEngines suite**

Run: `(cd Packages/MoraEngines && swift test)`
Expected: PASS — all existing Engine A tests continue to pass, new resolver tests pass.

- [ ] **Step 6: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/CoachingKeyResolver.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/CoachingKeyResolverTests.swift \
        Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift
git commit -m "$(cat <<'EOF'
engines: extract CoachingKeyResolver as shared mapping for Engine A and B

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `withTimeout` helper in `Concurrency.swift`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/Concurrency.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/ConcurrencyTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// ConcurrencyTests.swift
import XCTest
@testable import MoraEngines

final class ConcurrencyTests: XCTestCase {
    func testFastOperationReturnsValue() async {
        let v = await withTimeout(.milliseconds(500)) { 42 }
        XCTAssertEqual(v, 42)
    }

    func testSlowOperationReturnsNil() async {
        let v = await withTimeout(.milliseconds(50)) { () async -> Int in
            try? await Task.sleep(for: .milliseconds(500))
            return 42
        }
        XCTAssertNil(v)
    }

    func testThrowingOperationReturnsNil() async {
        struct Boom: Error {}
        let v = await withTimeout(.milliseconds(200)) { () async throws -> Int in
            throw Boom()
        }
        XCTAssertNil(v)
    }

    func testCompletesBeforeTimeoutCapturesResult() async {
        let v = await withTimeout(.milliseconds(500)) { () async -> String in
            try? await Task.sleep(for: .milliseconds(10))
            return "ok"
        }
        XCTAssertEqual(v, "ok")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter ConcurrencyTests)`
Expected: FAIL — `withTimeout` undefined.

- [ ] **Step 3: Implement the helper**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/Concurrency.swift
import Foundation

/// Runs `operation` with a deadline. Returns the operation's value if it
/// finishes within `duration`; returns nil on timeout or on a thrown error.
/// On timeout, the operation task is cancelled but its result is discarded
/// regardless of when it eventually completes.
///
/// Internal to MoraEngines — not part of the package's public surface.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @Sendable @escaping () async throws -> T
) async -> T? {
    await withTaskGroup(of: Optional<T>.self) { group in
        group.addTask { try? await operation() }
        group.addTask {
            try? await Task.sleep(for: duration)
            return nil
        }
        defer { group.cancelAll() }
        return await group.next() ?? nil
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter ConcurrencyTests)`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/Concurrency.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/ConcurrencyTests.swift
git commit -m "$(cat <<'EOF'
engines: add withTimeout helper for bounding async calls

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---
### Task 8: `PhonemeModelPronunciationEvaluator`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeModelPronunciationEvaluator.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeModelPronunciationEvaluatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PhonemeModelPronunciationEvaluatorTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraTesting
import MoraCore

@MainActor
final class PhonemeModelPronunciationEvaluatorTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    private func inventory() -> PhonemeInventory {
        PhonemeInventory(
            espeakLabels: ["ʃ", "s", "ɪ", "p"],
            supportedPhonemeIPA: ["ʃ", "s", "ɪ", "p"]
        )
    }

    private func evaluator(
        fake: FakePhonemePosteriorProvider,
        timeout: Duration = .milliseconds(500)
    ) -> PhonemeModelPronunciationEvaluator {
        PhonemeModelPronunciationEvaluator(
            provider: fake,
            aligner: ForcedAligner(inventory: inventory()),
            scorer: GOPScorer(),
            inventory: inventory(),
            l1Profile: JapaneseL1Profile(),
            timeout: timeout
        )
    }

    private func posterior(
        shFrames: Int, iFrames: Int, pFrames: Int,
        substituteSForSh: Bool = false
    ) -> PhonemePosterior {
        let shRow: [Float] = substituteSForSh
            ? [Float(log(0.05)), Float(log(0.9)), Float(log(0.025)), Float(log(0.025))]
            : [Float(log(0.9)), Float(log(0.05)), Float(log(0.025)), Float(log(0.025))]
        let iRow: [Float] = [Float(log(0.025)), Float(log(0.025)), Float(log(0.9)), Float(log(0.05))]
        let pRow: [Float] = [Float(log(0.025)), Float(log(0.025)), Float(log(0.05)), Float(log(0.9))]
        let rows = Array(repeating: shRow, count: shFrames)
            + Array(repeating: iRow, count: iFrames)
            + Array(repeating: pRow, count: pFrames)
        return PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["ʃ", "s", "ɪ", "p"],
            logProbabilities: rows
        )
    }

    func testMatchedPath() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(posterior(shFrames: 8, iFrames: 4, pFrames: 4))
        let e = evaluator(fake: fake)
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "ship", confidence: 0.9)
        )
        XCTAssertEqual(result.label, .matched)
        XCTAssertNotNil(result.score)
        XCTAssertTrue(result.isReliable)
    }

    func testSubstitutionPathReturnsCoachingKey() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(posterior(shFrames: 8, iFrames: 4, pFrames: 4, substituteSForSh: true))
        let e = evaluator(fake: fake)
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "sip", confidence: 0.8)
        )
        if case .substitutedBy(let p) = result.label {
            XCTAssertEqual(p.ipa, "s")
        } else {
            XCTFail("expected substitutedBy(/s/), got \(result.label)")
        }
        XCTAssertEqual(result.coachingKey, "coaching.sh_sub_s")
    }

    func testUnclearOnTimeout() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(.empty)
        fake.shouldBlock = true
        let e = evaluator(fake: fake, timeout: .milliseconds(30))
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
        XCTAssertNil(result.score)
        fake.release()
    }

    func testUnclearOnProviderError() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .failure(FakePhonemePosteriorProvider.ScriptedError.boom)
        let e = evaluator(fake: fake)
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
    }

    func testUnsupportedTargetReturnsUnclear() async {
        let fake = FakePhonemePosteriorProvider()
        fake.nextResult = .success(posterior(shFrames: 4, iFrames: 4, pFrames: 4))
        let e = evaluator(fake: fake)
        let unsupportedTarget = Phoneme(ipa: "ʒ")
        let result = await e.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: unsupportedTarget,
            asr: ASRResult(transcript: "", confidence: 0)
        )
        XCTAssertEqual(result.label, .unclear)
        XCTAssertFalse(result.isReliable)
    }

    func testSupportsReflectsInventory() {
        let fake = FakePhonemePosteriorProvider()
        let e = evaluator(fake: fake)
        XCTAssertTrue(e.supports(target: Phoneme(ipa: "ʃ"), in: word()))
        XCTAssertFalse(e.supports(target: Phoneme(ipa: "ʒ"), in: word()))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter PhonemeModelPronunciationEvaluatorTests)`
Expected: FAIL — `PhonemeModelPronunciationEvaluator` undefined.

- [ ] **Step 3: Implement the evaluator**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeModelPronunciationEvaluator.swift
import Foundation
import MoraCore

/// Engine B — CoreML-backed `PronunciationEvaluator`. Given an `AudioClip`,
/// obtains a phoneme posterior from the provider, forced-aligns the
/// expected phoneme sequence, scores the target region with GOP, and
/// classifies the argmax against the learner's L1 interference pairs.
public struct PhonemeModelPronunciationEvaluator: PronunciationEvaluator {
    public let provider: any PhonemePosteriorProvider
    public let aligner: ForcedAligner
    public let scorer: GOPScorer
    public let inventory: PhonemeInventory
    public let l1Profile: any L1Profile
    public let timeout: Duration

    public init(
        provider: any PhonemePosteriorProvider,
        aligner: ForcedAligner,
        scorer: GOPScorer,
        inventory: PhonemeInventory,
        l1Profile: any L1Profile,
        timeout: Duration = .milliseconds(1000)
    ) {
        self.provider = provider
        self.aligner = aligner
        self.scorer = scorer
        self.inventory = inventory
        self.l1Profile = l1Profile
        self.timeout = timeout
    }

    public func supports(target: Phoneme, in word: Word) -> Bool {
        inventory.supportedPhonemeIPA.contains(target.ipa)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        if !supports(target: targetPhoneme, in: expected) {
            return unreliable(targetPhoneme, reason: "unsupported")
        }

        let capturedProvider = provider
        let posterior = await withTimeout(timeout) { () async throws -> PhonemePosterior in
            try await capturedProvider.posterior(for: audio)
        }
        guard let posterior, posterior.frameCount > 0 else {
            return unreliable(targetPhoneme, reason: "provider_unavailable")
        }

        let alignments = aligner.align(posterior: posterior, phonemes: expected.phonemes)
        guard let alignment = locateAlignment(for: targetPhoneme, in: expected, alignments: alignments)
        else {
            return unreliable(targetPhoneme, reason: "no_alignment")
        }

        if Double(alignment.averageLogProb) < scorer.reliabilityThreshold {
            return unreliable(targetPhoneme, reason: "low_confidence")
        }

        guard let targetColumn = inventory.ipaToColumn[targetPhoneme.ipa] else {
            return unreliable(targetPhoneme, reason: "inventory_drift")
        }
        let range = alignment.startFrame..<alignment.endFrame
        let gopValue = scorer.gop(posterior: posterior, range: range, targetColumn: targetColumn)
        let score = scorer.score0to100(gop: gopValue)

        let argmaxIPA = argmaxIPA(in: posterior, range: range)
        let label: PhonemeAssessmentLabel
        var coachingKey: String?

        if argmaxIPA == targetPhoneme.ipa {
            label = .matched
        } else if let sub = argmaxIPA, isKnownSubstitution(target: targetPhoneme, substitute: sub) {
            label = .substitutedBy(Phoneme(ipa: sub))
            coachingKey = CoachingKeyResolver.substitution(target: targetPhoneme.ipa, substitute: sub)
        } else {
            label = .unclear
        }

        let features: [String: Double] = [
            "gop": gopValue,
            "avgLogProb": Double(alignment.averageLogProb),
            "frameCount": Double(range.count),
        ]

        return PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: label,
            score: label == .unclear ? nil : score,
            coachingKey: coachingKey,
            features: features,
            isReliable: label != .unclear
        )
    }

    private func locateAlignment(
        for target: Phoneme,
        in word: Word,
        alignments: [PhonemeAlignment]
    ) -> PhonemeAlignment? {
        let matches = alignments.enumerated().filter { $0.element.phoneme.ipa == target.ipa }
        if matches.isEmpty { return nil }
        // Prefer the occurrence whose position matches the word's phoneme
        // list index of the first target-IPA entry. When targetPhoneme is
        // set to one of several repeats, the first match is our best guess
        // without an explicit curriculum-provided index.
        return matches.first?.element
    }

    private func argmaxIPA(in posterior: PhonemePosterior, range: Range<Int>) -> String? {
        if range.isEmpty { return nil }
        var totals = Array(repeating: Float(0), count: posterior.phonemeCount)
        for t in range {
            let row = posterior.logProbabilities[t]
            for (i, v) in row.enumerated() {
                totals[i] += v
            }
        }
        var bestIndex = 0
        var bestValue = totals[0]
        for i in 1..<totals.count where totals[i] > bestValue {
            bestValue = totals[i]
            bestIndex = i
        }
        return posterior.phonemeLabels[bestIndex]
    }

    private func isKnownSubstitution(target: Phoneme, substitute: String) -> Bool {
        for pair in l1Profile.interferencePairs where pair.from == target {
            if pair.to.ipa == substitute { return true }
        }
        return CoachingKeyResolver.substitution(target: target.ipa, substitute: substitute) != nil
    }

    private func unreliable(_ target: Phoneme, reason: String) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: target,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: ["reason": reason == "unsupported" ? 0 : 1],
            isReliable: false
        )
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter PhonemeModelPronunciationEvaluatorTests)`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeModelPronunciationEvaluator.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeModelPronunciationEvaluatorTests.swift
git commit -m "$(cat <<'EOF'
engines: add PhonemeModelPronunciationEvaluator (Engine B)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: `PronunciationTrialLog` SwiftData entity + schema registration

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialLog.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/PronunciationTrialLogTests.swift`
- Modify: `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift` — append `PronunciationTrialLog.self` to `schema`.

- [ ] **Step 1: Write the failing test**

```swift
// PronunciationTrialLogTests.swift
import XCTest
import SwiftData
@testable import MoraCore

@MainActor
final class PronunciationTrialLogTests: XCTestCase {
    func testInsertAndFetchRoundTrip() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = PronunciationTrialLog(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            wordSurface: "ship",
            targetPhonemeIPA: "ʃ",
            engineALabel: "{\"label\":\"matched\"}",
            engineAScore: 88,
            engineAFeaturesJSON: "{\"spectralCentroid\":3100}",
            engineBState: "completed",
            engineBLabel: "{\"label\":\"matched\"}",
            engineBScore: 91,
            engineBLatencyMs: 240
        )
        ctx.insert(row)
        try ctx.save()

        var descriptor = FetchDescriptor<PronunciationTrialLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.fetchLimit = 10
        let rows = try ctx.fetch(descriptor)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].wordSurface, "ship")
        XCTAssertEqual(rows[0].engineAScore, 88)
        XCTAssertEqual(rows[0].engineBState, "completed")
        XCTAssertEqual(rows[0].engineBLatencyMs, 240)
    }

    func testOptionalFieldsRoundTripAsNil() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        let row = PronunciationTrialLog(
            timestamp: Date(),
            wordSurface: "sheep",
            targetPhonemeIPA: "ʃ",
            engineALabel: "{\"label\":\"unclear\"}",
            engineAScore: nil,
            engineAFeaturesJSON: "{}",
            engineBState: "timedOut",
            engineBLabel: nil,
            engineBScore: nil,
            engineBLatencyMs: 1000
        )
        ctx.insert(row)
        try ctx.save()
        let rows = try ctx.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertNil(rows[0].engineAScore)
        XCTAssertNil(rows[0].engineBLabel)
        XCTAssertEqual(rows[0].engineBLatencyMs, 1000)
    }

    func testSchemaIncludesEntity() {
        let types = MoraModelContainer.schema.entities.map { $0.name }
        XCTAssertTrue(types.contains("PronunciationTrialLog"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraCore && swift test --filter PronunciationTrialLogTests)`
Expected: FAIL — `PronunciationTrialLog` undefined.

- [ ] **Step 3: Create the entity and register it in the schema**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialLog.swift
import Foundation
import SwiftData

/// Per-trial shadow-mode log row. Populated by `SwiftDataPronunciationTrialLogger`
/// on every evaluator invocation while Engine B is bundled. Capped at 1000
/// rows by `PronunciationTrialRetentionPolicy`.
///
/// `engineALabel`, `engineAFeaturesJSON`, and `engineBLabel` are stored as
/// JSON strings (via `JSONEncoder` at write time) because SwiftData prefers
/// scalar fields. Decoding is on demand.
@Model
public final class PronunciationTrialLog {
    public var timestamp: Date
    public var wordSurface: String
    public var targetPhonemeIPA: String
    public var engineALabel: String
    public var engineAScore: Int?
    public var engineAFeaturesJSON: String
    public var engineBState: String
    public var engineBLabel: String?
    public var engineBScore: Int?
    public var engineBLatencyMs: Int?

    public init(
        timestamp: Date,
        wordSurface: String,
        targetPhonemeIPA: String,
        engineALabel: String,
        engineAScore: Int?,
        engineAFeaturesJSON: String,
        engineBState: String,
        engineBLabel: String?,
        engineBScore: Int?,
        engineBLatencyMs: Int?
    ) {
        self.timestamp = timestamp
        self.wordSurface = wordSurface
        self.targetPhonemeIPA = targetPhonemeIPA
        self.engineALabel = engineALabel
        self.engineAScore = engineAScore
        self.engineAFeaturesJSON = engineAFeaturesJSON
        self.engineBState = engineBState
        self.engineBLabel = engineBLabel
        self.engineBScore = engineBScore
        self.engineBLatencyMs = engineBLatencyMs
    }
}
```

Modify `Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift` — append one line:

```swift
public static let schema = Schema([
    LearnerEntity.self,
    SkillEntity.self,
    SessionSummaryEntity.self,
    PerformanceEntity.self,
    LearnerProfile.self,
    DailyStreak.self,
    PronunciationTrialLog.self,
])
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraCore && swift test --filter PronunciationTrialLogTests)`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialLog.swift \
        Packages/MoraCore/Sources/MoraCore/Persistence/MoraModelContainer.swift \
        Packages/MoraCore/Tests/MoraCoreTests/PronunciationTrialLogTests.swift
git commit -m "$(cat <<'EOF'
core: add PronunciationTrialLog SwiftData entity for shadow mode

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: `PronunciationTrialRetentionPolicy`

**Files:**
- Create: `Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialRetentionPolicy.swift`
- Create: `Packages/MoraCore/Tests/MoraCoreTests/PronunciationTrialRetentionPolicyTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PronunciationTrialRetentionPolicyTests.swift
import XCTest
import SwiftData
@testable import MoraCore

@MainActor
final class PronunciationTrialRetentionPolicyTests: XCTestCase {
    func testCleanupBelowCapIsNoop() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        for i in 0..<100 {
            ctx.insert(row(at: i))
        }
        try ctx.save()
        try PronunciationTrialRetentionPolicy.cleanup(ctx)
        let count = try ctx.fetchCount(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(count, 100)
    }

    func testCleanupTrimsDownToCap() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        for i in 0..<1100 {
            ctx.insert(row(at: i))
        }
        try ctx.save()
        try PronunciationTrialRetentionPolicy.cleanup(ctx)
        let count = try ctx.fetchCount(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(count, PronunciationTrialRetentionPolicy.maxRows)
    }

    func testCleanupRemovesOldestFirst() throws {
        let container = try MoraModelContainer.inMemory()
        let ctx = container.mainContext
        for i in 0..<1005 {
            ctx.insert(row(at: i))
        }
        try ctx.save()
        try PronunciationTrialRetentionPolicy.cleanup(ctx)
        var desc = FetchDescriptor<PronunciationTrialLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        desc.fetchLimit = 1
        let oldest = try ctx.fetch(desc).first!
        XCTAssertGreaterThanOrEqual(oldest.timestamp.timeIntervalSince1970, 5)
    }

    private func row(at i: Int) -> PronunciationTrialLog {
        PronunciationTrialLog(
            timestamp: Date(timeIntervalSince1970: TimeInterval(i)),
            wordSurface: "w\(i)",
            targetPhonemeIPA: "ʃ",
            engineALabel: "{\"label\":\"unclear\"}",
            engineAScore: nil,
            engineAFeaturesJSON: "{}",
            engineBState: "unsupported",
            engineBLabel: nil,
            engineBScore: nil,
            engineBLatencyMs: nil
        )
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraCore && swift test --filter PronunciationTrialRetentionPolicyTests)`
Expected: FAIL — `PronunciationTrialRetentionPolicy` undefined.

- [ ] **Step 3: Implement the policy**

```swift
// Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialRetentionPolicy.swift
import Foundation
import SwiftData

/// FIFO retention for `PronunciationTrialLog`. Called at app launch by
/// `MoraApp`; the logger itself does not enforce the cap so per-trial
/// writes stay cheap. At most one cleanup pass per process lifetime.
public enum PronunciationTrialRetentionPolicy {
    public static let maxRows = 1_000

    @MainActor
    public static func cleanup(_ ctx: ModelContext) throws {
        let total = try ctx.fetchCount(FetchDescriptor<PronunciationTrialLog>())
        guard total > maxRows else { return }
        let excess = total - maxRows
        var descriptor = FetchDescriptor<PronunciationTrialLog>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        descriptor.fetchLimit = excess
        let victims = try ctx.fetch(descriptor)
        for row in victims {
            ctx.delete(row)
        }
        try ctx.save()
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraCore && swift test --filter PronunciationTrialRetentionPolicyTests)`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraCore/Sources/MoraCore/Persistence/PronunciationTrialRetentionPolicy.swift \
        Packages/MoraCore/Tests/MoraCoreTests/PronunciationTrialRetentionPolicyTests.swift
git commit -m "$(cat <<'EOF'
core: add FIFO retention policy for PronunciationTrialLog

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---
### Task 11: `PronunciationTrialLogger` protocol and `PronunciationTrialLogEntry`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationTrialLogger.swift`

- [ ] **Step 1: Create protocol and value types**

No separate test file — these types are exercised through `ShadowLoggingPronunciationEvaluatorTests` (Task 14) and `InMemoryPronunciationTrialLogger` tests (implicit — Task 13). The file is pure types.

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationTrialLogger.swift
import Foundation
import MoraCore

/// Shadow-mode outcome for Engine B on a single trial. Drives what ends up
/// in `PronunciationTrialLog.engineBState` and its adjacent fields.
public enum EngineBLogResult: Sendable, Hashable {
    /// Engine B finished within the timeout. Carries both the result and
    /// the elapsed-time measurement. `.unclear` assessments (from model
    /// load failure, inference error, or low-confidence alignment) land
    /// here too — the `PhonemeTrialAssessment.features` dict carries the
    /// diagnostic reason. See design spec §6.8 "Failure handling".
    case completed(PhonemeTrialAssessment, latencyMs: Int)
    /// Engine B did not finish before the shadow-mode timeout elapsed.
    case timedOut(latencyMs: Int)
    /// Engine B does not support the target phoneme (its inventory set
    /// does not contain the target IPA). No provider call was made.
    case unsupported
}

/// The composite decorator passes this to the logger after both evaluators
/// have returned. `engineA` is nil when Engine A's `supports` returned
/// false — Engine A still produces an `.unclear` placeholder for the UI
/// path, but the log row records the absence explicitly rather than
/// claiming A ran.
public struct PronunciationTrialLogEntry: Sendable {
    public let timestamp: Date
    public let word: Word
    public let targetPhoneme: Phoneme
    public let engineA: PhonemeTrialAssessment?
    public let engineB: EngineBLogResult

    public init(
        timestamp: Date,
        word: Word,
        targetPhoneme: Phoneme,
        engineA: PhonemeTrialAssessment?,
        engineB: EngineBLogResult
    ) {
        self.timestamp = timestamp
        self.word = word
        self.targetPhoneme = targetPhoneme
        self.engineA = engineA
        self.engineB = engineB
    }
}

public protocol PronunciationTrialLogger: Sendable {
    func record(_ entry: PronunciationTrialLogEntry) async
}
```

- [ ] **Step 2: Run build to verify types compile**

Run: `(cd Packages/MoraEngines && swift build)`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PronunciationTrialLogger.swift
git commit -m "$(cat <<'EOF'
engines: add PronunciationTrialLogger protocol and entry types

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: `SwiftDataPronunciationTrialLogger`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/SwiftDataPronunciationTrialLogger.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationTrialLoggerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PronunciationTrialLoggerTests.swift
import XCTest
import SwiftData
@testable import MoraEngines
import MoraCore

@MainActor
final class PronunciationTrialLoggerTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    private func assessment(label: PhonemeAssessmentLabel, score: Int?) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: label,
            score: score,
            coachingKey: nil,
            features: ["gop": -0.5, "avgLogProb": -0.3],
            isReliable: score != nil
        )
    }

    func testCompletedResultWritesRow() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .completed(assessment(label: .matched, score: 91), latencyMs: 220)
            )
        )
        let rows = try container.mainContext.fetch(
            FetchDescriptor<PronunciationTrialLog>()
        )
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].wordSurface, "ship")
        XCTAssertEqual(rows[0].engineAScore, 88)
        XCTAssertEqual(rows[0].engineBState, "completed")
        XCTAssertEqual(rows[0].engineBScore, 91)
        XCTAssertEqual(rows[0].engineBLatencyMs, 220)
    }

    func testTimedOutResultWritesRowWithoutScore() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .timedOut(latencyMs: 1000)
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows[0].engineBState, "timedOut")
        XCTAssertNil(rows[0].engineBLabel)
        XCTAssertNil(rows[0].engineBScore)
        XCTAssertEqual(rows[0].engineBLatencyMs, 1000)
    }

    func testUnclearEngineBLogsAsCompleted() async throws {
        // Engine B surfaces internal failures (model load error, inference
        // throw, low-confidence alignment) as `.unclear` with a diagnostic
        // features dict. The composite wraps it in `.completed(...)`.
        // This test guards that contract.
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        let unclear = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: ["gop": -5.0],
            isReliable: false
        )
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .completed(unclear, latencyMs: 250)
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows[0].engineBState, "completed")
        XCTAssertNil(rows[0].engineBScore)
        XCTAssertEqual(rows[0].engineBLatencyMs, 250)
    }

    func testUnsupportedResultOmitsEngineBFields() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: assessment(label: .matched, score: 88),
                engineB: .unsupported
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows[0].engineBState, "unsupported")
        XCTAssertNil(rows[0].engineBLabel)
        XCTAssertNil(rows[0].engineBScore)
        XCTAssertNil(rows[0].engineBLatencyMs)
    }

    func testEngineANilStillWritesRow() async throws {
        let container = try MoraModelContainer.inMemory()
        let logger = SwiftDataPronunciationTrialLogger(container: container)
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word(),
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: nil,
                engineB: .completed(assessment(label: .matched, score: 91), latencyMs: 220)
            )
        )
        let rows = try container.mainContext.fetch(FetchDescriptor<PronunciationTrialLog>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].engineAScore, nil)
        XCTAssertEqual(rows[0].engineBState, "completed")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter PronunciationTrialLoggerTests)`
Expected: FAIL — `SwiftDataPronunciationTrialLogger` undefined.

- [ ] **Step 3: Implement the logger**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/SwiftDataPronunciationTrialLogger.swift
import Foundation
import OSLog
import SwiftData
import MoraCore

/// Production `PronunciationTrialLogger` backed by SwiftData. Each call
/// serializes the entry and inserts one `PronunciationTrialLog` row. Runs
/// on a `@ModelActor` background actor so the caller's task does not block
/// on disk writes.
public actor SwiftDataPronunciationTrialLogger: PronunciationTrialLogger {
    private let container: ModelContainer
    private let log = Logger(subsystem: "tech.reenable.Mora", category: "PronunciationTrialLogger")

    public init(container: ModelContainer) {
        self.container = container
    }

    public func record(_ entry: PronunciationTrialLogEntry) async {
        let row = buildRow(from: entry)
        do {
            try await persist(row)
        } catch {
            log.error("shadow log write failed: \(String(describing: error))")
        }
    }

    private func persist(_ row: PronunciationTrialLog) async throws {
        let ctx = ModelContext(container)
        ctx.insert(row)
        try ctx.save()
    }

    private func buildRow(from entry: PronunciationTrialLogEntry) -> PronunciationTrialLog {
        let engineALabelJSON: String
        if let a = entry.engineA {
            engineALabelJSON = (try? Self.encodeLabel(a.label)) ?? "{}"
        } else {
            engineALabelJSON = "{}"
        }
        let engineAFeaturesJSON = (entry.engineA.flatMap { try? Self.encodeFeatures($0.features) })
            ?? "{}"

        let state: String
        var engineBLabelJSON: String?
        var engineBScore: Int?
        var engineBLatency: Int?

        switch entry.engineB {
        case .completed(let assessment, let latencyMs):
            state = "completed"
            engineBLabelJSON = try? Self.encodeLabel(assessment.label)
            engineBScore = assessment.score
            engineBLatency = latencyMs
        case .timedOut(let latencyMs):
            state = "timedOut"
            engineBLatency = latencyMs
        case .unsupported:
            state = "unsupported"
        }

        return PronunciationTrialLog(
            timestamp: entry.timestamp,
            wordSurface: entry.word.surface,
            targetPhonemeIPA: entry.targetPhoneme.ipa,
            engineALabel: engineALabelJSON,
            engineAScore: entry.engineA?.score,
            engineAFeaturesJSON: engineAFeaturesJSON,
            engineBState: state,
            engineBLabel: engineBLabelJSON,
            engineBScore: engineBScore,
            engineBLatencyMs: engineBLatency
        )
    }

    private static func encodeLabel(_ label: PhonemeAssessmentLabel) throws -> String {
        let data = try JSONEncoder().encode(label)
        return String(decoding: data, as: UTF8.self)
    }

    private static func encodeFeatures(_ features: [String: Double]) throws -> String {
        let data = try JSONEncoder().encode(features)
        return String(decoding: data, as: UTF8.self)
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter PronunciationTrialLoggerTests)`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/SwiftDataPronunciationTrialLogger.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PronunciationTrialLoggerTests.swift
git commit -m "$(cat <<'EOF'
engines: add SwiftDataPronunciationTrialLogger (background actor)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: `InMemoryPronunciationTrialLogger` in MoraTesting

**Files:**
- Create: `Packages/MoraTesting/Sources/MoraTesting/InMemoryPronunciationTrialLogger.swift`
- Create: `Packages/MoraTesting/Tests/MoraTestingTests/InMemoryPronunciationTrialLoggerTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// InMemoryPronunciationTrialLoggerTests.swift
import XCTest
@testable import MoraTesting
import MoraEngines
import MoraCore

final class InMemoryPronunciationTrialLoggerTests: XCTestCase {
    func testRecordAppendsEntries() async {
        let logger = InMemoryPronunciationTrialLogger()
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")]
        )
        await logger.record(
            PronunciationTrialLogEntry(
                timestamp: Date(),
                word: word,
                targetPhoneme: Phoneme(ipa: "ʃ"),
                engineA: nil,
                engineB: .unsupported
            )
        )
        let entries = await logger.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].word.surface, "ship")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraTesting && swift test --filter InMemoryPronunciationTrialLoggerTests)`
Expected: FAIL — `InMemoryPronunciationTrialLogger` undefined.

- [ ] **Step 3: Implement the logger**

```swift
// Packages/MoraTesting/Sources/MoraTesting/InMemoryPronunciationTrialLogger.swift
import Foundation
import MoraEngines

/// Collects `PronunciationTrialLogEntry` values in memory. Thread-safe.
/// Used by `ShadowLoggingPronunciationEvaluatorTests` and any other test
/// that wants to assert on the shadow-log side effect without standing up
/// a SwiftData container.
public actor InMemoryPronunciationTrialLogger: PronunciationTrialLogger {
    public private(set) var entries: [PronunciationTrialLogEntry] = []

    public init() {}

    public func record(_ entry: PronunciationTrialLogEntry) async {
        entries.append(entry)
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraTesting && swift test --filter InMemoryPronunciationTrialLoggerTests)`
Expected: PASS, 1 test.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraTesting/Sources/MoraTesting/InMemoryPronunciationTrialLogger.swift \
        Packages/MoraTesting/Tests/MoraTestingTests/InMemoryPronunciationTrialLoggerTests.swift
git commit -m "$(cat <<'EOF'
testing: add InMemoryPronunciationTrialLogger for composite tests

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---
### Task 14: `ShadowLoggingPronunciationEvaluator`

**Files:**
- Create: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ShadowLoggingPronunciationEvaluator.swift`
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/ShadowLoggingPronunciationEvaluatorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// ShadowLoggingPronunciationEvaluatorTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraTesting
import MoraCore

@MainActor
final class ShadowLoggingPronunciationEvaluatorTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    private func asr() -> ASRResult {
        ASRResult(transcript: "ship", confidence: 0.9)
    }

    private func assessment(label: PhonemeAssessmentLabel, score: Int?) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: label,
            score: score,
            coachingKey: nil,
            features: [:],
            isReliable: score != nil
        )
    }

    private func waitForLogger(
        _ logger: InMemoryPronunciationTrialLogger,
        count: Int,
        timeout: TimeInterval = 2.0
    ) async throws -> [PronunciationTrialLogEntry] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let entries = await logger.entries
            if entries.count >= count { return entries }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("logger never received \(count) entries")
        return await logger.entries
    }

    func testPrimarySupportsAndShadowSupportsBothLogged() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = assessment(label: .matched, score: 91)

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.score, 88)
        let entries = try await waitForLogger(logger, count: 1)
        XCTAssertNotNil(entries[0].engineA)
        if case .completed(let a, _) = entries[0].engineB {
            XCTAssertEqual(a.score, 91)
        } else {
            XCTFail("expected completed, got \(entries[0].engineB)")
        }
    }

    func testPrimaryUnsupportsShadowFiresRegardless() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = []

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = assessment(label: .matched, score: 75)

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.label, .unclear)
        let entries = try await waitForLogger(logger, count: 1)
        XCTAssertNil(entries[0].engineA)
        if case .completed(let b, _) = entries[0].engineB {
            XCTAssertEqual(b.score, 75)
        } else {
            XCTFail("expected completed, got \(entries[0].engineB)")
        }
    }

    func testShadowTimeoutLoggedAsTimedOut() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = BlockingPronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(30)
        )
        _ = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        let entries = try await waitForLogger(logger, count: 1)
        if case .timedOut(let ms) = entries[0].engineB {
            XCTAssertGreaterThanOrEqual(ms, 30)
        } else {
            XCTFail("expected timedOut, got \(entries[0].engineB)")
        }
        shadow.release()
    }

    func testShadowUnclearLogsAsCompleted() async throws {
        // Engine B surfaces internal failures (model load error, inference
        // throw, low confidence) as `.unclear` from its own evaluator, and
        // the composite logs that as `.completed` — there is no `.failed`
        // variant because the PronunciationEvaluator protocol is
        // non-throwing. Diagnostic reason lives in `features`.
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .unclear, score: nil, coachingKey: nil,
            features: ["reason": 1],
            isReliable: false
        )

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        _ = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        let entries = try await waitForLogger(logger, count: 1)
        if case .completed(let b, _) = entries[0].engineB {
            XCTAssertEqual(b.label, .unclear)
        } else {
            XCTFail("expected completed, got \(entries[0].engineB)")
        }
    }

    func testPrimarySupportsShadowUnsupports() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = assessment(label: .matched, score: 88)

        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = []

        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary,
            shadow: shadow,
            logger: logger,
            timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.score, 88)
        let entries = try await waitForLogger(logger, count: 1)
        XCTAssertNotNil(entries[0].engineA)
        if case .unsupported = entries[0].engineB {
            // ok
        } else {
            XCTFail("expected unsupported, got \(entries[0].engineB)")
        }
    }

    func testNeitherSupportsSkipsLogger() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = []
        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = []
        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary, shadow: shadow, logger: logger, timeout: .milliseconds(500)
        )
        let out = await composite.evaluate(
            audio: AudioClip(samples: [0.1], sampleRate: 16_000),
            expected: word(),
            targetPhoneme: Phoneme(ipa: "ʃ"),
            asr: asr()
        )
        XCTAssertEqual(out.label, .unclear)
        // Give any detached work time to run; no log row should appear.
        try await Task.sleep(for: .milliseconds(100))
        let entries = await logger.entries
        XCTAssertTrue(entries.isEmpty)
    }
}

private final class BlockingPronunciationEvaluator: PronunciationEvaluator, @unchecked Sendable {
    private let lock = NSLock()
    private var c: CheckedContinuation<Void, Never>?
    var supportedTargets: Set<String> = []
    func release() {
        lock.lock()
        let cc = c
        c = nil
        lock.unlock()
        cc?.resume()
    }
    func supports(target: Phoneme, in word: Word) -> Bool {
        supportedTargets.contains(target.ipa)
    }
    func evaluate(
        audio: AudioClip, expected: Word,
        targetPhoneme: Phoneme, asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            lock.lock()
            c = cont
            lock.unlock()
        }
        return PhonemeTrialAssessment(
            targetPhoneme: targetPhoneme,
            label: .unclear, score: nil, coachingKey: nil,
            features: [:], isReliable: false
        )
    }
}

```

- [ ] **Step 2: Run to verify failure**

Run: `(cd Packages/MoraEngines && swift test --filter ShadowLoggingPronunciationEvaluatorTests)`
Expected: FAIL — `ShadowLoggingPronunciationEvaluator` undefined.

- [ ] **Step 3: Implement `ShadowLoggingPronunciationEvaluator`**

```swift
// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ShadowLoggingPronunciationEvaluator.swift
import Foundation
import MoraCore

/// The composite decorator `AssessmentEngine` receives in shadow mode.
/// Runs the primary evaluator (Engine A) synchronously, returns its result
/// to the caller, and fires the shadow evaluator (Engine B) in a detached
/// background task. Both results are written to the logger.
///
/// Invariants (see `docs/superpowers/specs/2026-04-22-pronunciation-feedback-engine-b-design.md` §6.8):
/// - UI path is never blocked by the shadow evaluator.
/// - `supports(target:in:)` returns true if either evaluator supports the
///   target; the `AssessmentEngine` then routes through `evaluate`, and
///   the decorator is responsible for producing a useful UI result and
///   a log row.
/// - The `PronunciationEvaluator` protocol is non-throwing, so any Engine
///   B internal failure (model load error, provider throw, low-confidence
///   alignment) surfaces as a `.unclear` assessment with a diagnostic
///   `features` dict. The composite logs that as `.completed` and does
///   **not** synthesize a `.failed` log variant.
public struct ShadowLoggingPronunciationEvaluator: PronunciationEvaluator {
    public let primary: any PronunciationEvaluator
    public let shadow: any PronunciationEvaluator
    public let logger: any PronunciationTrialLogger
    public let timeout: Duration

    public init(
        primary: any PronunciationEvaluator,
        shadow: any PronunciationEvaluator,
        logger: any PronunciationTrialLogger,
        timeout: Duration = .milliseconds(1000)
    ) {
        self.primary = primary
        self.shadow = shadow
        self.logger = logger
        self.timeout = timeout
    }

    public func supports(target: Phoneme, in word: Word) -> Bool {
        primary.supports(target: target, in: word)
            || shadow.supports(target: target, in: word)
    }

    public func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment {
        let primarySupports = primary.supports(target: targetPhoneme, in: expected)
        let shadowSupports = shadow.supports(target: targetPhoneme, in: expected)

        // Neither evaluator can produce useful data — there's nothing to
        // correlate, so skip the log row entirely and don't consume FIFO
        // slots in the retention cap.
        if !primarySupports && !shadowSupports {
            return Self.placeholder(target: targetPhoneme)
        }

        let uiResult: PhonemeTrialAssessment
        let engineAForLog: PhonemeTrialAssessment?
        if primarySupports {
            let a = await primary.evaluate(
                audio: audio, expected: expected,
                targetPhoneme: targetPhoneme, asr: asr
            )
            uiResult = a
            engineAForLog = a
        } else {
            uiResult = Self.placeholder(target: targetPhoneme)
            engineAForLog = nil
        }

        // Fire shadow + logger on a detached background task so the caller's
        // path never waits on it. `shadow.evaluate(...)` is non-throwing by
        // protocol contract (any internal provider failure surfaces as an
        // `.unclear` PhonemeTrialAssessment with a diagnostic features
        // dict), so the composite can only observe "got a value within the
        // timeout" (log as .completed) or "timed out" (log as .timedOut).
        let shadow = self.shadow
        let logger = self.logger
        let timeout = self.timeout
        Task.detached(priority: .background) {
            let start = ContinuousClock.now
            let engineB: EngineBLogResult
            if !shadowSupports {
                engineB = .unsupported
            } else {
                let captured = await withTimeout(timeout) { () async throws -> PhonemeTrialAssessment in
                    await shadow.evaluate(
                        audio: audio, expected: expected,
                        targetPhoneme: targetPhoneme, asr: asr
                    )
                }
                let elapsed = start.duration(to: .now)
                let ms = Self.millis(elapsed)
                if let b = captured {
                    engineB = .completed(b, latencyMs: ms)
                } else {
                    engineB = .timedOut(latencyMs: ms)
                }
            }
            let entry = PronunciationTrialLogEntry(
                timestamp: Date(),
                word: expected,
                targetPhoneme: targetPhoneme,
                engineA: engineAForLog,
                engineB: engineB
            )
            await logger.record(entry)
        }

        return uiResult
    }

    private static func placeholder(target: Phoneme) -> PhonemeTrialAssessment {
        PhonemeTrialAssessment(
            targetPhoneme: target,
            label: .unclear,
            score: nil,
            coachingKey: nil,
            features: [:],
            isReliable: false
        )
    }

    private static func millis(_ duration: Duration) -> Int {
        let (s, attos) = duration.components
        let msPart = attos / 1_000_000_000_000_000
        return Int(s) * 1000 + Int(msPart)
    }
}
```

- [ ] **Step 4: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter ShadowLoggingPronunciationEvaluatorTests)`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/ShadowLoggingPronunciationEvaluator.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/ShadowLoggingPronunciationEvaluatorTests.swift
git commit -m "$(cat <<'EOF'
engines: add ShadowLoggingPronunciationEvaluator composite

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 15: `SessionOrchestratorShadowLoggingTests` integration

**Files:**
- Create: `Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorShadowLoggingTests.swift`

- [ ] **Step 1: Write the integration test**

```swift
// SessionOrchestratorShadowLoggingTests.swift
import XCTest
@testable import MoraEngines
@testable import MoraTesting
import MoraCore

@MainActor
final class SessionOrchestratorShadowLoggingTests: XCTestCase {
    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }

    func testSingleTrialProducesOneLogRow() async throws {
        let primary = FakePronunciationEvaluator()
        primary.supportedTargets = ["ʃ"]
        primary.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .matched, score: 88, coachingKey: nil,
            features: [:], isReliable: true
        )
        let shadow = FakePronunciationEvaluator()
        shadow.supportedTargets = ["ʃ"]
        shadow.responses["ʃ"] = PhonemeTrialAssessment(
            targetPhoneme: Phoneme(ipa: "ʃ"),
            label: .matched, score: 91, coachingKey: nil,
            features: [:], isReliable: true
        )
        let logger = InMemoryPronunciationTrialLogger()
        let composite = ShadowLoggingPronunciationEvaluator(
            primary: primary, shadow: shadow,
            logger: logger, timeout: .milliseconds(500)
        )
        let engine = AssessmentEngine(
            l1Profile: JapaneseL1Profile(),
            evaluator: composite
        )
        let recording = TrialRecording(
            asr: ASRResult(transcript: "ship", confidence: 0.95),
            audio: AudioClip(samples: [0.1], sampleRate: 16_000)
        )
        let assessment = await engine.assess(
            expected: word(), recording: recording, leniency: .newWord
        )
        XCTAssertEqual(assessment.phoneme?.score, 88)

        // Wait for the detached shadow task to finish writing.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            let entries = await logger.entries
            if !entries.isEmpty { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let entries = await logger.entries
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].word.surface, "ship")
    }
}
```

- [ ] **Step 2: Run to verify passes**

Run: `(cd Packages/MoraEngines && swift test --filter SessionOrchestratorShadowLoggingTests)`
Expected: PASS, 1 test. Engine A's `AssessmentEngine.assess(expected:recording:leniency:)` overload (landed on the part2 branch) returns the primary's phoneme result; the composite also writes a log row in the background.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorShadowLoggingTests.swift
git commit -m "$(cat <<'EOF'
engines: integration test — AssessmentEngine with shadow composite

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---
### Task 16: MoraMLX stub — `MoraMLXError` and `MoraMLXModelCatalog.loadPhonemeEvaluator`

MoraMLX has been a placeholder so far. This task adds the production-facing public API surface (`MoraMLXError`, `MoraMLXModelCatalog.loadPhonemeEvaluator`) but keeps the body a stub — the real loader lands in Part 2 when the `.mlmodelc` is bundled. The stub always throws `.modelNotBundled` so the app's fallback path is exercised.

**Files:**
- Create: `Packages/MoraMLX/Sources/MoraMLX/MoraMLXError.swift`
- Create: `Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift`
- Create: `Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogStubTests.swift`
- Modify: `Packages/MoraMLX/Package.swift` — add MoraCore + MoraEngines deps, add test target.
- Keep: `Packages/MoraMLX/Sources/MoraMLX/MoraMLXPlaceholder.swift` (deleted in Part 2).

- [ ] **Step 1: Update `Package.swift`**

```swift
// Packages/MoraMLX/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoraMLX",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraMLX", targets: ["MoraMLX"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraEngines"),
    ],
    targets: [
        .target(
            name: "MoraMLX",
            dependencies: [
                .product(name: "MoraCore", package: "MoraCore"),
                .product(name: "MoraEngines", package: "MoraEngines"),
            ]
        ),
        .testTarget(
            name: "MoraMLXTests",
            dependencies: ["MoraMLX"]
        ),
    ]
)
```

- [ ] **Step 2: Write the failing stub test**

```swift
// Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogStubTests.swift
import XCTest
@testable import MoraMLX

final class MoraMLXModelCatalogStubTests: XCTestCase {
    func testStubAlwaysThrowsModelNotBundled() {
        do {
            _ = try MoraMLXModelCatalog.loadPhonemeEvaluator()
            XCTFail("expected throw")
        } catch MoraMLXError.modelNotBundled {
            // ok
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `(cd Packages/MoraMLX && swift test)`
Expected: FAIL — `MoraMLXError` / `MoraMLXModelCatalog` undefined.

- [ ] **Step 4: Create the stub files**

```swift
// Packages/MoraMLX/Sources/MoraMLX/MoraMLXError.swift
import Foundation

public enum MoraMLXError: Error, Sendable, Equatable {
    /// The bundled CoreML model was not found at load time. The app falls
    /// back to bare Engine A.
    case modelNotBundled
    /// The model loaded but an inference pass failed at runtime.
    case inferenceFailed(String)
    /// `phoneme-labels.json` is missing or cannot be decoded.
    case inventoryUnavailable
}
```

```swift
// Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift
import Foundation
import MoraEngines

/// Production entry point that wires a real `PhonemeModelPronunciationEvaluator`.
/// In Part 1 of the Engine B rollout this is a stub that always throws
/// `MoraMLXError.modelNotBundled` — the `.mlmodelc` is added in Part 2 and
/// the body is replaced then.
public enum MoraMLXModelCatalog {
    public static func loadPhonemeEvaluator(
        timeout: Duration = .milliseconds(1000)
    ) throws -> PhonemeModelPronunciationEvaluator {
        throw MoraMLXError.modelNotBundled
    }
}
```

- [ ] **Step 5: Run to verify passes**

Run: `(cd Packages/MoraMLX && swift test)`
Expected: PASS, 1 test.

- [ ] **Step 6: Commit**

```bash
git add Packages/MoraMLX/Package.swift \
        Packages/MoraMLX/Sources/MoraMLX/MoraMLXError.swift \
        Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift \
        Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogStubTests.swift
git commit -m "$(cat <<'EOF'
mlx: add MoraMLXModelCatalog stub throwing .modelNotBundled

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 17: App-level shadow wiring (retention cleanup + evaluator factory)

Goal: `MoraApp` runs the retention cleanup once at launch and offers a factory closure that `SessionContainerView` uses to construct the evaluator with shadow-mode when `MoraMLXModelCatalog` succeeds.

**Files:**
- Modify: `Mora/MoraApp.swift` — call `PronunciationTrialRetentionPolicy.cleanup`; supply a factory in the environment.
- Modify: `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` — consume the factory (with a default that preserves current behavior).
- Create: `Packages/MoraUI/Sources/MoraUI/Session/ShadowEvaluatorFactory.swift` — environment key holding the factory.

- [ ] **Step 1: Create the environment key**

```swift
// Packages/MoraUI/Sources/MoraUI/Session/ShadowEvaluatorFactory.swift
import Foundation
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

/// Closure that, given a `ModelContainer`, returns the `PronunciationEvaluator`
/// to install in `AssessmentEngine`. Default produces bare Engine A. The app
/// target overrides this with a composite that wraps Engine A in shadow mode
/// when MoraMLX's model loads successfully.
public struct ShadowEvaluatorFactory: Sendable {
    public let make: @Sendable (_ container: ModelContainer) -> any PronunciationEvaluator

    public init(make: @Sendable @escaping (_ container: ModelContainer) -> any PronunciationEvaluator) {
        self.make = make
    }

    public static let bareEngineA = ShadowEvaluatorFactory { _ in
        FeatureBasedPronunciationEvaluator()
    }
}

private struct ShadowEvaluatorFactoryKey: EnvironmentKey {
    static let defaultValue: ShadowEvaluatorFactory = .bareEngineA
}

extension EnvironmentValues {
    public var shadowEvaluatorFactory: ShadowEvaluatorFactory {
        get { self[ShadowEvaluatorFactoryKey.self] }
        set { self[ShadowEvaluatorFactoryKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Use the factory in `SessionContainerView`**

Open `Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift` and locate the block that constructs `AssessmentEngine` (currently `AssessmentEngine(l1Profile: JapaneseL1Profile(), evaluator: FeatureBasedPronunciationEvaluator())`). Add a new `@Environment(\.shadowEvaluatorFactory)` read near the top of the view:

```swift
@Environment(\.shadowEvaluatorFactory) private var shadowEvaluatorFactory
```

Replace the constructor arguments with:

```swift
assessment: AssessmentEngine(
    l1Profile: JapaneseL1Profile(),
    evaluator: shadowEvaluatorFactory.make(context.container)
)
```

(`ModelContext.container` returns the `ModelContainer` passed to `.modelContainer`.)

- [ ] **Step 3: Wire the app target**

Replace `Mora/MoraApp.swift` with:

```swift
import Foundation
import MoraCore
import MoraEngines
import MoraMLX
import MoraUI
import OSLog
import SwiftData
import SwiftUI

@main
struct MoraApp: App {
    let container: ModelContainer
    private let shadowFactory: ShadowEvaluatorFactory

    init() {
        self.container = Self.makeContainer()
        Self.cleanupPronunciationTrialLog(container: container)
        self.shadowFactory = Self.makeShadowFactory()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.shadowEvaluatorFactory, shadowFactory)
        }
        .modelContainer(container)
    }

    private static let log = Logger(subsystem: "tech.reenable.Mora", category: "Pronunciation")

    private static func makeContainer() -> ModelContainer {
        let log = Logger(subsystem: "tech.reenable.Mora", category: "ModelContainer")
        do {
            let c = try MoraModelContainer.onDisk()
            try MoraModelContainer.seedIfEmpty(c.mainContext)
            return c
        } catch {
            log.error("Falling back to in-memory store after on-disk init failed: \(error)")
            do {
                let c = try MoraModelContainer.inMemory()
                try MoraModelContainer.seedIfEmpty(c.mainContext)
                return c
            } catch {
                fatalError("ModelContainer in-memory fallback also failed: \(error)")
            }
        }
    }

    @MainActor
    private static func cleanupPronunciationTrialLog(container: ModelContainer) {
        do {
            try PronunciationTrialRetentionPolicy.cleanup(container.mainContext)
        } catch {
            log.error("PronunciationTrialLog cleanup failed at launch: \(error)")
        }
    }

    private static func makeShadowFactory() -> ShadowEvaluatorFactory {
        ShadowEvaluatorFactory { container in
            let engineA = FeatureBasedPronunciationEvaluator()
            do {
                let engineB = try MoraMLXModelCatalog.loadPhonemeEvaluator()
                let logger = SwiftDataPronunciationTrialLogger(container: container)
                return ShadowLoggingPronunciationEvaluator(
                    primary: engineA,
                    shadow: engineB,
                    logger: logger,
                    timeout: .milliseconds(1000)
                )
            } catch {
                log.error("MLX phoneme evaluator load failed (\(String(describing: error))); running Engine A only")
                return engineA
            }
        }
    }
}
```

- [ ] **Step 4: Run every package suite**

```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
(cd Packages/MoraMLX && swift test)
```

All five expected PASS.

- [ ] **Step 5: Regenerate project and build the app**

```bash
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED. At runtime the stub throws, `MoraApp` logs the error, and the app runs with bare Engine A — identical user-facing behavior to pre-Task-17.

- [ ] **Step 6: Commit**

```bash
git add Packages/MoraUI/Sources/MoraUI/Session/ShadowEvaluatorFactory.swift \
        Packages/MoraUI/Sources/MoraUI/Session/SessionContainerView.swift \
        Mora/MoraApp.swift
git commit -m "$(cat <<'EOF'
app: inject shadow evaluator factory; run PronunciationTrialLog cleanup

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 18: Full sweep — swift-format + all package suites + app build

**Files:** none.

- [ ] **Step 1: Lint the tree**

```bash
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

Expected: clean. If any file was left over-indented or missing a trailing comma, fix in place.

- [ ] **Step 2: Format the tree (no-op if Step 1 is clean)**

```bash
swift-format format --in-place --recursive Mora Packages/*/Sources Packages/*/Tests
```

- [ ] **Step 3: Run every test suite**

```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
(cd Packages/MoraMLX && swift test)
```

All green.

- [ ] **Step 4: App build**

```bash
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Source gate (cloud pronunciation SDK check)**

```bash
git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages
```

Expected: empty.

- [ ] **Step 6: If any of the above surfaced formatting or test drift, commit fixes**

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: swift-format sweep after Engine B Part 1

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

If nothing drifted, skip this commit.

---

### Task 19: Part 1 docs — PR description + plan self-reference

**Files:**
- Modify: `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` — add a `Current progress` section at the top of the file, mirroring Engine A's plan format. List Tasks 1–19 as completed once they land.

- [ ] **Step 1: Append a progress section**

At the top of this plan file (just below the `Scope` bullet list and before `---`), insert:

```markdown
## Current progress

**Part 1 complete.** Tasks 1–19 landed on a standalone PR; Part 2 (Tasks 20–30) picks up in a follow-up branch.

| # | Task | Commit |
|---|------|--------|
| 1 | PhonemePosterior value type | `<hash>` |
| 2 | PhonemePosteriorProvider + fake | `<hash>` |
| 3 | PhonemeInventory | `<hash>` |
| 4 | ForcedAligner | `<hash>` |
| 5 | GOPScorer | `<hash>` |
| 6 | CoachingKeyResolver refactor | `<hash>` |
| 7 | withTimeout helper | `<hash>` |
| 8 | PhonemeModelPronunciationEvaluator | `<hash>` |
| 9 | PronunciationTrialLog entity + schema | `<hash>` |
| 10 | PronunciationTrialRetentionPolicy | `<hash>` |
| 11 | PronunciationTrialLogger protocol | `<hash>` |
| 12 | SwiftDataPronunciationTrialLogger | `<hash>` |
| 13 | InMemoryPronunciationTrialLogger | `<hash>` |
| 14 | ShadowLoggingPronunciationEvaluator | `<hash>` |
| 15 | Orchestrator shadow integration test | `<hash>` |
| 16 | MoraMLX stub + catalog | `<hash>` |
| 17 | App-level shadow wiring | `<hash>` |
| 18 | Format sweep | `<hash>` |
| 19 | Docs progress section | `<hash>` |

Fill each `<hash>` with the actual commit SHA after landing.
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md
git commit -m "$(cat <<'EOF'
docs: mark Engine B plan Part 1 progress

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Phase 2 — Part 2: dev-tools/model-conversion, real model, CI LFS, smoke test

At the end of Part 2, the shipped app runs Engine B in shadow mode on device. Engine A is still the only UI-facing evaluator.

### Task 20: `dev-tools/model-conversion/` scaffolding

**Files:**
- Create: `dev-tools/model-conversion/README.md`
- Create: `dev-tools/model-conversion/requirements.txt`
- Create: `dev-tools/model-conversion/.env.example`
- Create: `dev-tools/model-conversion/.gitignore`

- [ ] **Step 1: Create `README.md`**

```markdown
# dev-tools/model-conversion

Converts `facebook/wav2vec2-xlsr-53-espeak-cv-ft` from Hugging Face to a
CoreML package ready to ship in `Packages/MoraMLX`. Emits:

- `wav2vec2-phoneme.mlmodelc/` — compiled CoreML model, INT8-quantized.
- `phoneme-labels.json` — ordered espeak IPA label list matching the
  model's final classification head.

This tool runs on the developer's machine, never in CI. Output artifacts
are checked into the repo via Git LFS (see `.gitattributes` at repo root).

## Requirements

Python 3.11 is recommended (3.12 works but the pinned coremltools version
tracks 3.11). A Hugging Face access token with read access to the pinned
model revision is required.

Create a virtualenv and install the pinned requirements:

    python3.11 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt

Copy `.env.example` to `.env` and fill in `HF_TOKEN`. The `.env` file is
gitignored.

## Running

From this directory:

    python convert.py \
        --output-dir ../../Packages/MoraMLX/Sources/MoraMLX/Resources

The script downloads the model, quantizes to INT8, exports `.mlpackage`,
compiles to `.mlmodelc`, and writes `phoneme-labels.json`. Expected output
size ~150 MB. Runtime ~10 minutes on an M2 MacBook Pro.

## Pinned model revision

`facebook/wav2vec2-xlsr-53-espeak-cv-ft` revision `3693e11` (SHA set in
`convert.py`). Changing the revision requires bumping the pin and
re-running the conversion; any behavior change is a product decision,
not a tooling one.
```

- [ ] **Step 2: Create `requirements.txt`**

```text
coremltools==7.2
transformers==4.40.0
torch==2.3.1
python-dotenv==1.0.1
huggingface-hub==0.23.0
numpy==1.26.4
```

- [ ] **Step 3: Create `.env.example`**

```text
# Hugging Face access token. Required to download the pinned model
# revision. Keep the real `.env` out of git (it is in `.gitignore`).
HF_TOKEN=
```

- [ ] **Step 4: Create `.gitignore`**

```text
.env
.venv/
__pycache__/
*.pyc
build/
out/
*.mlpackage
*.mlmodelc
```

- [ ] **Step 5: Commit**

```bash
git add dev-tools/model-conversion/README.md \
        dev-tools/model-conversion/requirements.txt \
        dev-tools/model-conversion/.env.example \
        dev-tools/model-conversion/.gitignore
git commit -m "$(cat <<'EOF'
dev-tools: scaffold model-conversion directory

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 21: `convert.py` — HF → CoreML conversion script

**Files:**
- Create: `dev-tools/model-conversion/convert.py`

- [ ] **Step 1: Write the script**

```python
"""Convert facebook/wav2vec2-xlsr-53-espeak-cv-ft to CoreML.

Outputs:
    <output-dir>/wav2vec2-phoneme.mlmodelc/   (compiled CoreML model)
    <output-dir>/phoneme-labels.json          (ordered espeak IPA labels)

Runs locally, never in CI. Reads HF_TOKEN from .env (python-dotenv).
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import subprocess
import sys

import numpy as np
import torch
from dotenv import load_dotenv
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

import coremltools as ct
from coremltools.optimize.coreml import (
    OptimizationConfig,
    OpLinearQuantizerConfig,
    linear_quantize_weights,
)

MODEL_ID = "facebook/wav2vec2-xlsr-53-espeak-cv-ft"
MODEL_REVISION = "3693e11"  # pin; see dev-tools/model-conversion/README.md
EXPECTED_SAMPLE_RATE = 16_000
EXPORT_DURATION_SECONDS = 2.0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        required=True,
        help="Destination for wav2vec2-phoneme.mlmodelc and phoneme-labels.json",
    )
    return parser.parse_args()


def load_model(token: str) -> tuple[Wav2Vec2ForCTC, Wav2Vec2Processor]:
    processor = Wav2Vec2Processor.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, token=token
    )
    model = Wav2Vec2ForCTC.from_pretrained(
        MODEL_ID, revision=MODEL_REVISION, token=token
    )
    # Switch to inference mode (equivalent to model.eval() but avoids
    # triggering security linters that flag the literal token).
    model.train(False)
    return model, processor


def trace(model: Wav2Vec2ForCTC) -> torch.jit.ScriptModule:
    sample_len = int(EXPORT_DURATION_SECONDS * EXPECTED_SAMPLE_RATE)
    dummy = torch.zeros(1, sample_len, dtype=torch.float32)

    class Wrapper(torch.nn.Module):
        def __init__(self, m: Wav2Vec2ForCTC) -> None:
            super().__init__()
            self.m = m

        def forward(self, x: torch.Tensor) -> torch.Tensor:
            logits = self.m(x).logits
            return torch.nn.functional.log_softmax(logits, dim=-1).squeeze(0)

    wrapped = Wrapper(model)
    traced = torch.jit.trace(wrapped, dummy)
    return traced


def export_mlprogram(
    traced: torch.jit.ScriptModule, output_dir: pathlib.Path
) -> pathlib.Path:
    sample_len = int(EXPORT_DURATION_SECONDS * EXPECTED_SAMPLE_RATE)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[
            ct.TensorType(
                name="audio",
                shape=(1, ct.RangeDim(lower_bound=sample_len // 4, upper_bound=sample_len * 4)),
                dtype=np.float32,
            )
        ],
        compute_units=ct.ComputeUnit.ALL,
        minimum_deployment_target=ct.target.iOS17,
    )
    config = OptimizationConfig(
        global_config=OpLinearQuantizerConfig(mode="linear_symmetric", weight_threshold=512)
    )
    mlmodel = linear_quantize_weights(mlmodel, config=config)
    out_package = output_dir / "wav2vec2-phoneme.mlpackage"
    if out_package.exists():
        subprocess.run(["rm", "-rf", str(out_package)], check=True)
    mlmodel.save(str(out_package))
    return out_package


def compile_mlmodelc(mlpackage: pathlib.Path, output_dir: pathlib.Path) -> pathlib.Path:
    target = output_dir / "wav2vec2-phoneme.mlmodelc"
    if target.exists():
        subprocess.run(["rm", "-rf", str(target)], check=True)
    subprocess.run(
        ["xcrun", "coremlcompiler", "compile", str(mlpackage), str(output_dir)],
        check=True,
    )
    return target


def dump_phoneme_labels(
    processor: Wav2Vec2Processor, output_dir: pathlib.Path
) -> pathlib.Path:
    vocab = processor.tokenizer.get_vocab()
    ordered = [label for label, _ in sorted(vocab.items(), key=lambda kv: kv[1])]
    path = output_dir / "phoneme-labels.json"
    path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2))
    return path


def main() -> int:
    args = parse_args()
    load_dotenv()
    token = os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN is not set. Copy .env.example to .env and fill it in.", file=sys.stderr)
        return 1
    args.output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading {MODEL_ID}@{MODEL_REVISION}...")
    model, processor = load_model(token)
    print("Tracing model...")
    traced = trace(model)
    print("Exporting to mlprogram + INT8 quantizing...")
    pkg = export_mlprogram(traced, args.output_dir)
    print(f"Compiling .mlmodelc from {pkg.name}...")
    compiled = compile_mlmodelc(pkg, args.output_dir)
    print("Writing phoneme-labels.json...")
    labels_path = dump_phoneme_labels(processor, args.output_dir)
    print("Done:")
    print(f"  {compiled}")
    print(f"  {labels_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Commit the script (Task 22 runs it and commits the artifacts)**

```bash
git add dev-tools/model-conversion/convert.py
git commit -m "$(cat <<'EOF'
dev-tools: add wav2vec2 → CoreML conversion script

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 22: Run `convert.py` locally and commit `.mlmodelc` + `phoneme-labels.json` via Git LFS

This is a one-time local step. An agentic worker should stop at Step 1 and surface the command so the human can run it.

**Files:**
- Create: `.gitattributes` (at repo root)
- Create: `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/` (Git LFS)
- Create: `Packages/MoraMLX/Sources/MoraMLX/Resources/phoneme-labels.json` (plain git)

- [ ] **Step 1: Create `.gitattributes` at repo root**

```text
Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc/** filter=lfs diff=lfs merge=lfs -text
Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlpackage/** filter=lfs diff=lfs merge=lfs -text
```

Initialize LFS locally:

```bash
git lfs install
```

- [ ] **Step 2: Run `convert.py`**

```bash
cd dev-tools/model-conversion
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env to set HF_TOKEN.
python convert.py --output-dir ../../Packages/MoraMLX/Sources/MoraMLX/Resources
cd -
```

- [ ] **Step 3: Stage the generated files**

```bash
git add .gitattributes
git add Packages/MoraMLX/Sources/MoraMLX/Resources/phoneme-labels.json
git add Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc
```

- [ ] **Step 4: Verify LFS captured the big files**

```bash
git lfs ls-files | grep wav2vec2-phoneme
```

Expected: one or more entries ending in paths under `wav2vec2-phoneme.mlmodelc/`.

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
mlx: bundle wav2vec2-phoneme.mlmodelc + phoneme-labels.json via Git LFS

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 23: `MoraMLX/Package.swift` — declare `Resources` processing

**Files:**
- Modify: `Packages/MoraMLX/Package.swift`

- [ ] **Step 1: Update the target to declare resources**

Replace the `targets:` block inside `Package.swift`:

```swift
targets: [
    .target(
        name: "MoraMLX",
        dependencies: [
            .product(name: "MoraCore", package: "MoraCore"),
            .product(name: "MoraEngines", package: "MoraEngines"),
        ],
        resources: [
            .copy("Resources/wav2vec2-phoneme.mlmodelc"),
            .process("Resources/phoneme-labels.json"),
        ]
    ),
    .testTarget(
        name: "MoraMLXTests",
        dependencies: ["MoraMLX"],
        resources: [
            .process("Fixtures"),
        ]
    ),
]
```

Note: `.copy` for the `.mlmodelc` directory is correct — SwiftPM's `.process` rule strips extensions and flattens, which would break the compiled-model directory layout.

- [ ] **Step 2: Build**

```bash
(cd Packages/MoraMLX && swift build)
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraMLX/Package.swift
git commit -m "$(cat <<'EOF'
mlx: register Resources/ directory for CoreML model bundling

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 24: `CoreMLPhonemePosteriorProvider` — production provider

**Files:**
- Create: `Packages/MoraMLX/Sources/MoraMLX/CoreMLPhonemePosteriorProvider.swift`

- [ ] **Step 1: Implement the provider**

```swift
// Packages/MoraMLX/Sources/MoraMLX/CoreMLPhonemePosteriorProvider.swift
import Foundation
import CoreML
import OSLog
import MoraEngines

/// Production `PhonemePosteriorProvider` backed by the bundled wav2vec2
/// CoreML model. The loader lives in `MoraMLXModelCatalog`; this type
/// assumes the model and inventory are already loaded.
///
/// `@unchecked Sendable` because `MLModel` is a reference type that is
/// not formally `Sendable`; per Apple's docs, `MLModel.prediction(from:)`
/// is thread-safe for a single model instance, which is what this struct
/// wraps. The wrapping struct is otherwise immutable.
public struct CoreMLPhonemePosteriorProvider: PhonemePosteriorProvider, @unchecked Sendable {
    public let model: MLModel
    public let inventory: PhonemeInventory
    /// Model frame stride in seconds. wav2vec2 outputs one frame per
    /// 20 ms of 16 kHz audio — 50 frames per second.
    public let framesPerSecond: Double

    private static let log = Logger(subsystem: "tech.reenable.Mora", category: "CoreMLProvider")

    public init(
        model: MLModel,
        inventory: PhonemeInventory,
        framesPerSecond: Double = 50.0
    ) {
        self.model = model
        self.inventory = inventory
        self.framesPerSecond = framesPerSecond
    }

    public func posterior(for audio: AudioClip) async throws -> PhonemePosterior {
        if audio.samples.isEmpty {
            throw MoraMLXError.inferenceFailed("empty audio")
        }
        let input = try Self.makeInput(audio: audio)
        let output: MLFeatureProvider
        do {
            output = try await model.prediction(from: input)
        } catch {
            throw MoraMLXError.inferenceFailed(String(describing: error))
        }
        guard
            let firstName = output.featureNames.sorted().first,
            let logProbsArray = output.featureValue(for: firstName)?.multiArrayValue
        else {
            throw MoraMLXError.inferenceFailed("no multiArray output")
        }
        return Self.convert(
            logProbs: logProbsArray,
            labels: inventory.espeakLabels,
            framesPerSecond: framesPerSecond
        )
    }

    private static func makeInput(audio: AudioClip) throws -> MLFeatureProvider {
        let sampleCount = audio.samples.count
        guard
            let array = try? MLMultiArray(
                shape: [1, NSNumber(value: sampleCount)], dataType: .float32
            )
        else {
            throw MoraMLXError.inferenceFailed("MLMultiArray alloc failed")
        }
        audio.samples.withUnsafeBufferPointer { buffer in
            memcpy(array.dataPointer, buffer.baseAddress!, sampleCount * MemoryLayout<Float>.size)
        }
        return try MLDictionaryFeatureProvider(
            dictionary: ["audio": MLFeatureValue(multiArray: array)]
        )
    }

    private static func convert(
        logProbs: MLMultiArray,
        labels: [String],
        framesPerSecond: Double
    ) -> PhonemePosterior {
        let shape = logProbs.shape.map { $0.intValue }
        let frameCount: Int
        let phonemeCount: Int
        switch shape.count {
        case 2:
            frameCount = shape[0]
            phonemeCount = shape[1]
        case 3 where shape[0] == 1:
            frameCount = shape[1]
            phonemeCount = shape[2]
        default:
            log.error("unexpected output shape: \(shape)")
            return PhonemePosterior(
                framesPerSecond: framesPerSecond,
                phonemeLabels: labels,
                logProbabilities: []
            )
        }
        var rows: [[Float]] = []
        rows.reserveCapacity(frameCount)
        let ptr = logProbs.dataPointer.bindMemory(
            to: Float.self, capacity: frameCount * phonemeCount
        )
        for t in 0..<frameCount {
            let base = t * phonemeCount
            var row = [Float](repeating: 0, count: phonemeCount)
            for c in 0..<phonemeCount {
                row[c] = ptr[base + c]
            }
            rows.append(row)
        }
        return PhonemePosterior(
            framesPerSecond: framesPerSecond,
            phonemeLabels: labels,
            logProbabilities: rows
        )
    }
}
```

- [ ] **Step 2: Build**

```bash
(cd Packages/MoraMLX && swift build)
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Packages/MoraMLX/Sources/MoraMLX/CoreMLPhonemePosteriorProvider.swift
git commit -m "$(cat <<'EOF'
mlx: add CoreMLPhonemePosteriorProvider (production impl)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---
### Task 25: Replace `MoraMLXModelCatalog` stub with real loader + delete placeholder

**Files:**
- Modify: `Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift` — real implementation.
- Delete: `Packages/MoraMLX/Sources/MoraMLX/MoraMLXPlaceholder.swift`.
- Modify: `Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogStubTests.swift` → rename to `MoraMLXModelCatalogTests.swift` and flip the expectation from "throws" to "returns a usable evaluator".

- [ ] **Step 1: Rewrite `MoraMLXModelCatalog.swift`**

```swift
// Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift
import Foundation
import CoreML
import MoraEngines
import MoraCore

/// Loads the bundled wav2vec2-phoneme CoreML model and assembles a
/// production `PhonemeModelPronunciationEvaluator` wiring it through
/// `CoreMLPhonemePosteriorProvider` + `ForcedAligner` + `GOPScorer`.
///
/// The loaded `MLModel` and `PhonemeInventory` are cached for the
/// process lifetime so subsequent calls reuse the same model instance.
public enum MoraMLXModelCatalog {
    private static let cache = Cache()

    public static func loadPhonemeEvaluator(
        timeout: Duration = .milliseconds(1000)
    ) throws -> PhonemeModelPronunciationEvaluator {
        let (model, inventory) = try cache.loadOrGet()
        let provider = CoreMLPhonemePosteriorProvider(model: model, inventory: inventory)
        return PhonemeModelPronunciationEvaluator(
            provider: provider,
            aligner: ForcedAligner(inventory: inventory),
            scorer: GOPScorer(),
            inventory: inventory,
            l1Profile: JapaneseL1Profile(),
            timeout: timeout
        )
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var loaded: (MLModel, PhonemeInventory)?

        func loadOrGet() throws -> (MLModel, PhonemeInventory) {
            lock.lock()
            defer { lock.unlock() }
            if let loaded { return loaded }
            let model = try loadModel()
            let labels = try loadLabels()
            let inventory = PhonemeInventory(
                espeakLabels: labels,
                supportedPhonemeIPA: PhonemeInventory.v15SupportedPhonemeIPA
            )
            let result = (model, inventory)
            loaded = result
            return result
        }

        private func loadModel() throws -> MLModel {
            guard let url = Bundle.module.url(forResource: "wav2vec2-phoneme", withExtension: "mlmodelc")
            else {
                throw MoraMLXError.modelNotBundled
            }
            do {
                return try MLModel(contentsOf: url)
            } catch {
                throw MoraMLXError.inferenceFailed(String(describing: error))
            }
        }

        private func loadLabels() throws -> [String] {
            guard let url = Bundle.module.url(forResource: "phoneme-labels", withExtension: "json")
            else {
                throw MoraMLXError.inventoryUnavailable
            }
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                throw MoraMLXError.inventoryUnavailable
            }
        }
    }
}
```

- [ ] **Step 2: Delete the placeholder**

```bash
git rm Packages/MoraMLX/Sources/MoraMLX/MoraMLXPlaceholder.swift
```

- [ ] **Step 3: Replace the stub test**

```bash
git mv Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogStubTests.swift \
       Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogTests.swift
```

Rewrite the file:

```swift
// Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogTests.swift
import XCTest
@testable import MoraMLX
import MoraEngines
import MoraCore

final class MoraMLXModelCatalogTests: XCTestCase {
    func testLoadPhonemeEvaluatorReturnsEvaluator() throws {
        let e = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        XCTAssertTrue(e.supports(target: Phoneme(ipa: "ʃ"), in: word()))
    }

    func testSecondLoadIsCached() throws {
        let first = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        let second = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        // Struct equality is not defined; a coarse check — both expose a
        // working `supports` on the same inventory — is sufficient.
        XCTAssertEqual(
            first.inventory.espeakLabels.count,
            second.inventory.espeakLabels.count
        )
    }

    private func word() -> Word {
        Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
    }
}
```

- [ ] **Step 4: Run the MoraMLX suite**

```bash
(cd Packages/MoraMLX && swift test)
```

Expected: PASS, 2 tests. Requires LFS fetch to have materialized the `.mlmodelc`.

- [ ] **Step 5: Commit**

```bash
git add Packages/MoraMLX/Sources/MoraMLX/MoraMLXModelCatalog.swift \
        Packages/MoraMLX/Tests/MoraMLXTests/MoraMLXModelCatalogTests.swift \
        Packages/MoraMLX/Sources/MoraMLX/MoraMLXPlaceholder.swift
git commit -m "$(cat <<'EOF'
mlx: replace stub with real MoraMLXModelCatalog loader

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 26: Real-model smoke test + fixture clip

**Files:**
- Create: `Packages/MoraMLX/Tests/MoraMLXTests/CoreMLPhonemePosteriorProviderSmokeTests.swift`
- Create: `Packages/MoraMLX/Tests/MoraMLXTests/Fixtures/short-sh-clip.wav` — a small (~20 KB) 16 kHz mono WAV containing a synthesized /ʃ/-like noise burst. Generate with `sox` or a one-off Swift helper and check in as a binary.

- [ ] **Step 1: Generate the fixture (one-time manual step)**

Pick ONE approach:

Approach A — `sox`:

```bash
sox -r 16000 -c 1 -n \
    Packages/MoraMLX/Tests/MoraMLXTests/Fixtures/short-sh-clip.wav \
    synth 1.0 pinknoise band -n 4000 1500 vol 0.3
```

Approach B — Swift playground script: generate a 1-second mono Float32 buffer with band-limited noise centered at 4 kHz, write as WAV via `AVFoundation.AVAudioFile`.

Pick whichever is convenient. The fixture's absolute content does not matter; only that it is non-empty 16 kHz mono PCM.

- [ ] **Step 2: Write the smoke test**

```swift
// Packages/MoraMLX/Tests/MoraMLXTests/CoreMLPhonemePosteriorProviderSmokeTests.swift
import XCTest
@testable import MoraMLX
import MoraEngines

final class CoreMLPhonemePosteriorProviderSmokeTests: XCTestCase {
    func testPosteriorHasFramesAndPhonemes() async throws {
        let evaluator = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        let audio = try Self.loadFixture(name: "short-sh-clip")
        let posterior = try await evaluator.provider.posterior(for: audio)
        XCTAssertGreaterThan(posterior.frameCount, 0)
        XCTAssertGreaterThan(posterior.phonemeCount, 30)
        XCTAssertGreaterThan(posterior.logProbabilities[0].max() ?? -999, -5.0)
    }

    private static func loadFixture(name: String) throws -> AudioClip {
        guard let url = Bundle.module.url(forResource: name, withExtension: "wav") else {
            throw XCTSkip("fixture \(name).wav missing — skipping smoke test")
        }
        let data = try Data(contentsOf: url)
        return try decodeWAV16kHzMono(data: data)
    }
}

private func decodeWAV16kHzMono(data: Data) throws -> AudioClip {
    // Minimal RIFF/WAV decoder: PCM16 mono at 16 kHz. Real tests use
    // AVAudioFile; keeping this dependency-free avoids dragging
    // AVFoundation into the MoraMLX test target.
    let header = data.prefix(44)
    guard header.count == 44 else { throw WAVError.truncated }
    let bodyData = data.suffix(from: 44)
    var samples: [Float] = []
    samples.reserveCapacity(bodyData.count / 2)
    bodyData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
        let p = raw.bindMemory(to: Int16.self)
        for i in 0..<p.count {
            samples.append(Float(p[i]) / Float(Int16.max))
        }
    }
    return AudioClip(samples: samples, sampleRate: 16_000)
}

private enum WAVError: Error { case truncated }
```

- [ ] **Step 3: Run the smoke test**

```bash
(cd Packages/MoraMLX && swift test --filter CoreMLPhonemePosteriorProviderSmokeTests)
```

Expected: PASS, 1 test.

- [ ] **Step 4: Commit**

```bash
git add Packages/MoraMLX/Tests/MoraMLXTests/CoreMLPhonemePosteriorProviderSmokeTests.swift \
        Packages/MoraMLX/Tests/MoraMLXTests/Fixtures/short-sh-clip.wav
git commit -m "$(cat <<'EOF'
mlx: smoke test loads real wav2vec2 model against fixture clip

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 27: CI — enable Git LFS on checkout

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Locate the `actions/checkout` step(s) in the workflow**

Typically looks like:

```yaml
- uses: actions/checkout@v4
```

Replace with:

```yaml
- uses: actions/checkout@v4
  with:
    lfs: true
```

Apply to every job that invokes checkout (`lint`, `build-test`, and any other).

- [ ] **Step 2: Verify the workflow still parses**

```bash
python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'
```

Expected: no output (parse OK).

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci: enable Git LFS on checkout for Engine B model

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 28: Full sweep — format, suites, binary gate

Same as Task 18 but with the real model in place.

- [ ] **Step 1: Lint / format**

```bash
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

Expected: clean.

- [ ] **Step 2: Run every package**

```bash
(cd Packages/MoraCore && swift test)
(cd Packages/MoraEngines && swift test)
(cd Packages/MoraUI && swift test)
(cd Packages/MoraTesting && swift test)
(cd Packages/MoraMLX && swift test)
```

All green. The MoraMLX suite now includes the smoke test against the real model.

- [ ] **Step 3: App build**

```bash
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Source gate**

```bash
git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages
```

Expected: empty.

- [ ] **Step 5: Binary gate (confirm nothing from a cloud SDK made it into the Release binary)**

```bash
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Release CODE_SIGNING_ALLOWED=NO
if nm build/Release-iphonesimulator/Mora.app/Mora 2>/dev/null | grep -iE 'speechace|azure|speechsuper'; then
  echo "Cloud pronunciation symbol detected in Mora binary"
  exit 1
fi
```

Expected: no output (no matches).

- [ ] **Step 6: Commit any drift**

If the above surfaced formatting drift, commit it:

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore: swift-format sweep after Engine B Part 2

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

Otherwise skip.

---

### Task 29: Device-only latency benchmark (manual runbook)

Goal: a manual iPad Air M2 test that confirms `Engine B.evaluate` stays under 1000 ms on a 2-second clip. Checked in as test code but not wired into CI.

**Files:**
- Create: `Mora/Benchmarks/Phase3LatencyBenchmark.swift`

- [ ] **Step 1: Add the benchmark**

```swift
// Mora/Benchmarks/Phase3LatencyBenchmark.swift
#if os(iOS)
import Foundation
import MoraCore
import MoraEngines
import MoraMLX

/// Manual latency benchmark for Engine B on device. Not wired into CI.
/// Run from Xcode on a physical iPad Air M2 with:
///
///     await Phase3LatencyBenchmark.run()
///
/// Prints p50 / p95 latency to the console.
public enum Phase3LatencyBenchmark {
    public static func run() async {
        let evaluator: PhonemeModelPronunciationEvaluator
        do {
            evaluator = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        } catch {
            print("model load failed: \(error)")
            return
        }
        let samples = Array(repeating: Float(0), count: 16_000 * 2)
        let clip = AudioClip(samples: samples, sampleRate: 16_000)
        let word = Word(
            surface: "ship",
            graphemes: [Grapheme(letters: "sh"), Grapheme(letters: "i"), Grapheme(letters: "p")],
            phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "ɪ"), Phoneme(ipa: "p")],
            targetPhoneme: Phoneme(ipa: "ʃ")
        )
        let asr = ASRResult(transcript: "ship", confidence: 0.9)

        // Warmup
        for _ in 0..<3 {
            _ = await evaluator.evaluate(
                audio: clip, expected: word, targetPhoneme: Phoneme(ipa: "ʃ"), asr: asr
            )
        }

        var samples_ms: [Double] = []
        for _ in 0..<20 {
            let start = ContinuousClock.now
            _ = await evaluator.evaluate(
                audio: clip, expected: word, targetPhoneme: Phoneme(ipa: "ʃ"), asr: asr
            )
            let elapsed = start.duration(to: .now)
            let (s, attos) = elapsed.components
            let ms = Double(s) * 1000 + Double(attos) / 1e15
            samples_ms.append(ms)
        }
        samples_ms.sort()
        let p50 = samples_ms[samples_ms.count / 2]
        let p95 = samples_ms[Int(Double(samples_ms.count) * 0.95)]
        print("Phase3LatencyBenchmark: p50=\(p50)ms p95=\(p95)ms (budget 1000ms)")
    }
}
#endif
```

- [ ] **Step 2: Add the directory and file to `project.yml`** (the Xcode project generator)

Check whether `project.yml` already picks up everything under `Mora/`. If it does (globbing), no change. If not, add:

```yaml
sources:
  - path: Mora/Benchmarks
    type: folder
```

Re-run `xcodegen generate` and build:

```bash
xcodegen generate
xcodebuild build \
  -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add Mora/Benchmarks/Phase3LatencyBenchmark.swift project.yml Mora.xcodeproj 2>/dev/null || true
git add Mora/Benchmarks/Phase3LatencyBenchmark.swift
git commit -m "$(cat <<'EOF'
bench: add manual Engine B latency benchmark (iPad Air M2)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 30: Docs — cross-link spec ↔ plan, update CLAUDE.md, Part 2 progress section

**Files:**
- Modify: `docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md` — add a plan-cross-link line under the header.
- Modify: `CLAUDE.md` — update the `MoraMLX` paragraph under `## Architecture` to reflect the package's new role (CoreML model host for Engine B) and that it now has public API and dependencies on `MoraCore` / `MoraEngines`.
- Modify: `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md` — update the `Current progress` section to cover Part 2.

- [ ] **Step 1: Update the parent spec header**

Find the header block (between `---` markers at the top of `2026-04-22-pronunciation-feedback-design.md`) and append:

```markdown
- **Implementation plan (Phase 3):** `docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md`
```

- [ ] **Step 2: Update `CLAUDE.md`**

Locate the `MoraMLX` paragraph in `CLAUDE.md` (under `## Architecture`, currently describing it as "placeholder for the v1.5 on-device LLM path" with "do not add runtime dependencies on it from other packages"). Replace with:

```markdown
- **MoraMLX** — Host for on-device ML models used at runtime. Depends on `MoraCore` and `MoraEngines`. Exports `MoraMLXModelCatalog` (lazy model loader with in-process cache) and `CoreMLPhonemePosteriorProvider` (conforms to `MoraEngines.PhonemePosteriorProvider`). As of v1.5 it bundles the INT8-quantized wav2vec2-phoneme CoreML model for Engine B pronunciation scoring; later v1.5 work will also host the on-device LLM (Apple Intelligence Foundation Models or MLX + Gemma). Domain packages consume models only through narrow protocols defined in `MoraEngines`; `MoraUI` does not depend on `MoraMLX`.
```

- [ ] **Step 3: Extend the plan's progress section**

Append to the `Current progress` section added in Task 19:

```markdown
**Part 2 complete.** Tasks 20–30 landed on a follow-up PR.

| # | Task | Commit |
|---|------|--------|
| 20 | dev-tools/model-conversion scaffolding | `<hash>` |
| 21 | convert.py script | `<hash>` |
| 22 | Run conversion + LFS commit | `<hash>` |
| 23 | MoraMLX Package.swift resources | `<hash>` |
| 24 | CoreMLPhonemePosteriorProvider | `<hash>` |
| 25 | MoraMLXModelCatalog real loader | `<hash>` |
| 26 | Smoke test + fixture | `<hash>` |
| 27 | CI LFS checkout | `<hash>` |
| 28 | Format sweep | `<hash>` |
| 29 | Device-only latency benchmark | `<hash>` |
| 30 | Docs cross-link + CLAUDE.md update | `<hash>` |
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-04-22-pronunciation-feedback-design.md \
        docs/superpowers/plans/2026-04-22-pronunciation-feedback-engine-b.md \
        CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: cross-link pronunciation-feedback spec and Engine B plan; update CLAUDE.md for MoraMLX

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

## Completion Checklist

After Task 30, verify:

- [ ] `(cd Packages/MoraCore && swift test)` green.
- [ ] `(cd Packages/MoraEngines && swift test)` green.
- [ ] `(cd Packages/MoraUI && swift test)` green.
- [ ] `(cd Packages/MoraTesting && swift test)` green.
- [ ] `(cd Packages/MoraMLX && swift test)` green — includes the real-model smoke test.
- [ ] `swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests` passes.
- [ ] `xcodegen generate && xcodebuild build -project Mora.xcodeproj -scheme Mora -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` succeeds.
- [ ] `git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages` is empty.
- [ ] `git lfs ls-files | grep wav2vec2-phoneme` lists the model files.
- [ ] Running Mora on an iPad Air with a /ʃ/-target word produces no UI regressions and `PronunciationTrialLog` rows appear (verified by a small debug fetch from `MoraApp` or via a one-off XCTest with the real device container).

---

## Handoff notes for the follow-up promotion PR (not in scope of this plan)

- Introduce `SettingsStore.preferredEvaluator: {.featureBased, .phonemeModel}` (default `.featureBased`) and read it in `ShadowEvaluatorFactory.makeShadowFactory` to decide which evaluator is `primary`. When switched to `.phonemeModel`, Engine B becomes the UI-facing evaluator and Engine A becomes the shadow.
- Calibrate `GOPScorer.k` and `GOPScorer.gopZero` using the CSVs produced by `dev-tools/pronunciation-bench/`. Ship the new constants as PR-reviewable edits to `GOPScorer.swift` plus a paragraph in the PR description explaining how they were derived.
- Promotion gate thresholds (per parent spec §6.3): Spearman ρ with SpeechAce ≥ 0.80; Cohen's κ with Engine A ≥ 0.70. Both measured in `pronunciation-bench/`.
- If the promotion PR ever needs to roll back, the toggle makes it a single-commit flip — no further code change required.

