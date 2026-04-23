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

        var samplesMs: [Double] = []
        for _ in 0..<20 {
            let start = ContinuousClock.now
            _ = await evaluator.evaluate(
                audio: clip, expected: word, targetPhoneme: Phoneme(ipa: "ʃ"), asr: asr
            )
            let elapsed = start.duration(to: .now)
            let (s, attos) = elapsed.components
            let ms = Double(s) * 1000 + Double(attos) / 1e15
            samplesMs.append(ms)
        }
        samplesMs.sort()
        let p50 = samplesMs[samplesMs.count / 2]
        let p95 = samplesMs[Int(Double(samplesMs.count) * 0.95)]
        print("Phase3LatencyBenchmark: p50=\(p50)ms p95=\(p95)ms (budget 1000ms)")
    }
}
#endif
