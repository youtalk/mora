import SwiftUI

@main
struct MoraBenchApp: App {
    @StateObject private var runner = LLMRunner()

    var body: some Scene {
        WindowGroup {
            SmokeTestView()
                .environmentObject(runner)
        }
    }
}

struct SmokeTestView: View {
    @EnvironmentObject private var runner: LLMRunner

    var body: some View {
        VStack(spacing: 16) {
            Text("Mora Bench — smoke").font(.title2)
            Text(statusText).monospaced().multilineTextAlignment(.center)
            HStack {
                Button("Load SmolLM") { Task { await runner.loadSmoke() } }
                Button("Generate") {
                    Task {
                        await runner.generateOneShot(
                            prompt: "Write one short decodable sentence using only the letters s-h-i-p: "
                        )
                    }
                }
            }
        }
        .padding()
    }

    private var statusText: String {
        switch runner.status {
        case .idle: return "idle"
        case .loading(let s): return "loading \(s)"
        case .ready(let s): return "ready: \(s)"
        case .generating: return "generating…"
        case .done(let s): return "done: \(s)"
        case .error(let s): return "error: \(s)"
        }
    }
}
