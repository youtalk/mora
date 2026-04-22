// Packages/MoraUI/Tests/MoraUITests/AgePickerViewTests.swift
import SwiftUI
import XCTest

@testable import MoraUI

/// SwiftUI view tree introspection is out of scope for the alpha test
/// harness (see spec §11.4). These tests confirm the view type is
/// constructable with the bindings it advertises and that the binding is
/// passed through untouched — the real flow-level behavior is exercised
/// in `LanguageAgeFlowTests`.
@MainActor
final class AgePickerViewTests: XCTestCase {
    func test_bindingPassesThroughWhenPreselected() {
        var selection: Int? = 8
        _ = AgePickerView(
            selectedAge: Binding(
                get: { selection }, set: { selection = $0 }
            ),
            onContinue: {}
        )
        XCTAssertEqual(selection, 8)
    }

    func test_bindingPassesThroughWhenNil() {
        var selection: Int? = nil
        _ = AgePickerView(
            selectedAge: Binding(
                get: { selection }, set: { selection = $0 }
            ),
            onContinue: {}
        )
        XCTAssertNil(selection)
    }
}
