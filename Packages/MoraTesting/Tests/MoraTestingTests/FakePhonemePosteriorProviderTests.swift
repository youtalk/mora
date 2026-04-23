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
