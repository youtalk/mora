import MoraCore
import MoraEngines
import SwiftUI

public struct DecodeBoardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.moraStrings) private var strings
    @Bindable public var engine: TileBoardEngine
    public let chainPipStates: [ChainPipState]
    public let incomingRole: ChainRole
    public let speech: SpeechController?
    /// When true, skip the auto-`speakTarget()` on appear. The parent
    /// (SessionContainerView) sets this while the first-time decoding
    /// tutorial cover is up so the underlying board does not speak the
    /// target word under the modal.
    public let audioMuted: Bool
    public var onTrialComplete: (TileBoardTrialResult) -> Void = { _ in }

    @State private var showHelp: Bool = false

    private let tileSize: CGFloat = 128
    private let slotSize: CGFloat = 168

    public init(
        engine: TileBoardEngine,
        chainPipStates: [ChainPipState],
        incomingRole: ChainRole,
        speech: SpeechController? = nil,
        audioMuted: Bool = false,
        onTrialComplete: @escaping (TileBoardTrialResult) -> Void = { _ in }
    ) {
        self.engine = engine
        self.chainPipStates = chainPipStates
        self.incomingRole = incomingRole
        self.speech = speech
        self.audioMuted = audioMuted
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
                listenAgainButton
                pool
            }
            .padding(.horizontal, 24)
            .onChange(of: engine.state) { _, newValue in
                if newValue == .completed {
                    onTrialComplete(engine.result)
                }
            }
        }
        .onAppear {
            engine.apply(.preparationFinished)
            engine.apply(.promptFinished)
            if !audioMuted {
                speakTarget()
            }
        }
        .onChange(of: audioMuted) { _, isMuted in
            // The first-time decoding tutorial covers the board on appear,
            // so onAppear suppresses speakTarget() while audioMuted is
            // true. When the tutorial dismisses, the board has been on
            // screen the whole time but never spoke — fire speakTarget()
            // once on the falling edge so the learner hears the target.
            if !isMuted {
                speakTarget()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MoraTheme.Accent.teal)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .accessibilityLabel(strings.decodingHelpLabel)
        }
        .sheet(isPresented: $showHelp) {
            DecodingTutorialOverlay(mode: .replay) {
                showHelp = false
            }
            .environment(\.moraStrings, strings)
        }
        .onChange(of: showHelp) { _, isShowing in
            if isShowing {
                Task { await speech?.stop() }
            }
        }
    }

    private var prompt: some View {
        Text(promptText)
            .font(MoraType.subtitle())
            .foregroundStyle(MoraTheme.Ink.secondary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .accessibilityLabel(promptText)
    }

    private var slotRow: some View {
        HStack(spacing: 16) {
            ForEach(Array(engine.trial.expectedSlots.enumerated()), id: \.offset) { index, expected in
                SlotView(state: slotState(at: index, expected: expected), size: slotSize, reduceMotion: reduceMotion)
                    .dropDestination(for: String.self) { items, _ in
                        guard let tileID = items.first else { return false }
                        engine.apply(.tileDropped(slotIndex: index, tileID: tileID))
                        return true
                    }
            }
        }
    }

    private var listenAgainButton: some View {
        Button(action: speakTarget) {
            Text(strings.decodingListenAgain)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MoraTheme.Accent.teal)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(MoraTheme.Background.mint, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(speech == nil)
    }

    private func slotState(at index: Int, expected: Grapheme) -> SlotState {
        if let filled = engine.filled[index] {
            let tile = Tile(grapheme: filled)
            if engine.autoFilledSlots.contains(index) { return .autoFilled(tile) }
            if case .change = engine.trial, index != engine.trial.activeSlotIndex { return .locked(tile) }
            return .filled(tile)
        }
        if engine.trial.activeSlotIndex == index { return .emptyActive }
        if case .build = engine.trial { return .emptyActive }  // Build mode: any empty slot is receptive
        return .emptyInactive
    }

    private var pool: some View {
        TilePoolView(tiles: engine.pool, tileSize: tileSize, reduceMotion: reduceMotion)
    }

    private var promptText: String {
        strings.decodingBuildPrompt
    }

    private func speakTarget() {
        speech?.play([.text(engine.trial.word.surface, .normal)])
    }
}
