import SwiftUI
import XCTest
@testable import MoraUI

final class MoraThemeTests: XCTestCase {
    func test_pageBackground_isWarmOffWhite() {
        // Frozen token values; if these change, the visual review in the PR
        // description must be updated.
        XCTAssertEqual(MoraTheme.Background.pageHex, 0xFFFBF5)
        XCTAssertEqual(MoraTheme.Accent.orangeHex, 0xFF7A00)
        XCTAssertEqual(MoraTheme.Accent.orangeShadowHex, 0xC85800)
        XCTAssertEqual(MoraTheme.Accent.tealHex, 0x00A896)
        XCTAssertEqual(MoraTheme.Ink.primaryHex, 0x2A1E13)
    }

    func test_spacingScale_isPowerOfTwoish() {
        XCTAssertEqual(MoraTheme.Space.xs, 4)
        XCTAssertEqual(MoraTheme.Space.sm, 8)
        XCTAssertEqual(MoraTheme.Space.md, 16)
        XCTAssertEqual(MoraTheme.Space.lg, 24)
        XCTAssertEqual(MoraTheme.Space.xl, 32)
        XCTAssertEqual(MoraTheme.Space.xxl, 48)
    }

    func test_radiusCapsuleIsLarge() {
        XCTAssertEqual(MoraTheme.Radius.button, 999)
        XCTAssertEqual(MoraTheme.Radius.chip, 999)
        XCTAssertEqual(MoraTheme.Radius.card, 22)
        XCTAssertEqual(MoraTheme.Radius.tile, 14)
    }
}
