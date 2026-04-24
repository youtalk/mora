import Foundation

public enum YokaiClipKey: String, CaseIterable, Codable, Sendable {
    case phoneme
    case example1 = "example_1"
    case example2 = "example_2"
    case example3 = "example_3"
    case greet
    case encourage
    case gentleRetry = "gentle_retry"
    case fridayAcknowledge = "friday_acknowledge"
}
