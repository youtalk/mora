// Packages/MoraCore/Sources/MoraCore/EnglishL1Profile.swift
import Foundation

/// English L1 profile. L1 == L2, so `interferencePairs == []` (no L1-driven
/// substitution patterns apply). UI strings flow from the existing English
/// literals in MoraUI. See spec §6.3.
public struct EnglishL1Profile: L1Profile {
    public let identifier = "en"
    public let characterSystem: CharacterSystem = .alphabetic
    public let interferencePairs: [PhonemeConfusionPair] = []
    public let interestCategories: [InterestCategory] = JapaneseL1Profile().interestCategories

    public init() {}

    public func exemplars(for phoneme: Phoneme) -> [String] {
        switch phoneme.ipa {
        case "ʃ": return ["ship", "shop", "fish"]
        case "tʃ": return ["chop", "chin", "rich"]
        case "θ": return ["thin", "thick", "math"]
        case "f": return ["fan", "fox", "fun"]
        case "r": return ["red", "rat", "run"]
        case "æ": return ["cat", "hat", "bat"]
        case "k": return ["duck", "back", "rock"]
        default: return []
        }
    }

    public func uiStrings(at level: LearnerLevel) -> MoraStrings { Self.stringsKidEn }

    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
        switch key {
        case "animals": return "Animals"
        case "dinosaurs": return "Dinosaurs"
        case "vehicles": return "Vehicles"
        case "space": return "Space"
        case "sports": return "Sports"
        case "robots": return "Robots"
        default: return key
        }
    }

    private static let bestiaryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateStyle = .long
        return f
    }()

    /// Authoring rules: Dolch first 100 sight words primarily; ≤8 words per
    /// phrase; concrete kid words; warm encouraging tone. See spec §6.3.1.
    /// Coaching scaffolds are dead-code paths (interferencePairs is empty)
    /// but authored for `MoraStrings` constructor completeness.
    private static let stringsKidEn = MoraStrings(
        ageOnboardingPrompt: "How old are you?",
        ageOnboardingCTA: "▶ Start",
        welcomeTitle: "Let's learn English sounds together",
        welcomeCTA: "Start",
        namePrompt: "What's your name?",
        nameSkip: "Skip",
        nameCTA: "Next",
        interestPrompt: "Pick 3 things you like",
        interestCTA: "Next",
        permissionTitle: "I'll listen to your voice",
        permissionBody: "I'll hear what you read and check if it's right.",
        permissionAllow: "Allow",
        permissionNotNow: "Not now",
        yokaiIntroConceptTitle: "Sounds have friends",
        yokaiIntroConceptBody:
            "A Yokai lives in every English sound. "
            + "Listen well and say it out loud to make friends.",
        yokaiIntroTodayTitle: "This week's friend",
        yokaiIntroTodayBody: "Let's practice this sound this week.",
        yokaiIntroSessionTitle: "How one round goes",
        yokaiIntroSessionBody: "About 10 minutes per round.",
        yokaiIntroSessionStep1: "Listen",
        yokaiIntroSessionStep2: "Build",
        yokaiIntroSessionStep3: "Say",
        yokaiIntroProgressTitle: "5 rounds and you're friends",
        yokaiIntroProgressBody:
            "Practice with the Yokai 5 times to become friends. "
            + "Once a day is enough.",
        yokaiIntroNext: "Next",
        yokaiIntroBegin: "▶ Start",
        yokaiIntroClose: "Close",
        homeTodayQuest: "Today's quest",
        homeStart: "▶ Start",
        homeDurationPill: { minutes in "\(minutes) min" },
        homeWordsPill: { count in "\(count) words" },
        homeSentencesPill: { count in "\(count) sentences" },
        bestiaryLinkLabel: "Friends book",
        bestiaryPlayGreeting: "🔊 Greet",
        bestiaryBefriendedOn: { date in
            "Friends since \(Self.bestiaryDateFormatter.string(from: date))"
        },
        homeRecapLink: "How to play",
        voiceGateTitle: "Please download an English voice",
        voiceGateBody:
            "Mora needs a clear voice that isn't on this iPad yet.\n"
            + "Open the Settings app and follow this path:\n\n"
            + "  Settings\n"
            + "  → Accessibility\n"
            + "  → Read & Speak\n"
            + "  → Voices → English\n\n"
            + "Then download a Premium or Enhanced voice\n"
            + "(Ava / Samantha / Siri etc.).\n"
            + "(Before iPadOS 26, Read & Speak appears as Spoken Content.)",
        voiceGateOpenSettings: "Open Settings",
        voiceGateRecheck: "Check again",
        voiceGateInstalledVoicesTitle: "Installed English voices",
        voiceGateNoVoicesPlaceholder: "(none)",
        sessionCloseTitle: "End today's quest?",
        sessionCloseMessage: "Your progress so far is saved.",
        sessionCloseKeepGoing: "Keep going",
        sessionCloseEnd: "End",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 Again",
        newRuleGotIt: "Got it",
        newRuleListenAgain: "🔊 Again",
        decodingLongPressHint: "Long-press to hear it again.",
        decodingBuildPrompt: "Listen well and build it",
        decodingListenAgain: "🔊 Again",
        tileTutorialSlotTitle: "Put letters in slots to make a word",
        tileTutorialSlotBody:
            "One slot, one sound. Long-press a tile and drag it to a slot.",
        tileTutorialAudioTitle: "Make the sound you heard",
        tileTutorialAudioBody:
            "First 🔊 plays the sound. Build tiles to match it. "
            + "Tap \"Listen again\" if you need to hear it once more.",
        tileTutorialNext: "Next",
        tileTutorialTry: "▶ Try it",
        decodingHelpLabel: "How to play",
        sentencesListenAgain: "🔊 Again",
        feedbackCorrect: "Correct!",
        feedbackTryAgain: "Try again",
        micButtonLabel: "Speak",
        micButtonHintTapToStart: "Tap to start recording",
        micButtonHintTapToStop: "Tap to stop recording",
        micIdlePrompt: "Tap the mic and read it",
        micListening: "Listening…",
        micAssessing: "Checking…",
        micDeniedBanner: "The mic is off — answer with the buttons.",
        coachingShSubS: "Round your lips and lift the back of your tongue. Say \"sh\".",
        coachingShDrift: "Round your mouth a little more and stretch it long. \"shhhh\".",
        coachingRSubL: "Don't touch the tip of your tongue. Lift the back a little. \"r\".",
        coachingLSubR: "Touch the tip to behind your top teeth and stay there. \"l\".",
        coachingFSubH: "Press your top teeth on your bottom lip. Say \"fff\".",
        coachingVSubB: "Press your top teeth on your bottom lip and buzz your throat. \"vvv\".",
        coachingThVoicelessSubS: "Stick your tongue tip out a little and blow. \"thhh\".",
        coachingThVoicelessSubT: "Stick your tongue tip out and don't stop. \"thhh\".",
        coachingTSubThVoiceless: "Tap the tip of your tongue behind your top teeth. \"t\".",
        coachingAeSubSchwa: "Open your mouth wide and drop your jaw. \"æ\".",
        categorySubstitutionBanner: { target, substitute in
            "That \(target) was leaning toward \(substitute)"
        },
        categoryDriftBanner: { target in
            "Get a little closer to a clean \(target)"
        },
        completionTitle: "You did it!",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "See you tomorrow!",
        a11yCloseSession: "End the quest",
        a11yMicButton: "Mic",
        a11yStreakChip: { days in "\(days)-day streak" }
        // PR 3 will append the four language-switch fields.
    )
}
