import Foundation

struct BenchPrompt: Identifiable, Hashable {
    let id: String
    let displayName: String
    let systemPrompt: String
    let userPrompt: String
    let expectedApproxOutputTokens: Int
    let shapeLabel: String        // e.g., "~200 in / ~30 out"
}
