import SwiftUI

struct ResultsView: View {
    @State private var results: [BenchResult] = []
    @State private var shareURL: URL?

    var body: some View {
        List {
            ForEach(results) { r in
                VStack(alignment: .leading) {
                    Text("\(r.modelID) — \(r.promptID)").font(.headline)
                    Text(r.startedAt.formatted()).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(String(format: "TTFT %.3fs", r.ttftSeconds))
                        Text(String(format: "dec %.1f tok/s", r.decodeTokensPerSecond))
                        Text(String(format: "RSS %.1f GB", Double(r.peakRSSBytes) / 1e9))
                    }
                    .monospaced()
                    .font(.caption)
                }
            }
        }
        .navigationTitle("Results")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Export") {
                    shareURL = ResultStore.shared.exportURL()
                }
                .disabled(results.isEmpty)
            }
        }
        .onAppear { results = ResultStore.shared.loadAll() }
        .sheet(item: $shareURL) { url in
            ShareSheet(url: url)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
