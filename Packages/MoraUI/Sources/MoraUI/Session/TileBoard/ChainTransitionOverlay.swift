import MoraCore
import SwiftUI

public struct ChainTransitionOverlay: View {
    public let incomingRole: ChainRole
    public var reduceMotion: Bool = false

    public init(incomingRole: ChainRole, reduceMotion: Bool = false) {
        self.incomingRole = incomingRole
        self.reduceMotion = reduceMotion
    }

    public var body: some View {
        LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
            .opacity(0.9)
            .scaleEffect(reduceMotion ? 1 : 1.02)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: incomingRole)
            .transition(.opacity)
    }

    private var gradient: [Color] {
        switch incomingRole {
        case .warmup:
            return [Color(red: 0.91, green: 0.95, blue: 1.0), Color(red: 0.93, green: 0.92, blue: 1.0)]
        case .targetIntro:
            return [Color(red: 1.0, green: 0.97, blue: 0.85), Color(red: 1.0, green: 0.92, blue: 0.85)]
        case .mixedApplication:
            return [Color(red: 1.0, green: 0.92, blue: 0.85), Color(red: 1.0, green: 0.82, blue: 0.80)]
        }
    }
}
