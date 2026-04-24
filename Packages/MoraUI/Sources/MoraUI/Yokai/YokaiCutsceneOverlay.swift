import MoraCore
import MoraEngines
import SwiftUI

public struct YokaiCutsceneOverlay: View {
    @Bindable var orchestrator: YokaiOrchestrator

    public init(orchestrator: YokaiOrchestrator) {
        self.orchestrator = orchestrator
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            if let yokai = orchestrator.currentYokai {
                VStack(spacing: 24) {
                    YokaiPortraitCorner(yokai: yokai)
                        .frame(width: 240, height: 240)
                    Text(subtitleText(for: orchestrator.activeCutscene, yokai: yokai))
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                    Button("Tap to continue") { orchestrator.dismissCutscene() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func subtitleText(for cutscene: YokaiCutscene?, yokai: YokaiDefinition) -> String {
        switch cutscene {
        case .mondayIntro:
            return yokai.voice.clips[.greet] ?? ""
        case .fridayClimax:
            return yokai.voice.clips[.fridayAcknowledge] ?? ""
        case .srsCameo:
            return yokai.voice.clips[.encourage] ?? ""
        case .sessionStart, .none:
            return ""
        }
    }
}
