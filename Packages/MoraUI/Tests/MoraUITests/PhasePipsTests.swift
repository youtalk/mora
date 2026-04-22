import MoraEngines
import XCTest

@testable import MoraUI

final class PhasePipsTests: XCTestCase {
    func test_pipIndex_mapsEveryADayPhase() {
        XCTAssertEqual(PhasePips.pipIndex(for: .notStarted), -1)
        XCTAssertEqual(PhasePips.pipIndex(for: .warmup), 0)
        XCTAssertEqual(PhasePips.pipIndex(for: .newRule), 1)
        XCTAssertEqual(PhasePips.pipIndex(for: .decoding), 2)
        XCTAssertEqual(PhasePips.pipIndex(for: .shortSentences), 3)
        XCTAssertEqual(PhasePips.pipIndex(for: .completion), 4)
    }

    func test_pipIndex_fitsWithinTotalCount() {
        // Any phase other than .notStarted must land inside 0..<5 so the
        // ForEach in body highlights a real pip.
        for phase: ADayPhase in [.warmup, .newRule, .decoding, .shortSentences, .completion] {
            let idx = PhasePips.pipIndex(for: phase)
            XCTAssertTrue((0..<5).contains(idx), "Phase \(phase) mapped to \(idx)")
        }
    }

    func test_accessibilityLabel_beforeSessionStart() {
        let pips = PhasePips(phase: .notStarted)
        XCTAssertEqual(pips.accessibilityLabel, "Session not started")
    }

    func test_accessibilityLabel_reportsHumanNumbering() {
        XCTAssertEqual(PhasePips(phase: .warmup).accessibilityLabel, "Phase 1 of 5")
        XCTAssertEqual(PhasePips(phase: .decoding).accessibilityLabel, "Phase 3 of 5")
        XCTAssertEqual(PhasePips(phase: .completion).accessibilityLabel, "Phase 5 of 5")
    }
}
