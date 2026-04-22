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
                VStack(spacing: 8) {
                    NavigationLink("Run single", value: RunDestination.single(model))
                        .buttonStyle(.borderedProminent)
                    NavigationLink("Run 20-min endurance", value: RunDestination.endurance(model))
                        .buttonStyle(.bordered)
                }
            } else {
                Button("Load") { Task { await runner.load(model) } }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationDestination(for: RunDestination.self) { dest in
            switch dest {
            case .single(let m): SingleRunView(model: m)
            case .endurance(let m): EnduranceRunView(model: m)
            }
        }
    }

    enum RunDestination: Hashable {
        case single(BenchModel)
        case endurance(BenchModel)
    }

    private var statusLabel: String {
        if case let .loading(label) = runner.status { return label }
        return "Idle"
    }
}
