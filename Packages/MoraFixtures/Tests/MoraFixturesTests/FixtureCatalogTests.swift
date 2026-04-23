import XCTest

@testable import MoraFixtures

final class FixtureCatalogTests: XCTestCase {

    func testCountIsTwelve() {
        XCTAssertEqual(FixtureCatalog.v1Patterns.count, 12)
    }

    func testAllIDsAreUnique() {
        let ids = FixtureCatalog.v1Patterns.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testAllFilenameStemsAreUnique() {
        let stems = FixtureCatalog.v1Patterns.map(\.filenameStem)
        XCTAssertEqual(stems.count, Set(stems).count)
    }

    func testSubstituteBijectsWithExpectedLabel() {
        for p in FixtureCatalog.v1Patterns {
            if p.expectedLabel == .substitutedBy {
                XCTAssertNotNil(
                    p.substitutePhonemeIPA,
                    "substitutedBy entry \(p.id) must have substitutePhonemeIPA")
            } else {
                XCTAssertNil(
                    p.substitutePhonemeIPA,
                    "non-substituted entry \(p.id) must not have substitutePhonemeIPA")
            }
        }
    }

    func testTargetIndexIsWithinSequence() {
        for p in FixtureCatalog.v1Patterns {
            XCTAssertTrue(
                p.phonemeSequenceIPA.indices.contains(p.targetPhonemeIndex),
                "\(p.id) targetPhonemeIndex \(p.targetPhonemeIndex) outside "
                    + "sequence of length \(p.phonemeSequenceIPA.count)")
            XCTAssertEqual(
                p.phonemeSequenceIPA[p.targetPhonemeIndex],
                p.targetPhonemeIPA,
                "\(p.id) sequence[targetPhonemeIndex] \(p.phonemeSequenceIPA[p.targetPhonemeIndex]) "
                    + "does not match targetPhonemeIPA \(p.targetPhonemeIPA)"
            )
        }
    }
}
