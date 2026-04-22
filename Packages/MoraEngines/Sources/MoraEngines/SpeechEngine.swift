import Foundation

public protocol SpeechEngine: Sendable {
    func listen() async throws -> ASRResult
    func cancel()
}
