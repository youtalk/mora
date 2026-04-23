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
    public private(set) var scaffoldLevel: Int = 0
    public private(set) var ttsHintIssued: Bool = false
    public private(set) var poolReducedToTwo: Bool = false
    public private(set) var autoFilled: Bool = false
    public private(set) var lastIntervention: ScaffoldStep?
    public private(set) var pool: [Tile]

    private var slotMisses: [Int: Int] = [:]
    private let clock: () -> Date
    private let start: Date

    public init(trial: TileBoardTrial, clock: @escaping () -> Date = Date.init) {
        self.trial = trial
        self.clock = clock
        self.start = clock()
        self.pool = trial.pool
        switch trial {
        case let .build(target, _):
            self.filled = Array(repeating: nil as Grapheme?, count: target.slots.count)
        case let .change(_, lockedSlots, _):
            self.filled = lockedSlots.map { Optional($0) }
            if let active = trial.activeSlotIndex { self.filled[active] = nil }
        }
    }

    public func slotMissCount(for slot: Int) -> Int { slotMisses[slot] ?? 0 }

    public func apply(_ event: TileBoardEvent) {
        switch (state, event) {
        case (.preparing, .preparationFinished):
            state = .listening
        case (.listening, .promptFinished):
            state = .building
        case (.building, let .tileDropped(slotIndex, tileID)):
            handleDrop(slotIndex: slotIndex, tileID: tileID)
        case (.completed, .completionAnimationFinished):
            state = .speaking
        case (.speaking, .utteranceRecorded):
            state = .feedback
        case (.feedback, .feedbackDismissed):
            state = .transitioning
        default:
            break
        }
    }

    public var result: TileBoardTrialResult {
        TileBoardTrialResult(
            word: trial.word,
            buildAttempts: buildAttempts,
            scaffoldLevel: scaffoldLevel,
            ttsHintIssued: ttsHintIssued,
            poolReducedToTwo: poolReducedToTwo,
            autoFilled: autoFilled
        )
    }

    private func handleDrop(slotIndex: Int, tileID: String) {
        guard filled.indices.contains(slotIndex), filled[slotIndex] == nil else { return }
        if let active = trial.activeSlotIndex, active != slotIndex { return }
        let expected = trial.expectedSlots[slotIndex]
        let dropped = Grapheme(letters: tileID)
        let offset = clock().timeIntervalSince(start)
        let correct = dropped == expected
        buildAttempts.append(BuildAttemptRecord(
            slotIndex: slotIndex,
            tileDropped: dropped,
            wasCorrect: correct,
            timestampOffset: offset
        ))
        if correct {
            filled[slotIndex] = expected
            lastIntervention = nil
            if filled.allSatisfy({ $0 != nil }) { state = .completed }
            return
        }
        let nextMisses = (slotMisses[slotIndex] ?? 0) + 1
        slotMisses[slotIndex] = nextMisses
        let distractor = pool.first(where: { $0.grapheme != expected })?.grapheme ?? expected
        let step = ChainScaffoldLadder.next(missCount: nextMisses, correct: expected, distractor: distractor)
        applyScaffold(step: step, slotIndex: slotIndex, expected: expected)
    }

    private func applyScaffold(step: ScaffoldStep, slotIndex: Int, expected: Grapheme) {
        lastIntervention = step
        scaffoldLevel = max(scaffoldLevel, Self.levelFor(step: step))
        switch step {
        case .bounceBack:
            break
        case .ttsHint:
            ttsHintIssued = true
        case let .reducePool(correct, distractor):
            poolReducedToTwo = true
            pool = [Tile(grapheme: correct), Tile(grapheme: distractor)]
        case .autoFill:
            autoFilled = true
            filled[slotIndex] = expected
            if filled.allSatisfy({ $0 != nil }) { state = .completed }
        }
    }

    private static func levelFor(step: ScaffoldStep) -> Int {
        switch step {
        case .bounceBack: return 1
        case .ttsHint: return 2
        case .reducePool: return 3
        case .autoFill: return 4
        }
    }
}
