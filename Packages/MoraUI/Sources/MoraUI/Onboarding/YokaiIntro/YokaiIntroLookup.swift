// Packages/MoraUI/Sources/MoraUI/Onboarding/YokaiIntro/YokaiIntroLookup.swift
import MoraCore
import MoraEngines

/// Shared helpers for resolving the "active week" yokai across YokaiIntro panels.
///
/// Both `TodaysYokaiPanel` and `ProgressPanel` need to surface the yokai tied to
/// the learner's current target skill (the first entry in
/// `CurriculumEngine.sharedV1.skills`). The lookup walks the bundled catalog and
/// returns the matching `YokaiDefinition`, or `nil` when either the store is
/// unavailable or the catalog has no row for that yokai ID.
enum YokaiIntroLookup {
    static func activeYokai(in store: BundledYokaiStore?) -> YokaiDefinition? {
        guard let store else { return nil }
        let firstYokaiID = CurriculumEngine.sharedV1.skills.first?.yokaiID
        return store.catalog().first { $0.id == firstYokaiID }
    }
}
