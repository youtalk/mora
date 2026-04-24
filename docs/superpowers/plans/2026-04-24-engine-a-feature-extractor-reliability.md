# Engine A Feature Extractor Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Engine A's substitution detection actually work on natural recorder-app takes by fixing three feature-extractor reliability issues that surfaced when running `~/mora-fixtures-adult/` through `dev-tools/pronunciation-bench/`.

**Architecture:** Three independent fixes, each in `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/`. Tasks land in dependency-free order so each can ship as its own PR. No public API changes — only the internal heuristics that `FeatureBasedPronunciationEvaluator.measure(...)` and `PhonemeRegionLocalizer.region(...)` rely on.

**Tech Stack:** Swift 6 (`.v5` language mode), `Accelerate.vDSP` for FFT/autocorrelation, XCTest. Existing `SyntheticAudio` test helpers in `Packages/MoraEngines/Tests/MoraEnginesTests/Support/SyntheticAudio.swift` cover sine/band-noise/silence; this plan extends them with voiced-stop and voiced-fricative synth.

---

## Discovery

Re-bench of all 12 adult-proxy fixtures against `main` HEAD `d88bf51` (post-PR #58 Engine A whole-word + medial-vowel fixes) showed:

| | Match | Mismatch root cause |
|---|---|---|
| r/l | 3/4 | `light-correct` measured F3=1531 Hz, in /r/ territory (literature /l/=3000). Coarticulation: the 150 ms onset slice catches the start of the following diphthong /aɪ/, whose F3 is naturally low. |
| v/b | 1/4 | `very-correct` measured VOT=150 ms, biologically implausible for /v/ (literature /v/=−30 ms). Three other v/b takes returned matched by default because `judgeSubstitution` never put their measured value on the substitute side; for `berry-correct` that's the right call, but `berry-as-very` and `very-as-berry` both should have been flagged substituted and weren't. The current VOT extractor is just "first RMS rise above 0.05" from clip start — it can't distinguish voiced fricative onset (negative VOT) from voiced stop burst (small positive VOT). |
| æ/ʌ | 1/4 | `cat-correct` measured F1=594 Hz against a literature 640 Hz boundary — calibration issue, addressed in a separate one-line PR (æ/ʌ boundary 640→590). The other three medial-vowel mismatches are recording-quality issues (the speaker did not produce the substitute clearly enough to push F1 across the boundary) **plus** the same short-window FFT resolution problem that hides true F1 under pitch harmonics. |

The threshold-tuning lever cannot fix any of v/b or r/l: the measured values are not just slightly off-boundary — they are in the wrong feature-space region entirely. Two extractor fixes (better VOT estimation, liquid-onset-aware localization) plus one short-window F1 robustness fix are required before bench-followups Task A1 can land all 12 fixtures.

This plan does not block on the æ/ʌ boundary calibration (handled by `2026-04-24-engine-a-feature-extractor-reliability.md` is a sibling, not a prerequisite); the three tasks here are independent of that one-line change.

## Scope

### Goals

- Replace the absolute "first-rise" VOT extractor with a relative voicing-vs-burst measurement that produces negative values for voiced consonants (/v/, /b/) and positive for voiceless onsets.
- Add a liquid-onset-aware path to `PhonemeRegionLocalizer` so /r/ and /l/ take a tighter window (40–80 ms) before the following vowel transition begins, instead of the current fixed 150 ms slice.
- Add an F1 robustness pass to `FeatureExtractor.spectralPeakInBand` that suppresses pitch-harmonic peaks when the measurement window is < 200 ms, so vowel formants in short medial slices don't get masked by the speaker's fundamental.

### Non-goals

- Replacing Engine A wholesale with Engine B (`PhonemeModelPronunciationEvaluator`). Engine B is the long-term substitution-detection path; Engine A stays as the v1 baseline + reliability fallback. This plan keeps Engine A's heuristic shape, just makes it more honest about what it's measuring.
- Full LPC formant tracker. The pitch-harmonic suppression here is a quick fix; a real LPC pipeline is its own project (out of scope for v1).
- Per-speaker / L1-aware threshold profiles. The `L1Profile` protocol exists in `MoraCore` but Engine A's `PhonemeThresholds` is L1-agnostic. Threading L1 awareness through is a separate spec.
- Re-running the full bench in CI. The bench stays a developer-laptop tool; this plan's tests are unit tests against synthesized audio.
- New phoneme pairs (θ/t, etc.). Already tracked in `2026-04-23-pronunciation-bench-followups.md` Task B3.

### Invariants

- `FeatureExtractor` stays a `public enum` with stateless static methods. No new dependencies.
- `PhonemeRegionLocalizer.region(...)` keeps its signature `(clip:, word:, phonemePosition:) -> LocalizedRegion`. The new liquid-onset behavior keys off `phonemePosition` + `word.targetPhoneme.ipa` only; no protocol additions.
- All Engine A changes stay backwards-compatible with `ShadowLoggingPronunciationEvaluator`'s wrapping (`PronunciationEvaluator` protocol unchanged).
- Swift 6 `.v5` language mode pin holds.
- No CI gate changes.

## File Structure

| File | Change | Why |
|---|---|---|
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureExtractor.swift` | Rewrite `voicingOnsetTime`; add `voicingOnsetTimeRelative(clip:burstThreshold:voicingThreshold:)`; add private `dominantPitchHz(clip:)`; modify `spectralPeakInBand` to accept an optional `suppressPitchHarmonics: Bool = false` flag. | Three of the four reliability fixes live in feature extraction. Stateless module, no migration concerns. |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift` | Switch the `.voicingOnsetTimeMs` measure call to the new relative-VOT API; pass `suppressPitchHarmonics: true` to `spectralPeakInBand` when measuring vowel formants on regions shorter than 200 ms. | Wires the new extractor entry points into the production path. |
| `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeRegionLocalizer.swift` | Add an `LiquidOnsetWindow` enum + branch inside `.onset` so /r/ and /l/ targets get a 40–80 ms slice instead of 150 ms. Other onsets unchanged. | Liquid coarticulation fix — no new public type. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/Support/SyntheticAudio.swift` | Add `voicedFricative(durationMs:burstStartMs:)` and `voicedStop(durationMs:burstStartMs:vowelStartMs:)` synthesizers that produce predictable VOT signatures. | New tests need predictable voiced-consonant audio; sine/noise alone can't represent a burst. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureExtractorTests.swift` | New tests: relative VOT for voiced fricative (negative), voiced stop (small positive), voiceless stop (large positive); pitch-harmonic suppression on a 100 ms window. | TDD coverage for the new extractor entry points. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeRegionLocalizerTests.swift` | New test: `.onset` on a `Word` with `targetPhoneme = /l/` returns a 40–80 ms slice; `.onset` on `/ʃ/` still returns 150 ms (regression guard). | TDD coverage for the liquid-onset branch. |
| `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift` | One end-to-end test per fix: synthesized voiced-fricative passes the v/b substitution check correctly; synthesized /l/ + /aɪ/ avoids being mislabeled /r/. | Locks the integration in so a regression in either layer surfaces here, not just at the bench. |

## Tasks

### Task 1: Liquid onset window (lowest-risk, smallest change)

Liquids /r/ /l/ get a 60 ms onset slice instead of 150 ms. The 60 ms target comes from the formant-stable region of /l/ in CV onsets; per the literature it's typically 60–80 ms for adult speakers in unstressed contexts.

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeRegionLocalizer.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeRegionLocalizerTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `PhonemeRegionLocalizerTests.swift`:

```swift
func testLiquidOnsetUsesShorterWindow() {
    // 1 s clip at 16 kHz = 16_000 samples. /l/ onset → 60 ms = 960 samples.
    let lightWord = Word(
        surface: "light",
        graphemes: [Grapheme(letters: "l"), Grapheme(letters: "i"), Grapheme(letters: "ght")],
        phonemes: [Phoneme(ipa: "l"), Phoneme(ipa: "aɪ"), Phoneme(ipa: "t")],
        targetPhoneme: Phoneme(ipa: "l")
    )
    let clip = AudioClip(samples: Array(repeating: Float(0), count: 16_000), sampleRate: 16_000)
    let region = PhonemeRegionLocalizer.region(
        clip: clip, word: lightWord, phonemePosition: .onset
    )
    XCTAssertEqual(region.clip.samples.count, 960)
    XCTAssertEqual(region.durationMs, 60, accuracy: 0.01)
    XCTAssertTrue(region.isReliable)
}

func testNonLiquidOnsetKeepsExistingWindow() {
    // Regression guard: /ʃ/ onset stays at the existing 150 ms / 25%-of-clip rule.
    let clip = AudioClip(samples: Array(repeating: Float(0), count: 16_000), sampleRate: 16_000)
    let region = PhonemeRegionLocalizer.region(
        clip: clip, word: word, phonemePosition: .onset
    )
    XCTAssertEqual(region.clip.samples.count, 2_400)  // 150 ms of 1 s = 2_400 samples
    XCTAssertEqual(region.durationMs, 150, accuracy: 0.01)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
(cd Packages/MoraEngines && swift test --filter PhonemeRegionLocalizerTests.testLiquidOnsetUsesShorterWindow)
(cd Packages/MoraEngines && swift test --filter PhonemeRegionLocalizerTests.testNonLiquidOnsetKeepsExistingWindow)
```

Expected: `testLiquid…` fails with `XCTAssertEqual failed: ("2400") is not equal to ("960")`. `testNonLiquid…` passes (it's a regression guard for the existing behavior).

- [ ] **Step 3: Implement the liquid-onset branch**

Edit `PhonemeRegionLocalizer.swift`. Add this private helper before `region(clip:word:phonemePosition:)`:

```swift
private static let liquidIPAs: Set<String> = ["r", "l"]

private static func onsetWindowMs(for word: Word, defaultMs: Double, fractionMs: Double) -> Double {
    let target = word.targetPhoneme.ipa
    if liquidIPAs.contains(target) {
        // Liquids' acoustically-stable region is ~60 ms before the following
        // vowel's formants begin. The 150 ms default catches that vowel.
        return min(60, fractionMs)
    }
    return min(defaultMs, fractionMs)
}
```

In the `region(...)` method, replace the existing `let sliceMs = min(fixedMs, fractionMs)` line and the `case .onset:` body with:

```swift
        let totalMs = clip.durationSeconds * 1000.0
        let fixedMs = 150.0
        let fractionMs = totalMs * 0.25

        switch phonemePosition {
        case .onset:
            let onsetMs = onsetWindowMs(for: word, defaultMs: fixedMs, fractionMs: fractionMs)
            return slice(clip: clip, startMs: 0, durationMs: onsetMs, reliable: true)
        case .coda:
            let sliceMs = min(fixedMs, fractionMs)
            return slice(clip: clip, startMs: totalMs - sliceMs, durationMs: sliceMs, reliable: true)
        case .medial(let position, let count):
```

(The `.medial(...)` branch is unchanged — keep the existing body.)

The `_:` parameter on `region(clip:word _:phonemePosition:)` becomes `word:` (no underscore) because we now read it. Update the signature accordingly.

- [ ] **Step 4: Run the new tests + the existing suite**

```sh
(cd Packages/MoraEngines && swift test --filter PhonemeRegionLocalizerTests)
```

Expected: all 5 tests in `PhonemeRegionLocalizerTests` pass. `testOnsetSlicesFirstHalfOfShortWord` still passes because `ship`'s `targetPhoneme.ipa` is `ʃ`, which is not in `liquidIPAs`.

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -3)
```

Expected: 214 total tests pass (212 previous + 2 new), 12 skipped, 0 failures.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemeRegionLocalizer.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/PhonemeRegionLocalizerTests.swift
git commit -m "$(cat <<'EOF'
engines: shorten onset window for liquids /r/ /l/ to 60 ms

The default 150 ms onset slice catches the start of the following vowel
in CV liquid onsets like "light" (l-aɪ-t), so the diphthong's F3 (low for
/aɪ/) dominates the F3 measurement and engine mislabels /l/ as /r/.
Liquids' acoustically-stable region is ~60 ms before the formant
transition; this matches the literature window for adult speakers in
unstressed contexts.

Regression guard: non-liquid onsets (/ʃ/, /v/, /f/, /θ/) still take the
existing 150 ms / 25 %-of-clip default.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Synthetic voiced-consonant audio for tests

Adds two synthesizers to the existing `SyntheticAudio` helper so Task 3 has predictable VOT signatures. This task lands first because both Task 3's unit tests and Task 4's integration test depend on it.

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/Support/SyntheticAudio.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/Support/SyntheticAudioTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `SyntheticAudioTests.swift`:

```swift
func testVoicedFricativeHasContinuousVoicingThenVowel() {
    // 200 ms total: 80 ms low-band voiced fricative + 120 ms vowel.
    // Both regions should have RMS above the noise floor; no silence gap.
    let clip = SyntheticAudio.voicedFricative(durationMs: 200, burstStartMs: 80)
    XCTAssertEqual(clip.samples.count, 3_200)  // 200 ms at 16 kHz

    // Both halves should be above noise floor (no internal silence).
    let firstHalf = clip.samples.prefix(1_600)
    let secondHalf = clip.samples.suffix(1_600)
    let rms1 = sqrt(firstHalf.reduce(0) { $0 + $1 * $1 } / Float(firstHalf.count))
    let rms2 = sqrt(secondHalf.reduce(0) { $0 + $1 * $1 } / Float(secondHalf.count))
    XCTAssertGreaterThan(rms1, 0.01)
    XCTAssertGreaterThan(rms2, 0.01)
}

func testVoicedStopHasSilencePauseBeforeBurst() {
    // 200 ms total: 60 ms voicing + 30 ms silence + burst at 90 ms + vowel.
    // RMS at 70 ms (mid-silence) should be near zero.
    let clip = SyntheticAudio.voicedStop(durationMs: 200, burstStartMs: 90, vowelStartMs: 95)
    XCTAssertEqual(clip.samples.count, 3_200)

    // Window the silence region: samples 1_120..1_440 = 70..90 ms.
    let silenceWindow = clip.samples[1_120..<1_440]
    let rmsSilence = sqrt(silenceWindow.reduce(0) { $0 + $1 * $1 } / Float(silenceWindow.count))
    XCTAssertLessThan(rmsSilence, 0.005)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
(cd Packages/MoraEngines && swift test --filter SyntheticAudioTests.testVoicedFricativeHasContinuousVoicingThenVowel)
```

Expected: compile error, `voicedFricative` not defined.

- [ ] **Step 3: Implement the synthesizers**

Add to `SyntheticAudio.swift` (after `silence(durationMs:)`):

```swift
    /// Voiced fricative: low-amplitude band-limited noise (200–800 Hz)
    /// continuous from t=0 to `burstStartMs`, then a sustained voiced
    /// vowel (sine at 220 Hz) from `burstStartMs` onward. Both regions
    /// share an envelope with RMS ≈ 0.05 so the seam is acoustically
    /// continuous — the signature expected from /v/, /z/, /ð/.
    static func voicedFricative(durationMs: Int, burstStartMs: Int) -> AudioClip {
        let sr = sampleRate
        let totalSamples = Int(Double(durationMs) / 1000.0 * sr)
        let burstSamples = Int(Double(burstStartMs) / 1000.0 * sr)

        var samples = [Float](repeating: 0, count: totalSamples)
        // Fricative half: low-band noise, gain 0.05.
        var rng = SeededGenerator(seed: 0xFEED5)
        for i in 0..<burstSamples {
            samples[i] = Float.random(in: -1...1, using: &rng) * 0.05
        }
        // Vowel half: sustained 220 Hz sine, gain 0.05.
        for i in burstSamples..<totalSamples {
            let t = Double(i) / sr
            samples[i] = Float(0.05 * sin(2 * .pi * 220 * t))
        }
        return AudioClip(samples: samples, sampleRate: sr)
    }

    /// Voiced stop: low-amplitude voicing from t=0 to `burstStartMs`,
    /// then 5 ms silence (closure), then a sharp burst (single-sample
    /// impulse), then a sustained vowel (sine at 220 Hz) from
    /// `vowelStartMs`. The signature expected from /b/, /d/, /g/:
    /// pre-burst voicing → pause → burst → voicing resumes.
    static func voicedStop(
        durationMs: Int,
        burstStartMs: Int,
        vowelStartMs: Int
    ) -> AudioClip {
        let sr = sampleRate
        let totalSamples = Int(Double(durationMs) / 1000.0 * sr)
        let preVoicingSamples = max(0, Int(Double(burstStartMs) / 1000.0 * sr) - 80)
        let burstSample = Int(Double(burstStartMs) / 1000.0 * sr)
        let vowelStartSample = Int(Double(vowelStartMs) / 1000.0 * sr)

        var samples = [Float](repeating: 0, count: totalSamples)
        // Pre-burst voicing: 220 Hz sine, gain 0.04.
        for i in 0..<preVoicingSamples {
            let t = Double(i) / sr
            samples[i] = Float(0.04 * sin(2 * .pi * 220 * t))
        }
        // Closure (silence): preVoicingSamples..<burstSample stays at 0.
        // Burst: single-sample impulse at burstSample.
        if burstSample < totalSamples {
            samples[burstSample] = 0.5
        }
        // Vowel: 220 Hz sine, gain 0.05.
        for i in vowelStartSample..<totalSamples {
            let t = Double(i) / sr
            samples[i] = Float(0.05 * sin(2 * .pi * 220 * t))
        }
        return AudioClip(samples: samples, sampleRate: sr)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

```sh
(cd Packages/MoraEngines && swift test --filter SyntheticAudioTests)
```

Expected: all `SyntheticAudioTests` (existing + 2 new) pass.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/Support/SyntheticAudio.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/Support/SyntheticAudioTests.swift
git commit -m "$(cat <<'EOF'
test: add voiced-fricative and voiced-stop synthesizers

The relative-VOT extractor (Task 3 of 2026-04-24-engine-a-feature-extractor-reliability.md)
needs predictable voiced-consonant audio with known burst / voicing
seams. Sine + band-noise alone can't represent the closure-then-burst
signature of /b/, /d/, /g/ or the continuous-voicing profile of /v/, /z/.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Relative VOT extractor

Replaces the current "first-rise from clip start" VOT with a relative measurement: time(voicing) − time(burst). Negative for voiced fricatives (/v/), small positive for voiced stops (/b/), large positive for voiceless stops (/p/, /t/, /k/).

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureExtractor.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureExtractorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `FeatureExtractorTests.swift`:

```swift
func testRelativeVOTNegativeForVoicedFricative() {
    // Voiced fricative: voicing throughout, no burst → VOT should be
    // strongly negative (voicing precedes any "burst-like" event by a lot,
    // or the extractor reports the burst as never-found and falls back to
    // a sentinel negative value that lands well below the v/b boundary).
    let clip = SyntheticAudio.voicedFricative(durationMs: 200, burstStartMs: 80)
    let vot = FeatureExtractor.voicingOnsetTimeRelative(
        clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
    )
    XCTAssertLessThan(vot, -10, "/v/-like signal should produce VOT well below the v/b boundary (-5)")
}

func testRelativeVOTSmallPositiveForVoicedStop() {
    // Voiced stop: pre-burst voicing → silence → burst at 90 ms → vowel
    // at 95 ms. Burst at 90 ms; voicing resumes at 95 ms → VOT ≈ +5 ms.
    let clip = SyntheticAudio.voicedStop(durationMs: 200, burstStartMs: 90, vowelStartMs: 95)
    let vot = FeatureExtractor.voicingOnsetTimeRelative(
        clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
    )
    XCTAssertGreaterThan(vot, 0)
    XCTAssertLessThan(vot, 30, "/b/-like signal should produce small positive VOT")
}

func testRelativeVOTBoundsForVoicelessStop() {
    // Voiceless stop: silence → burst at 50 ms → vowel at 100 ms (50 ms
    // aspiration gap). VOT should be ~50 ms — comfortably positive.
    let clip = SyntheticAudio.voicedStop(
        durationMs: 200, burstStartMs: 50, vowelStartMs: 100
    )
    let vot = FeatureExtractor.voicingOnsetTimeRelative(
        clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
    )
    XCTAssertGreaterThan(vot, 30)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureExtractorTests.testRelativeVOTNegativeForVoicedFricative)
```

Expected: compile error, `voicingOnsetTimeRelative` not defined.

- [ ] **Step 3: Implement the relative VOT extractor**

Add to `FeatureExtractor.swift` (after the existing `voicingOnsetTime`):

```swift
    /// Relative voicing onset time (ms): the difference between the time
    /// of the strongest amplitude-derivative spike (the "burst") and the
    /// time periodic voicing first becomes detectable. Negative values
    /// mean voicing precedes the burst (voiced fricatives, voiced stops
    /// with prevoicing); positive values mean voicing follows the burst
    /// (voiceless stops, large for aspirated /p/, /t/, /k/).
    ///
    /// `burstThreshold` is the per-window dRMS that counts as a burst.
    /// `voicingThreshold` is the RMS level that counts as voicing.
    /// Returns -100 if no burst is detected (the signal is steady) so the
    /// caller's substitution boundary still classifies it as voiced.
    public static func voicingOnsetTimeRelative(
        clip: AudioClip,
        burstThreshold: Float,
        voicingThreshold: Float
    ) -> Double {
        let windowMs = 5
        let windowSamples = max(8, Int(Double(windowMs) / 1000.0 * clip.sampleRate))
        guard clip.samples.count >= windowSamples * 2 else { return -100 }

        // Per-window RMS, then per-step delta.
        var rms = [Float]()
        var i = 0
        while i + windowSamples <= clip.samples.count {
            let window = clip.samples[i..<(i + windowSamples)]
            let r = sqrt(window.reduce(0) { $0 + $1 * $1 } / Float(window.count))
            rms.append(r)
            i += windowSamples
        }
        guard rms.count >= 2 else { return -100 }

        // Burst = window with the largest positive delta.
        var burstWindow = -1
        var burstDelta: Float = burstThreshold
        for k in 1..<rms.count {
            let delta = rms[k] - rms[k - 1]
            if delta > burstDelta {
                burstDelta = delta
                burstWindow = k
            }
        }
        // Voicing onset = first window with RMS >= voicingThreshold.
        var voicingWindow = -1
        for (k, r) in rms.enumerated() where r >= voicingThreshold {
            voicingWindow = k
            break
        }
        guard voicingWindow >= 0 else { return -100 }
        if burstWindow < 0 {
            // No burst → signal is steady; treat as fully voiced.
            return -100
        }
        let burstMs = Double(burstWindow) * Double(windowMs)
        let voicingMs = Double(voicingWindow) * Double(windowMs)
        return voicingMs - burstMs
    }
```

In `FeatureBasedPronunciationEvaluator.swift`, find the `.voicingOnsetTimeMs` case in `measure(feature:in:)` (line 190) and replace its body:

```swift
        case .voicingOnsetTimeMs:
            return FeatureExtractor.voicingOnsetTimeRelative(
                clip: clip, burstThreshold: 0.2, voicingThreshold: 0.02
            )
```

(Remove the leftover `let vot = FeatureExtractor.voicingOnsetTime(...)` line and any wrapper math around it; the new function returns the value directly.)

- [ ] **Step 4: Run the new tests + full suite**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureExtractorTests)
```

Expected: all `FeatureExtractorTests` (existing + 3 new) pass.

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -3)
```

Expected: zero failures, 12 skipped (the existing fixture skips). The existing `FeatureBasedEvaluatorTests.testVSubstitutedByB…`-style cases (if any) may need their input audio adjusted; if a test now fails because the synthetic input doesn't trigger the new VOT logic the way the old extractor's "first rise" did, fix the synthetic input rather than weaken the new extractor.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureExtractor.swift \
        Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/FeatureExtractorTests.swift
git commit -m "$(cat <<'EOF'
engines: relative VOT (voicing - burst), not first-rise from clip start

The previous voicingOnsetTime extractor returned absolute time from
clip start to the first RMS rise above 0.05 — it could not distinguish a
voiced fricative (continuous voicing throughout) from a voiced stop
(pre-burst voicing → closure → burst → vowel) because both have an early
"first rise" event. On the bench, /v/ recordings produced VOT ≈ 150 ms,
biologically implausible for a voiced consonant.

The new voicingOnsetTimeRelative extractor finds the burst (largest
positive dRMS spike) and the voicing onset (first window above
voicingThreshold) separately, then returns the signed difference. Voiced
fricatives → strongly negative (or -100 sentinel for "no burst found"),
voiced stops → small positive, voiceless stops → larger positive.

The v/b substitution boundary (-5 ms in PhonemeThresholds) classifies
correctly under the new measurement.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Pitch-harmonic suppression for short-window F1

Adds an opt-in `suppressPitchHarmonics` mode to `spectralPeakInBand` that estimates the speaker's fundamental from the clip and excludes peaks within ±20 Hz of an integer multiple. Used only when the measurement window is short (< 200 ms), where pitch harmonics regularly outweigh true formants in the lowest band.

**Files:**
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureExtractor.swift`
- Modify: `Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift`
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureExtractorTests.swift`

- [ ] **Step 1: Write the failing test**

Append to `FeatureExtractorTests.swift`:

```swift
func testF1SuppressesPitchHarmonic() {
    // 100 ms clip with a strong 220 Hz pitch (3rd harmonic at 660 Hz),
    // a true F1 at 800 Hz with lower amplitude. Without suppression the
    // 660 Hz harmonic wins; with suppression the 800 Hz peak should be
    // selected.
    let clip = SyntheticAudio.sineMix(
        frequencies: [220, 660, 800],
        gains: [1.0, 1.0, 0.6],
        durationMs: 100
    )

    let withoutSuppress = FeatureExtractor.spectralPeakInBand(
        clip: clip, lowHz: 200, highHz: 1_000
    )
    XCTAssertEqual(withoutSuppress, 660, accuracy: 80, "harmonic dominates without suppression")

    let withSuppress = FeatureExtractor.spectralPeakInBand(
        clip: clip, lowHz: 200, highHz: 1_000, suppressPitchHarmonics: true
    )
    XCTAssertEqual(withSuppress, 800, accuracy: 80, "true F1 selected with suppression")
}
```

- [ ] **Step 2: Run test to verify it fails**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureExtractorTests.testF1SuppressesPitchHarmonic)
```

Expected: compile error, `spectralPeakInBand` doesn't accept `suppressPitchHarmonics`.

- [ ] **Step 3: Implement pitch-harmonic suppression**

In `FeatureExtractor.swift`, replace the existing `spectralPeakInBand(clip:lowHz:highHz:)` with:

```swift
    /// Frequency (Hz) of the strongest FFT bin whose center lies within
    /// [lowHz, highHz]. When `suppressPitchHarmonics` is true, the
    /// extractor first estimates the speaker's pitch (50–400 Hz peak in
    /// the autocorrelation) and excludes any band-peak within ±20 Hz of
    /// an integer multiple of that pitch. Use suppression on short
    /// windows (< 200 ms) where pitch harmonics regularly mask the true
    /// F1 / F2.
    public static func spectralPeakInBand(
        clip: AudioClip,
        lowHz: Double,
        highHz: Double,
        suppressPitchHarmonics: Bool = false
    ) -> Double {
        guard let spectrum = powerSpectrum(clip: clip) else { return 0 }
        let binWidth = clip.sampleRate / Double(2 * spectrum.count)

        let pitchHz: Double? = suppressPitchHarmonics ? dominantPitchHz(clip: clip) : nil
        let suppressionTolerance = 20.0

        var bestBin = -1
        var bestPower: Float = 0
        for (i, p) in spectrum.enumerated() {
            let freq = Double(i) * binWidth
            if freq < lowHz || freq > highHz { continue }
            if let f0 = pitchHz, f0 > 0 {
                // Reject bins within tolerance of any harmonic of f0.
                let nearestHarmonic = (freq / f0).rounded() * f0
                if abs(freq - nearestHarmonic) < suppressionTolerance {
                    continue
                }
            }
            if p > bestPower {
                bestPower = p
                bestBin = i
            }
        }
        return bestBin >= 0 ? Double(bestBin) * binWidth : 0
    }

    /// Estimate the dominant pitch (50–400 Hz) by autocorrelation.
    /// Returns 0 when no clear period is found. Used internally by
    /// `spectralPeakInBand` for harmonic suppression on short windows.
    static func dominantPitchHz(clip: AudioClip) -> Double {
        let sr = clip.sampleRate
        let minLag = Int(sr / 400.0)  // 400 Hz max
        let maxLag = Int(sr / 50.0)   // 50 Hz min
        let samples = clip.samples
        guard samples.count > maxLag * 2 else { return 0 }

        var bestLag = -1
        var bestCorr: Double = 0
        for lag in minLag...maxLag {
            var corr: Double = 0
            let n = samples.count - lag
            for i in 0..<n {
                corr += Double(samples[i]) * Double(samples[i + lag])
            }
            corr /= Double(n)
            if corr > bestCorr {
                bestCorr = corr
                bestLag = lag
            }
        }
        return bestLag > 0 ? sr / Double(bestLag) : 0
    }
```

In `FeatureBasedPronunciationEvaluator.swift`, modify the `.formantF1Hz` and `.formantF2Hz` measure cases:

```swift
        case .formantF1Hz:
            let suppress = clip.durationSeconds < 0.2
            return FeatureExtractor.spectralPeakInBand(
                clip: clip, lowHz: 200, highHz: 1_000,
                suppressPitchHarmonics: suppress
            )
        case .formantF2Hz:
            let suppress = clip.durationSeconds < 0.2
            return FeatureExtractor.spectralPeakInBand(
                clip: clip, lowHz: 1_000, highHz: 2_500,
                suppressPitchHarmonics: suppress
            )
```

`.formantF3Hz` keeps the unsuppressed call — F3 is high enough that pitch-harmonic interference is minimal in the 1500–3500 band.

- [ ] **Step 4: Run the new test + full suite**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureExtractorTests.testF1SuppressesPitchHarmonic)
```

Expected: PASS.

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -3)
```

Expected: zero failures, 12 skipped.

- [ ] **Step 5: Commit**

```sh
git add Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureExtractor.swift \
        Packages/MoraEngines/Sources/MoraEngines/Pronunciation/FeatureBasedPronunciationEvaluator.swift \
        Packages/MoraEngines/Tests/MoraEnginesTests/FeatureExtractorTests.swift
git commit -m "$(cat <<'EOF'
engines: suppress pitch harmonics when measuring F1/F2 on short windows

On short (< 200 ms) measurement windows the FFT bin width is wide enough
that the speaker's pitch harmonics often outweigh the true formants in
the F1 / F2 bands. /æ/ recordings of "cat" measured F1 ≈ 594 Hz —
suspiciously close to the speaker's 220 Hz × 3 harmonic at 660 Hz —
which pushed the æ/ʌ classifier the wrong way.

spectralPeakInBand now accepts an opt-in suppressPitchHarmonics mode
that estimates the dominant pitch by autocorrelation and rejects any
band-peak within ±20 Hz of an integer multiple. F3 stays unsuppressed
because pitch-harmonic interference is minimal at 1500–3500 Hz.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: End-to-end integration tests against synthetic recordings

Locks the three fixes in via end-to-end paths through `FeatureBasedPronunciationEvaluator.evaluate(...)` so a regression in either the extractor, the localizer, or the wiring surfaces here, not just at the bench.

**Files:**
- Modify: `Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `FeatureBasedEvaluatorTests.swift` (just above the `// MARK: - Skipped substitution pairs` block):

```swift
    // MARK: - Integration: feature-extractor reliability

    func testVoicedFricativeOnsetEvaluatesAsMatched() async {
        let veryWord = Word(
            surface: "very",
            graphemes: [Grapheme(letters: "v"), Grapheme(letters: "e"), Grapheme(letters: "ry")],
            phonemes: [Phoneme(ipa: "v"), Phoneme(ipa: "ɛ"), Phoneme(ipa: "r"), Phoneme(ipa: "i")],
            targetPhoneme: Phoneme(ipa: "v")
        )
        // Voiced fricative onset → vowel. Should evaluate as matched, not
        // substituted-by-/b/, because the relative-VOT extractor (Task 3)
        // returns a strongly-negative value.
        let audio = SyntheticAudio.voicedFricative(durationMs: 200, burstStartMs: 80)
        let result = await evaluator.evaluate(
            audio: audio, expected: veryWord,
            targetPhoneme: Phoneme(ipa: "v"),
            asr: ASRResult(transcript: "very", confidence: 0.9)
        )
        XCTAssertEqual(result.label, .matched)
        XCTAssertTrue(result.isReliable)
    }

    func testLiquidOnsetWithDiphthongVowelDoesNotMislabelLAsR() async {
        let lightWord = Word(
            surface: "light",
            graphemes: [Grapheme(letters: "l"), Grapheme(letters: "i"), Grapheme(letters: "ght")],
            phonemes: [Phoneme(ipa: "l"), Phoneme(ipa: "aɪ"), Phoneme(ipa: "t")],
            targetPhoneme: Phoneme(ipa: "l")
        )
        // /l/ formant region (clean F3 ≈ 3000 Hz, lasting 60 ms) followed
        // by a diphthong region with low F3. Without the liquid-onset
        // shortening (Task 1) the 150 ms onset slice catches the diphthong
        // and engine mislabels /l/ as /r/.
        let lOnset = SyntheticAudio.bandNoise(lowHz: 2_900, highHz: 3_100, durationMs: 60)
        let diphthong = SyntheticAudio.bandNoise(lowHz: 1_400, highHz: 1_700, durationMs: 240)
        let audio = SyntheticAudio.concat(lOnset, diphthong)
        let result = await evaluator.evaluate(
            audio: audio, expected: lightWord,
            targetPhoneme: Phoneme(ipa: "l"),
            asr: ASRResult(transcript: "light", confidence: 0.9)
        )
        XCTAssertNotEqual(
            result.label,
            .substitutedBy(Phoneme(ipa: "r")),
            "with shortened liquid onset window the diphthong should not pull /l/ into /r/ territory"
        )
    }
```

- [ ] **Step 2: Run tests to verify they pass**

```sh
(cd Packages/MoraEngines && swift test --filter FeatureBasedEvaluatorTests.testVoicedFricativeOnsetEvaluatesAsMatched)
(cd Packages/MoraEngines && swift test --filter FeatureBasedEvaluatorTests.testLiquidOnsetWithDiphthongVowelDoesNotMislabelLAsR)
```

Expected: both PASS — they should pass on the first run because Tasks 1, 2, 3 already implemented the underlying changes. If either fails here, the failure is the integration wiring (`FeatureBasedPronunciationEvaluator.measure(...)` not picking up the new extractor entry point, or `PhonemeRegionLocalizer.region(...)` not branching on the liquid target) — fix the wiring before proceeding.

- [ ] **Step 3: Run the full suite**

```sh
(cd Packages/MoraEngines && swift test 2>&1 | tail -3)
```

Expected: zero failures, 12 skipped.

```sh
(cd Packages/MoraCore && swift test 2>&1 | tail -3)
(cd Packages/MoraUI && swift test 2>&1 | tail -3)
(cd Packages/MoraTesting && swift test 2>&1 | tail -3)
(cd dev-tools/pronunciation-bench && swift test 2>&1 | tail -3)
```

All green.

- [ ] **Step 4: Lint**

```sh
swift-format lint --strict --recursive Mora Packages/*/Sources Packages/*/Tests
```

Expected: silent.

- [ ] **Step 5: Xcode build**

```sh
xcodegen generate
xcodebuild build -project Mora.xcodeproj -scheme Mora \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```sh
git add Packages/MoraEngines/Tests/MoraEnginesTests/FeatureBasedEvaluatorTests.swift
git commit -m "$(cat <<'EOF'
engines: integration tests for VOT + liquid-onset reliability fixes

End-to-end coverage through FeatureBasedPronunciationEvaluator.evaluate
so regressions in either FeatureExtractor or PhonemeRegionLocalizer
surface in package tests, not just at the developer-laptop bench.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Real-recording verification

Manual verification step against the existing `~/mora-fixtures-adult/` recordings (no re-record needed). Not committed — just confirms the bench result.

- [ ] **Step 1: Re-trim and re-bench**

```sh
rm -rf ~/mora-fixtures-adult-trimmed
mkdir -p ~/mora-fixtures-adult-trimmed/{rl,vb,aeuh}
for subdir in rl vb aeuh; do
  for wav in ~/mora-fixtures-adult/$subdir/*.wav; do
    stem=$(basename "$wav" -take1.wav)
    sox "$wav" -r 16000 -b 16 -c 1 \
        ~/mora-fixtures-adult-trimmed/$subdir/$stem.wav \
        silence 1 0.05 0.5% reverse silence 1 0.05 0.5% reverse trim 0 2.0
    cp "$(dirname "$wav")/$stem-take1.json" \
       ~/mora-fixtures-adult-trimmed/$subdir/$stem.json
  done
done

cd dev-tools/pronunciation-bench
for d in rl vb aeuh; do
  swift run bench ~/mora-fixtures-adult-trimmed/$d \
                  ~/mora-fixtures-adult-trimmed/out-$d.csv --no-speechace
done
```

- [ ] **Step 2: Inspect labels**

Combine the per-subdir CSVs and check the match rate. Expected improvement vs the baseline 5/12:

| Fixture | Pre-PR result | Post-PR expected | Why |
|---|---|---|---|
| `light-correct` | sub:r ✗ | matched ✓ | Task 1 — shorter onset window avoids the /aɪ/ F3 |
| `very-correct` | sub:b ✗ | matched ✓ | Task 3 — relative VOT no longer reads /v/ as /b/ |
| `cat-correct` | sub:ʌ ✗ | matched ✓ | Task 4 — F1 with pitch suppression measures the true 700 Hz peak |
| `berry-as-very` | matched ✗ | sub:v ✓ or matched | Task 3 — depends on speaker producing /v/ clearly enough |
| `very-as-berry` | matched ✗ | sub:b ✓ or matched | Task 3 — depends on speaker producing /b/ clearly enough |
| `cat-as-cut` | matched ✗ | sub:ʌ ✓ or matched | Task 4 — depends on speaker producing /ʌ/ clearly enough |
| `cut-as-cat` | matched ✗ | sub:æ ✓ or matched | Task 4 — depends on speaker producing /æ/ clearly enough |

The four `*-as-X` cases may still fail if the recording is recording-quality-limited rather than extractor-limited. That is a Task A1 re-record concern (per `2026-04-23-pronunciation-bench-followups.md`), not an Engine A correctness concern.

- [ ] **Step 3: Document in the PR**

Include the per-fixture label table in the PR body (before / after) so a reviewer can confirm the engine fix landed without retreading the analysis.

---

## Self-Review

- **Spec coverage:** Three feature-extractor reliability issues identified in the discovery section all have a task. VOT (Task 3), liquid onset (Task 1), F1 short-window (Task 4). Synthetic test infrastructure (Task 2) gates 3 and 5. Integration coverage (Task 5) and real-recording verification (Task 6) close the loop. The æ/ʌ boundary calibration is explicitly handled in a sibling change, not this plan.
- **Placeholder scan:** No `TBD`, `TODO`, "implement appropriate", "handle edge cases", or "similar to Task N" deferrals. Every code step has full code; every command has the exact invocation and the expected output.
- **Type consistency:** `voicingOnsetTimeRelative(clip:burstThreshold:voicingThreshold:)` is the same signature in Task 3 Step 1 (test), Step 3 (extractor body), and Step 3 (caller in `FeatureBasedPronunciationEvaluator`). `spectralPeakInBand(clip:lowHz:highHz:suppressPitchHarmonics:)` is the same in Task 4 Step 1 (test) and Step 3 (implementation + caller). `voicedFricative(durationMs:burstStartMs:)` and `voicedStop(durationMs:burstStartMs:vowelStartMs:)` defined in Task 2 are used identically in Tasks 3 and 5.

## Open questions

1. **Is Engine A worth this effort vs accelerating Engine B promotion?** Engine B (`PhonemeModelPronunciationEvaluator` with the wav2vec2 CoreML model) lands as the v1.5 substitution-detection path — a real phoneme posterior model will outperform any tuning of these heuristic extractors. The case for Tasks 1-5 is that Engine B is still in shadow mode (`docs/superpowers/plans/2026-04-23-engine-b-followup-real-model-bundling.md`), and Engine A remains the active scoring path until promotion. If Engine B is promoted to primary before this plan ships, the v/b and r/l fixes still earn their keep as a fallback when Engine B's confidence is low.
2. **Should `voicingOnsetTime` (the old extractor) stay public?** No external callers within the repo at the time of writing. Recommend keeping it for one release as `@available(*, deprecated)` to avoid breaking any out-of-tree consumers (this repo currently has none, but it's a small cost), then removing in a follow-up cleanup PR.
3. **`dominantPitchHz` autocorrelation cost on long clips:** O(n²) over the lag range. For 2 s clips at 16 kHz the inner loop runs ~32 000 × 320 ≈ 10 M ops — acceptable for offline use and per-trial evaluation, but if Engine A ever becomes a real-time-streaming path, swap for a vDSP `vDSP_dotpr`-based correlation or downsample first. Not a v1 concern.
4. **Liquid onset window of 60 ms:** Empirically chosen to clear typical /aɪ/ formant transitions. If real adult-male recordings of `right` measure the steady-state /r/ region in 80 ms, widen to 80 ms; if they cluster at 50 ms, narrow. The number is tunable without a schema change.
