import Foundation
import MoraCore
import MoraEngines
import SwiftData
import SwiftUI

/// Closure that, given a `ModelContainer`, returns the `PronunciationEvaluator`
/// to install in `AssessmentEngine`. Default produces bare Engine A. The app
/// target overrides this with a composite that wraps Engine A in shadow mode
/// when MoraMLX's model loads successfully.
public struct ShadowEvaluatorFactory: Sendable {
    public let make: @Sendable (_ container: ModelContainer) -> any PronunciationEvaluator

    public init(
        make: @Sendable @escaping (_ container: ModelContainer) -> any PronunciationEvaluator
    ) {
        self.make = make
    }

    public static let bareEngineA = ShadowEvaluatorFactory { _ in
        FeatureBasedPronunciationEvaluator()
    }
}

private struct ShadowEvaluatorFactoryKey: EnvironmentKey {
    static let defaultValue: ShadowEvaluatorFactory = .bareEngineA
}

extension EnvironmentValues {
    public var shadowEvaluatorFactory: ShadowEvaluatorFactory {
        get { self[ShadowEvaluatorFactoryKey.self] }
        set { self[ShadowEvaluatorFactoryKey.self] = newValue }
    }
}
