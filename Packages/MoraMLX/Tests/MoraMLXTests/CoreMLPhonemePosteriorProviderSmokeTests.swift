// Packages/MoraMLX/Tests/MoraMLXTests/CoreMLPhonemePosteriorProviderSmokeTests.swift
import XCTest

@testable import MoraMLX
import MoraEngines

/// End-to-end smoke test: load the real wav2vec2 CoreML model through
/// `MoraMLXModelCatalog`, decode the bundled fixture WAV into an
/// `AudioClip`, and run a forward pass through the provider.
///
/// The real model is hosted on the `models/wav2vec2-phoneme-int8-v1`
/// GitHub Release and materialized into `Resources/` by
/// `tools/fetch-models.sh` (see
/// `docs/superpowers/plans/2026-04-24-ci-lfs-to-releases.md`). The
/// `short-sh-clip.wav` fixture lives alongside this test target.
///
/// The `catch MoraMLXError` branch is a historical guard for the
/// pre-migration placeholder state and is not expected to trigger on
/// `main`: `phoneme-labels.json` is committed with the real 392-entry
/// vocabulary so `PlaceholderDetection.isPlaceholderModelBundled()`
/// returns `false`, and a throwing catalog FAILs the test instead of
/// silently skipping on `.inferenceFailed`. On a fresh clone that has
/// not yet run `bash tools/fetch-models.sh` (or a build that triggers
/// the Mora target's preBuildScript), the `.mlmodelc/` directory is
/// missing and the test FAILs with `.modelNotBundled` — the failure is
/// the intended cue to run the bootstrap.
final class CoreMLPhonemePosteriorProviderSmokeTests: XCTestCase {
    func testPosteriorHasFramesAndPhonemes() async throws {
        let evaluator: PhonemeModelPronunciationEvaluator
        do {
            evaluator = try MoraMLXModelCatalog.loadPhonemeEvaluator()
        } catch let error as MoraMLXError {
            if PlaceholderDetection.isPlaceholderModelBundled() {
                throw XCTSkip(
                    "placeholder model bundled — run bash tools/fetch-models.sh "
                        + "to materialize the real model from the GitHub Release (saw \(error))"
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
