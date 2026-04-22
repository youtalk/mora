import SwiftUI

struct DownloadView: View {
    let model: BenchModel
    @EnvironmentObject private var runner: LLMRunner

    var body: some View {
        VStack(spacing: 16) {
            Text(model.displayName).font(.headline)
            Text(String(format: "Approx %.1f GB download", model.approxSizeGB))
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(statusLabel)
            Button("Load") { Task { await runner.load(model) } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var statusLabel: String {
        if case let .loading(label) = runner.status { return label }
        return "Idle"
    }
}
