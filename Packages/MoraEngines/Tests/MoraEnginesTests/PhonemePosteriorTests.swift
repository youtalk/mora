// PhonemePosteriorTests.swift
import XCTest
@testable import MoraEngines

final class PhonemePosteriorTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let p = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["a", "b", "c"],
            logProbabilities: [
                [-0.1, -0.2, -0.3],
                [-0.4, -0.5, -0.6],
            ]
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(PhonemePosterior.self, from: data)
        XCTAssertEqual(decoded, p)
    }

    func testFrameCountAndPhonemeCount() {
        let p = PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["x", "y"],
            logProbabilities: [[-1.0, -2.0], [-1.5, -0.5], [-0.1, -3.0]]
        )
        XCTAssertEqual(p.frameCount, 3)
        XCTAssertEqual(p.phonemeCount, 2)
    }

    func testFrameIndexForSecond() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"], logProbabilities: []
        )
        XCTAssertEqual(p.frameIndex(forSecond: 0), 0)
        XCTAssertEqual(p.frameIndex(forSecond: 0.02), 1)
        XCTAssertEqual(p.frameIndex(forSecond: 1.0), 50)
    }

    func testSecondForFrame() {
        let p = PhonemePosterior(
            framesPerSecond: 50, phonemeLabels: ["a"], logProbabilities: []
        )
        XCTAssertEqual(p.second(forFrame: 0), 0.0, accuracy: 1e-6)
        XCTAssertEqual(p.second(forFrame: 50), 1.0, accuracy: 1e-6)
    }

    func testEmptyPosteriorIsWellFormed() {
        let p = PhonemePosterior.empty
        XCTAssertEqual(p.frameCount, 0)
        XCTAssertEqual(p.phonemeCount, 0)
    }
}
