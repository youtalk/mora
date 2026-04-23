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
