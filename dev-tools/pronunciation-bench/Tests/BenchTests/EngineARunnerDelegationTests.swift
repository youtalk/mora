import Foundation
import MoraEngines
import MoraFixtures
import XCTest
@testable import Bench

final class EngineARunnerDelegationTests: XCTestCase {

    // The bench's EngineARunner must produce a PhonemeTrialAssessment
    // byte-for-byte identical to what PronunciationEvaluationRunner
    // produces when fed the same primitives. This guarantees the iPad
    // recorder (which calls the runner directly) and the Mac bench
    // (which goes through EngineARunner) never disagree on the same
    // audio.
    func testBenchDelegatesToPronunciationEvaluationRunner() async throws {
        // Synthetic /æ/-ish tone — stable and cheap to generate here
        // without pulling MoraTesting helpers into the bench target.
        let durationMs = 600
        let sampleRate: Double = 16_000
        let n = Int(Double(durationMs) / 1000.0 * sampleRate)
        var samples = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / sampleRate
            let s = 0.5 * sin(2 * .pi * 700 * t) + 0.3 * sin(2 * .pi * 1400 * t)
            samples[i] = Float(s)
        }

        let metadata = FixtureMetadata(
            capturedAt: Date(timeIntervalSince1970: 1_714_000_000),
            targetPhonemeIPA: "æ",
            expectedLabel: .matched,
            substitutePhonemeIPA: nil,
            wordSurface: "cat",
            sampleRate: sampleRate,
            durationSeconds: Double(durationMs) / 1000.0,
            speakerTag: .adult,
            phonemeSequenceIPA: ["k", "æ", "t"],
            targetPhonemeIndex: 1,
            patternID: "aeuh-cat-correct"
        )
        let loaded = LoadedFixture(
            pair: FixturePair(
                basename: "cat-correct-take1",
                wavURL: URL(fileURLWithPath: "/dev/null"),
                sidecarURL: URL(fileURLWithPath: "/dev/null")
            ),
            metadata: metadata,
            samples: samples,
            sampleRate: sampleRate
        )

        let direct = await PronunciationEvaluationRunner().evaluate(
            samples: samples,
            sampleRate: sampleRate,
            wordSurface: metadata.wordSurface,
            targetPhonemeIPA: metadata.targetPhonemeIPA,
            phonemeSequenceIPA: metadata.phonemeSequenceIPA,
            targetPhonemeIndex: metadata.targetPhonemeIndex
        )
        let viaBench = await EngineARunner().evaluate(loaded)

        XCTAssertEqual(direct, viaBench)
    }
}
