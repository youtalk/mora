import CoreGraphics
import CoreText
import Foundation
import SwiftUI

public enum MoraFontRegistration {
    /// PostScript name of the bundled OpenDyslexic Regular font.
    /// Verified against the OTF's name table — CoreText resolves to this name.
    public static let postScriptName = "OpenDyslexic-Regular"

    /// Registers the bundled OpenDyslexic-Regular.otf once per process and
    /// caches the outcome. Every `Font.openDyslexic(size:)` call funnels
    /// through here; without the cache, each scroll / body invalidation
    /// re-invoked `CTFontManagerRegisterFontsForURL`, which logs
    /// "GSFont: file already registered" to Console for every repeated call
    /// and floods sysdiagnose during real device runs. Swift's lazy static
    /// gives us a thread-safe dispatch_once semantics without extra code.
    public static let isRegistered: Bool = {
        guard
            let url = Bundle.module.url(
                forResource: "OpenDyslexic-Regular", withExtension: "otf"
            )
        else {
            return false
        }
        var error: Unmanaged<CFError>?
        let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if ok { return true }
        if let err = error?.takeRetainedValue() {
            let domain = CFErrorGetDomain(err) as String
            let code = CFErrorGetCode(err)
            // The font may already be registered by a prior process-owner
            // (e.g. a test harness that loaded it before the app target).
            // Treat that as success so callers get the font.
            if domain == kCTFontManagerErrorDomain as String,
                code == CTFontManagerError.alreadyRegistered.rawValue
            {
                return true
            }
        }
        return false
    }()

    /// Idempotent façade so existing callers keep compiling. Reads the cached
    /// lazy-static; the actual CoreText call only fires the first time.
    @discardableResult
    public static func registerBundledFonts() -> Bool { isRegistered }
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

/// Typography policy
/// -----------------
/// **Every text role uses OpenDyslexic**, including chrome (buttons, pills,
/// headings) and large display roles (hero, decoding word). The earlier
/// design split SF Pro Rounded (chrome) and OpenDyslexic (body reading), but
/// the visual hand-off looked broken to the learner — they'd see the home
/// target in OpenDyslexic, then jump into a session and find buttons,
/// pills, and even worked-example tiles in a different typeface. Unifying
/// on OpenDyslexic keeps every glyph the learner reads consistent.
///
/// Japanese characters are not in OpenDyslexic, so SwiftUI's per-glyph
/// font fallback renders them in the system Japanese font (Hiragino).
/// Latin characters and digits stay in OpenDyslexic.
///
/// Sizes are tuned for iPad — large enough to read across a kitchen table
/// but conservative enough that portrait layout still fits without
/// horizontal clipping. Per-call `size:` overrides exist for the few places
/// (worked-example tiles, NewRule mapping card) that need bigger glyphs.
public enum MoraType {
    /// Display-size numerals / symbols (age picker, completion score).
    public static func hero(_ size: CGFloat = 200) -> Font {
        .openDyslexic(size: size)
    }
    /// Display-size English word / grapheme (home target card).
    public static func heroWord(_ size: CGFloat = 180) -> Font {
        .openDyslexic(size: size)
    }
    public static func heading() -> Font {
        .openDyslexic(size: 44)
    }
    /// Primary call-to-action button label.
    public static func cta() -> Font {
        .openDyslexic(size: 38)
    }
    public static func label() -> Font {
        .openDyslexic(size: 30)
    }
    public static func pill() -> Font {
        .openDyslexic(size: 24)
    }
    /// Long-form English body text, also used for spoken-phrase captions
    /// shown alongside TTS playback so the parent has a written reference.
    public static func bodyReading(size: CGFloat = 36) -> Font {
        .openDyslexic(size: size)
    }
    /// Single word the learner is decoding in the session.
    public static func decodingWord(size: CGFloat = 144) -> Font {
        .openDyslexic(size: size)
    }
    /// Short sentence the learner is decoding.
    public static func sentence(size: CGFloat = 80) -> Font {
        .openDyslexic(size: size)
    }
    /// Displayed ASR transcript (live partial + post-trial record).
    public static func transcript(size: CGFloat = 48) -> Font {
        .openDyslexic(size: size)
    }
}
