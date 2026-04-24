import MoraFixtures
import SwiftUI

@main
struct MoraFixtureRecorderApp: App {

    @State private var store = RecorderStore()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CatalogListView(store: store)
            }
        }
    }
}
