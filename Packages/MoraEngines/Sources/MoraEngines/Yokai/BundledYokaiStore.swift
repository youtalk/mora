import Foundation
import MoraCore

public final class BundledYokaiStore: YokaiStore {
    private let definitions: [YokaiDefinition]
    private let resourceBundle: Bundle

    public init(loader: YokaiCatalogLoader? = nil, resourceBundle: Bundle? = nil) throws {
        let actualBundle = resourceBundle ?? YokaiResourceAnchor.bundle
        self.resourceBundle = actualBundle
        let actualLoader = loader ?? YokaiCatalogLoader.bundled(bundle: actualBundle)
        self.definitions = try actualLoader.load()
    }

    public func catalog() -> [YokaiDefinition] { definitions }

    public func portraitURL(for id: String) -> URL? {
        if let url = resourceBundle.url(forResource: "portrait", withExtension: "png", subdirectory: "Yokai/\(id)") {
            return url
        }
        return resourceBundle.url(forResource: "portrait", withExtension: "png", subdirectory: "_placeholder")
    }

    public func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL? {
        resourceBundle.url(forResource: clip.rawValue, withExtension: "m4a", subdirectory: "Yokai/\(id)/voice")
    }
}
