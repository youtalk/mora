import Accelerate
import Foundation

/// Pure acoustic feature routines used by `FeatureBasedPronunciationEvaluator`.
/// All routines are stateless and can run off the main actor.
public enum FeatureExtractor {

    /// Spectral centroid in Hz: the amplitude-weighted mean frequency over
    /// a windowed FFT of the clip. Returns 0 if the clip is empty or silent.
    public static func spectralCentroid(clip: AudioClip) -> Double {
        guard let spectrum = powerSpectrum(clip: clip) else { return 0 }
        var weightedSum = 0.0
        var totalPower = 0.0
        let binWidth = clip.sampleRate / Double(2 * spectrum.count)
        for (i, p) in spectrum.enumerated() {
            let freq = Double(i) * binWidth
            weightedSum += freq * Double(p)
            totalPower += Double(p)
        }
        return totalPower > 0 ? weightedSum / totalPower : 0
    }

    /// Ratio of power above `splitHz` to power below it. Useful for
    /// /f/ vs /h/ and as a drift proxy for /ʃ/ lip rounding (low-band gain).
    public static func highLowBandEnergyRatio(clip: AudioClip, splitHz: Double) -> Double {
        guard let spectrum = powerSpectrum(clip: clip) else { return 0 }
        let binWidth = clip.sampleRate / Double(2 * spectrum.count)
        var high = 0.0
        var low = 0.0
        for (i, p) in spectrum.enumerated() {
            let freq = Double(i) * binWidth
            if freq >= splitHz {
                high += Double(p)
            } else {
                low += Double(p)
            }
        }
        return low > 0 ? high / low : .infinity
    }

    /// Spectral flatness (geometric mean / arithmetic mean of the power
    /// spectrum). 1.0 = white noise, 0.0 = pure tone. Useful for telling a
    /// broadband /s/ from a peakier /θ/.
    public static func spectralFlatness(clip: AudioClip) -> Double {
        guard let spectrum = powerSpectrum(clip: clip), !spectrum.isEmpty else { return 0 }
        let eps = 1e-12
        var sumLog = 0.0
        var sum = 0.0
        for p in spectrum {
            let v = Double(p) + eps
            sumLog += log(v)
            sum += v
        }
        let arithmetic = sum / Double(spectrum.count)
        let geometric = exp(sumLog / Double(spectrum.count))
        return arithmetic > 0 ? min(1.0, geometric / arithmetic) : 0
    }

    /// Variance of the per-window zero-crossing rate across the clip.
    /// Low variance → sustained-voiced signals; high variance → boundary-heavy
    /// signals such as /b/ bursts or abrupt onsets.
    public static func zeroCrossingRateVariance(clip: AudioClip, windowMs: Int) -> Double {
        let samplesPerWindow = max(8, Int(Double(windowMs) / 1000.0 * clip.sampleRate))
        guard clip.samples.count >= samplesPerWindow * 2 else { return 0 }
        var rates = [Double]()
        var i = 0
        while i + samplesPerWindow <= clip.samples.count {
            let window = clip.samples[i..<(i + samplesPerWindow)]
            var crossings = 0
            var prev = window.first ?? 0
            for s in window.dropFirst() {
                if (prev < 0) != (s < 0) { crossings += 1 }
                prev = s
            }
            rates.append(Double(crossings) / Double(samplesPerWindow))
            i += samplesPerWindow
        }
        guard rates.count > 1 else { return 0 }
        let mean = rates.reduce(0, +) / Double(rates.count)
        let variance = rates.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(rates.count)
        return variance
    }

    /// Slope of the RMS envelope over the first `windowMs`. Larger values
    /// indicate a sharper onset (burst phonemes like /t/, /b/); smaller
    /// values indicate gradual onsets (fricatives that ramp in).
    public static func onsetBurstSlope(clip: AudioClip, windowMs: Int) -> Double {
        let windowSamples = Int(Double(windowMs) / 1000.0 * clip.sampleRate)
        guard clip.samples.count >= windowSamples, windowSamples >= 16 else { return 0 }
        let firstHalf = clip.samples.prefix(windowSamples / 2)
        let secondHalf = clip.samples[(windowSamples / 2)..<windowSamples]
        let rms1 = sqrt(firstHalf.reduce(0) { $0 + $1 * $1 } / Float(firstHalf.count))
        let rms2 = sqrt(secondHalf.reduce(0) { $0 + $1 * $1 } / Float(secondHalf.count))
        return Double(rms2 - rms1) * (1000.0 / Double(windowMs))
    }

    /// Milliseconds from clip start to the first frame whose absolute-value
    /// RMS rises above `threshold`. Approximates voicing onset; a negative
    /// return is not produced by this routine (callers who need lead/lag
    /// should compute their own sign by comparing to a reference onset).
    public static func voicingOnsetTime(clip: AudioClip, threshold: Float) -> Double {
        let windowMs = 10
        let windowSamples = max(8, Int(Double(windowMs) / 1000.0 * clip.sampleRate))
        var i = 0
        while i + windowSamples <= clip.samples.count {
            let window = clip.samples[i..<(i + windowSamples)]
            let rms = sqrt(window.reduce(0) { $0 + $1 * $1 } / Float(window.count))
            if rms >= threshold {
                return Double(i) / clip.sampleRate * 1000.0
            }
            i += windowSamples
        }
        return Double(clip.samples.count) / clip.sampleRate * 1000.0
    }

    /// Frequency (Hz) of the strongest FFT bin whose center lies within
    /// [lowHz, highHz]. Intended as a lightweight stand-in for LPC formant
    /// tracking — accurate enough for the onset / coda regions we score.
    public static func spectralPeakInBand(clip: AudioClip, lowHz: Double, highHz: Double) -> Double {
        guard let spectrum = powerSpectrum(clip: clip) else { return 0 }
        let binWidth = clip.sampleRate / Double(2 * spectrum.count)
        var bestBin = -1
        var bestPower: Float = 0
        for (i, p) in spectrum.enumerated() {
            let freq = Double(i) * binWidth
            if freq < lowHz || freq > highHz { continue }
            if p > bestPower {
                bestPower = p
                bestBin = i
            }
        }
        return bestBin >= 0 ? Double(bestBin) * binWidth : 0
    }

    /// Power spectrum of the windowed FFT, returned as a half-band magnitude
    /// array (DC to Nyquist). Returns nil for empty clips.
    static func powerSpectrum(clip: AudioClip) -> [Float]? {
        let samples = clip.samples
        guard samples.count >= 64 else { return nil }

        // Pick the largest power of two that fits the clip.
        let log2n = vDSP_Length(log2(Double(samples.count)))
        let n = Int(1 << log2n)
        let window = vDSP.window(
            ofType: Float.self,
            usingSequence: .hanningNormalized,
            count: n,
            isHalfWindow: false
        )
        var windowed = [Float](repeating: 0, count: n)
        vDSP.multiply(window, Array(samples.prefix(n)), result: &windowed)

        var realp = [Float](repeating: 0, count: n / 2)
        var imagp = [Float](repeating: 0, count: n / 2)
        var magnitudes = [Float](repeating: 0, count: n / 2)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                windowed.withUnsafeBytes { ptr in
                    let complexPtr = ptr.bindMemory(to: DSPComplex.self).baseAddress!
                    vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(n / 2))
                }
                guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
                defer { vDSP_destroy_fftsetup(setup) }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(n / 2))
            }
        }
        return magnitudes
    }
}
