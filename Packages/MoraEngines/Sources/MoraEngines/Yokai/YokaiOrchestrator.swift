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
    private var dayGainSoFar: Double = 0

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

    public func startWeek(yokaiID: String, weekStart: Date) throws {
        guard let yokai = store.catalog().first(where: { $0.id == yokaiID }) else { return }
        currentYokai = yokai
        let encounter = YokaiEncounterEntity(
            yokaiID: yokaiID,
            weekStart: weekStart,
            state: .active,
            friendshipPercent: 0.10
        )
        modelContext.insert(encounter)
        try modelContext.save()
        currentEncounter = encounter
        activeCutscene = .mondayIntro(yokaiID: yokaiID)
        dayGainSoFar = 0
    }

    public func recordTrialOutcome(correct: Bool) {
        guard let encounter = currentEncounter else { return }
        let result = FriendshipMeterMath.applyTrialOutcome(
            percent: encounter.friendshipPercent,
            correct: correct,
            dayGainSoFar: dayGainSoFar
        )
        encounter.friendshipPercent = result.percent
        dayGainSoFar = result.dayGain
        if correct { encounter.correctReadCount += 1 }
    }

    public func beginDay() {
        dayGainSoFar = 0
    }

    public func recordSessionCompletion() {
        guard let encounter = currentEncounter else { return }
        let result = FriendshipMeterMath.applySessionCompletion(
            percent: encounter.friendshipPercent,
            dayGainSoFar: dayGainSoFar
        )
        encounter.friendshipPercent = result.percent
        dayGainSoFar = result.dayGain
        encounter.sessionCompletionCount += 1
    }
}
