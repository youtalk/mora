import SwiftUI
import MoraEngines

public struct YokaiLayerView: View {
    @Bindable var orchestrator: YokaiOrchestrator
    let speech: SpeechController?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(orchestrator: YokaiOrchestrator, speech: SpeechController? = nil) {
        self.orchestrator = orchestrator
        self.speech = speech
    }

    public var body: some View {
        ZStack {
            if let yokai = orchestrator.currentYokai {
                VStack {
                    HStack {
                        Spacer()
                        FriendshipGaugeHUD(percent: orchestrator.currentEncounter?.friendshipPercent ?? 0)
                            .frame(width: 200, height: 18)
                            .padding(.trailing, 24)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        YokaiPortraitCorner(yokai: yokai, sparkleTrigger: orchestrator.lastCorrectTrialID)
                            .frame(width: 140, height: 140)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.top, 24)

                if orchestrator.activeCutscene != nil {
                    YokaiCutsceneOverlay(orchestrator: orchestrator, speech: speech)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: orchestrator.activeCutscene)
        .allowsHitTesting(orchestrator.currentYokai != nil && orchestrator.activeCutscene != nil)
    }
}
