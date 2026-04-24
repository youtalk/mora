import Foundation

/// Anchor class whose module-resolution lets consumers locate the MoraCore
/// resource bundle from outside the package.
public final class YokaiResourceAnchor {
    public static var bundle: Bundle { .module }
}
