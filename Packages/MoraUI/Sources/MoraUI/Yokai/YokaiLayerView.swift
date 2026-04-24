import SwiftUI
import MoraEngines

public struct YokaiLayerView: View {
    @Bindable var orchestrator: YokaiOrchestrator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(orchestrator: YokaiOrchestrator) {
        self.orchestrator = orchestrator
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
                        YokaiPortraitCorner(yokai: yokai)
                            .frame(width: 80, height: 80)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.top, 24)

                if orchestrator.activeCutscene != nil {
                    YokaiCutsceneOverlay(orchestrator: orchestrator)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: orchestrator.activeCutscene)
        .allowsHitTesting(orchestrator.currentYokai != nil && orchestrator.activeCutscene != nil)
    }
}
