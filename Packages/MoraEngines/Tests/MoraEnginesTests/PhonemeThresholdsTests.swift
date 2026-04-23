import XCTest

@testable import MoraEngines

final class PhonemeThresholdsTests: XCTestCase {
    func testShCentroidThresholds() {
        let t = PhonemeThresholds.primary(for: "ʃ", against: "s")!
        XCTAssertEqual(t.targetCentroid, 3_000, accuracy: 1)
        XCTAssertEqual(t.substituteCentroid, 6_500, accuracy: 1)
        XCTAssertEqual(t.boundary, 4_500, accuracy: 1)
        XCTAssertEqual(t.feature, .spectralCentroidHz)
    }

    func testRFormantThresholds() {
        let t = PhonemeThresholds.primary(for: "r", against: "l")!
        XCTAssertEqual(t.feature, .formantF3Hz)
        XCTAssertEqual(t.targetCentroid, 1_700, accuracy: 1)
        XCTAssertEqual(t.substituteCentroid, 3_000, accuracy: 1)
    }

    func testDriftTargetForSh() {
        let d = PhonemeThresholds.drift(for: "ʃ")!
        XCTAssertEqual(d.feature, .formantF2Hz)
        XCTAssertEqual(d.targetCentroid, 2_000, accuracy: 1)
        XCTAssertEqual(d.minReliable, 1_700, accuracy: 1)
    }
}
