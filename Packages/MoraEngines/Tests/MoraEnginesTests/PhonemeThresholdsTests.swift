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

    func testAeUhFormantThresholds() {
        // æ → ʌ direction. Boundary lowered from the original literature
        // 640 Hz to 590 Hz (7.8 % shift, within Plan A4's ±15 % rule) so
        // adult-speaker /æ/ measurements landing in the 590-640 Hz band
        // classify as matched rather than substituted-by-/ʌ/.
        let aeUh = PhonemeThresholds.primary(for: "æ", against: "ʌ")!
        XCTAssertEqual(aeUh.feature, .formantF1Hz)
        XCTAssertEqual(aeUh.targetCentroid, 700, accuracy: 1)
        XCTAssertEqual(aeUh.substituteCentroid, 580, accuracy: 1)
        XCTAssertEqual(aeUh.boundary, 590, accuracy: 1)

        // ʌ → æ direction shares the same boundary (the table is
        // symmetric by construction), with target/substitute centroids
        // swapped.
        let uhAe = PhonemeThresholds.primary(for: "ʌ", against: "æ")!
        XCTAssertEqual(uhAe.feature, .formantF1Hz)
        XCTAssertEqual(uhAe.targetCentroid, 580, accuracy: 1)
        XCTAssertEqual(uhAe.substituteCentroid, 700, accuracy: 1)
        XCTAssertEqual(uhAe.boundary, 590, accuracy: 1)
    }
}
