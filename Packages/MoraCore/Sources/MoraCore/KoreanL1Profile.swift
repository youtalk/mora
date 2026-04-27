// Packages/MoraCore/Sources/MoraCore/KoreanL1Profile.swift
import Foundation

/// Korean L1 profile. Single level-invariant `MoraStrings` table —
/// at primary grade 1–2 ages (target 6–8), Korean has no script-difficulty
/// ladder analogous to JP's kanji ladder. See spec §6.2.
public struct KoreanL1Profile: L1Profile {
    public let identifier = "ko"
    public let characterSystem: CharacterSystem = .alphabetic
    public let interferencePairs: [PhonemeConfusionPair] = Self.koInterference
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

    public func uiStrings(at level: LearnerLevel) -> MoraStrings { Self.stringsKidKo }

    public func interestCategoryDisplayName(key: String, at level: LearnerLevel) -> String {
        switch key {
        case "animals": return "동물"
        case "dinosaurs": return "공룡"
        case "vehicles": return "탈것"
        case "space": return "우주"
        case "sports": return "스포츠"
        case "robots": return "로봇"
        default: return key
        }
    }

    /// KO L1 → EN L2 phonological transfer pairs. See spec §6.4 for sources
    /// (Ko 2009, Cho & Park 2006, Yang 1996).
    private static let koInterference: [PhonemeConfusionPair] = [
        PhonemeConfusionPair(
            tag: "ko_f_p_sub",
            from: Phoneme(ipa: "f"), to: Phoneme(ipa: "p"),
            examples: ["fan/pan", "fox/pox", "fish/pish"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_v_b_sub",
            from: Phoneme(ipa: "v"), to: Phoneme(ipa: "b"),
            examples: ["vat/bat", "very/berry", "van/ban"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_th_voiceless_s_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "s"),
            examples: ["thin/sin", "thick/sick"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_th_voiceless_t_sub",
            from: Phoneme(ipa: "θ"), to: Phoneme(ipa: "t"),
            examples: ["thin/tin", "three/tree"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_z_dz_sub",
            from: Phoneme(ipa: "z"), to: Phoneme(ipa: "dʒ"),
            examples: ["zoo/Jew", "zip/Jip"], bidirectional: false),
        PhonemeConfusionPair(
            tag: "ko_r_l_swap",
            from: Phoneme(ipa: "r"), to: Phoneme(ipa: "l"),
            examples: ["right/light", "rock/lock"], bidirectional: true),
        PhonemeConfusionPair(
            tag: "ko_ae_e_conflate",
            from: Phoneme(ipa: "æ"), to: Phoneme(ipa: "ɛ"),
            examples: ["bad/bed", "cat/ket"], bidirectional: true),
        PhonemeConfusionPair(
            tag: "ko_sh_drift_target",
            from: Phoneme(ipa: "ʃ"), to: Phoneme(ipa: "ʃ"),
            examples: ["ship", "shop", "fish"], bidirectional: false),
    ]

    /// Bestiary date formatter — Korean locale, gregorian calendar.
    /// Renders e.g. "2026년 4월 26일" at `.long` style.
    private static let bestiaryDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateStyle = .long
        return f
    }()

    /// Single level-invariant table — KO has no script ladder at this age range.
    /// Authoring rules: simple-vocab register from 한국 초등 1–2학년 교과서,
    /// 반말 informal kid-directed form, 한자 not used. See spec §6.2.1.
    private static let stringsKidKo = MoraStrings(
        ageOnboardingPrompt: "몇 살이야?",
        ageOnboardingCTA: "▶ 시작하기",
        welcomeTitle: "영어 소리, 같이 배워요",
        welcomeCTA: "시작하기",
        namePrompt: "이름이 뭐야?",
        nameSkip: "건너뛰기",
        nameCTA: "다음",
        interestPrompt: "좋아하는 것 3개 골라봐",
        interestCTA: "다음",
        permissionTitle: "목소리를 들을게",
        permissionBody: "네가 읽은 말을 듣고, 맞는지 확인해.",
        permissionAllow: "허락하기",
        permissionNotNow: "나중에",
        yokaiIntroConceptTitle: "소리에는 친구가 있어",
        yokaiIntroConceptBody:
            "영어의 소리 하나하나에 Yokai가 살고 있어. "
            + "친해지려면 그 소리를 잘 듣고 말로 만들어 보자.",
        yokaiIntroTodayTitle: "이번 주의 친구",
        yokaiIntroTodayBody: "이번 주는 이 소리를 같이 연습하자.",
        yokaiIntroSessionTitle: "한 번의 진행 방법",
        yokaiIntroSessionBody: "한 번에 약 10분.",
        yokaiIntroSessionStep1: "듣기",
        yokaiIntroSessionStep2: "맞추기",
        yokaiIntroSessionStep3: "말하기",
        yokaiIntroProgressTitle: "5번이면 친구가 돼",
        yokaiIntroProgressBody:
            "Yokai와 5번 연습하면 친해질 수 있어. "
            + "하루 한 번이라도 좋아.",
        yokaiIntroNext: "다음",
        yokaiIntroBegin: "▶ 시작하기",
        yokaiIntroClose: "닫기",
        homeTodayQuest: "오늘의 퀘스트",
        homeStart: "▶ 시작하기",
        homeDurationPill: { minutes in "\(minutes)분" },
        homeWordsPill: { count in "\(count)글자" },
        homeSentencesPill: { count in "\(count)문장" },
        bestiaryLinkLabel: "친구 도감",
        bestiaryPlayGreeting: "🔊 인사",
        bestiaryBefriendedOn: { date in
            "친해진 날 \(Self.bestiaryDateFormatter.string(from: date))"
        },
        homeRecapLink: "노는 법",
        voiceGateTitle: "영어 목소리를 받아주세요",
        voiceGateBody:
            "Mora에서 쓸 깨끗한 목소리가 iPad에 없어요.\n"
            + "설정 앱을 열고, 아래 순서로 들어가세요:\n\n"
            + "  설정 (Settings)\n"
            + "  → 손쉬운 사용 (Accessibility)\n"
            + "  → 읽기 및 말하기 (Read & Speak)\n"
            + "  → 음성 (Voices) → 영어 (English)\n\n"
            + "그중에서 Premium 또는 Enhanced 음성 (Ava / Samantha / Siri 등) 을\n"
            + "다운로드해 주세요.\n"
            + "(iPadOS 26 이전에는 Read & Speak 대신\n"
            + " Spoken Content / 발화 콘텐츠 라고 표시됩니다.\n"
            + " OS 언어가 영어인 경우 괄호 안의 표기로 표시됩니다.)",
        voiceGateOpenSettings: "설정 열기",
        voiceGateRecheck: "다시 확인하기",
        voiceGateInstalledVoicesTitle: "설치된 영어 voice",
        voiceGateNoVoicesPlaceholder: "(없음)",
        sessionCloseTitle: "오늘의 퀘스트를 끝낼까?",
        sessionCloseMessage: "여기까지의 기록은 남아.",
        sessionCloseKeepGoing: "계속하기",
        sessionCloseEnd: "끝내기",
        sessionWordCounter: { current, total in "\(current)/\(total)" },
        sessionSentenceCounter: { current, total in "\(current)/\(total)" },
        warmupListenAgain: "🔊 한 번 더",
        newRuleGotIt: "알았어",
        newRuleListenAgain: "🔊 한 번 더",
        decodingLongPressHint: "길게 누르면 다시 들을 수 있어.",
        decodingBuildPrompt: "잘 듣고 맞춰보자",
        decodingListenAgain: "🔊 한 번 더",
        tileTutorialSlotTitle: "글자를 칸에 넣어 말을 만들어",
        tileTutorialSlotBody:
            "칸 하나는 소리 하나. 타일을 길게 눌러 칸으로 끌어다 놔.",
        tileTutorialAudioTitle: "들은 소리를 만들자",
        tileTutorialAudioBody:
            "처음에 🔊가 소리를 들려줘. 들은 소리와 같아지도록 "
            + "타일을 맞춰. 다시 듣고 싶으면 \"한 번 더 듣기\"를 눌러.",
        tileTutorialNext: "다음",
        tileTutorialTry: "▶ 해보기",
        decodingHelpLabel: "노는 법 보기",
        sentencesListenAgain: "🔊 한 번 더",
        feedbackCorrect: "정답!",
        feedbackTryAgain: "한 번 더",
        micButtonLabel: "말하기",
        micButtonHintTapToStart: "탭해서 녹음 시작하기",
        micButtonHintTapToStop: "탭해서 녹음 멈추기",
        micIdlePrompt: "마이크를 누르고 읽어봐",
        micListening: "듣고 있어…",
        micAssessing: "확인 중…",
        micDeniedBanner: "마이크를 못 써서 버튼으로 대답해 줘.",
        coachingShSubS: "입술을 둥글게 하고 혀 안쪽을 올려서 \"sh\".",
        coachingShDrift: "입을 좀 더 둥글게 하고 길게 \"shhhh\".",
        coachingRSubL: "혀끝은 어디에도 닿지 않게, 안쪽만 살짝 올려서 \"r\".",
        coachingLSubR: "혀끝을 윗니 뒤에 대고 그대로 \"l\".",
        coachingFSubH: "윗니로 아랫입술을 살짝 누르고 \"fff\".",
        coachingVSubB: "윗니로 아랫입술을 누르고 목을 떨려서 \"vvv\".",
        coachingThVoicelessSubS: "혀끝을 이 사이에 살짝 내고 \"thhh\".",
        coachingThVoicelessSubT: "혀끝을 이 사이에 살짝 내고 멈추지 말고 \"thhh\".",
        coachingTSubThVoiceless: "혀끝을 윗니 뒤에 딱 붙였다가 바로 떼서 \"t\".",
        coachingAeSubSchwa: "입을 옆으로 벌리고 턱을 내려서 \"æ\".",
        categorySubstitutionBanner: { target, substitute in
            "지금의 \(target)는 \(substitute) 쪽이었어"
        },
        categoryDriftBanner: { target in
            "조금 더 \(target)다운 소리에 가까워지자"
        },
        completionTitle: "잘했어!",
        completionScore: { correct, total in "\(correct)/\(total)" },
        completionComeBack: "내일 또 만나요",
        a11yCloseSession: "퀘스트를 끝내기",
        a11yMicButton: "마이크",
        a11yStreakChip: { days in "\(days)일 연속" }
    )
}
