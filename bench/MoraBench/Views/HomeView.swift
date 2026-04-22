import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var runner: LLMRunner

    var body: some View {
        NavigationSplitView {
            List(ModelCatalog.defaults) { model in
                NavigationLink(value: model) {
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                        Text(String(format: "%.1f GB • ctx %d", model.approxSizeGB, model.contextLength))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Mora Bench")
        } detail: {
            Text("Pick a model")
        }
        .navigationDestination(for: BenchModel.self) { model in
            DownloadView(model: model)
        }
    }
}
