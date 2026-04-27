import XCTest
import MoraCore
@testable import MoraUI

@MainActor
final class HomeViewLanguageSwitchTests: XCTestCase {
    func test_globe_a11yLabel_matchesMoraStrings() {
        let strings = JapaneseL1Profile().uiStrings(at: .advanced)
        XCTAssertEqual(strings.homeChangeLanguageButton, "ことばを かえる")
    }

    // Full SwiftUI render harness for sheet presentation is out of scope;
    // the sheet's behavior is covered by LanguageSwitchSheetTests.
}
