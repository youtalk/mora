import CoreText
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

    /// Verifies that the font can be resolved by the PostScript name used by
    /// SwiftUI's `Font.custom(_:size:)` after registration succeeds.
    func test_fontIsInstantiableByPostScriptName_afterRegistration() throws {
        let registered = MoraFontRegistration.registerBundledFonts()
        try XCTSkipUnless(registered, "Font registration failed — cannot verify instantiation")

        let descriptor = CTFontDescriptorCreateWithNameAndSize(
            MoraFontRegistration.postScriptName as CFString,
            22
        )
        let font = CTFontCreateWithFontDescriptor(descriptor, 22, nil)
        let resolvedName = CTFontCopyPostScriptName(font) as String
        XCTAssertEqual(
            resolvedName,
            MoraFontRegistration.postScriptName,
            "CTFont resolved from '\(MoraFontRegistration.postScriptName)' has unexpected PostScript name '\(resolvedName)'"
        )
    }
}
