import SwiftUI

public struct RootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "session":
                        SessionContainerView()
                    default:
                        EmptyView()
                    }
                }
        }
    }
}
