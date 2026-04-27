import XCTest
import MoraCore
@testable import MoraUI

@MainActor
final class LanguageSwitchSheetTests: XCTestCase {
    func test_onCommit_calledWithPickedID_whenConfirmTapped() {
        var committed: String?
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { committed = $0 },
            onCancel: {}
        )
        sheet.simulateSelect(identifier: "ko")
        sheet.simulateConfirm()
        XCTAssertEqual(committed, "ko")
    }

    func test_onCancel_called_whenCancelTapped() {
        var cancelled = false
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in },
            onCancel: { cancelled = true }
        )
        sheet.simulateCancel()
        XCTAssertTrue(cancelled)
    }

    func test_confirmDisabled_whenSelectionEqualsCurrent() {
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in XCTFail("should not commit") },
            onCancel: {}
        )
        XCTAssertEqual(sheet.pickedID, "ja")
        XCTAssertTrue(sheet.isConfirmDisabled)
    }

    func test_confirmEnabled_whenSelectionDiffersFromCurrent() {
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in },
            onCancel: {}
        )
        sheet.simulateSelect(identifier: "en")
        XCTAssertEqual(sheet.pickedID, "en")
        XCTAssertFalse(sheet.isConfirmDisabled)
    }
}
