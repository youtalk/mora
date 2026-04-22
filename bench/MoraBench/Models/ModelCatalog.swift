import Foundation

enum ModelCatalog {
    static let defaults: [BenchModel] = [
        BenchModel(
            id: "smollm-135m-4bit",
            displayName: "SmolLM 135M Instruct (smoke)",
            huggingFaceRepo: "mlx-community/SmolLM-135M-Instruct-4bit",
            approxSizeBytes: 90_000_000,
            contextLength: 2048,
            isSmokeModel: true
        ),
        BenchModel(
            id: "llama-3.2-3b-4bit",
            displayName: "Llama 3.2 3B Instruct",
            huggingFaceRepo: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            approxSizeBytes: 1_900_000_000,
            contextLength: 8192,
            isSmokeModel: false
        ),
        BenchModel(
            id: "qwen-2.5-3b-4bit",
            displayName: "Qwen 2.5 3B Instruct (closest to spec)",
            huggingFaceRepo: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            approxSizeBytes: 2_000_000_000,
            contextLength: 8192,
            isSmokeModel: false
        ),
        BenchModel(
            id: "phi-3.5-mini-4bit",
            displayName: "Phi 3.5 mini Instruct",
            huggingFaceRepo: "mlx-community/Phi-3.5-mini-instruct-4bit",
            approxSizeBytes: 2_400_000_000,
            contextLength: 128_000,
            isSmokeModel: false
        ),
    ]
}
