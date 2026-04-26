// Packages/MoraUI/Sources/MoraUI/Design/MoraStringsEnvironment.swift
import MoraCore
import SwiftUI

private struct MoraStringsKey: EnvironmentKey {
    static let defaultValue: MoraStrings = MoraStrings.previewDefault
}

public extension EnvironmentValues {
    var moraStrings: MoraStrings {
        get { self[MoraStringsKey.self] }
        set { self[MoraStringsKey.self] = newValue }
    }
}

private struct CurrentL1ProfileKey: EnvironmentKey {
    static let defaultValue: any L1Profile = JapaneseL1Profile()
}

public extension EnvironmentValues {
    var currentL1Profile: any L1Profile {
        get { self[CurrentL1ProfileKey.self] }
        set { self[CurrentL1ProfileKey.self] = newValue }
    }
}
