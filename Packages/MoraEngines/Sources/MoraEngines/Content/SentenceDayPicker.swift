import Foundation
import MoraCore

/// Per-day picker over the bundled sentence library. The library JSON authors
/// pre-trimmed Day 1..4 variants in each sentence's `byDay` object; this
/// helper just looks them up by integer day. Day 5 (or any day with no
/// authored variant) returns the full sentence unchanged.
public enum SentenceDayPicker {
    public static func pick(
        full: DecodeSentence,
        byDay: [String: DecodeSentence]?,
        dayInWeek: Int
    ) -> DecodeSentence {
        guard dayInWeek >= 1, dayInWeek <= 4 else { return full }
        return byDay?[String(dayInWeek)] ?? full
    }
}
