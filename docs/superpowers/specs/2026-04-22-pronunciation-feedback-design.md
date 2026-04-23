# mora — Acoustic Pronunciation Feedback Design Spec

- **Date:** 2026-04-22
- **Status:** Draft, pending user review
- **Author:** Yutaka Kondo (with Claude Code)
- **Release target:** v1.5 (alongside MoraMLX activation)
- **Extends:** `2026-04-21-mora-dyslexia-esl-design.md` §11 Assessment Pipeline (phoneme-level edit distance promise) and §5 L1 interference pairs. Does not supersede any existing spec.
- **Relates to:** `2026-04-22-mora-ipad-ux-speech-alpha-design.md` §10 (Speech Engine reshape) — the alpha lands first with transcript-only assessment; this spec later reshapes `SpeechEvent` and `OrchestratorEvent` to carry raw audio.

---

## 1. Overview

v1 ships with a transcript-level assessment path: `AppleSpeechEngine` emits `ASRResult(transcript, confidence)` and `AssessmentEngine` compares the lowercased transcript to the expected word using edit distance plus a first-character onset heuristic. The acoustic signal that would tell the app *how* a phoneme was pronounced is discarded before it reaches the engine.

This design adds a parallel acoustic pathway. Raw PCM flows from the microphone to a new `PronunciationEvaluator` protocol, which produces per-phoneme diagnoses — a category label (matched, substituted, drifted, unclear), an honest 0-100 score when the audio segmentation is reliable, and a coaching-prose key the UI speaks back through TTS. Two implementations land together:

- **Engine A** — `FeatureBasedPronunciationEvaluator`. Deterministic, rule-based, built on hand-picked acoustic features (spectral centroid, formant estimates, voicing-onset time, etc.) computed with Accelerate/vDSP. No ML model bundled. Covers a small set of high-value phonemes drawn from `JapaneseL1Profile.interferencePairs`.
- **Engine B** — `PhonemeModelPronunciationEvaluator`. CoreML-hosted wav2vec2-phoneme model plus forced alignment and GOP scoring. Covers the full English phoneme inventory. Shipped in shadow mode in v1.5 (runs in parallel, logged, not shown to the user) and promoted to primary in a later release once its correlation with SpeechAce benchmarks and its agreement with Engine A clear thresholds set in this spec.

Strict on-device invariant from `2026-04-21-mora-dyslexia-esl-design.md` §3 is preserved: no audio, no transcript, no per-trial detail leaves the device at runtime. Cloud benchmarking against SpeechAce happens only in `dev-tools/pronunciation-bench/`, a repo-root directory that is not referenced by any SPM package or by `project.yml`.

## 2. Motivation

The learner's motivating example is `/ʃ/` in words like "ship". When the child says /sɪp/ instead of /ʃɪp/, the current transcript path either accepts the word (because ASR softens the difference) or rejects it with a generic "try again" — neither is useful feedback. The child cannot tell which sound was wrong, how close they were, or what to change.

Orton-Gillingham and Barton pedagogy rest on explicit, multisensory instruction about *articulation* ("round your lips, keep the tongue back, now say sh"). mora can only close that loop with acoustic-level evaluation. The L1-interference framework already encoded in `JapaneseL1Profile` tells us which confusions matter most for this learner; the pipeline below turns that catalogue into runtime feedback.

## 3. Goals and Non-Goals

### Goals

- Per-phoneme feedback for a curated set of phonemes: categorical diagnosis (`matched` / `substitutedBy(X)` / `driftedWithin` / `unclear`) plus an honest 0-100 score when segmentation is reliable.
- Coaching prose, hand-authored per (target, substitute) pair, delivered by TTS and as a short on-screen bubble. Prose is versioned and ships through `MoraStrings`.
- Engine A ships as the primary v1.5 evaluator, Engine B ships alongside in shadow mode.
- No additional cloud dependencies in the runtime app binary. Existing on-device invariant intact.
- Protocol abstraction allows Engine B to replace Engine A with a one-line setting flip once promotion gates clear.
- Calibration methodology is reproducible: Engine A's thresholds are backed by acoustic-phonetics literature (Kent & Read, Ladefoged, Fujimura) and tunable per-speaker via a benchmark harness.

### Non-Goals

- General-purpose pronunciation assessment for arbitrary phonemes in v1.5's first release. Engine A's `supports(target:in:)` returns false outside a curated list; outside-support trials fall back to transcript-only assessment.
- Per-speaker adaptive thresholds in v1.5's first release. Initial thresholds are fixed literature values; adaptation is a separate follow-up PR.
- Prosody, stress, or intonation scoring. Out of scope for v1.5; phoneme articulation only.
- A user-visible evaluator toggle in Settings. Engine A vs Engine B primary selection is a build-internal decision gated by correlation thresholds, not a UX choice.
- Cloud-based runtime evaluation in any build configuration of the shipped app. SpeechAce is a development-time benchmark only, isolated in `dev-tools/`.

## 4. Design Decisions

### 4.1 On-device strictly; cloud confined to dev tools

The mora v1 privacy invariant ("no raw audio, transcripts, or per-trial details may leave the device" — `2026-04-21-mora-dyslexia-esl-design.md` §3) is preserved for every shipped build, Debug and Release alike.

SpeechAce is used only as a **correlation oracle** during Engine A threshold calibration and Engine B promotion gating. It lives in a repo-root directory `dev-tools/pronunciation-bench/` that:

- is its own Swift Package with no dependency on `MoraCore` / `MoraEngines` / `MoraUI` / `MoraMLX`,
- is not listed in `project.yml` or in any `Package.swift` of the shipped packages,
- reads exported audio fixtures and produces a CSV of (fixture, SpeechAce score, Engine A score, Engine B score) for manual review.

A CI job asserts that neither sources nor compiled binary of the shipped app contain any reference to SpeechAce or to any other cloud assessment SDK. See §11 for the exact grep invocation.

### 4.2 Engine A first, Engine B alongside in shadow

Engine A is a rule-based feature extractor, tiny, deterministic, and interpretable. It is the right implementation for:

- a v1.5 audience of one (the author's son) plus a small TestFlight ring,
- a design where scoring must not be fabricated (score comes from a measured feature value plus a documented boundary; every score is reproducible from the log),
- a surface area we can debug with `print(features)` and a spectrogram, not a neural network.

Engine B is the right long-term implementation because it generalizes beyond the curated pair list, is forced-aligned against the actual target text, and produces industry-standard GOP scores. Shipping B in shadow from v1.5 day one gives us the dataset we need to promote it to primary in a later release without shipping a regression.

A middle option (tiny per-pair CoreML classifiers) was rejected: training data is not in hand, and the per-pair acoustic literature is strong enough that a rule-based classifier is expected to match a trained binary classifier on the pairs it covers, without the data-collection overhead.

### 4.3 Feedback UX: categorical diagnosis, honest score, coaching prose

The child receives three things after an in-scope trial:

1. A category bar: "今の `sh` は `s` に寄ってたよ" (categorical — maps to `PhonemeAssessmentLabel`).
2. A 0-100 score bar, but only when segmentation confidence is above a threshold (reliable flag). Otherwise the bar is suppressed.
3. A coaching bubble plus TTS of the same text: "唇を少し丸めて、舌の奥を上げてみよう。sh。" (prose from `MoraStrings`, selected by a coaching key returned from the evaluator).

The score is computed as a linear interpolation between the substitute-phoneme's feature centroid and the target-phoneme's feature centroid, clamped to [0, 100]. The number is tied to the measured feature, never to a black-box model output. When the evaluator cannot localize the target phoneme region with high confidence, it sets `isReliable = false` and the UI hides the score entirely.

### 4.4 `/ʃ/` handling: two L1Profile pair entries

`JapaneseL1Profile.interferencePairs` does not currently include `/ʃ/`. Two entries are added:

- `sh_s_sub` — `/ʃ/` → `/s/` substitution. The child's sibilant is sharp / high-frequency; perceived as "ship" said as "sip".
- `sh_drift_target` — `/ʃ/` → `/ʃ/` *drift sentinel*. The child produces an /ʃ/-like sibilant but with insufficient lip rounding or tongue retraction (the /ɕ/ carryover from Japanese し). There is no substitute phoneme; the evaluator scores the articulatory distance from the English `/ʃ/` acoustic target but does not label a substitution.

The `from == to` sentinel is a deliberate compromise: it keeps the existing `PhonemeConfusionPair` type, leaves `L1Profile.matchInterference(expected:heard:)` unchanged, and routes drift through the evaluator's scoring path only (never through substitution classification). A cleaner `PhonemeAcousticTarget` type is considered in §14 Open Questions; introducing it is deferred to Engine B design work to avoid diff surface on an already-busy L1Profile.

### 4.5 Scoring honesty constraint

The author's product requirement: "Grade C should be awarded only if the scoring is reasonably accurate." Scores must not be performative. The spec enforces this by:

- Using linear interpolation between literature-derived feature centroids, not a learned or inferred score.
- Gating score display behind `isReliable`.
- Logging the raw feature dictionary on every trial so a stored assessment can be re-derived and audited.
- Never producing a score for `driftedWithin` in Engine A's first release unless both the primary feature (e.g. F2 for `/ʃ/` lip rounding) and its confidence proxy (energy above 250 Hz) clear the reliability threshold.

### 4.6 Release timing: v1.5 alongside MoraMLX

Coincidence with MoraMLX activation is intentional: Engine B uses the MLX / CoreML runtime path that MoraMLX lights up. Engine A is runtime-independent (Accelerate only) and could ship earlier, but shipping it with Engine B keeps the pronunciation-feedback feature's external surface coherent — one release introduces per-phoneme feedback, not two.

Engine A and Engine B completion are to be pushed through promptly after the current alpha plans land (`2026-04-22-mora-ipad-ux-speech-alpha.md` and `2026-04-22-native-language-and-age-selection.md`).

## 5. Architecture

```
MoraUI (SwiftUI)
  ├── DecodeActivityView / ShortSentencesView
  │     emits .answerHeard(TrialRecording)              [was: .answerHeard(ASRResult)]
  └── PronunciationFeedbackOverlay                       [NEW]
        renders category + score + coaching bubble, triggers TTS

MoraEngines
  ├── SessionOrchestrator
  │     passes TrialRecording to AssessmentEngine
  ├── AssessmentEngine
  │     holds a `PronunciationEvaluator`; consults it before the transcript path
  ├── PronunciationEvaluator (protocol)                 [NEW]
  │     func supports(target:in:) -> Bool
  │     func evaluate(audio:expected:targetPhoneme:asr:) async -> PhonemeTrialAssessment
  ├── FeatureBasedPronunciationEvaluator                [NEW — Engine A, v1.5 primary]
  │     Accelerate/vDSP feature extractors, rule-based labeling + scoring
  └── Speech/AppleSpeechEngine
        maintains a PCM ring buffer, emits TrialRecording on final

MoraMLX  (activates in v1.5)
  └── PhonemeModelPronunciationEvaluator                [NEW — Engine B, v1.5 shadow]
        wav2vec2-phoneme CoreML model + forced alignment + GOP scoring

MoraCore
  └── JapaneseL1Profile
        interferencePairs += { sh_s_sub, sh_drift_target }

MoraTesting
  └── FakePronunciationEvaluator                        [NEW]
        scripted responses for SessionOrchestrator / AssessmentEngine tests

dev-tools/pronunciation-bench/                          [NEW, repo-root]
  Swift Package, not referenced from project.yml or any shipped Package.swift
  reads fixture audio, calls SpeechAce API, loads Engine A and Engine B,
  produces (fixture, speechace_score, engineA_score, engineB_score) CSVs
```

Dependency direction preserved: `Core ← Engines ← UI`, with `MoraMLX` hosting Engine B behind the protocol defined in `MoraEngines`. `dev-tools/` depends on whatever packages it needs for programmatic use but is not depended on in return.

## 6. Components

### 6.1 `PronunciationEvaluator` protocol

New file: `Packages/MoraEngines/Sources/MoraEngines/PronunciationEvaluator.swift`.

```swift
import Foundation
import MoraCore

public struct AudioClip: Sendable, Hashable {
    public let samples: [Float]          // mono PCM
    public let sampleRate: Double        // nominally 16000
    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }
}

public enum PhonemeAssessmentLabel: Sendable, Hashable, Codable {
    case matched
    case substitutedBy(Phoneme)
    case driftedWithin       // same target phoneme, but articulation off-center
    case unclear             // segmentation or audio unusable
}

public struct PhonemeTrialAssessment: Sendable, Hashable, Codable {
    public let targetPhoneme: Phoneme
    public let label: PhonemeAssessmentLabel
    public let score: Int?                           // 0...100, nil when !isReliable
    public let coachingKey: String?                  // MoraStrings key; nil for matched or unclear
    public let features: [String: Double]            // diagnostic payload for logs
    public let isReliable: Bool                      // segmentation-confidence gate
}

public protocol PronunciationEvaluator: Sendable {
    func supports(target: Phoneme, in word: Word) -> Bool
    func evaluate(
        audio: AudioClip,
        expected: Word,
        targetPhoneme: Phoneme,
        asr: ASRResult
    ) async -> PhonemeTrialAssessment
}
```

The protocol is `async` even though Engine A's implementation is synchronous. This keeps the call site identical for Engine B, which performs CoreML inference and may yield.

### 6.2 `FeatureBasedPronunciationEvaluator` (Engine A)

New file: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift`.

**Supported targets** (v1.5 first release):

| Pair / Target | IPA | Mode | Primary feature | Secondary feature |
|---|---|---|---|---|
| `sh_s_sub` | /ʃ/ vs /s/ | substitution | spectral centroid (kHz) | peak frequency |
| `sh_drift_target` | /ʃ/ articulation | drift | F2 estimate | low-band (250–750 Hz) energy ratio |
| `r_l_swap` | /r/ vs /l/ | substitution (bidir) | F3 estimate (LPC) | F3 transition slope |
| `f_h_sub` | /f/ vs /h/ | substitution | high/low band energy ratio | onset RMS slope |
| `v_b_sub` | /v/ vs /b/ | substitution | voicing onset time | zero-crossing-rate variance |
| `th_voiceless_s_sub` | /θ/ vs /s/ | substitution | spectral centroid | spectral flatness |
| `th_voiceless_t_sub` | /θ/ vs /t/ | substitution | onset-burst RMS slope (30 ms) | post-onset energy |
| `ae_lax_conflate` | /æ/ vs /ʌ/ | substitution (bidir) | F1, F2 joint | vowel duration |

**Feature centroids and boundaries** (initial, literature-derived; units as listed):

| Feature | Target centroid | Substitute centroid | Boundary | Unit |
|---|---|---|---|---|
| /ʃ/ spectral centroid | 3.0 | 6.5 (/s/) | 4.5 | kHz |
| /ʃ/ F2 | 2.0 | — | 1.7 (min reliable) | kHz |
| /r/ F3 | 1.7 | 3.0 (/l/) | 2.3 | kHz |
| /f/ h/l energy ratio | 1.4 | 0.5 (/h/) | 0.9 | dimensionless |
| /v/ voicing onset time | −30 (lead) | +15 (/b/) | −5 | ms |
| /θ/ spectral centroid | 4.5 | 6.5 (/s/) | 5.5 | kHz |
| /θ/ burst slope 30 ms | 0.4 | 1.5 (/t/) | 0.8 | RMS/ms (normalized) |
| /æ/ F1 | 700 | 580 (/ʌ/) | 640 | Hz |
| /æ/ F2 | 1900 | 1300 (/ʌ/) | 1600 | Hz |

These values are recorded in the spec as the source of truth for v1.5's first release and are expected to shift by at most ±15% per-speaker in follow-up PRs.

**Scoring**: for a measured feature value `f` with target centroid `t` and boundary `b`,

```
raw = (b - f) / (b - t)          // signed; direction depends on sign of (b - t)
score = clamp(round(raw * 100), 0, 100)
```

When the pair has two features (primary + secondary), both are scored independently and the final score is the minimum of the two (the pronunciation is only as good as its weakest measured dimension). When the feature is `driftedWithin` only, a single dimension is scored; the pair's substitution branch is not invoked.

**Phoneme-region localization**: Engine A uses the word-level timing from `SFTranscription.segments` combined with a positional heuristic:

- Onset phoneme (position 0 in `Word.phonemes`): first `min(150 ms, 0.25 × wordDuration)` of the word's audio segment.
- Coda phoneme (last position in `Word.phonemes`): last `min(150 ms, 0.25 × wordDuration)`.
- Medial phoneme (any other position): slice roughly at `position × wordDuration / phonemeCount` with ±50 ms window, and set `isReliable = false`.

When `isReliable = false`, Engine A still returns a label but no score.

**Audio sanity**: before any feature extraction, Engine A checks:

- Segment RMS above a noise-floor threshold (`−42 dBFS`). If below, returns `.unclear` with `isReliable = false`.
- Segment duration between 40 ms and 600 ms. If outside, same as above.

### 6.3 `PhonemeModelPronunciationEvaluator` (Engine B)

New file: `Packages/MoraMLX/Sources/MoraMLX/PhonemeModelPronunciationEvaluator.swift`.

- Model: `wav2vec2-xlsr-53-espeak-cv-ft` (Facebook, phoneme-level CTC head, espeak IPA output). Converted to CoreML via `coremltools` (conversion script lives in `dev-tools/model-conversion/`, not shipped). INT8-quantized. Expected size: ~150 MB post-quantization.
- Model file bundled as package resource `Packages/MoraMLX/Sources/MoraMLX/Resources/wav2vec2-phoneme.mlmodelc`.
- Loader: `MoraMLX.loadPhonemeModel()` returns a cached `MLModel`. First call is lazy (first-launch cost once).
- Inference: audio → phoneme-posterior matrix → forced alignment against `Word.phonemes` using Viterbi on the posterior sequence → per-phoneme GOP scores.
- GOP: `GOP(p, segment) = log p(p | segment) − max_q log p(q | segment)`. Mapped to 0-100 via a sigmoid trained on a held-out set from `dev-tools/pronunciation-bench/`.
- Latency budget: <1000 ms on iPad Air M2 for a 2-second utterance. If exceeded, the orchestrator uses Engine A's result and logs the timeout; Engine B's eventual result is discarded for that trial.

**Shadow mode in v1.5 first release**:

- `AssessmentEngine` consults Engine A synchronously for UI-facing results.
- In parallel, the orchestrator fires an Engine B `evaluate` call; the result is written to a new SwiftData entity `PronunciationTrialLog` alongside Engine A's result. The UI never sees Engine B output in shadow mode.
- Shadow-mode log rows are capped per device (1000 rows, FIFO) and included in the parent-mode audit export (future Parent Mode spec; out of scope here beyond the capped-storage note).

**Promotion gate** (future PR, flagged in §14 Open Questions):

- `dev-tools/pronunciation-bench/` computes, over a shared fixture set:
  - Spearman ρ between Engine B scores and SpeechAce scores ≥ 0.80.
  - Cohen's κ between Engine B categorical labels and Engine A categorical labels ≥ 0.70 on the Engine A-supported phoneme set.
- When both clear, a follow-up PR flips `SettingsStore.preferredEvaluator = .phonemeModel` by default. Engine A remains available as fallback.

### 6.4 `JapaneseL1Profile` changes

`Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift` gains two entries at the end of `interferencePairs`:

```swift
PhonemeConfusionPair(
    tag: "sh_s_sub",
    from: Phoneme(ipa: "ʃ"), to: Phoneme(ipa: "s"),
    examples: ["ship/sip", "shoe/sue", "shell/sell"],
    bidirectional: false
),
PhonemeConfusionPair(
    tag: "sh_drift_target",
    from: Phoneme(ipa: "ʃ"), to: Phoneme(ipa: "ʃ"),
    examples: ["ship", "shop", "fish"],
    bidirectional: false
),
```

The `from == to` sentinel on `sh_drift_target` is recognized by `FeatureBasedPronunciationEvaluator` as a drift-only target (scoring path, no substitution label). `L1Profile.matchInterference(expected:heard:)` unchanged: it still only matches substitution pairs where `from != to`, so the new drift entry is transparent to any existing call site.

### 6.5 Coaching prose in `MoraStrings`

New catalog keys. Values are authored in Japanese (learner's L1) and English (future-proofing for L1 expansion). Table below quotes the strings directly per CLAUDE.md language-policy exception for localized product content.

| Key | Japanese | English |
|---|---|---|
| `coaching.sh_sub_s.ja` | くちびるをまるめて、したのおくをもちあげてみよう。「sh」。 | (not used in v1.5) |
| `coaching.sh_drift.ja` | もうすこしくちをまるくして、ながくのばしてみよう。「shhhh」。 | — |
| `coaching.r_sub_l.ja` | したのさきはどこにもつけないで、おくだけすこし上に。「r」。 | — |
| `coaching.l_sub_r.ja` | したのさきを上のはのうらにつけて、そのまま「l」。 | — |
| `coaching.f_sub_h.ja` | 上のはでしたくちびるに、かるくふれて「fff」。 | — |
| `coaching.v_sub_b.ja` | 上のはでしたくちびるにふれて、のどをふるわせて「vvv」。 | — |
| `coaching.th_voiceless_sub_s.ja` | したのさきをはのあいだにそっと出して「thhh」。 | — |
| `coaching.th_voiceless_sub_t.ja` | したのさきをはのあいだにそっと出して、とめずに「thhh」。 | — |
| `coaching.ae_sub_schwa.ja` | 口をよこにひろげて、あごを下げて「æ」。 | — |

The spec fixes the catalog keys. The Japanese copy is the author's first draft; final wording is Yutaka's call during implementation. English copy is left blank in v1.5 because no non-Japanese L1 ships yet.

Evaluator returns `coachingKey` set to one of the above when the label is `substitutedBy(...)` or `driftedWithin`. UI resolves the key through the existing `moraStrings` catalog and hands the resolved text to both the on-screen bubble and `AppleTTSEngine.speak(text:)`.

### 6.6 `FakePronunciationEvaluator` (MoraTesting)

New file: `Packages/MoraTesting/Sources/MoraTesting/FakePronunciationEvaluator.swift`.

- Scripted responses keyed by `targetPhoneme.ipa`. Test code configures `fake.responses["ʃ"] = PhonemeTrialAssessment(...)` and the fake returns the scripted value on `evaluate`. Unconfigured targets return `.unclear` with `isReliable = false`.
- `supports(target:in:)` honors a `supportedTargets: Set<String>` property; tests that exercise the fallback path set this to `[]`.

## 7. Data Flow — Single Trial

```
1. UI (DecodeActivityView / ShortSentencesView) starts tap-to-listen.
2. AppleSpeechEngine.listen() streams:
     .started
     .partial(...)  *
     .final(TrialRecording)
   where AppleSpeechEngine now keeps a ring-buffer of Float32 PCM samples
   captured from the installed audio tap, and on SFSpeech recognition-final
   emits the `.final` event with the buffered audio sliced to the final
   recognized range plus 100 ms trailing silence.
3. View handles the .final event:
     await orchestrator.handle(.answerHeard(recording))
4. SessionOrchestrator.answerHeard(recording):
     await assessmentEngine.assess(
         expected: currentWord,
         recording: recording,
         leniency: .newWord
     )
5. AssessmentEngine.assess:
     let targetPhoneme = expected.targetPhoneme  // selected by curriculum
     if evaluator.supports(target: targetPhoneme, in: expected):
         let phoneme = await evaluator.evaluate(
             audio: recording.audio,
             expected: expected,
             targetPhoneme: targetPhoneme,
             asr: recording.asr
         )
         return TrialAssessment(..., phoneme: phoneme)
     else:
         return (existing transcript-based TrialAssessment, phoneme: nil)
6. UI renders TrialAssessment:
     - correct/wrong tile          (existing)
     - if phoneme != nil && phoneme.isReliable && phoneme.score != nil:
           category bar + 0-100 score bar + coaching bubble (TTS + text)
     - else if phoneme != nil:
           category bar + short TTS hint, no score
     - else:
           existing bare-bones retry prompt
```

`*` Partial events remain transcript-only; no audio is attached until the final event, to keep memory bounded.

## 8. API Reshape

### 8.1 `SpeechEvent`

```swift
// Packages/MoraEngines/Sources/MoraEngines/Speech/SpeechEvent.swift

public enum SpeechEvent: Sendable {
    case started
    case partial(String)
    case final(TrialRecording)        // was: final(ASRResult)
}

public struct TrialRecording: Sendable, Hashable {
    public let asr: ASRResult
    public let audio: AudioClip
    public init(asr: ASRResult, audio: AudioClip) {
        self.asr = asr
        self.audio = audio
    }
}
```

`AppleSpeechEngine` installs a tap at 16 kHz mono (downmixing and downsampling if the hardware format differs). On final, it slices the ring buffer to `[SFTranscription.segments.first.timestamp ... last.timestamp + last.duration + 0.1s]` and wraps the slice in `AudioClip`.

### 8.2 `OrchestratorEvent`

```swift
// Packages/MoraEngines/Sources/MoraEngines/ADayPhase.swift

public enum OrchestratorEvent: Sendable {
    case tick
    case tap
    case answerHeard(TrialRecording)  // was: answerHeard(ASRResult)
}
```

Call sites in `DecodeActivityView` and `ShortSentencesView` swap `.answerHeard(asr)` for `.answerHeard(recording)`.

### 8.3 `AssessmentEngine`

New overload preserves existing signatures for transcript-only test usage:

```swift
public struct AssessmentEngine: Sendable {
    public let l1Profile: any L1Profile
    public let leniency: Double
    public let evaluator: any PronunciationEvaluator    // new dependency, injected

    // existing: preserves all current call sites + tests
    public func assess(expected: Word, asr: ASRResult) -> TrialAssessment
    public func assess(expected: Word, asr: ASRResult, leniency: AssessmentLeniency) -> TrialAssessment

    // new: acoustic-aware entry point used by SessionOrchestrator
    public func assess(
        expected: Word,
        recording: TrialRecording,
        leniency: AssessmentLeniency
    ) async -> TrialAssessment
}
```

The `recording` overload is `async` because the evaluator is `async`. The transcript overloads remain synchronous and unchanged. `TrialAssessment` gains a `phoneme: PhonemeTrialAssessment?` field; existing fields (`correct`, `errorKind`, `l1InterferenceTag`) unchanged.

### 8.4 `Word.targetPhoneme`

The curriculum already tracks which phoneme a given word is rehearsing. `MoraCore.Word` gains a computed property or stored field `targetPhoneme: Phoneme` that reflects the curriculum's current focus for that word. The precise source of this value is `CurriculumEngine`'s responsibility; this spec requires that by the time a `Word` reaches `AssessmentEngine`, `targetPhoneme` is set.

If, in some not-yet-identified code path, `targetPhoneme` is nil, `AssessmentEngine` falls back to the transcript-only path. This fallback is a safety net, not a strategy.

## 9. Error Handling

| Condition | Behavior |
|---|---|
| Target phoneme not in evaluator's supported set | `evaluator.supports(...)` returns false; `AssessmentEngine` falls back to transcript-only `assess(expected:asr:leniency:)` |
| Audio RMS below noise floor (−42 dBFS) or duration out of bounds | `PhonemeTrialAssessment(label: .unclear, score: nil, coachingKey: nil, isReliable: false)` |
| Segmentation confidence low (medial phoneme with imprecise word timing) | Label produced but `isReliable = false`, score nil, UI hides score bar |
| Engine B model load fails | `AssessmentEngine` uses Engine A; Engine B is tried again on next app launch |
| Engine B inference exceeds 1000 ms | Discarded for this trial; Engine A result used; shadow log records timeout |
| Microphone permission denied | Existing `PermissionCoordinator` flow; evaluator never invoked |
| SFSpeechRecognizer produces no final (hard-timeout watchdog fires) | Watchdog emits `.final(TrialRecording(asr: "", audio: <empty>))`; evaluator returns `.unclear` |

## 10. Privacy and Cloud Isolation

### 10.1 Invariants

- No shipped build (Debug or Release) of the Mora app contains any cloud-assessment SDK, API key, or network call reaching a pronunciation-assessment service.
- No audio sample, PCM buffer, `ASRResult`, `TrialAssessment`, or `PhonemeTrialAssessment` is written off device from the app binary at runtime.
- Shadow-mode Engine B logs are persisted locally in SwiftData (`PronunciationTrialLog`), capped at 1000 rows, and never transmitted. Parent Mode export (future spec) is opt-in and device-local.

### 10.2 `dev-tools/pronunciation-bench/`

- Repo location: `/dev-tools/pronunciation-bench/` at the repo root. Not inside `Packages/`, not inside `Mora/`.
- Structure: its own `Package.swift`. Lists its own dependencies (SpeechAce HTTP client, local ports of Engine A and Engine B linked via `path:` references *for offline benchmarking only*).
- Usage: Yutaka records fixture audio on-device via a debug-only recording UI (to be spec'd separately) or captures it with QuickTime/Xcode during TestFlight sessions, exports WAV to his laptop, and runs `swift run bench <fixture-dir>`. The bench uploads audio to SpeechAce, captures Engine A and Engine B scores for the same files locally, and writes a CSV.
- Secrets: SpeechAce API key read from `dev-tools/pronunciation-bench/.env` (gitignored). A `.env.example` is checked in listing required keys but no values.

### 10.3 CI enforcement

Two gates run in CI on every PR:

1. **Source gate** — `git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages` must return empty. The gate explicitly excludes `dev-tools/` and `docs/`.
2. **Binary gate** — after `xcodebuild build ... -configuration Debug`, run `nm build/Mora.app/Mora 2>/dev/null | grep -iE 'speechace|azure|speechsuper'`. Must return empty. Repeat for Release configuration.

Both gates fail the PR if anything is found.

## 11. Testing Strategy

### 11.1 Unit — feature math

Fixtures are synthetic PCM generated by test helpers: sine mixtures with known spectral centroid, white-noise band-pass filtered to target band, short bursts with known onset slope. The tests verify each feature extractor's output against the analytical ground truth to within 5% tolerance.

Example (pseudocode):

```swift
@Test
func spectralCentroidOfSineMix() {
    let clip = SyntheticAudio.sineMix(frequencies: [3000, 4000], rates: [0.5, 0.5], durationMs: 200)
    let centroid = FeatureExtractor.spectralCentroid(clip: clip)
    #expect(abs(centroid - 3500) < 100)   // within 5% of 3.5 kHz
}
```

### 11.2 Unit — recorded fixtures

A small set of recorded fixtures (Yutaka producing /ʃ/ both correctly and substituted with /s/, /r/ vs /l/, etc.) is checked into `Packages/MoraEngines/Tests/MoraEnginesTests/Fixtures/` as short WAV files. Engine A evaluation runs against each fixture and asserts expected label + score range:

| Fixture | Expected label | Expected score range |
|---|---|---|
| `ship-correct.wav` | `.matched` for /ʃ/ | ≥ 80 |
| `ship-as-sip.wav` | `.substitutedBy(/s/)` for /ʃ/ | ≤ 30 |
| `ship-drift-rounded-loose.wav` | `.driftedWithin` for /ʃ/ | 40–70 |
| `right-correct.wav` | `.matched` for /r/ | ≥ 80 |
| `right-as-light.wav` | `.substitutedBy(/l/)` for /r/ | ≤ 30 |

Fixtures are kept under 100 KB each (short, mono, 16 kHz).

### 11.3 Unit — L1Profile regression

`Packages/MoraCore/Tests/.../JapaneseL1ProfileTests.swift`:

- Existing `matchInterference` tests continue to pass unchanged.
- New tests cover: `matchInterference(expected: /ʃ/, heard: /s/)` returns the `sh_s_sub` pair; `matchInterference(expected: /ʃ/, heard: /ʃ/)` returns `nil` (drift sentinel does not match as substitution).

### 11.4 Integration — SessionOrchestrator

`Packages/MoraEngines/Tests/MoraEnginesTests/SessionOrchestratorPronunciationTests.swift`:

- Orchestrator configured with `FakePronunciationEvaluator` returning a scripted `PhonemeTrialAssessment`.
- Feeds a `TrialRecording` through `.answerHeard`, asserts the resulting `TrialAssessment.phoneme` equals the fake's response.
- Additional test: evaluator returns `.unclear`; assessment still records the trial but marks the phoneme field unclear; orchestrator advances or retries per existing rules.

### 11.5 Contract — `PronunciationEvaluator`

A protocol-level test suite that any conforming evaluator must pass. In v1.5 first release, runs only on Engine A; when Engine B lands, runs on both.

- `supports` for each `JapaneseL1Profile.interferencePairs` target matches the documented support table.
- `evaluate` is idempotent for identical input.
- `evaluate` returns `.unclear` with `isReliable = false` for a silent audio clip.

### 11.6 CI gate

In `.github/workflows/`, two new steps in the existing CI job:

```yaml
- name: Source gate — no cloud pronunciation SDK
  run: |
    if git grep -nIE 'speechace|azure\.cognitive|pronunciation-assessment|speechsuper' -- Mora Packages; then
      echo "Cloud pronunciation reference detected in shipped source tree"
      exit 1
    fi

- name: Binary gate — no cloud symbols in built binary
  run: |
    xcodebuild build -project Mora.xcodeproj -scheme Mora \
      -destination 'generic/platform=iOS Simulator' \
      -configuration Debug CODE_SIGNING_ALLOWED=NO
    if nm build/Debug-iphonesimulator/Mora.app/Mora 2>/dev/null | grep -iE 'speechace|azure|speechsuper'; then
      echo "Cloud pronunciation symbol detected in Mora binary"
      exit 1
    fi
```

### 11.7 Dev benchmark (not in CI)

`dev-tools/pronunciation-bench/` contains its own test target that runs on Yutaka's laptop only. Results (CSV) are not checked in.

## 12. Phasing

The work is structured in three phases to keep PRs reviewable.

### Phase 1 — Infrastructure

- `PronunciationEvaluator` protocol, `AudioClip`, `PhonemeAssessmentLabel`, `PhonemeTrialAssessment` types.
- `FakePronunciationEvaluator` in MoraTesting.
- `AppleSpeechEngine` PCM ring buffer + `TrialRecording` emission.
- `SpeechEvent.final` and `OrchestratorEvent.answerHeard` reshape.
- `AssessmentEngine` new `async assess(expected:recording:leniency:)` overload.
- `TrialAssessment.phoneme` field addition.
- `JapaneseL1Profile.interferencePairs` adds `sh_s_sub` and `sh_drift_target`.
- Tests: protocol contract, orchestrator integration with fake evaluator, L1Profile regression.

At the end of Phase 1, no actual acoustic evaluation happens yet — the evaluator is always a fake, the UI still uses the transcript path — but the entire pipeline compiles and the existing tests still pass.

### Phase 2 — Engine A

- `FeatureBasedPronunciationEvaluator` with all eight pairs.
- Feature extractors (vDSP).
- Scoring + reliability gating.
- Synthetic-PCM unit tests.
- Recorded-fixture unit tests (small WAV set).
- `PronunciationFeedbackOverlay` in MoraUI: category bar, score bar, coaching bubble + TTS.
- `MoraStrings` keys added.
- CI source + binary gates.

Phase 2 end = Engine A is the v1.5 primary evaluator, wired end to end.

### Phase 3 — Engine B shadow mode

- wav2vec2-phoneme CoreML conversion (in `dev-tools/model-conversion/`, not shipped as code).
- Model bundled in MoraMLX.
- `PhonemeModelPronunciationEvaluator` implementation.
- `PronunciationTrialLog` SwiftData entity, capped retention, parallel logging.
- Orchestrator fires Engine A (UI) + Engine B (shadow log) in parallel.
- Protocol contract tests run against Engine B.
- Latency benchmark confirms <1000 ms on iPad Air M2 for 2-second utterance.

Phase 3 end = Engine B present, logging in shadow, no UI change.

### Phase 4 (future, out of scope of this spec)

- `dev-tools/pronunciation-bench/` correlation study.
- Promotion gate evaluation.
- Per-speaker threshold adaptation.
- Parent-mode export of shadow logs.

## 13. Data Model Addition

### 13.1 SwiftData entity `PronunciationTrialLog` (Phase 3)

```swift
import Foundation
import SwiftData

@Model
public final class PronunciationTrialLog {
    public var timestamp: Date
    public var wordSurface: String
    public var targetPhonemeIPA: String
    public var engineALabel: String           // JSON of PhonemeAssessmentLabel
    public var engineAScore: Int?
    public var engineBLabel: String?
    public var engineBScore: Int?
    public var engineBLatencyMs: Int?
    public var featuresJSON: String           // Engine A's features dict
    public init(...) { ... }
}
```

Retention: FIFO, capped at 1000 rows. A cleanup task runs at app launch when the count exceeds the cap.

### 13.2 `Word.targetPhoneme`

Added to `MoraCore.Word`. Non-breaking: default is the first element of `phonemes` (onset) when curriculum hasn't set one explicitly. `CurriculumEngine` is updated to set the field on every word it emits.

## 14. Open Questions

1. Medial-position phoneme evaluation is gated behind `isReliable = false` in Engine A. When Engine B lands with forced alignment, medial positions become fully supported. Is the UX confusing for the learner when the same phoneme sometimes shows a score (onset/coda) and sometimes does not (medial)? Revisit with Yutaka after first-week use.
2. Per-speaker threshold adaptation (±15% shift based on a calibration set collected from the son's first N sessions). Trigger: Settings UI? Background automatic after N sessions with variance under a bound? Deferred to a post-v1.5 PR.
3. The `PhonemeConfusionPair.from == to` sentinel for drift targets is a pragmatic fit but is not self-documenting. When Engine B design begins, evaluate introducing a distinct `PhonemeAcousticTarget` type and migrating drift entries into it. If migrated, deprecate the sentinel pattern and update Engine A accordingly.
4. Shadow-mode log retention UX — parent-mode-only view or also a debug-mode in-app screen? Decide when Parent Mode spec starts.
5. Engine B's CoreML model size (~150 MB) is significant against the app download size. If App Store review raises concerns, consider on-demand resource download (first-launch-only, over Wi-Fi) for the model file. Out of scope for this spec.
6. Child-speech acoustics: all literature values are for adult speakers. Children's formants and spectral peaks sit higher (shorter vocal tract). A secondary validation pass against Yutaka's son's own recordings may require a uniform upward shift of ~10% on F-features. Observe and adjust during Phase 2 testing.
7. `AudioClip` uses Float32 samples; memory cost is roughly 8 bytes/ms at 16 kHz stereo or 4 bytes/ms mono. A 2-second clip is ~8 KB mono, which is negligible, but the SwiftData log should store feature JSON + score only, not the audio itself. Confirmed in §13.1 schema.

---

## Appendix A — Why not cloud at runtime

The product's dyslexia + ESL positioning rests on parents trusting that their child's voice never leaves the device. This is reinforced by `2026-04-21-mora-dyslexia-esl-design.md` §3 ("No raw audio, transcripts, or per-trial details leave the device") and is a recurring line in the design docs. Cloud pronunciation APIs (SpeechAce, Azure Pronunciation Assessment, GPT-4o audio, Gemini audio) would produce excellent results but are outside the invariant. The SpeechAce carve-out in `dev-tools/` is a developer-tooling concession, not a product decision.

## Appendix B — Why not a tiny per-pair CoreML classifier

A middle option — training a tiny CNN per L1 pair on mel-spectrograms — was considered and rejected. Rationale:

- Training data is not in hand. Collecting a usefully-sized, labeled child ESL corpus is a project in itself.
- The acoustic literature for the covered pairs is strong enough that a rule-based classifier using a single well-chosen feature meets the accuracy bar on adult speakers. Child-speaker shifts are addressed with per-feature offsets, not with a re-trained model.
- Adding a CoreML model per pair (five to eight models) carries the same download and launch-time overhead as one larger general-purpose model (Engine B), without the generalization benefit.

Engine A and Engine B together cover both ends of the trade-off space. A middle-ground implementation is unnecessary.
