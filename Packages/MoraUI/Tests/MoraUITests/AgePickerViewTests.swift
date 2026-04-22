// Packages/MoraUI/Tests/MoraUITests/AgePickerViewTests.swift
import SwiftUI
import XCTest
@testable import MoraUI

@MainActor
final class AgePickerViewTests: XCTestCase {
    func test_preselectedAge_enablesContinue() {
        var selection: Int? = 8
        _ = AgePickerView(
            selectedAge: Binding(
                get: { selection }, set: { selection = $0 }
            ),
            onContinue: {}
        )
        XCTAssertEqual(selection, 8)
    }

    func test_nilSelection_rejectsContinue() {
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
