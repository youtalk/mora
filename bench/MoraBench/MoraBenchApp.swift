import SwiftUI

@main
struct MoraBenchApp: App {
    @StateObject private var runner = LLMRunner()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(runner)
        }
    }
}
