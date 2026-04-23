import Foundation

/// Mono PCM audio clip, typically captured from `AppleSpeechEngine`'s tap.
/// Sample format is Float32, range roughly [-1.0, 1.0]. The sample rate is
/// carried alongside the samples because feature extraction needs it; the
/// tap does not guarantee a fixed rate across hardware.
public struct AudioClip: Sendable, Hashable, Codable {
    public let samples: [Float]
    public let sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var durationSeconds: Double {
        sampleRate > 0 ? Double(samples.count) / sampleRate : 0
    }

    public static let empty = AudioClip(samples: [], sampleRate: 16_000)
}
