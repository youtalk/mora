// Packages/MoraEngines/Sources/MoraEngines/WeekRotation.swift
import Foundation
import MoraCore
import SwiftData

/// Helper that decides which skill a learner should be working on, using
/// `YokaiEncounterEntity` as the authoritative source of rotation state and
/// `BestiaryEntryEntity` to avoid re-offering befriended yokai.
///
/// `resolve` reads from the supplied `ModelContext` and, when no open
/// encounter matches a ladder skill, inserts and saves a new `.active`
/// encounter for the next unresolved skill (or deletes an orphaned open
/// encounter whose `yokaiID` no longer maps to any ladder skill, to avoid
/// leaving multiple active rows in the store).
///
/// Returns `nil` when every skill in the ladder has a bestiary entry —
/// i.e. the v1 alpha's curriculum is complete and no next session makes
/// sense.
public enum WeekRotation {
    public struct Resolution: Sendable {
        public let skill: Skill
        public let encounter: YokaiEncounterEntity
        public let isNewEncounter: Bool
    }

    @MainActor
    public static func resolve(
        context: ModelContext,
        ladder: CurriculumEngine,
        clock: () -> Date = Date.init
    ) throws -> Resolution? {
        // Hoist raw values out of the #Predicate macro — it cannot form key
        // paths into enum cases (e.g. `\.active`), so reading them inline
        // fails to compile. Capturing string constants works.
        let activeRaw = YokaiEncounterState.active.rawValue
        let carryoverRaw = YokaiEncounterState.carryover.rawValue
        var activeDescriptor = FetchDescriptor<YokaiEncounterEntity>(
            predicate: #Predicate {
                $0.stateRaw == activeRaw || $0.stateRaw == carryoverRaw
            },
            sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
        )
        activeDescriptor.fetchLimit = 1
        if let open = try context.fetch(activeDescriptor).first {
            if let skill = ladder.skills.first(where: { $0.yokaiID == open.yokaiID }) {
                return Resolution(skill: skill, encounter: open, isNewEncounter: false)
            }
            // Orphaned: open encounter whose yokaiID doesn't map to any
            // current ladder skill (ladder shrunk, id typo, stale seed).
            // Delete so we don't leave it active alongside the fresh one we're
            // about to insert below.
            context.delete(open)
        }

        let bestiary = try context.fetch(FetchDescriptor<BestiaryEntryEntity>())
        let befriended = Set(bestiary.map(\.yokaiID))
        guard
            let nextSkill = ladder.skills.first(where: {
                guard let yid = $0.yokaiID else { return false }
                return !befriended.contains(yid)
            })
        else {
            return nil
        }

        guard let yokaiID = nextSkill.yokaiID else { return nil }
        let encounter = YokaiEncounterEntity(
            yokaiID: yokaiID,
            weekStart: clock(),
            state: .active,
            friendshipPercent: 0
        )
        context.insert(encounter)
        try context.save()
        return Resolution(skill: nextSkill, encounter: encounter, isNewEncounter: true)
    }
}
