import Foundation

public protocol SpeechEngine: Sendable {
    func listen() -> AsyncThrowingStream<SpeechEvent, Error>
    func cancel()
}
