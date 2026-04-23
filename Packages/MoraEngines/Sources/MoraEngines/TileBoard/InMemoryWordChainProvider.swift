import Foundation
import MoraCore

/// Test-only provider that returns a fixed phase regardless of inputs. Use
/// from MoraTesting fixtures and unit tests.
public struct InMemoryWordChainProvider: WordChainProvider {
    public let phase: [WordChain]

    public init(phase: [WordChain]) {
        self.phase = phase
    }

    public func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain] {
        guard phase.count == 3 else {
            throw WordChainProviderError(
                "InMemoryWordChainProvider requires exactly 3 chains, has \(phase.count)")
        }
        return phase
    }
}
