import Foundation
import Observation

@Observable
@MainActor
final class YokaiIntroState {
    enum Step: Equatable, CaseIterable {
        case concept, todayYokai, sessionShape, progress, finished
    }

    var step: Step = .concept

    static let onboardedKey = "tech.reenable.Mora.yokaiIntroSeen"

    func advance() {
        switch step {
        case .concept: step = .todayYokai
        case .todayYokai: step = .sessionShape
        case .sessionShape: step = .progress
        case .progress: step = .finished
        case .finished: break
        }
    }

    func finalize(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: Self.onboardedKey)
    }
}
