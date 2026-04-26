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
        case "f": return ["fan", "fox", "fun"]
        case "r": return ["red", "rat", "run"]
        case "æ": return ["cat", "hat", "bat"]
        case "k": return ["duck", "back", "rock"]  // for "ck" coda
        default: return []
        }
    }

    // MARK: - L1Profile.uiStrings / interestCategoryDisplayName

    public func uiStrings(at level: LearnerLevel) -> MoraStrings {
        switch level {
        case .entry: return Self.stringsEntryHiraOnly
        case .core: return Self.stringsCoreG1
        case .advanced: return Self.stringsAdvancedG1G2
        }
    }

    public func allowedScriptBudget(at level: LearnerLevel) -> Set<Character>? {
        switch level {
        case .entry: return JPKanjiLevel.empty
        case .core: return JPKanjiLevel.grade1
        case .advanced: return JPKanjiLevel.grade1And2
        }
    }

    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
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

    /// Cached formatter for `bestiaryBefriendedOn` at the advanced tier.
    /// Forces a Gregorian calendar so the kanji budget stays at grade1+grade2
    /// (a Japanese imperial-era style would emit `令和` etc., which is grade 4).
    /// `dateStyle = .long` renders as `yyyy年M月d日` — uses `年` (G2), `月` (G2),
    /// `日` (G1), all within the advanced budget.
    private static let bestiaryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateStyle = .long
        return f
    }()

    /// Numeric date formatter used by the core and entry tiers, where the
    /// kanji budget cannot accommodate `年` / `月`. Renders `yyyy/M/d`.
    private static let bestiaryDateFormatterNumeric: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy/M/d"
        return f
    }()

    /// Ages 7 (1st-grade-finished) — kanji budget: JPKanjiLevel.grade1 only
    /// (80 chars). Mechanically derived from stringsAdvancedG1G2 by replacing
    /// every G2+ kanji with its hiragana reading. Per spec §6.1.1 the
    /// partial-mix rule applies: if any kanji in a compound is outside the G1
    /// budget the whole compound is rendered in hiragana.
    private static let stringsCoreG1 = MoraStrings(
        ageOnboardingPrompt: "なんさい？",
        ageOnboardingCTA: "▶ はじめる",
        welcomeTitle: "えいごの 音を いっしょに",
        welcomeCTA: "はじめる",
        // `名` G1 but `前` G2 → partial-mix forbidden → all-hira.
        // `教` G2 → all-hira.
        namePrompt: "なまえを おしえてね",
        nameSkip: "スキップ",
        nameCTA: "つぎへ",
        interestPrompt: "すきな ものを 3つ えらんでね",
        interestCTA: "つぎへ",
        // `声` G2, `聞` G2 → all-hira.
        permissionTitle: "こえを きくよ",
        // `読` G2, `聞` G2 → all-hira. `正` G1 kept.
        permissionBody: "きみが よんだ ことばを きいて、正しいか しらべるよ",
        permissionAllow: "ゆるす",
        // `後` G2 → all-hira.
        permissionNotNow: "あとで",
        yokaiIntroConceptTitle: "音には ともだちが いるよ",
        // `聞` G2 → all-hira.
        yokaiIntroConceptBody:
            "えいごの 音 ひとつ ひとつに、Yokai が すんでいる。"
            + "なかよく なるには、その 音を よく きいて、ことばに しよう。",
        // `今` G2, `週` G2 → all-hira.
        yokaiIntroTodayTitle: "こんしゅうの ともだち",
        // `今` G2, `週` G2 → all-hira.
        yokaiIntroTodayBody: "こんしゅうは この 音を いっしょに れんしゅうしよう。",
        // `回` G2 → all-hira.
        yokaiIntroSessionTitle: "1かいの すすめかた",
        // `回` G2, `分` G2 → all-hira.
        yokaiIntroSessionBody: "1かい だいたい 10ぷん。",
        yokaiIntroSessionStep1: "きく",
        yokaiIntroSessionStep2: "ならべる",
        // `話` G2 → all-hira.
        yokaiIntroSessionStep3: "はなす",
        // `回` G2 → all-hira.
        yokaiIntroProgressTitle: "5かいで ともだちに なる",
        // `回` G2 → all-hira. `日` G1 kept.
        yokaiIntroProgressBody:
            "Yokai と 5かい れんしゅうすると、なかよく なれる。"
            + "1日 1かい でも、すきな ペースで OK。",
        yokaiIntroNext: "つぎへ",
        yokaiIntroBegin: "▶ はじめる",
        yokaiIntroClose: "とじる",
        // `今` G2 → all-hira.
        homeTodayQuest: "きょうの クエスト",
        homeStart: "▶ はじめる",
        // `分` G2 → all-hira.
        homeDurationPill: { minutes in "\(minutes)ぷん" },
        // `文` G1, `字` G1 — both in budget, kept.
        homeWordsPill: { count in "\(count)文字" },
        // `文` G1 — kept.
        homeSentencesPill: { count in "\(count)文" },
        bestiaryLinkLabel: "ともだち ずかん",
        bestiaryPlayGreeting: "🔊 あいさつ",
        // `日` G1 kept. Numeric date formatter avoids `年` / `月` (G2, outside
        // the core G1 budget).
        bestiaryBefriendedOn: { date in
            "なかよくなった日 \(Self.bestiaryDateFormatterNumeric.string(from: date))"
        },
        homeRecapLink: "あそびかた",
        // `英` G2, `語` G2, `声` G2 → all-hira.
        voiceGateTitle: "えいごの こえを ダウンロードしてください",
        // `入` G1, `中` G1 kept. All G2+ compounds replaced per partial-mix
        // rule. `前` G2 → まえ. `内` G2 → ない. `表示` G3+G2 → ひょうじ.
        // `言語` G2+G2 → ことば. `場合` G2+G2 → ばあい.
        voiceGateBody:
            "Moraで つかう きれいな こえが iPadに 入っていません。\n"
            + "せっていアプリを ひらき、下の じゅんで ひらいてください:\n\n"
            + "  せってい (Settings)\n"
            + "  → アクセシビリティ (Accessibility)\n"
            + "  → よみあげ と はつわ (Read & Speak)\n"
            + "  → こえ (Voices) → えいご (English)\n\n"
            + "その中から Premium または Enhanced の こえ (Ava / Samantha / Siri など) を\n"
            + "ダウンロードしてください。\n"
            + "(iPadOS 26より まえは Read & Speak の かわりに\n"
            + " Spoken Content / よみあげコンテンツ と ひょうじされます。\n"
            + " OSの ことばが えいごの ばあいは カッコ内の ひょうきで ひょうじされます。)",
        // `設` `定` `開` all G3+ → all-hira.
        voiceGateOpenSettings: "せっていを ひらく",
        // `一` G1 but `度` G3 → partial-mix forbidden → all-hira.
        voiceGateRecheck: "もういちど たしかめる",
        // `済` G6, `英` G2, `語` G2 → all-hira.
        voiceGateInstalledVoicesTitle: "インストールずみの えいご voice",
        voiceGateNoVoicesPlaceholder: "(なし)",
        // `今` G2 → all-hira.
        sessionCloseTitle: "きょうの クエストを おわる？",
        sessionCloseMessage: "ここまでの きろくは のこるよ",
        sessionCloseKeepGoing: "つづける",
        sessionCloseEnd: "おわる",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 もういちど",
        // `分` G2 → all-hira.
        newRuleGotIt: "わかった",
        newRuleListenAgain: "🔊 もういちど",
        // `聞` G2 → all-hira.
        decodingLongPressHint: "ながおしで もういちど きけるよ",
        decodingBuildPrompt: "よく きいて ならべよう",
        decodingListenAgain: "🔊 もういちど",
        // `文` G1, `字` G1, `入` G1 — all in budget, kept.
        tileTutorialSlotTitle: "文字を ますに 入れて ことばを つくる",
        // `音` G1 kept.
        tileTutorialSlotBody:
            "ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。",
        // `聞` G2 → all-hira. `音` G1 kept.
        tileTutorialAudioTitle: "きいた 音を つくろう",
        // `聞` G2, `同` G2 → all-hira. `音` G1 kept.
        tileTutorialAudioBody:
            "はじめに 🔊 が 音を きかせる。きいた 音と おなじに なるよう、"
            + "タイルを ならべよう。きこえなおすときは「もういちど きく」を タップ。",
        tileTutorialNext: "つぎへ",
        tileTutorialTry: "▶ やってみる",
        // `見` G1 kept.
        decodingHelpLabel: "あそびかたを 見る",
        // `聞` G2 → all-hira.
        sentencesLongPressHint: "ながおしで もういちど きけるよ",
        feedbackCorrect: "せいかい！",
        // `一` G1 but `回` G2 → partial-mix forbidden → all-hira.
        feedbackTryAgain: "もういちど",
        // `読` G2 → all-hira.
        micIdlePrompt: "マイクを タップして よんでね",
        // `聞` G2 → all-hira.
        micListening: "きいてるよ…",
        // `中` G1 kept.
        micAssessing: "チェック中…",
        // `答` G2 → all-hira.
        micDeniedBanner: "マイクが つかえないので ボタンで こたえてね",
        coachingShSubS: "くちびるをまるめて、したのおくをもちあげてみよう。「sh」。",
        coachingShDrift: "もうすこしくちをまるくして、ながくのばしてみよう。「shhhh」。",
        coachingRSubL: "したのさきはどこにもつけないで、おくだけすこし上に。「r」。",
        coachingLSubR: "したのさきを上のはのうらにつけて、そのまま「l」。",
        coachingFSubH: "上のはでしたくちびるに、かるくふれて「fff」。",
        coachingVSubB: "上のはでしたくちびるにふれて、のどをふるわせて「vvv」。",
        coachingThVoicelessSubS: "したのさきをはのあいだにそっと出して「thhh」。",
        coachingThVoicelessSubT: "したのさきをはのあいだにそっと出して、とめずに「thhh」。",
        coachingTSubThVoiceless: "したのさきを上のはのうらにぴたっとつけて、すぐはなして「t」。",
        coachingAeSubSchwa: "口をよこにひろげて、あごを下げて「æ」。",
        // `今` G2, `寄` G4 → all-hira.
        categorySubstitutionBanner: { target, substitute in
            "いまの \(target) は \(substitute) に よってたよ"
        },
        // `少` G2, `近` G2 → all-hira. `音` G1 kept.
        categoryDriftBanner: { target in
            "もうすこし \(target) らしい音に ちかづけよう"
        },
        completionTitle: "できた！",
        completionScore: { correct, total in "\(correct)/\(total)" },
        // `明` G2 + `日` G1 → partial-mix forbidden → all-hira.
        completionComeBack: "あしたも またね",
        a11yCloseSession: "クエストを おわる",
        a11yMicButton: "マイク",
        // `日` G1 kept.
        a11yStreakChip: { days in "\(days)日 れんぞく" }
    )

    /// Ages ≤6 (entry tier). Kanji budget: empty — every kanji collapses to
    /// its hiragana reading. Mechanically derived from `stringsCoreG1` by
    /// applying the additional substitutions in spec §6.1.1 / Task 1.6.
    private static let stringsEntryHiraOnly = MoraStrings(
        ageOnboardingPrompt: "なんさい？",
        ageOnboardingCTA: "▶ はじめる",
        // `音` G1 → おと
        welcomeTitle: "えいごの おとを いっしょに",
        welcomeCTA: "はじめる",
        namePrompt: "なまえを おしえてね",
        nameSkip: "スキップ",
        nameCTA: "つぎへ",
        interestPrompt: "すきな ものを 3つ えらんでね",
        interestCTA: "つぎへ",
        permissionTitle: "こえを きくよ",
        // `正` G1 → ただ
        permissionBody: "きみが よんだ ことばを きいて、ただしいか しらべるよ",
        permissionAllow: "ゆるす",
        permissionNotNow: "あとで",
        // `音` G1 → おと
        yokaiIntroConceptTitle: "おとには ともだちが いるよ",
        // `音` G1 → おと (both occurrences)
        yokaiIntroConceptBody:
            "えいごの おと ひとつ ひとつに、Yokai が すんでいる。"
            + "なかよく なるには、その おとを よく きいて、ことばに しよう。",
        yokaiIntroTodayTitle: "こんしゅうの ともだち",
        yokaiIntroTodayBody: "こんしゅうは この おとを いっしょに れんしゅうしよう。",
        yokaiIntroSessionTitle: "1かいの すすめかた",
        yokaiIntroSessionBody: "1かい だいたい 10ぷん。",
        yokaiIntroSessionStep1: "きく",
        yokaiIntroSessionStep2: "ならべる",
        yokaiIntroSessionStep3: "はなす",
        yokaiIntroProgressTitle: "5かいで ともだちに なる",
        // `日` G1 → ひ
        yokaiIntroProgressBody:
            "Yokai と 5かい れんしゅうすると、なかよく なれる。"
            + "1ひ 1かい でも、すきな ペースで OK。",
        yokaiIntroNext: "つぎへ",
        yokaiIntroBegin: "▶ はじめる",
        yokaiIntroClose: "とじる",
        homeTodayQuest: "きょうの クエスト",
        homeStart: "▶ はじめる",
        homeDurationPill: { minutes in "\(minutes)ぷん" },
        // `文` G1, `字` G1 → もじ
        homeWordsPill: { count in "\(count)もじ" },
        // `文` G1 → ぶん
        homeSentencesPill: { count in "\(count)ぶん" },
        bestiaryLinkLabel: "ともだち ずかん",
        bestiaryPlayGreeting: "🔊 あいさつ",
        // `日` G1 → ひ
        bestiaryBefriendedOn: { date in
            "なかよくなったひ \(Self.bestiaryDateFormatterNumeric.string(from: date))"
        },
        homeRecapLink: "あそびかた",
        voiceGateTitle: "えいごの こえを ダウンロードしてください",
        // `入` G1 → はい, `中` G1 → なか, `下` G1 → した
        voiceGateBody:
            "Moraで つかう きれいな こえが iPadに はいっていません。\n"
            + "せっていアプリを ひらき、したの じゅんで ひらいてください:\n\n"
            + "  せってい (Settings)\n"
            + "  → アクセシビリティ (Accessibility)\n"
            + "  → よみあげ と はつわ (Read & Speak)\n"
            + "  → こえ (Voices) → えいご (English)\n\n"
            + "その なかから Premium または Enhanced の こえ (Ava / Samantha / Siri など) を\n"
            + "ダウンロードしてください。\n"
            + "(iPadOS 26より まえは Read & Speak の かわりに\n"
            + " Spoken Content / よみあげコンテンツ と ひょうじされます。\n"
            + " OSの ことばが えいごの ばあいは カッコ ないの ひょうきで ひょうじされます。)",
        voiceGateOpenSettings: "せっていを ひらく",
        voiceGateRecheck: "もういちど たしかめる",
        voiceGateInstalledVoicesTitle: "インストールずみの えいご voice",
        voiceGateNoVoicesPlaceholder: "(なし)",
        sessionCloseTitle: "きょうの クエストを おわる？",
        sessionCloseMessage: "ここまでの きろくは のこるよ",
        sessionCloseKeepGoing: "つづける",
        sessionCloseEnd: "おわる",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 もういちど",
        newRuleGotIt: "わかった",
        newRuleListenAgain: "🔊 もういちど",
        decodingLongPressHint: "ながおしで もういちど きけるよ",
        decodingBuildPrompt: "よく きいて ならべよう",
        decodingListenAgain: "🔊 もういちど",
        // `文` G1, `字` G1, `入` G1 → もじ, ます, い
        tileTutorialSlotTitle: "もじを ますに いれて ことばを つくる",
        // `音` G1 → おと
        tileTutorialSlotBody:
            "ます 1つは おと 1つ。タイルを ながおしして、ますへ ドラッグしよう。",
        // `音` G1 → おと
        tileTutorialAudioTitle: "きいた おとを つくろう",
        // `音` G1 → おと (both occurrences)
        tileTutorialAudioBody:
            "はじめに 🔊 が おとを きかせる。きいた おとと おなじに なるよう、"
            + "タイルを ならべよう。きこえなおすときは「もういちど きく」を タップ。",
        tileTutorialNext: "つぎへ",
        tileTutorialTry: "▶ やってみる",
        // `見` G1 → みる (spec §6.1.1 empty budget; plan note "unchanged" is
        // superseded by the invariant that no kanji may appear at entry tier)
        decodingHelpLabel: "あそびかたを みる",
        sentencesLongPressHint: "ながおしで もういちど きけるよ",
        feedbackCorrect: "せいかい！",
        feedbackTryAgain: "もういちど",
        micIdlePrompt: "マイクを タップして よんでね",
        micListening: "きいてるよ…",
        // `中` G1 → on'yomi ちゅう (avoids awkward なか after カタカナ stem)
        micAssessing: "チェックちゅう…",
        micDeniedBanner: "マイクが つかえないので ボタンで こたえてね",
        // coaching strings: `上` G1 → うえ, `出` G1 → だ(して), `下` G1 → さ(げて)
        coachingShSubS: "くちびるをまるめて、したのおくをもちあげてみよう。「sh」。",
        coachingShDrift: "もうすこしくちをまるくして、ながくのばしてみよう。「shhhh」。",
        coachingRSubL: "したのさきはどこにもつけないで、おくだけすこし うえに。「r」。",
        coachingLSubR: "したのさきを うえのはのうらにつけて、そのまま「l」。",
        coachingFSubH: "うえのはでしたくちびるに、かるくふれて「fff」。",
        coachingVSubB: "うえのはでしたくちびるにふれて、のどをふるわせて「vvv」。",
        coachingThVoicelessSubS: "したのさきをはのあいだにそっとだして「thhh」。",
        coachingThVoicelessSubT: "したのさきをはのあいだにそっとだして、とめずに「thhh」。",
        coachingTSubThVoiceless: "したのさきを うえのはのうらにぴたっとつけて、すぐはなして「t」。",
        coachingAeSubSchwa: "くちをよこにひろげて、あごをさげて「æ」。",
        categorySubstitutionBanner: { target, substitute in
            "いまの \(target) は \(substitute) に よってたよ"
        },
        categoryDriftBanner: { target in
            "もうすこし \(target) らしいおとに ちかづけよう"
        },
        completionTitle: "できた！",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "あしたも またね",
        a11yCloseSession: "クエストを おわる",
        a11yMicButton: "マイク",
        // `日` G1 → にち
        a11yStreakChip: { days in "\(days)にち れんぞく" }
    )

    /// Ages 8+ (advanced tier). Kanji budget: only JPKanjiLevel.grade1And2
    /// characters appear. See spec §7.2 for the authoring rules and the
    /// per-row rationale.
    private static let stringsAdvancedG1G2 = MoraStrings(
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
        yokaiIntroConceptTitle: "音には ともだちが いるよ",
        yokaiIntroConceptBody:
            "えいごの 音 ひとつ ひとつに、Yokai が すんでいる。"
            + "なかよく なるには、その 音を よく 聞いて、ことばに しよう。",
        yokaiIntroTodayTitle: "今週の ともだち",
        yokaiIntroTodayBody: "今週は この 音を いっしょに れんしゅうしよう。",
        yokaiIntroSessionTitle: "1回の すすめかた",
        yokaiIntroSessionBody: "1回 だいたい 10分。",
        yokaiIntroSessionStep1: "きく",
        yokaiIntroSessionStep2: "ならべる",
        yokaiIntroSessionStep3: "話す",
        yokaiIntroProgressTitle: "5回で ともだちに なる",
        yokaiIntroProgressBody:
            "Yokai と 5回 れんしゅうすると、なかよく なれる。"
            + "1日 1回 でも、すきな ペースで OK。",
        yokaiIntroNext: "つぎへ",
        yokaiIntroBegin: "▶ はじめる",
        yokaiIntroClose: "とじる",
        homeTodayQuest: "今日の クエスト",
        homeStart: "▶ はじめる",
        homeDurationPill: { minutes in "\(minutes)分" },
        homeWordsPill: { count in "\(count)文字" },
        homeSentencesPill: { count in "\(count)文" },
        bestiaryLinkLabel: "ともだち ずかん",
        bestiaryPlayGreeting: "🔊 あいさつ",
        bestiaryBefriendedOn: { date in
            "なかよくなった日 \(Self.bestiaryDateFormatter.string(from: date))"
        },
        homeRecapLink: "あそびかた",
        voiceGateTitle: "英語の 声を ダウンロードしてください",
        voiceGateBody:
            "Moraで つかう きれいな 声が iPadに 入っていません。\n"
            + "設定アプリを ひらき、下の 順で ひらいてください:\n\n"
            + "  設定 (Settings)\n"
            + "  → アクセシビリティ (Accessibility)\n"
            + "  → 読み上げ と 発話 (Read & Speak)\n"
            + "  → 声 (Voices) → 英語 (English)\n\n"
            + "その中から Premium または Enhanced の 声 (Ava / Samantha / Siri など) を\n"
            + "ダウンロードしてください。\n"
            + "(iPadOS 26より 前は Read & Speak の かわりに\n"
            + " Spoken Content / 読み上げコンテンツ と 表示されます。\n"
            + " OSの 言語が 英語の 場合は カッコ内の 表記で 表示されます。)",
        voiceGateOpenSettings: "設定を 開く",
        voiceGateRecheck: "もう一度 たしかめる",
        voiceGateInstalledVoicesTitle: "インストール済みの 英語 voice",
        voiceGateNoVoicesPlaceholder: "(なし)",
        sessionCloseTitle: "今日の クエストを おわる？",
        sessionCloseMessage: "ここまでの きろくは のこるよ",
        sessionCloseKeepGoing: "つづける",
        sessionCloseEnd: "おわる",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 もういちど",
        newRuleGotIt: "分かった",
        newRuleListenAgain: "🔊 もういちど",
        decodingLongPressHint: "ながおしで もういちど 聞けるよ",
        decodingBuildPrompt: "よく きいて ならべよう",
        decodingListenAgain: "🔊 もういちど",
        tileTutorialSlotTitle: "文字を ますに 入れて ことばを つくる",
        tileTutorialSlotBody:
            "ます 1つは 音 1つ。タイルを ながおしして、ますへ ドラッグしよう。",
        tileTutorialAudioTitle: "聞いた 音を つくろう",
        tileTutorialAudioBody:
            "はじめに 🔊 が 音を 聞かせる。きいた 音と 同じに なるよう、"
            + "タイルを ならべよう。聞きなおすときは「もういちど きく」を タップ。",
        tileTutorialNext: "つぎへ",
        tileTutorialTry: "▶ やってみる",
        decodingHelpLabel: "あそびかたを 見る",
        sentencesLongPressHint: "ながおしで もういちど 聞けるよ",
        sentencesListenAgain: "🔊 もういちど",
        feedbackCorrect: "せいかい！",
        feedbackTryAgain: "もう一回",
        micIdlePrompt: "マイクを タップして 読んでね",
        micListening: "聞いてるよ…",
        micAssessing: "チェック中…",
        micDeniedBanner: "マイクが つかえないので ボタンで 答えてね",
        coachingShSubS: "くちびるをまるめて、したのおくをもちあげてみよう。「sh」。",
        coachingShDrift: "もうすこしくちをまるくして、ながくのばしてみよう。「shhhh」。",
        coachingRSubL: "したのさきはどこにもつけないで、おくだけすこし上に。「r」。",
        coachingLSubR: "したのさきを上のはのうらにつけて、そのまま「l」。",
        coachingFSubH: "上のはでしたくちびるに、かるくふれて「fff」。",
        coachingVSubB: "上のはでしたくちびるにふれて、のどをふるわせて「vvv」。",
        coachingThVoicelessSubS: "したのさきをはのあいだにそっと出して「thhh」。",
        coachingThVoicelessSubT: "したのさきをはのあいだにそっと出して、とめずに「thhh」。",
        coachingTSubThVoiceless: "したのさきを上のはのうらにぴたっとつけて、すぐはなして「t」。",
        coachingAeSubSchwa: "口をよこにひろげて、あごを下げて「æ」。",
        // `寄` is G3 (outside the G1+G2 budget) → render as hiragana.
        categorySubstitutionBanner: { target, substitute in
            "今の \(target) は \(substitute) によってたよ"
        },
        categoryDriftBanner: { target in
            "もう少し \(target) らしい音に近づけよう"
        },
        completionTitle: "できた！",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "明日も またね",
        a11yCloseSession: "クエストを おわる",
        a11yMicButton: "マイク",
        a11yStreakChip: { days in "\(days)日 れんぞく" }
    )
}
