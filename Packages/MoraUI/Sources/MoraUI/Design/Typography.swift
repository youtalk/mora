import CoreGraphics
import CoreText
import Foundation
import SwiftUI

public enum MoraFontRegistration {
    /// PostScript name of the bundled OpenDyslexic Regular font.
    /// Verified against the OTF's name table — CoreText resolves to this name.
    public static let postScriptName = "OpenDyslexic-Regular"

    /// Registers the bundled OpenDyslexic-Regular.otf once per process.
    /// Returns `true` when the font is available for use, `false` when the
    /// resource is missing or registration fails with an unexpected error.
    /// Idempotent — returns `true` on subsequent calls when the font is
    /// already registered.
    @discardableResult
    public static func registerBundledFonts() -> Bool {
        guard
            let url = Bundle.module.url(
                forResource: "OpenDyslexic-Regular", withExtension: "otf"
            )
        else {
            return false
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok, let err = error?.takeRetainedValue() {
            let domain = CFErrorGetDomain(err) as String
            let code = CFErrorGetCode(err)
            // kCTFontManagerErrorAlreadyRegistered in kCTFontManagerErrorDomain
            if domain == kCTFontManagerErrorDomain as String,
                code == CTFontManagerError.alreadyRegistered.rawValue
            {
                return true
            }
            return false
        }
        return ok
    }
}

public extension Font {
    /// Returns the OpenDyslexic font at `size`. Falls back to SF Rounded when
    /// font registration fails (e.g. missing resource in test bundles).
    static func openDyslexic(size: CGFloat) -> Font {
        guard MoraFontRegistration.registerBundledFonts() else {
            return .system(size: size, weight: .regular, design: .rounded)
        }
        return Font.custom(MoraFontRegistration.postScriptName, size: size)
    }
}

public enum MoraType {
    /// Hero grapheme / numerals. Uses SF Pro Rounded Heavy via SwiftUI's
    /// system font with `.rounded` design.
    public static func hero(_ size: CGFloat = 180) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    public static func heading() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    /// Primary call-to-action button label (HeroCTA). Spec §6.4: 18pt text.
    public static func cta() -> Font {
        .system(size: 18, weight: .bold, design: .rounded)
    }
    public static func label() -> Font {
        .system(size: 14, weight: .semibold, design: .rounded)
    }
    public static func pill() -> Font {
        .system(size: 12, weight: .semibold, design: .rounded)
    }
    /// Body reading font. v1 uses OpenDyslexic; a future Settings screen will
    /// let the user switch to SF Rounded via `LearnerProfile.preferredFontKey`.
    public static func bodyReading(size: CGFloat = 22) -> Font {
        .openDyslexic(size: size)
    }
    /// Large on-screen word (decoding). Uses SF Rounded so OpenDyslexic's
    /// low x-height does not crush the hero typography.
    public static func decodingWord(size: CGFloat = 96) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    /// Short sentence. Same family as decoding word but lighter weight.
    public static func sentence(size: CGFloat = 52) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}
