// Packages/MoraUI/Tests/MoraUITests/LanguagePickerViewTests.swift
import MoraCore
import SwiftUI
import XCTest

@testable import MoraUI

/// SwiftUI view tree introspection is out of scope for the alpha test
/// harness (see spec §11.4). These tests confirm the view type is
/// constructable with the bindings it advertises and that the binding is
/// passed through untouched — the real flow-level behavior is exercised
/// in `LanguageAgeFlowTests`.
@MainActor
final class LanguagePickerViewTests: XCTestCase {
    func test_bindingPassesThroughWhenPreselected() {
        var selection = "ja"
        _ = LanguagePickerView(
            selectedLanguageID: Binding(
                get: { selection }, set: { selection = $0 }
            ),
            onContinue: {}
        )
        XCTAssertEqual(selection, "ja")
    }

    func test_bindingPassesThroughWhenEmpty() {
        var selection = ""
        _ = LanguagePickerView(
            selectedLanguageID: Binding(
                get: { selection }, set: { selection = $0 }
            ),
            onContinue: {}
        )
        XCTAssertTrue(selection.isEmpty)
    }
}
