import MoraCore
import MoraEngines
import SwiftUI

public struct DecodeBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable public var engine: TileBoardEngine
    public let target: Target
    public let chainPipStates: [ChainPipState]
    public let incomingRole: ChainRole
    public let isFirstTrialOfPhase: Bool
    public var onTrialComplete: (TileBoardTrialResult) -> Void = { _ in }

    @State private var betaOverlayVisible: Bool = false

    public init(
        engine: TileBoardEngine,
        target: Target,
        chainPipStates: [ChainPipState],
        incomingRole: ChainRole,
        isFirstTrialOfPhase: Bool = false,
        onTrialComplete: @escaping (TileBoardTrialResult) -> Void = { _ in }
    ) {
        self.engine = engine
        self.target = target
        self.chainPipStates = chainPipStates
        self.incomingRole = incomingRole
        self.isFirstTrialOfPhase = isFirstTrialOfPhase
        self.onTrialComplete = onTrialComplete
    }

    public var body: some View {
        ZStack {
            ChainTransitionOverlay(incomingRole: incomingRole, reduceMotion: reduceMotion)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                ChainProgressRibbon(states: chainPipStates)
                prompt
                slotRow
                pool
            }
            .padding(.horizontal, 24)
            .onChange(of: engine.state) { oldValue, newValue in
                if newValue == .completed {
                    onTrialComplete(engine.result)
                }
            }
            if betaOverlayVisible {
                Text(engine.trial.word.surface)
                    .font(.openDyslexic(size: 72))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            if isFirstTrialOfPhase {
                betaOverlayVisible = true
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await MainActor.run {
                        withAnimation(reduceMotion ? .linear(duration: 0.12) : .easeOut(duration: 0.35)) {
                            betaOverlayVisible = false
                        }
                        engine.apply(.preparationFinished)
                        engine.apply(.promptFinished)
                    }
                }
            } else {
                engine.apply(.preparationFinished)
                engine.apply(.promptFinished)
            }
        }
    }

    private var prompt: some View {
        Text(promptText)
            .font(.headline)
            .foregroundColor(.secondary)
            .accessibilityLabel(promptText)
    }

    private var slotRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(engine.trial.expectedSlots.enumerated()), id: \.offset) { index, expected in
                SlotView(state: slotState(at: index, expected: expected), reduceMotion: reduceMotion)
                    .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                        _ = providers.first?.loadObject(ofClass: NSString.self) { (text, _) in
                            guard let tileID = text as? String else { return }
                            Task { @MainActor in
                                engine.apply(.tileDropped(slotIndex: index, tileID: tileID))
                            }
                        }
                        return true
                    }
            }
        }
    }

    private func slotState(at index: Int, expected: Grapheme) -> SlotState {
        if let filled = engine.filled[index] {
            let tile = Tile(grapheme: filled)
            if engine.autoFilled { return .autoFilled(tile) }
            if case .change = engine.trial, index != engine.trial.activeSlotIndex { return .locked(tile) }
            return .filled(tile)
        }
        if engine.trial.activeSlotIndex == index { return .emptyActive }
        if case .build = engine.trial { return .emptyActive }  // Build mode: any empty slot is receptive
        return .emptyInactive
    }

    private var pool: some View {
        TilePoolView(tiles: engine.pool, reduceMotion: reduceMotion)
    }

    private var promptText: String {
        switch engine.trial {
        case .build: return "Listen and build the word"
        case let .change(target, _, _):
            return "Change \(target.oldGrapheme.letters) to \(target.newGrapheme.letters)"
        }
    }
}
