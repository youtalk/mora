import MoraCore
import MoraUI
import OSLog
import SwiftData
import SwiftUI

@main
struct MoraApp: App {
    let container: ModelContainer

    init() {
        self.container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }

    /// Try the on-disk store first; if it can't be opened (corrupt store,
    /// migration failure, disk full…) fall back to an in-memory container so
    /// the app still launches and the user can recover. The fallback is
    /// logged so the failure is visible in Console / sysdiagnose rather than
    /// silently swallowed by `try?`. A future Parent Mode will surface this
    /// state in the UI; for v1, "session log not persisted" is preferable
    /// to "app won't start".
    private static func makeContainer() -> ModelContainer {
        let log = Logger(subsystem: "tech.reenable.Mora", category: "ModelContainer")
        do {
            let c = try MoraModelContainer.onDisk()
            try MoraModelContainer.seedIfEmpty(c.mainContext)
            return c
        } catch {
            log.error("Falling back to in-memory store after on-disk init failed: \(error)")
            do {
                let c = try MoraModelContainer.inMemory()
                try MoraModelContainer.seedIfEmpty(c.mainContext)
                return c
            } catch {
                // In-memory init failing means the schema itself is broken;
                // there is nothing we can do at runtime to recover.
                fatalError("ModelContainer in-memory fallback also failed: \(error)")
            }
        }
    }
}
