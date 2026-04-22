import SwiftUI

struct SingleRunView: View {
    @EnvironmentObject private var runner: LLMRunner
    let model: BenchModel
    @State private var selectedPrompt: BenchPrompt = PromptLibrary.all[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.displayName).font(.headline)
            Picker("Prompt", selection: $selectedPrompt) {
                ForEach(PromptLibrary.all) { p in
                    Text("\(p.displayName) — \(p.shapeLabel)").tag(p)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Run once") { Task { await runner.run(prompt: selectedPrompt) } }
                    .buttonStyle(.borderedProminent)
                Text("Live tokens: \(runner.liveTokenCount)")
                    .monospaced()
            }

            if let r = runner.lastResult {
                ResultSummary(result: r)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Single run")
    }
}

private struct ResultSummary: View {
    let result: BenchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Input tokens", value: "\(result.inputTokenCount)")
            row("Output tokens", value: "\(result.outputTokenCount)")
            row("TTFT", value: String(format: "%.3f s", result.ttftSeconds))
            row("Prefill tok/s", value: String(format: "%.1f", result.prefillTokensPerSecond))
            row("Decode tok/s", value: String(format: "%.1f", result.decodeTokensPerSecond))
            row("Total", value: String(format: "%.3f s", result.totalGenerationSeconds))
            row("Peak RSS", value: String(format: "%.2f GB", Double(result.peakRSSBytes) / 1_000_000_000))
            row("Avail mem min", value: String(format: "%.2f GB", Double(result.availableMemoryMinBytes) / 1_000_000_000))
            if let thermal = result.thermalSamples.last {
                row("Thermal end", value: thermal.state)
            }
            Divider()
            Text(result.outputPreview).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospaced()
        }
    }
}
