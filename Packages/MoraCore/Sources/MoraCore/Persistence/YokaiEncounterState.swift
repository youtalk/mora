import Foundation

public enum YokaiEncounterState: String, Codable, CaseIterable, Sendable {
    case upcoming
    case active
    case befriended
    case carryover
}
