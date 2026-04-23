import Foundation
import MoraCore
import MoraEngines

@MainActor
public final class FakeTileBoardEngine {
    public private(set) var recordedEvents: [TileBoardEvent] = []
    public var preprogrammedResult: TileBoardTrialResult?

    public init(preprogrammedResult: TileBoardTrialResult? = nil) {
        self.preprogrammedResult = preprogrammedResult
    }

    public func apply(_ event: TileBoardEvent) {
        recordedEvents.append(event)
    }

    public var result: TileBoardTrialResult {
        preprogrammedResult
            ?? TileBoardTrialResult(
                word: Word(surface: "", graphemes: [], phonemes: []),
                buildAttempts: [],
                scaffoldLevel: 0,
                ttsHintIssued: false,
                poolReducedToTwo: false,
                autoFilled: false
            )
    }
}
