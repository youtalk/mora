// ForcedAlignerTests.swift
import XCTest
@testable import MoraEngines
import MoraCore

final class ForcedAlignerTests: XCTestCase {
    private func inventory(_ labels: [String]) -> PhonemeInventory {
        PhonemeInventory(
            espeakLabels: labels,
            supportedPhonemeIPA: Set(labels)
        )
    }

    func testSinglePhonemeCoversWholePosterior() {
        let aligner = ForcedAligner(inventory: inventory(["ʃ", "s"]))
        let p = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["ʃ", "s"],
            logProbabilities: Array(
                repeating: [Float(log(0.9)), Float(log(0.1))],
                count: 10
            )
        )
        let out = aligner.align(posterior: p, phonemes: [Phoneme(ipa: "ʃ")])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].phoneme.ipa, "ʃ")
        XCTAssertEqual(out[0].startFrame, 0)
        XCTAssertEqual(out[0].endFrame, 10)
        XCTAssertGreaterThan(out[0].averageLogProb, Float(log(0.5)))
    }

    func testTwoPhonemesRecoverBoundary() {
        // First 5 frames: /ʃ/ strong; last 5 frames: /s/ strong.
        let shRow: [Float] = [Float(log(0.9)), Float(log(0.1))]
        let sRow: [Float] = [Float(log(0.1)), Float(log(0.9))]
        let rows = Array(repeating: shRow, count: 5) + Array(repeating: sRow, count: 5)
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["ʃ", "s"], logProbabilities: rows
        )
        let aligner = ForcedAligner(inventory: inventory(["ʃ", "s"]))
        let out = aligner.align(posterior: p, phonemes: [Phoneme(ipa: "ʃ"), Phoneme(ipa: "s")])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0].phoneme.ipa, "ʃ")
        XCTAssertEqual(out[1].phoneme.ipa, "s")
        XCTAssertEqual(out[0].endFrame, 5)
        XCTAssertEqual(out[1].startFrame, 5)
        XCTAssertEqual(out[1].endFrame, 10)
    }

    func testPhonemeNotInInventoryUsesPositionalFallback() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"],
            logProbabilities: Array(repeating: [Float(0)], count: 10)
        )
        let aligner = ForcedAligner(inventory: inventory(["a"]))
        let out = aligner.align(
            posterior: p,
            phonemes: [Phoneme(ipa: "a"), Phoneme(ipa: "unknown")]
        )
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[1].phoneme.ipa, "unknown")
        XCTAssertLessThanOrEqual(out[1].averageLogProb, 0)
    }

    func testMoreFramesAcrossThreePhonemesStillContiguous() {
        let rows: [[Float]] = (0..<12).map { i in
            if i < 4 { return [Float(log(0.9)), Float(log(0.05)), Float(log(0.05))] }
            if i < 8 { return [Float(log(0.05)), Float(log(0.9)), Float(log(0.05))] }
            return [Float(log(0.05)), Float(log(0.05)), Float(log(0.9))]
        }
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a", "b", "c"], logProbabilities: rows
        )
        let aligner = ForcedAligner(inventory: inventory(["a", "b", "c"]))
        let out = aligner.align(
            posterior: p,
            phonemes: [Phoneme(ipa: "a"), Phoneme(ipa: "b"), Phoneme(ipa: "c")]
        )
        XCTAssertEqual(out[0].endFrame, out[1].startFrame)
        XCTAssertEqual(out[1].endFrame, out[2].startFrame)
        XCTAssertEqual(out.last?.endFrame, 12)
    }

    func testFewerFramesThanPhonemesReturnsInfiniteLowProb() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"],
            logProbabilities: [[Float(log(0.9))]]
        )
        let aligner = ForcedAligner(inventory: inventory(["a"]))
        let out = aligner.align(
            posterior: p,
            phonemes: [Phoneme(ipa: "a"), Phoneme(ipa: "a"), Phoneme(ipa: "a")]
        )
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(out[0].averageLogProb, -.infinity)
    }

    func testEmptyPhonemesReturnsEmptyAlignment() {
        let aligner = ForcedAligner(inventory: inventory(["a"]))
        let out = aligner.align(posterior: .empty, phonemes: [])
        XCTAssertTrue(out.isEmpty)
    }
}
