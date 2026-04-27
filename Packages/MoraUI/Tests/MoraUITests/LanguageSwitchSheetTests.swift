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
        sheet.select(identifier: "ko")
        sheet.confirm()
        XCTAssertEqual(committed, "ko")
    }

    func test_onCancel_called_whenCancelTapped() {
        var cancelled = false
        let sheet = LanguageSwitchSheet(
            currentIdentifier: "ja",
            onCommit: { _ in },
            onCancel: { cancelled = true }
        )
        sheet.cancel()
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
        sheet.select(identifier: "en")
        XCTAssertEqual(sheet.pickedID, "en")
        XCTAssertFalse(sheet.isConfirmDisabled)
    }
}
