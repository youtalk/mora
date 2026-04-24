import XCTest
@testable import MoraEngines

final class CoachingKeyResolverTests: XCTestCase {
    func testKnownSubstitutionPairs() {
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "ʃ", substitute: "s"), "coaching.sh_sub_s")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "r", substitute: "l"), "coaching.r_sub_l")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "l", substitute: "r"), "coaching.l_sub_r")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "f", substitute: "h"), "coaching.f_sub_h")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "v", substitute: "b"), "coaching.v_sub_b")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "θ", substitute: "s"), "coaching.th_voiceless_sub_s")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "θ", substitute: "t"), "coaching.th_voiceless_sub_t")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "t", substitute: "θ"), "coaching.t_sub_th_voiceless")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "æ", substitute: "ʌ"), "coaching.ae_sub_schwa")
        XCTAssertEqual(CoachingKeyResolver.substitution(target: "ʌ", substitute: "æ"), "coaching.ae_sub_schwa")
    }

    func testUnknownSubstitutionReturnsNil() {
        XCTAssertNil(CoachingKeyResolver.substitution(target: "x", substitute: "y"))
    }

    func testKnownDriftTargets() {
        XCTAssertEqual(CoachingKeyResolver.drift(target: "ʃ"), "coaching.sh_drift")
    }

    func testUnknownDriftReturnsNil() {
        XCTAssertNil(CoachingKeyResolver.drift(target: "r"))
    }
}
