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
    public private(set) var lastCorrectTrialID: UUID?

    private let store: YokaiStore
    private let modelContext: ModelContext
    private let calendar: Calendar
    private var dayGainSoFar: Double = 0
    private let progressionSource: YokaiProgressionSource?
    private var isFridaySession: Bool = false

    public init(
        store: YokaiStore,
        modelContext: ModelContext,
        calendar: Calendar = .current,
        progressionSource: YokaiProgressionSource? = nil
    ) {
        self.store = store
        self.modelContext = modelContext
        self.calendar = calendar
        self.progressionSource = progressionSource
    }

    public func dismissCutscene() { activeCutscene = nil }

    public func startWeek(yokaiID: String, weekStart: Date) throws {
        guard let yokai = store.catalog().first(where: { $0.id == yokaiID }) else {
            throw YokaiOrchestratorError.unknownYokai(yokaiID)
        }
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

    /// Re-attach the orchestrator to an existing encounter without creating
    /// a new one. Used by bootstrap after the first session of a week has
    /// already happened (`sessionCompletionCount >= 1`). Preserves the stored
    /// friendship percent, session count, and all other encounter fields;
    /// clears transient per-day state.
    public func resume(encounter: YokaiEncounterEntity) {
        currentEncounter = encounter
        currentYokai = store.catalog().first(where: { $0.id == encounter.yokaiID })
        activeCutscene = nil
        dayGainSoFar = 0
    }

    public func recordTrialOutcome(correct: Bool) {
        if isFridaySession {
            applyFridayTrial(correct: correct)
            return
        }
        guard let encounter = currentEncounter else { return }
        let result = FriendshipMeterMath.applyTrialOutcome(
            percent: encounter.friendshipPercent,
            correct: correct,
            dayGainSoFar: dayGainSoFar
        )
        encounter.friendshipPercent = result.percent
        dayGainSoFar = result.dayGain
        if correct {
            encounter.correctReadCount += 1
            lastCorrectTrialID = UUID()
        }
        try? modelContext.save()
    }

    /// Per-trial Friday math: distributes the remaining 1.0-friendship
    /// deficit across `fridayTrialsRemaining` so every trial contributes
    /// to the ramp rather than the first correct trial alone concentrating
    /// the full deficit. Finalizes (befriend or carryover) when every
    /// planned trial has been consumed, OR when the meter reaches 100%
    /// ahead of schedule — whichever comes first. The explicit final-trial
    /// concentration behavior still lives on `recordFridayFinalTrial` for
    /// callers that want it.
    private func applyFridayTrial(correct: Bool) {
        guard let encounter = currentEncounter else { return }
        // Clamp to 1 so a caller who starts Friday mode with 0 planned
        // trials still produces a sane boost instead of dividing by zero.
        let remaining = max(1, fridayTrialsRemaining)
        if correct {
            let boost = FriendshipMeterMath.floorBoostWeight(
                currentPercent: encounter.friendshipPercent,
                trialsRemaining: remaining
            )
            let effectiveGain = max(FriendshipMeterMath.correctTrialGain, boost)
            encounter.friendshipPercent = min(1.0, encounter.friendshipPercent + effectiveGain)
            encounter.correctReadCount += 1
            lastCorrectTrialID = UUID()
        }
        fridayTrialsRemaining = max(0, fridayTrialsRemaining - 1)
        try? modelContext.save()

        if fridayTrialsRemaining == 0 || encounter.friendshipPercent >= 1.0 - 1e-9 {
            finalizeFridayIfNeeded()
        }
    }

    public func beginDay() {
        dayGainSoFar = 0
        isFridaySession = false
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
        try? modelContext.save()
    }

    private var fridayTrialsRemaining: Int = 0

    public func beginFridaySession(trialsPlanned: Int) {
        beginDay()
        fridayTrialsRemaining = trialsPlanned
        isFridaySession = true
    }

    public func recordFridayFinalTrial(correct: Bool) {
        guard let encounter = currentEncounter else { return }
        if correct {
            // This is the final trial: boost is computed with trialsRemaining=1 so the
            // full deficit is concentrated into this one shot, guaranteeing a befriending
            // opportunity when the learner answers correctly.
            let boost = FriendshipMeterMath.floorBoostWeight(
                currentPercent: encounter.friendshipPercent,
                trialsRemaining: 1
            )
            let effectiveGain = max(FriendshipMeterMath.correctTrialGain, boost)
            encounter.friendshipPercent = min(1.0, encounter.friendshipPercent + effectiveGain)
            encounter.correctReadCount += 1
            lastCorrectTrialID = UUID()
        }
        fridayTrialsRemaining = max(0, fridayTrialsRemaining - 1)
        finalizeFridayIfNeeded()
    }

    public func maybeTriggerCameo(grapheme: String, sessionID: UUID, pronunciationSuccess: Bool) {
        let descriptor = FetchDescriptor<BestiaryEntryEntity>()
        guard let entries = try? modelContext.fetch(descriptor) else { return }
        guard
            let befriended = entries.first(where: { entry in
                store.catalog().first(where: { $0.id == entry.yokaiID })?.grapheme == grapheme
            })
        else { return }
        let cameo = YokaiCameoEntity(
            yokaiID: befriended.yokaiID,
            sessionID: sessionID,
            triggeredAt: Date(),
            pronunciationSuccess: pronunciationSuccess
        )
        modelContext.insert(cameo)
        try? modelContext.save()
        activeCutscene = .srsCameo(yokaiID: befriended.yokaiID)
    }

    private func finalizeFridayIfNeeded() {
        guard let encounter = currentEncounter, let yokai = currentYokai else { return }
        if encounter.friendshipPercent >= 1.0 - 1e-9 {
            encounter.state = .befriended
            let when = Date()
            encounter.befriendedAt = when
            let entry = BestiaryEntryEntity(yokaiID: yokai.id, befriendedAt: when)
            modelContext.insert(entry)

            if let nextID = progressionSource?.nextYokaiID(after: yokai.id) {
                let next = YokaiEncounterEntity(
                    yokaiID: nextID,
                    weekStart: when,
                    state: .active,
                    friendshipPercent: 0
                )
                modelContext.insert(next)
            }

            try? modelContext.save()
            activeCutscene = .fridayClimax(yokaiID: yokai.id)
            isFridaySession = false
        } else {
            encounter.state = .carryover
            encounter.storedRolloverFlag = true
            try? modelContext.save()
            isFridaySession = false
        }
    }
}
