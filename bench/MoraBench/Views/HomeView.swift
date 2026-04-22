import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var runner: LLMRunner
    @State private var selection: BenchModel?
    @State private var showResults = false

    var body: some View {
        NavigationSplitView {
            List(ModelCatalog.defaults, selection: $selection) { model in
                VStack(alignment: .leading) {
                    Text(model.displayName)
                    Text(String(format: "%.1f GB • ctx %d", model.approxSizeGB, model.contextLength))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(model)
            }
            .navigationTitle("Mora Bench")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Results") { showResults = true }
                }
            }
        } detail: {
            NavigationStack {
                if let selection {
                    DownloadView(model: selection)
                } else {
                    Text("Pick a model")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showResults) {
            NavigationStack { ResultsView() }
        }
    }
}
