import Foundation
import Observation

@Observable
@MainActor
final class DecodingTutorialState {
    enum Step: Equatable, CaseIterable {
        case slot, audio, finished
    }

    var step: Step = .slot

    static let seenKey = "tech.reenable.Mora.decodingTutorialSeen"

    func advance() {
        switch step {
        case .slot: step = .audio
        case .audio: step = .finished
        case .finished: break
        }
    }

    func dismiss(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.seenKey)
    }
}
