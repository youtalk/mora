import SwiftUI

struct ResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var results: [BenchResult] = []
    @State private var shareTarget: ShareTarget?

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
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Export") {
                    if let url = ResultStore.shared.exportURL() {
                        shareTarget = ShareTarget(url: url)
                    }
                }
                .disabled(results.isEmpty)
            }
        }
        .onAppear { results = ResultStore.shared.loadAll() }
        .sheet(item: $shareTarget) { target in
            ShareSheet(url: target.url)
        }
    }
}

private struct ShareTarget: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
