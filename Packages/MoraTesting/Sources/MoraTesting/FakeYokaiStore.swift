import Foundation
import MoraCore
import MoraEngines

public final class FakeYokaiStore: YokaiStore, @unchecked Sendable {
    public var definitions: [YokaiDefinition]
    public var portraitURLs: [String: URL] = [:]
    public var clipURLs: [String: [YokaiClipKey: URL]] = [:]

    public init(definitions: [YokaiDefinition] = YokaiFixtures.smallCatalog) {
        self.definitions = definitions
    }

    public func catalog() -> [YokaiDefinition] { definitions }

    public func portraitURL(for id: String) -> URL? { portraitURLs[id] }

    public func voiceClipURL(for id: String, clip: YokaiClipKey) -> URL? {
        clipURLs[id]?[clip]
    }
}
