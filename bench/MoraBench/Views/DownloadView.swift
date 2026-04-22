import SwiftUI

struct DownloadView: View {
    let model: BenchModel
    @EnvironmentObject private var runner: LLMRunner

    var body: some View {
        VStack(spacing: 16) {
            Text(model.displayName).font(.headline)
            Text(String(format: "Approx %.1f GB download", model.approxSizeGB))
                .font(.caption).foregroundStyle(.secondary)

            ProgressView(statusLabel)

            if case .ready = runner.status, runner.loadedModel?.id == model.id {
                NavigationLink("Run benchmark", value: RunDestination.single(model))
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Load") { Task { await runner.load(model) } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationDestination(for: RunDestination.self) { dest in
            switch dest {
            case .single(let m): SingleRunView(model: m)
            }
        }
    }

    enum RunDestination: Hashable {
        case single(BenchModel)
    }

    private var statusLabel: String {
        if case let .loading(label) = runner.status { return label }
        return "Idle"
    }
}
