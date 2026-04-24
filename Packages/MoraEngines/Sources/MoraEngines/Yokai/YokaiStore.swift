import Foundation
import MoraCore

public protocol YokaiStore: Sendable {
    /// All yokai defined in the bundled catalog.
    func catalog() -> [YokaiDefinition]

    /// Resource URL for the yokai's portrait PNG. Returns `nil` if the asset
    /// is not yet bundled (placeholder phase R2).
    func portraitURL(for id: String) -> URL?

    /// Resource URL for a yokai voice clip. Returns `nil` if the asset is
    /// not yet bundled.
    func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL?
}
