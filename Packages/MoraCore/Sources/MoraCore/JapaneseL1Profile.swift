// Packages/MoraCore/Sources/MoraCore/JapaneseL1Profile.swift
import Foundation

public struct JapaneseL1Profile: L1Profile {
    public let identifier = "ja"
    public let characterSystem: CharacterSystem = .mixed

    public let interferencePairs: [PhonemeConfusionPair] = [
        PhonemeConfusionPair(
            tag: "r_l_swap",
            from: Phoneme(ipa: "r"), to: Phoneme(ipa: "l"),
            examples: ["right/light", "rock/lock", "grass/glass"],
            bidirectional: true
        ),
        PhonemeConfusionPair(
            tag: "f_h_sub",
            from: Phoneme(ipa: "f"), to: Phoneme(ipa: "h"),
            examples: ["fat/hat", "fair/hair"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "v_b_sub",
            from: Phoneme(ipa: "v"), to: Phoneme(ipa: "b"),
            examples: ["vat/bat", "van/ban"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "th_voiceless_s_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "s"),
            examples: ["thin/sin", "thick/sick"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "th_voiceless_t_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "t"),
            examples: ["thin/tin", "three/tree"],
            bidirectional: false
        ),
        PhonemeConfusionPair(
            tag: "ae_lax_conflate",
            from: Phoneme(ipa: "æ"), to: Phoneme(ipa: "ʌ"),
            examples: ["cat/cut", "bag/bug"],
            bidirectional: true
        ),
        PhonemeConfusionPair(
            tag: "sh_s_sub",
            from: Phoneme(ipa: "ʃ"), to: Phoneme(ipa: "s"),
            examples: ["ship/sip", "shoe/sue", "shell/sell"],
            bidirectional: false
        ),
        // Drift-target sentinel (from == to): the acoustic evaluator reads
        // this to score within-phoneme drift (/ʃ/ articulated with too little
        // lip rounding, carrying /ɕ/ influence). Never matched as substitution.
        PhonemeConfusionPair(
            tag: "sh_drift_target",
            from: Phoneme(ipa: "ʃ"), to: Phoneme(ipa: "ʃ"),
            examples: ["ship", "shop", "fish"],
            bidirectional: false
        ),
    ]

    public let interestCategories: [InterestCategory] = [
        InterestCategory(key: "animals", displayName: "Animals"),
        InterestCategory(key: "dinosaurs", displayName: "Dinosaurs"),
        InterestCategory(key: "vehicles", displayName: "Vehicles"),
        InterestCategory(key: "space", displayName: "Space"),
        InterestCategory(key: "sports", displayName: "Sports"),
        InterestCategory(key: "robots", displayName: "Robots"),
    ]

    public init() {}

    public func exemplars(for phoneme: Phoneme) -> [String] {
        switch phoneme.ipa {
        case "ʃ": return ["ship", "shop", "fish"]
        case "tʃ": return ["chop", "chin", "rich"]
        case "θ": return ["thin", "thick", "math"]
        case "k": return ["duck", "back", "rock"]  // for "ck" coda
        default: return []
        }
    }

    // MARK: - L1Profile.uiStrings / interestCategoryDisplayName

    private enum JPStringBucket { case preschool, early, mid, late }

    private static func bucket(forAgeYears y: Int) -> JPStringBucket {
        switch y {
        case ..<6: return .preschool
        case 6...7: return .early
        case 8...9: return .mid
        default: return .late
        }
    }

    public func uiStrings(forAgeYears years: Int) -> MoraStrings {
        // Alpha: every bucket returns the `mid` (ages 8-9) table.
        // A future plan authors the other three tables and flips this switch.
        switch Self.bucket(forAgeYears: years) {
        case .preschool, .early, .mid, .late:
            return Self.stringsMid
        }
    }

    public func interestCategoryDisplayName(key: String, forAgeYears years: Int) -> String {
        switch key {
        case "animals": return "どうぶつ"
        case "dinosaurs": return "きょうりゅう"
        case "vehicles": return "のりもの"
        case "space": return "うちゅう"
        case "sports": return "スポーツ"
        case "robots": return "ロボット"
        default: return key
        }
    }

    /// Ages 8-9 (alpha target). Kanji budget: only JPKanjiLevel.grade1And2
    /// characters appear. See spec §7.2 for the authoring rules and the
    /// per-row rationale.
    private static let stringsMid = MoraStrings(
        ageOnboardingPrompt: "なんさい？",
        ageOnboardingCTA: "▶ はじめる",
        welcomeTitle: "えいごの 音を いっしょに",
        welcomeCTA: "はじめる",
        namePrompt: "名前を 教えてね",
        nameSkip: "スキップ",
        nameCTA: "つぎへ",
        interestPrompt: "すきな ものを 3つ えらんでね",
        interestCTA: "つぎへ",
        permissionTitle: "声を 聞くよ",
        permissionBody: "きみが 読んだ ことばを 聞いて、正しいか しらべるよ",
        permissionAllow: "ゆるす",
        permissionNotNow: "後で",
        homeTodayQuest: "今日の クエスト",
        homeStart: "▶ はじめる",
        homeDurationPill: { minutes in "\(minutes)分" },
        homeWordsPill: { count in "\(count)文字" },
        homeSentencesPill: { count in "\(count)文" },
        homeBetterVoiceChip: "もっと きれいな 声 ›",
        sessionCloseTitle: "今日の クエストを おわる？",
        sessionCloseMessage: "ここまでの きろくは のこるよ",
        sessionCloseKeepGoing: "つづける",
        sessionCloseEnd: "おわる",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 もういちど",
        newRuleGotIt: "分かった",
        decodingLongPressHint: "ながおしで もういちど 聞けるよ",
        sentencesLongPressHint: "ながおしで もういちど 聞けるよ",
        feedbackCorrect: "せいかい！",
        feedbackTryAgain: "もう一回",
        micIdlePrompt: "マイクを タップして 読んでね",
        micListening: "聞いてるよ…",
        micAssessing: "チェック中…",
        micDeniedBanner: "マイクが つかえないので ボタンで 答えてね",
        completionTitle: "できた！",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "明日も またね",
        a11yCloseSession: "クエストを おわる",
        a11yMicButton: "マイク",
        a11yStreakChip: { days in "\(days)日 れんぞく" }
    )
}
