// Packages/MoraEngines/Sources/MoraEngines/WeekRotation.swift
import Foundation
import MoraCore
import SwiftData

/// Pure helper that decides which skill a learner should be working on,
/// using `YokaiEncounterEntity` as the authoritative source of rotation
/// state and `BestiaryEntryEntity` to avoid re-offering befriended yokai.
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
        var activeDescriptor = FetchDescriptor<YokaiEncounterEntity>(
            predicate: #Predicate { $0.stateRaw == "active" || $0.stateRaw == "carryover" },
            sortBy: [SortDescriptor(\.weekStart, order: .reverse)]
        )
        activeDescriptor.fetchLimit = 1
        if let open = try context.fetch(activeDescriptor).first,
            let skill = ladder.skills.first(where: { $0.yokaiID == open.yokaiID })
        {
            return Resolution(skill: skill, encounter: open, isNewEncounter: false)
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
