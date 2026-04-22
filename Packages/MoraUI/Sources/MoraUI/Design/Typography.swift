import CoreGraphics
import CoreText
import Foundation
import SwiftUI

public enum MoraFontRegistration {
    /// Registered once per process. Returns true if OpenDyslexic Regular is
    /// available as a UIFont after the call, false otherwise (the caller should
    /// fall back to SF Rounded in that case). Idempotent — second call is a
    /// no-op if the font is already registered.
    @discardableResult
    public static func registerBundledFonts() -> Bool {
        guard let url = Bundle.module.url(
            forResource: "OpenDyslexic-Regular", withExtension: "otf"
        ) else {
            return false
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !ok, let err = error?.takeRetainedValue() {
            let nsErr = err as Error as NSError
            // kCTFontManagerErrorAlreadyRegistered == 105
            if nsErr.code == 105 { return true }
            return false
        }
        return ok
    }
}

public extension Font {
    static func openDyslexic(size: CGFloat) -> Font {
        MoraFontRegistration.registerBundledFonts()
        return Font.custom("OpenDyslexic", size: size)
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
