import Foundation
import MoraCore
import Observation
import SwiftData

@Observable
@MainActor
public final class YokaiOrchestrator {
    public private(set) var currentEncounter: YokaiEncounterEntity?
    public private(set) var currentYokai: YokaiDefinition?
    public private(set) var activeCutscene: YokaiCutscene?

    private let store: YokaiStore
    private let modelContext: ModelContext
    private let calendar: Calendar

    public init(
        store: YokaiStore,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) {
        self.store = store
        self.modelContext = modelContext
        self.calendar = calendar
    }

    public func dismissCutscene() { activeCutscene = nil }
}
