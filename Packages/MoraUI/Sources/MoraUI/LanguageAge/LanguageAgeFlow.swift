// Packages/MoraUI/Sources/MoraUI/LanguageAge/LanguageAgeFlow.swift
import MoraCore
import Observation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class LanguageAgeState {
    var step: Step = .language
    var selectedLanguageID: String = "ja"  // pre-selected per spec §6.1
    var selectedAge: Int? = 8  // pre-selected per spec §6.2

    static let onboardedKey = "tech.reenable.Mora.languageAgeOnboarded"

    enum Step: Equatable { case language, age, finished }

    func advance() {
        switch step {
        case .language: step = .age
        case .age: step = .finished
        case .finished: break
        }
    }

    /// Upsert the LearnerProfile with the picked language+age, flip the
    /// UserDefaults flag. Returns true on success, false on bad input or
    /// SwiftData error (leaves flag unflipped so next launch retries).
    @discardableResult
    func finalize(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) -> Bool {
        guard let age = selectedAge else { return false }
        let languageID = selectedLanguageID.trimmingCharacters(in: .whitespaces)
        guard !languageID.isEmpty else { return false }

        // Fetch existing profile if any; @Query isn't available in a
        // non-View context, so we use FetchDescriptor directly. A fetch
        // error here means SwiftData is in a bad state — bail rather than
        // risk inserting a duplicate row on top of an unreadable store.
        let existingProfile: LearnerProfile?
        do {
            existingProfile = try context.fetch(
                FetchDescriptor<LearnerProfile>(
                    sortBy: [SortDescriptor(\.createdAt, order: .forward)]
                )
            )
            .first
        } catch {
            return false
        }

        let profile: LearnerProfile
        let isInsert: Bool
        if let existingProfile {
            profile = existingProfile
            isInsert = false
        } else {
            profile = LearnerProfile(
                displayName: "",
                l1Identifier: languageID,
                ageYears: age,
                interests: [],
                preferredFontKey: "openDyslexic",
                createdAt: now
            )
            isInsert = true
        }

        profile.l1Identifier = languageID
        profile.ageYears = age

        if isInsert { context.insert(profile) }

        do {
            try context.save()
        } catch {
            // Roll back the insert so we don't leave a half-built row.
            if isInsert { context.delete(profile) }
            return false
        }
        defaults.set(true, forKey: Self.onboardedKey)
        return true
    }
}

public struct LanguageAgeFlow: View {
    @Environment(\.modelContext) private var context
    @State private var state = LanguageAgeState()
    private let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        // Alpha only ships JapaneseL1Profile, so Step 2 always renders in
        // Japanese regardless of `state.selectedLanguageID`. When a second
        // L1 profile lands, switch on `state.selectedLanguageID` here.
        let strings = JapaneseL1Profile().uiStrings(
            at: LearnerLevel.from(years: state.selectedAge ?? 8)
        )

        ZStack {
            MoraTheme.Background.page.ignoresSafeArea()
            stepView
        }
        .environment(\.moraStrings, strings)
        .onChange(of: state.step) { _, new in
            if new == .finished {
                if state.finalize(in: context) {
                    onFinished()
                }
            }
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch state.step {
        case .language:
            LanguagePickerView(
                selectedLanguageID: Binding(
                    get: { state.selectedLanguageID },
                    set: { state.selectedLanguageID = $0 }
                ),
                onContinue: { state.advance() }
            )
        case .age:
            AgePickerView(
                selectedAge: Binding(
                    get: { state.selectedAge },
                    set: { state.selectedAge = $0 }
                ),
                onContinue: { state.advance() }
            )
        case .finished:
            ProgressView()
        }
    }
}
