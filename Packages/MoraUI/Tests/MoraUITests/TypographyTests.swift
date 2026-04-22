import XCTest

@testable import MoraUI

final class TypographyTests: XCTestCase {
    func test_registerBundledFonts_returnsTrue_whenFontIsPresent() {
        XCTAssertTrue(
            MoraFontRegistration.registerBundledFonts(),
            "OpenDyslexic-Regular.otf must be bundled as a package resource and registerable via CoreText"
        )
    }

    func test_registerBundledFonts_isIdempotent() {
        _ = MoraFontRegistration.registerBundledFonts()
        XCTAssertTrue(MoraFontRegistration.registerBundledFonts())
    }
}
