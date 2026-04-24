import Foundation

/// Who produced the fixture. Adult fixtures are checked into the engines
/// package for regression coverage; child fixtures stay on the developer's
/// laptop per the bench-and-calibration spec.
public enum SpeakerTag: String, Codable, Sendable, Hashable {
    case adult
    case child
}
