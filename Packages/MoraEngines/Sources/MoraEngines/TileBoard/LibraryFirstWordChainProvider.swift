import Foundation
import MoraCore

public struct LibraryFirstWordChainProvider: WordChainProvider {
    private struct LibraryFile: Decodable {
        struct WordLit: Decodable {
            let surface: String
            let graphemes: [String]
            func toWord() -> Word {
                Word(
                    surface: surface,
                    graphemes: graphemes.map { Grapheme(letters: $0) },
                    phonemes: []
                )
            }
        }
        struct ChainLit: Decodable {
            let head: WordLit
            let successors: [WordLit]
        }
        let target: String
        let warmup: [ChainLit]
        let targetIntro: [ChainLit]
        let mixedApplication: [ChainLit]
    }

    private let bundle: Bundle

    public init() {
        self.bundle = .module
    }

    internal init(bundle: Bundle) {
        self.bundle = bundle
    }

    public func generatePhase(target: Grapheme, masteredSet: Set<Grapheme>) throws -> [WordChain] {
        guard
            let url = bundle.url(forResource: target.letters, withExtension: "json")
        else {
            throw WordChainProviderError(
                "No chain library bundled for target '\(target.letters)'")
        }
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(LibraryFile.self, from: data)
        let inventory = masteredSet.union([target])
        let warmup = try pickChain(file.warmup, role: .warmup, inventory: inventory, target: target)
        let intro = try pickChain(
            file.targetIntro, role: .targetIntro, inventory: inventory, target: target)
        let mixed = try pickChain(
            file.mixedApplication, role: .mixedApplication, inventory: inventory, target: target)
        return [warmup, intro, mixed]
    }

    private func pickChain(
        _ candidates: [LibraryFile.ChainLit], role: ChainRole, inventory: Set<Grapheme>,
        target: Grapheme
    ) throws -> WordChain {
        for candidate in candidates {
            let chain = WordChain(
                role: role,
                head: BuildTarget(word: candidate.head.toWord()),
                successorWords: candidate.successors.map { $0.toWord() },
                inventory: inventory
            )
            if let chain { return chain }
        }
        throw WordChainProviderError(
            "No valid \(role.rawValue) chain for target '\(target.letters)' in the library")
    }
}
