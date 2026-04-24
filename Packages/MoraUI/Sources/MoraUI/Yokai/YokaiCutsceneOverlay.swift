import AVFoundation
import MoraCore
import MoraEngines
import SwiftUI

public struct YokaiCutsceneOverlay: View {
    @Bindable var orchestrator: YokaiOrchestrator

    // Friday choreography state
    @State private var fridayPhase: Int = 0
    @State private var washiProgress: Double = 0
    @State private var choreographyTask: Task<Void, Never>?

    // Audio playback
    @State private var player: AVAudioPlayer?
    @State private var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    @State private var store: BundledYokaiStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(orchestrator: YokaiOrchestrator) {
        self.orchestrator = orchestrator
    }

    private var bgOpacity: Double {
        fridayPhase >= 1 ? 0.65 : 0.35
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(bgOpacity).ignoresSafeArea()
            if let yokai = orchestrator.currentYokai {
                switch orchestrator.activeCutscene {
                case .fridayClimax:
                    fridayClimax(for: yokai)
                default:
                    simpleStack(for: yokai)
                }
            }
        }
    }

    @ViewBuilder
    private func fridayClimax(for yokai: YokaiDefinition) -> some View {
        ZStack {
            WashiCardMorph(progress: $washiProgress)
                .frame(width: 280, height: 280)

            VStack(spacing: 24) {
                YokaiPortraitCorner(yokai: yokai)
                    .frame(width: 240, height: 240)
                    .scaleEffect(reduceMotion ? 1.0 : (fridayPhase >= 2 ? 1.25 : 1.0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: fridayPhase)

                if fridayPhase >= 3 {
                    Text(yokai.voice.clips[.fridayAcknowledge] ?? "")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }

                Button("Tap to continue") {
                    choreographyTask?.cancel()
                    stopAudio()
                    orchestrator.dismissCutscene()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            if store == nil { store = try? BundledYokaiStore() }
            fridayPhase = 0
            washiProgress = 0
            if reduceMotion {
                choreographyTask = Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        fridayPhase = 4
                        washiProgress = 1.0
                    }
                    play(clip: .fridayAcknowledge, yokai: yokai)
                }
            } else {
                choreographyTask = Task { @MainActor in
                    // Phase 1: deepen bg (0.6s)
                    do { try await Task.sleep(for: .seconds(0.6)) } catch { return }
                    withAnimation(.easeIn(duration: 0.3)) { fridayPhase = 1 }

                    // Phase 2: enlarge portrait (0.6s -> 1.4s)
                    do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
                    withAnimation(.easeInOut(duration: 0.8)) { fridayPhase = 2 }

                    // Phase 3: show subtitle + play voice (1.4s -> 4.4s)
                    do { try await Task.sleep(for: .seconds(1.0)) } catch { return }
                    withAnimation(.easeIn(duration: 0.4)) { fridayPhase = 3 }
                    play(clip: .fridayAcknowledge, yokai: yokai)

                    // Phase 4: morph washi card (4.4s -> 7.0s)
                    do { try await Task.sleep(for: .seconds(2.0)) } catch { return }
                    withAnimation(.easeInOut(duration: 2.6)) {
                        fridayPhase = 4
                        washiProgress = 1.0
                    }
                }
            }
        }
        .onDisappear {
            choreographyTask?.cancel()
            choreographyTask = nil
            stopAudio()
        }
    }

    @ViewBuilder
    private func simpleStack(for yokai: YokaiDefinition) -> some View {
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

    private func play(clip: YokaiClipKey, yokai: YokaiDefinition) {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
        if let store, let url = store.voiceClipURL(for: yokai.id, clip: clip) {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        } else if let text = yokai.voice.clips[clip] {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }

    private func stopAudio() {
        synthesizer.stopSpeaking(at: .immediate)
        player?.stop()
    }
}
