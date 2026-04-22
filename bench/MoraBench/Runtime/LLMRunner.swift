// MLX smoke test runner: loads SmolLM-135M via mlx-swift-lm
// and runs a one-shot generation. The UI binds to `status`.
//
// The `mlx-swift-lm` package (split out of `mlx-swift-examples`)
// requires callers to inject a `Downloader` and `TokenizerLoader`.
// The `MLXHuggingFace` product provides freestanding macros
// (`#hubDownloader()` and `#huggingFaceTokenizerLoader()`) that
// supply Hugging Face Hub-backed defaults.

import Foundation
import HuggingFace
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers

@MainActor
final class LLMRunner: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading(String)
        case ready(String)
        case generating
        case done(String)
        case error(String)
    }

    @Published private(set) var loadedModel: BenchModel?
    @Published private(set) var status: Status = .idle

    private var container: ModelContainer?

    func load(_ model: BenchModel) async {
        status = .loading(model.displayName)
        do {
            let config = ModelConfiguration(id: model.huggingFaceRepo)
            let container = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(),
                using: #huggingFaceTokenizerLoader(),
                configuration: config
            ) { progress in
                Task { @MainActor [weak self] in
                    let pct = Int(progress.fractionCompleted * 100)
                    self?.status = .loading("\(model.displayName) \(pct)%")
                }
            }
            self.container = container
            self.loadedModel = model
            status = .ready(model.displayName)
        } catch {
            status = .error("load failed: \(error.localizedDescription)")
        }
    }

    func generateOneShot(prompt: String) async {
        guard let container else {
            status = .error("no model loaded")
            return
        }
        status = .generating
        do {
            let result = try await container.perform { context in
                let input = try await context.processor.prepare(
                    input: UserInput(prompt: prompt)
                )
                let parameters = GenerateParameters(maxTokens: 32, temperature: 0.4)
                var output = ""
                let stream = try MLXLMCommon.generate(
                    input: input,
                    parameters: parameters,
                    context: context
                )
                for await event in stream {
                    if case let .chunk(text) = event {
                        output += text
                    }
                }
                return output
            }
            status = .done(result)
        } catch {
            status = .error("generate failed: \(error.localizedDescription)")
        }
    }
}
