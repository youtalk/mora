import Foundation
import MoraCore
import Observation

@Observable
@MainActor
public final class TileBoardEngine {
    public private(set) var state: TileBoardState = .preparing
    public let trial: TileBoardTrial
    public private(set) var filled: [Grapheme?]
    public private(set) var buildAttempts: [BuildAttemptRecord] = []

    private let clock: () -> Date
    private let start: Date

    public init(trial: TileBoardTrial, clock: @escaping () -> Date = Date.init) {
        self.trial = trial
        self.clock = clock
        self.start = clock()
        switch trial {
        case let .build(target, _):
            self.filled = Array(repeating: nil as Grapheme?, count: target.slots.count)
        case let .change(_, lockedSlots, _):
            self.filled = lockedSlots.map { Optional($0) }
            if let active = trial.activeSlotIndex { self.filled[active] = nil }
        }
    }

    public func apply(_ event: TileBoardEvent) {
        switch (state, event) {
        case (.preparing, .preparationFinished):
            state = .listening
        case (.listening, .promptFinished):
            state = .building
        default:
            break  // later tasks expand this
        }
    }
}
