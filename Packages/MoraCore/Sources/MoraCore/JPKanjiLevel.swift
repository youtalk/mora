// Packages/MoraCore/Sources/MoraCore/JPKanjiLevel.swift
import Foundation

/// Canonical Japanese elementary kanji sets used to gate alpha JP UI
/// strings against what a Japanese 8-year-old (end of 小学2年) has
/// actually been taught. Source: MEXT 学習指導要領 小学校 別表
/// 学年別漢字配当表 (2017 告示, 2020-04-01 施行).
public enum JPKanjiLevel {
    /// 80 kanji taught in JP elementary grade 1.
    public static let grade1: Set<Character> = [
        "一", "右", "雨", "円", "王", "音", "下", "火", "花", "貝",
        "学", "気", "九", "休", "玉", "金", "空", "月", "犬", "見",
        "五", "口", "校", "左", "三", "山", "子", "四", "糸", "字",
        "耳", "七", "車", "手", "十", "出", "女", "小", "上", "森",
        "人", "水", "正", "生", "青", "夕", "石", "赤", "千", "川",
        "先", "早", "草", "足", "村", "大", "男", "竹", "中", "虫",
        "町", "天", "田", "土", "二", "日", "入", "年", "白", "八",
        "百", "文", "木", "本", "名", "目", "立", "力", "林", "六",
    ]

    /// 160 kanji taught in JP elementary grade 2.
    public static let grade2: Set<Character> = [
        "引", "羽", "雲", "園", "遠", "何", "科", "夏", "家", "歌",
        "画", "回", "会", "海", "絵", "外", "角", "楽", "活", "間",
        "丸", "岩", "顔", "汽", "記", "帰", "弓", "牛", "魚", "京",
        "強", "教", "近", "兄", "形", "計", "元", "言", "原", "戸",
        "古", "午", "後", "語", "工", "公", "広", "交", "光", "考",
        "行", "高", "黄", "合", "谷", "国", "黒", "今", "才", "細",
        "作", "算", "止", "市", "矢", "姉", "思", "紙", "寺", "自",
        "時", "室", "社", "弱", "首", "秋", "週", "春", "書", "少",
        "場", "色", "食", "心", "新", "親", "図", "数", "西", "声",
        "星", "晴", "切", "雪", "船", "線", "前", "組", "走", "多",
        "太", "体", "台", "地", "池", "知", "茶", "昼", "長", "鳥",
        "朝", "直", "通", "弟", "店", "点", "電", "刀", "冬", "当",
        "東", "答", "頭", "同", "道", "読", "内", "南", "肉", "馬",
        "売", "買", "麦", "半", "番", "父", "風", "分", "聞", "米",
        "歩", "母", "方", "北", "毎", "妹", "万", "明", "鳴", "毛",
        "門", "夜", "野", "友", "用", "曜", "来", "里", "理", "話",
    ]

    /// Cumulative G1+G2 (240 characters). The alpha JP strings render
    /// a word in kanji only when every component character is in this set.
    public static let grade1And2: Set<Character> = grade1.union(grade2)
}
