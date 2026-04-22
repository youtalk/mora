// Packages/MoraUI/Sources/MoraUI/Design/MoraStringsEnvironment.swift
import MoraCore
import SwiftUI

/// SwiftUI environment value that yields the current learner's UI strings.
///
/// The default value (JapaneseL1Profile at age 8) is used by previews and
/// test harnesses that do not inject a specific profile. `RootView`
/// overrides this in PR 3 based on the active `LearnerProfile`.
private struct MoraStringsKey: EnvironmentKey {
    static let defaultValue: MoraStrings =
        JapaneseL1Profile().uiStrings(forAgeYears: 8)
}

public extension EnvironmentValues {
    var moraStrings: MoraStrings {
        get { self[MoraStringsKey.self] }
        set { self[MoraStringsKey.self] = newValue }
    }
}
