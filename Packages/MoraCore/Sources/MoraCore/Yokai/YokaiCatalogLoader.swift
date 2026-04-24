import Foundation

public struct YokaiCatalogLoader: Sendable {
    private let source: @Sendable () throws -> Data

    public init(source: @escaping @Sendable () throws -> Data) {
        self.source = source
    }

    public static func bundled(bundle: Bundle? = nil) -> YokaiCatalogLoader {
        YokaiCatalogLoader {
            let resourceBundle = bundle ?? .module
            guard let url = resourceBundle.url(forResource: "YokaiCatalog", withExtension: "json") else {
                throw YokaiCatalogError.resourceMissing
            }
            return try Data(contentsOf: url)
        }
    }

    public func load() throws -> [YokaiDefinition] {
        let data = try source()
        return try JSONDecoder().decode([YokaiDefinition].self, from: data)
    }
}

public enum YokaiCatalogError: Error, Equatable {
    case resourceMissing
}
