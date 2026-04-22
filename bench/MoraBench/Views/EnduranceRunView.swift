import SwiftUI

struct EnduranceRunView: View {
    @EnvironmentObject private var runner: LLMRunner
    let model: BenchModel
    @State private var selectedPrompt: BenchPrompt = PromptLibrary.all[0]
    @State private var minutes: Double = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.displayName).font(.headline)
            Picker("Prompt", selection: $selectedPrompt) {
                ForEach(PromptLibrary.all) { p in Text(p.displayName).tag(p) }
            }
            Stepper(value: $minutes, in: 1...60, step: 1) {
                Text("Duration: \(Int(minutes)) min")
            }
            Button("Start") {
                Task {
                    await runner.runEndurance(
                        prompt: selectedPrompt,
                        durationSeconds: minutes * 60
                    )
                }
            }
            .buttonStyle(.borderedProminent)

            ProgressView(value: runner.enduranceElapsedSeconds, total: minutes * 60)
            Text("Runs complete: \(runner.enduranceResults.count)").monospaced()

            if let s = runner.enduranceSummary() {
                summaryBox(s)
            }

            if let prev = JetsamMarker.detectPreviousKill() {
                Text("⚠︎ Previous run was killed at \(prev.startedAt.formatted()) — likely jetsam")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
        .navigationTitle("Endurance")
    }

    @ViewBuilder
    private func summaryBox(_ s: LLMRunner.EnduranceSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Runs: \(s.runCount)")
            Text(String(format: "p50 turn: %.3f s", s.p50TurnLatency))
            Text(String(format: "p95 turn: %.3f s", s.p95TurnLatency))
            Text(String(format: "First 5min decode: %.1f tok/s", s.firstWindowDecodeMean))
            Text(String(format: "Last 5min decode: %.1f tok/s", s.lastWindowDecodeMean))
            Text(String(format: "Decode drift: %+.1f%%", s.decodeDriftPercent))
                .foregroundStyle(abs(s.decodeDriftPercent) > 15 ? .red : .primary)
        }
        .monospaced()
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
}
