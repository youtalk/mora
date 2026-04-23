// PhonemeInventoryTests.swift
import XCTest
@testable import MoraEngines

final class PhonemeInventoryTests: XCTestCase {
    func testIpaToColumnMapsEachLabelToItsIndex() {
        let inv = PhonemeInventory(
            espeakLabels: ["ʃ", "s", "r", "l"],
            supportedPhonemeIPA: ["ʃ", "s"]
        )
        XCTAssertEqual(inv.ipaToColumn["ʃ"], 0)
        XCTAssertEqual(inv.ipaToColumn["s"], 1)
        XCTAssertEqual(inv.ipaToColumn["r"], 2)
        XCTAssertEqual(inv.ipaToColumn["l"], 3)
        XCTAssertNil(inv.ipaToColumn["unknown"])
    }

    func testSupportedPhonemeIPAIsPreserved() {
        let inv = PhonemeInventory(
            espeakLabels: ["a", "b"],
            supportedPhonemeIPA: ["a"]
        )
        XCTAssertEqual(inv.supportedPhonemeIPA, ["a"])
    }

    func testV15SupportedSetCoversEngineA() {
        let required: Set<String> = ["ʃ", "s", "r", "l", "f", "h", "v", "b", "θ", "t", "æ", "ʌ"]
        XCTAssertTrue(required.isSubset(of: PhonemeInventory.v15SupportedPhonemeIPA))
    }
}
