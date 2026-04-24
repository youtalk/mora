import XCTest

@testable import MoraCore

/// Pins `YokaiEncounterState` raw values to the literal strings used in
/// SwiftData `#Predicate` closures (see `HomeView.openEncounters` and
/// `WeekRotation.resolve`). `#Predicate` cannot form key paths into enum
/// cases, so those call sites compare `stateRaw` against bare strings; if a
/// case is renamed, the raw value shifts and the predicates silently match
/// zero rows in prod. These assertions surface the drift in CI instead.
final class YokaiEncounterStateRawValuesTests: XCTestCase {
    func test_rawValues_matchPredicateLiterals() {
        XCTAssertEqual(YokaiEncounterState.upcoming.rawValue, "upcoming")
        XCTAssertEqual(YokaiEncounterState.active.rawValue, "active")
        XCTAssertEqual(YokaiEncounterState.carryover.rawValue, "carryover")
        XCTAssertEqual(YokaiEncounterState.befriended.rawValue, "befriended")
    }
}
