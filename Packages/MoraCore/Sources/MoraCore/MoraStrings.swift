// Packages/MoraCore/Sources/MoraCore/MoraStrings.swift
import Foundation

/// UI-chrome strings resolved per (language, age-bucket) by an L1Profile.
/// Closures are used for simple pluralization/count-parameterization so
/// the struct stays pure Swift (no Foundation formatter dependency).
public struct MoraStrings: Sendable {
    // Language + age onboarding
    public let ageOnboardingPrompt: String
    public let ageOnboardingCTA: String

    // Existing four-step onboarding
    public let welcomeTitle: String
    public let welcomeCTA: String
    public let namePrompt: String
    public let nameSkip: String
    public let nameCTA: String
    public let interestPrompt: String
    public let interestCTA: String
    public let permissionTitle: String
    public let permissionBody: String
    public let permissionAllow: String
    public let permissionNotNow: String

    // Yokai intro flow (4 panels + 3 CTAs + 1 replay close)
    public let yokaiIntroConceptTitle: String
    public let yokaiIntroConceptBody: String
    public let yokaiIntroTodayTitle: String
    public let yokaiIntroTodayBody: String
    public let yokaiIntroSessionTitle: String
    public let yokaiIntroSessionBody: String
    public let yokaiIntroSessionStep1: String
    public let yokaiIntroSessionStep2: String
    public let yokaiIntroSessionStep3: String
    public let yokaiIntroProgressTitle: String
    public let yokaiIntroProgressBody: String
    public let yokaiIntroNext: String
    public let yokaiIntroBegin: String
    public let yokaiIntroClose: String

    // Home
    public let homeTodayQuest: String
    public let homeStart: String
    public let homeDurationPill: @Sendable (Int) -> String
    public let homeWordsPill: @Sendable (Int) -> String
    public let homeSentencesPill: @Sendable (Int) -> String
    public let bestiaryLinkLabel: String
    public let bestiaryPlayGreeting: String
    public let bestiaryBefriendedOn: @Sendable (Date) -> String
    public let homeRecapLink: String

    // Voice gate — shown on Home when no `.enhanced` or `.premium` English
    // voice is installed. Parent-facing setup copy (not in the child kanji
    // budget because it has to mirror iOS Settings labels verbatim).
    public let voiceGateTitle: String
    public let voiceGateBody: String
    public let voiceGateOpenSettings: String
    public let voiceGateRecheck: String
    public let voiceGateInstalledVoicesTitle: String
    public let voiceGateNoVoicesPlaceholder: String

    // Session chrome
    public let sessionCloseTitle: String
    public let sessionCloseMessage: String
    public let sessionCloseKeepGoing: String
    public let sessionCloseEnd: String
    public let sessionWordCounter: @Sendable (Int, Int) -> String
    public let sessionSentenceCounter: @Sendable (Int, Int) -> String

    // Per-phase chrome
    public let warmupListenAgain: String
    public let newRuleGotIt: String
    public let newRuleListenAgain: String
    public let decodingLongPressHint: String
    public let decodingBuildPrompt: String
    public let decodingListenAgain: String
    // Tile-board first-run tutorial (2 panels + 2 CTAs + Help label)
    public let tileTutorialSlotTitle: String
    public let tileTutorialSlotBody: String
    public let tileTutorialAudioTitle: String
    public let tileTutorialAudioBody: String
    public let tileTutorialNext: String
    public let tileTutorialTry: String
    public let decodingHelpLabel: String
    public let sentencesLongPressHint: String
    public let feedbackCorrect: String
    public let feedbackTryAgain: String

    // Mic UI
    public let micIdlePrompt: String
    public let micListening: String
    public let micAssessing: String
    public let micDeniedBanner: String

    // Pronunciation coaching (per L1 interference pair)
    public let coachingShSubS: String
    public let coachingShDrift: String
    public let coachingRSubL: String
    public let coachingLSubR: String
    public let coachingFSubH: String
    public let coachingVSubB: String
    public let coachingThVoicelessSubS: String
    public let coachingThVoicelessSubT: String
    public let coachingTSubThVoiceless: String
    public let coachingAeSubSchwa: String

    // Pronunciation feedback category banner. Closures so the overlay can
    // substitute kid-friendly letter pairs (e.g. "sh"/"s") at render time
    // without embedding the per-locale template inside MoraUI source.
    public let categorySubstitutionBanner: @Sendable (String, String) -> String
    public let categoryDriftBanner: @Sendable (String) -> String

    // Completion
    public let completionTitle: String
    public let completionScore: @Sendable (Int, Int) -> String
    public let completionComeBack: String

    // Accessibility
    public let a11yCloseSession: String
    public let a11yMicButton: String
    public let a11yStreakChip: @Sendable (Int) -> String

    public init(
        ageOnboardingPrompt: String,
        ageOnboardingCTA: String,
        welcomeTitle: String, welcomeCTA: String,
        namePrompt: String, nameSkip: String, nameCTA: String,
        interestPrompt: String, interestCTA: String,
        permissionTitle: String, permissionBody: String,
        permissionAllow: String, permissionNotNow: String,
        yokaiIntroConceptTitle: String,
        yokaiIntroConceptBody: String,
        yokaiIntroTodayTitle: String,
        yokaiIntroTodayBody: String,
        yokaiIntroSessionTitle: String,
        yokaiIntroSessionBody: String,
        yokaiIntroSessionStep1: String,
        yokaiIntroSessionStep2: String,
        yokaiIntroSessionStep3: String,
        yokaiIntroProgressTitle: String,
        yokaiIntroProgressBody: String,
        yokaiIntroNext: String,
        yokaiIntroBegin: String,
        yokaiIntroClose: String,
        homeTodayQuest: String, homeStart: String,
        homeDurationPill: @escaping @Sendable (Int) -> String,
        homeWordsPill: @escaping @Sendable (Int) -> String,
        homeSentencesPill: @escaping @Sendable (Int) -> String,
        bestiaryLinkLabel: String,
        bestiaryPlayGreeting: String,
        bestiaryBefriendedOn: @escaping @Sendable (Date) -> String,
        homeRecapLink: String,
        voiceGateTitle: String, voiceGateBody: String,
        voiceGateOpenSettings: String, voiceGateRecheck: String,
        voiceGateInstalledVoicesTitle: String,
        voiceGateNoVoicesPlaceholder: String,
        sessionCloseTitle: String, sessionCloseMessage: String,
        sessionCloseKeepGoing: String, sessionCloseEnd: String,
        sessionWordCounter: @escaping @Sendable (Int, Int) -> String,
        sessionSentenceCounter: @escaping @Sendable (Int, Int) -> String,
        warmupListenAgain: String, newRuleGotIt: String, newRuleListenAgain: String,
        decodingLongPressHint: String,
        decodingBuildPrompt: String, decodingListenAgain: String,
        tileTutorialSlotTitle: String,
        tileTutorialSlotBody: String,
        tileTutorialAudioTitle: String,
        tileTutorialAudioBody: String,
        tileTutorialNext: String,
        tileTutorialTry: String,
        decodingHelpLabel: String,
        sentencesLongPressHint: String,
        feedbackCorrect: String, feedbackTryAgain: String,
        micIdlePrompt: String, micListening: String,
        micAssessing: String, micDeniedBanner: String,
        coachingShSubS: String,
        coachingShDrift: String,
        coachingRSubL: String,
        coachingLSubR: String,
        coachingFSubH: String,
        coachingVSubB: String,
        coachingThVoicelessSubS: String,
        coachingThVoicelessSubT: String,
        coachingTSubThVoiceless: String,
        coachingAeSubSchwa: String,
        categorySubstitutionBanner: @escaping @Sendable (String, String) -> String,
        categoryDriftBanner: @escaping @Sendable (String) -> String,
        completionTitle: String,
        completionScore: @escaping @Sendable (Int, Int) -> String,
        completionComeBack: String,
        a11yCloseSession: String, a11yMicButton: String,
        a11yStreakChip: @escaping @Sendable (Int) -> String
    ) {
        self.ageOnboardingPrompt = ageOnboardingPrompt
        self.ageOnboardingCTA = ageOnboardingCTA
        self.welcomeTitle = welcomeTitle
        self.welcomeCTA = welcomeCTA
        self.namePrompt = namePrompt
        self.nameSkip = nameSkip
        self.nameCTA = nameCTA
        self.interestPrompt = interestPrompt
        self.interestCTA = interestCTA
        self.permissionTitle = permissionTitle
        self.permissionBody = permissionBody
        self.permissionAllow = permissionAllow
        self.permissionNotNow = permissionNotNow
        self.yokaiIntroConceptTitle = yokaiIntroConceptTitle
        self.yokaiIntroConceptBody = yokaiIntroConceptBody
        self.yokaiIntroTodayTitle = yokaiIntroTodayTitle
        self.yokaiIntroTodayBody = yokaiIntroTodayBody
        self.yokaiIntroSessionTitle = yokaiIntroSessionTitle
        self.yokaiIntroSessionBody = yokaiIntroSessionBody
        self.yokaiIntroSessionStep1 = yokaiIntroSessionStep1
        self.yokaiIntroSessionStep2 = yokaiIntroSessionStep2
        self.yokaiIntroSessionStep3 = yokaiIntroSessionStep3
        self.yokaiIntroProgressTitle = yokaiIntroProgressTitle
        self.yokaiIntroProgressBody = yokaiIntroProgressBody
        self.yokaiIntroNext = yokaiIntroNext
        self.yokaiIntroBegin = yokaiIntroBegin
        self.yokaiIntroClose = yokaiIntroClose
        self.homeTodayQuest = homeTodayQuest
        self.homeStart = homeStart
        self.homeDurationPill = homeDurationPill
        self.homeWordsPill = homeWordsPill
        self.homeSentencesPill = homeSentencesPill
        self.bestiaryLinkLabel = bestiaryLinkLabel
        self.bestiaryPlayGreeting = bestiaryPlayGreeting
        self.bestiaryBefriendedOn = bestiaryBefriendedOn
        self.homeRecapLink = homeRecapLink
        self.voiceGateTitle = voiceGateTitle
        self.voiceGateBody = voiceGateBody
        self.voiceGateOpenSettings = voiceGateOpenSettings
        self.voiceGateRecheck = voiceGateRecheck
        self.voiceGateInstalledVoicesTitle = voiceGateInstalledVoicesTitle
        self.voiceGateNoVoicesPlaceholder = voiceGateNoVoicesPlaceholder
        self.sessionCloseTitle = sessionCloseTitle
        self.sessionCloseMessage = sessionCloseMessage
        self.sessionCloseKeepGoing = sessionCloseKeepGoing
        self.sessionCloseEnd = sessionCloseEnd
        self.sessionWordCounter = sessionWordCounter
        self.sessionSentenceCounter = sessionSentenceCounter
        self.warmupListenAgain = warmupListenAgain
        self.newRuleGotIt = newRuleGotIt
        self.newRuleListenAgain = newRuleListenAgain
        self.decodingLongPressHint = decodingLongPressHint
        self.decodingBuildPrompt = decodingBuildPrompt
        self.decodingListenAgain = decodingListenAgain
        self.tileTutorialSlotTitle = tileTutorialSlotTitle
        self.tileTutorialSlotBody = tileTutorialSlotBody
        self.tileTutorialAudioTitle = tileTutorialAudioTitle
        self.tileTutorialAudioBody = tileTutorialAudioBody
        self.tileTutorialNext = tileTutorialNext
        self.tileTutorialTry = tileTutorialTry
        self.decodingHelpLabel = decodingHelpLabel
        self.sentencesLongPressHint = sentencesLongPressHint
        self.feedbackCorrect = feedbackCorrect
        self.feedbackTryAgain = feedbackTryAgain
        self.micIdlePrompt = micIdlePrompt
        self.micListening = micListening
        self.micAssessing = micAssessing
        self.micDeniedBanner = micDeniedBanner
        self.coachingShSubS = coachingShSubS
        self.coachingShDrift = coachingShDrift
        self.coachingRSubL = coachingRSubL
        self.coachingLSubR = coachingLSubR
        self.coachingFSubH = coachingFSubH
        self.coachingVSubB = coachingVSubB
        self.coachingThVoicelessSubS = coachingThVoicelessSubS
        self.coachingThVoicelessSubT = coachingThVoicelessSubT
        self.coachingTSubThVoiceless = coachingTSubThVoiceless
        self.coachingAeSubSchwa = coachingAeSubSchwa
        self.categorySubstitutionBanner = categorySubstitutionBanner
        self.categoryDriftBanner = categoryDriftBanner
        self.completionTitle = completionTitle
        self.completionScore = completionScore
        self.completionComeBack = completionComeBack
        self.a11yCloseSession = a11yCloseSession
        self.a11yMicButton = a11yMicButton
        self.a11yStreakChip = a11yStreakChip
    }
}

extension MoraStrings {
    /// Convenience for SwiftUI #Preview blocks. Always returns the JP
    /// advanced table — runtime resolution happens in RootView via
    /// L1ProfileResolver. Preview-only; not used in production paths.
    public static var previewDefault: MoraStrings {
        JapaneseL1Profile().uiStrings(at: .advanced)
    }
}
