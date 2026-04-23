import Foundation
import MoraCore

public struct WordChainProviderError: Error, Hashable, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
}

public protocol WordChainProvider: Sendable {
    func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain]
}
