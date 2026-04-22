import Foundation

public enum SpeechEvent: Sendable {
    case started
    case partial(String)
    case final(ASRResult)
}
