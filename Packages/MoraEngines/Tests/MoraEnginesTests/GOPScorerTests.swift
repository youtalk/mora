// GOPScorerTests.swift
import XCTest
@testable import MoraEngines

final class GOPScorerTests: XCTestCase {
    private func posterior(_ rows: [[Float]]) -> PhonemePosterior {
        PhonemePosterior(
            framesPerSecond: 50,
            phonemeLabels: ["a", "b"],
            logProbabilities: rows
        )
    }

    func testGopIsZeroWhenTargetDominates() {
        // target column is overwhelmingly the max across all frames
        let rows = Array(repeating: [Float(log(0.99)), Float(log(0.01))], count: 4)
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<4, targetColumn: 0)
        XCTAssertEqual(g, 0.0, accuracy: 1e-3)
        XCTAssertGreaterThanOrEqual(scorer.score0to100(gop: g), 99)
    }

    func testGopIsNegativeWhenOtherDominates() {
        let rows = Array(repeating: [Float(log(0.01)), Float(log(0.99))], count: 4)
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<4, targetColumn: 0)
        XCTAssertLessThan(g, -3.0)
        XCTAssertLessThanOrEqual(scorer.score0to100(gop: g), 10)
    }

    func testScoreIsMonotoneInGop() {
        let s = GOPScorer()
        let a = s.score0to100(gop: -2.0)
        let b = s.score0to100(gop: -1.5)
        let c = s.score0to100(gop: -1.0)
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
    }

    func testScoreClamped() {
        let s = GOPScorer()
        XCTAssertGreaterThanOrEqual(s.score0to100(gop: -100), 0)
        XCTAssertLessThanOrEqual(s.score0to100(gop: 100), 100)
    }

    func testEmptyRangeReturnsNegInfinity() {
        let rows = [[Float(0), Float(0)]]
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<0, targetColumn: 0)
        XCTAssertEqual(g, -.infinity)
    }

    func testOutOfRangeColumnReturnsNegInfinity() {
        let rows = [[Float(0), Float(0)]]
        let scorer = GOPScorer()
        let g = scorer.gop(posterior: posterior(rows), range: 0..<1, targetColumn: 5)
        XCTAssertEqual(g, -.infinity)
    }
}
