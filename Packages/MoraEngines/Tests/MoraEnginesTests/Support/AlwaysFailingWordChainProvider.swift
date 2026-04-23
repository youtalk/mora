import Foundation
import MoraCore
@testable import MoraEngines

/// Test-only `WordChainProvider` that always throws, simulating a content gap.
/// Used to verify the orchestrator skips decoding gracefully when no chains
/// are available.
struct AlwaysFailingWordChainProvider: WordChainProvider {
    func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain] {
        throw WordChainProviderError("No chains available (test stub)")
    }
}
