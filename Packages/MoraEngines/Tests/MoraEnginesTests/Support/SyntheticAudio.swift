import Foundation
import MoraEngines

/// Test-only synthesizers for predictable audio fixtures. The generated
/// clips have known spectral centroids, formants, or burst profiles so that
/// `FeatureExtractor` assertions can be exact.
enum SyntheticAudio {
    static let sampleRate: Double = 16_000

    /// Mixture of sine tones with unit amplitude and per-frequency relative gain.
    static func sineMix(
        frequencies: [Double],
        gains: [Double]? = nil,
        durationMs: Int
    ) -> AudioClip {
        let n = Int(Double(durationMs) / 1000.0 * sampleRate)
        let g =
            gains
            ?? Array(repeating: 1.0 / Double(frequencies.count), count: frequencies.count)
        precondition(g.count == frequencies.count, "frequencies and gains count mismatch")
        var samples = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            var s = 0.0
            for (freq, gain) in zip(frequencies, g) {
                s += gain * sin(2 * .pi * freq * t)
            }
            samples[i] = Float(s)
        }
        return AudioClip(samples: samples, sampleRate: sampleRate)
    }

    /// Band-limited white noise: uniform random, then a simple 2-pole
    /// bi-quad band-pass around (low, high). Not audio-engineering-grade,
    /// but centroid and band-energy ratio land within 10% of analytic.
    static func bandNoise(
        lowHz: Double,
        highHz: Double,
        durationMs: Int,
        seed: UInt64 = 0xC0FFEE
    ) -> AudioClip {
        var rng = SeededGenerator(seed: seed)
        let n = Int(Double(durationMs) / 1000.0 * sampleRate)
        var noise = [Float](repeating: 0, count: n)
        for i in 0..<n { noise[i] = Float.random(in: -1...1, using: &rng) }
        let center = (lowHz + highHz) / 2
        let bandwidth = max(1.0, highHz - lowHz)
        let q = center / bandwidth
        let w0 = 2 * .pi * center / sampleRate
        let alpha = sin(w0) / (2 * q)
        let b0 = alpha, b1 = 0.0, b2 = -alpha
        let a0 = 1 + alpha, a1 = -2 * cos(w0), a2 = 1 - alpha
        var y1 = 0.0, y2 = 0.0, x1 = 0.0, x2 = 0.0
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let x0 = Double(noise[i])
            let y0 = (b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            out[i] = Float(y0)
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }
        return AudioClip(samples: out, sampleRate: sampleRate)
    }

    /// Voiced fricative: low-amplitude full-band uniform noise continuous
    /// from t=0 to `burstStartMs`, then a sustained voiced vowel (sine at
    /// 220 Hz) from `burstStartMs` onward. Both regions share an envelope
    /// with RMS ≈ 0.05 so the seam is acoustically continuous — the
    /// signature expected from /v/, /z/, /ð/. Spectral shape is not
    /// constrained because the relative-VOT extractor only inspects RMS
    /// envelope and burst/voicing transitions, not band content.
    static func voicedFricative(durationMs: Int, burstStartMs: Int) -> AudioClip {
        precondition(
            durationMs > 0 && (0...durationMs).contains(burstStartMs),
            "voicedFricative: burstStartMs must be within [0, durationMs]"
        )
        let sr = sampleRate
        let totalSamples = Int(Double(durationMs) / 1000.0 * sr)
        let burstSamples = Int(Double(burstStartMs) / 1000.0 * sr)

        var samples = [Float](repeating: 0, count: totalSamples)
        // Fricative half: full-band uniform noise, gain 0.05.
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
    /// then 5 ms silence (closure), then a 5 ms high-amplitude burst
    /// centered at `burstStartMs`, then a sustained vowel (sine at 220 Hz)
    /// from `vowelStartMs`. The signature expected from /b/, /d/, /g/:
    /// pre-burst voicing → pause → burst → voicing resumes.
    ///
    /// The burst spans one 5 ms window at amplitude 0.5 so that a
    /// relative-VOT extractor using 5 ms RMS windows sees a dRMS spike
    /// well above 0.2 at the burst location.
    static func voicedStop(
        durationMs: Int,
        burstStartMs: Int,
        vowelStartMs: Int
    ) -> AudioClip {
        precondition(
            durationMs > 0
                && burstStartMs >= 0
                && vowelStartMs >= burstStartMs
                && vowelStartMs <= durationMs,
            "voicedStop: expect 0 <= burstStartMs <= vowelStartMs <= durationMs"
        )
        let sr = sampleRate
        let totalSamples = Int(Double(durationMs) / 1000.0 * sr)
        let preVoicingSamples = max(0, Int(Double(burstStartMs) / 1000.0 * sr) - 80)
        let burstStartSample = Int(Double(burstStartMs) / 1000.0 * sr)
        // Burst spans one full 5 ms window (80 samples) so the RMS delta is
        // large enough to exceed the burstThreshold used by the VOT extractor.
        let burstEndSample = min(totalSamples, burstStartSample + 80)
        let vowelStartSample = Int(Double(vowelStartMs) / 1000.0 * sr)

        var samples = [Float](repeating: 0, count: totalSamples)
        // Pre-burst murmur: sub-threshold 220 Hz sine, gain 0.01 (below the
        // 0.02 voicingThreshold used by voicingOnsetTimeRelative, so the
        // relative-VOT extractor treats this region as silence).
        for i in 0..<preVoicingSamples {
            let t = Double(i) / sr
            samples[i] = Float(0.01 * sin(2 * .pi * 220 * t))
        }
        // Closure (silence): preVoicingSamples..<burstStartSample stays at 0.
        // Burst: 5 ms high-amplitude burst (one full 5 ms window at 0.5) so
        // that the dRMS spike exceeds burstThreshold 0.2.
        for i in burstStartSample..<burstEndSample {
            samples[i] = 0.5
        }
        // Vowel: 220 Hz sine, gain 0.05 (above voicingThreshold 0.02).
        for i in vowelStartSample..<totalSamples {
            let t = Double(i) / sr
            samples[i] = Float(0.05 * sin(2 * .pi * 220 * t))
        }
        return AudioClip(samples: samples, sampleRate: sr)
    }

    /// Silent clip of the given duration.
    static func silence(durationMs: Int) -> AudioClip {
        let n = Int(Double(durationMs) / 1000.0 * sampleRate)
        return AudioClip(samples: Array(repeating: 0, count: n), sampleRate: sampleRate)
    }

    /// Concatenate clips that share a sample rate.
    static func concat(_ clips: AudioClip...) -> AudioClip {
        precondition(!clips.isEmpty)
        let sr = clips[0].sampleRate
        var combined = [Float]()
        for c in clips {
            precondition(c.sampleRate == sr, "sample rate mismatch in concat")
            combined.append(contentsOf: c.samples)
        }
        return AudioClip(samples: combined, sampleRate: sr)
    }
}

/// Deterministic seeded generator — `SystemRandomNumberGenerator` is
/// non-seedable, so tests need their own. A simple xorshift64* is enough
/// here: we only want reproducibility, not cryptographic strength.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xDEADBEEF : seed }
    mutating func next() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2_685_821_657_736_338_717
    }
}
