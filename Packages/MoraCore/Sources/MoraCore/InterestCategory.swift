import Foundation

public struct InterestCategory: Hashable, Codable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let displayName: String
    public let parentAuthored: Bool

    public init(key: String, displayName: String, parentAuthored: Bool = false) {
        self.key = key
        self.displayName = displayName
        self.parentAuthored = parentAuthored
    }
}
