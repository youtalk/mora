import MoraCore
import MoraUI
import SwiftData
import SwiftUI

@main
struct MoraApp: App {
    let container: ModelContainer

    init() {
        do {
            let c = try MoraModelContainer.onDisk()
            try MoraModelContainer.seedIfEmpty(c.mainContext)
            self.container = c
        } catch {
            fatalError("Failed to init ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
