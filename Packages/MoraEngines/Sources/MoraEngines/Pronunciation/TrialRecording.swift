import Foundation
import MoraCore

public struct TrialRecording: Sendable, Hashable, Codable {
    public let asr: ASRResult
    public let audio: AudioClip
    public let buildAttempts: [BuildAttemptRecord]
    public let scaffoldLevel: Int

    public init(
        asr: ASRResult,
        audio: AudioClip,
        buildAttempts: [BuildAttemptRecord] = [],
        scaffoldLevel: Int = 0
    ) {
        self.asr = asr
        self.audio = audio
        self.buildAttempts = buildAttempts
        self.scaffoldLevel = scaffoldLevel
    }
}
