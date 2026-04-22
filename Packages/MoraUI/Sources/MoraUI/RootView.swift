import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

public struct RootView: View {
    @Environment(\.modelContext) private var context

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("mora")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                Text("Today's quest: sh")
                    .font(.title2)
                NavigationLink(value: "session") {
                    Text("Start today's session")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 260, minHeight: 64)
                        .background(.tint, in: .capsule)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.98, green: 0.96, blue: 0.90))  // warm off-white
            .navigationDestination(for: String.self) { _ in
                SessionContainerView()
            }
        }
    }
}
