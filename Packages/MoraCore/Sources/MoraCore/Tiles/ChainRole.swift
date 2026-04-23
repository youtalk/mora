import Foundation

public enum ChainRole: String, Hashable, Codable, Sendable {
    case warmup
    case targetIntro
    case mixedApplication
}
