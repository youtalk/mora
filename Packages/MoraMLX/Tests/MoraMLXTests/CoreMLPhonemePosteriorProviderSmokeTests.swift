// Packages/MoraMLX/Tests/MoraMLXTests/CoreMLPhonemePosteriorProviderSmokeTests.swift
import XCTest

@testable import MoraMLX
import MoraEngines

/// End-to-end smoke test: load the real wav2vec2 CoreML model through
/// `MoraMLXModelCatalog`, decode the bundled fixture WAV into an
/// `AudioClip`, and run a forward pass through the provider.
///
/// This test is adaptive because both the model and the fixture are
/// deferred: the model is bundled via Git LFS in a follow-up manual step
/// (see `dev-tools/model-conversion/convert.py`) and the fixture WAV is
/// created the same way. Until the model is present,
/// `PlaceholderDetection.isPlaceholderModelBundled()` returns true and
/// the test `XCTSkip`s on any `MoraMLXError`; once the real model is
/// bundled, a throwing catalog will FAIL the test (no more blanket skip
/// on `.inferenceFailed`).
final class CoreMLPhonemePosteriorProviderSmokeTests: XCTestCase {
    func testPosteriorHasFramesAndPhonemes() async throws {
        let evaluator: PhonemeModelPronunciationEvaluator
        do {
            evaluator = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        } catch let error as MoraMLXError {
            if PlaceholderDetection.isPlaceholderModelBundled() {
                throw XCTSkip(
                    "placeholder model bundled — run dev-tools/model-conversion/convert.py "
                        + "to enable this test (saw \(error))"
                )
            }
            throw error
        }
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
