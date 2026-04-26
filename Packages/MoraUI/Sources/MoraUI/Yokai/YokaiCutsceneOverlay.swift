import AVFoundation
import MoraCore
import MoraEngines
import SwiftUI

public struct YokaiCutsceneOverlay: View {
    @Bindable var orchestrator: YokaiOrchestrator
    let speech: SpeechController?

    @State private var fridayPhase: Int = 0
    @State private var washiProgress: Double = 0
    @State private var choreographyTask: Task<Void, Never>?
    @State private var didHapticFriday = false
    @State private var player: AVAudioPlayer?
    @State private var store: BundledYokaiStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.moraStrings) private var strings

    public init(orchestrator: YokaiOrchestrator, speech: SpeechController? = nil) {
        self.orchestrator = orchestrator
        self.speech = speech
    }

    private var bgOpacity: Double {
        fridayPhase >= 1 ? 0.92 : 0.85
    }

    public var body: some View {
        ZStack {
            // The full-screen black tint is part of the cutscene treatment
            // and must NOT render during `.mondayIntro` — `WeeklyIntroView`
            // owns that case (via `SessionContainerView`'s `.warmup` gate)
            // and would otherwise be dimmed by the overlay sitting on top.
            // Keeping the tint inside the same conditional as the content
            // means the overlay collapses to an empty `ZStack` for Monday
            // intro, with no visible footprint and no hit-testing surface.
            if let yokai = orchestrator.currentYokai,
                orchestrator.activeCutscene?.isMondayIntro != true
            {
                Color.black.opacity(bgOpacity).ignoresSafeArea()
                switch orchestrator.activeCutscene {
                case .fridayClimax:
                    fridayClimax(for: yokai)
                        .accessibilityIdentifier(Self.contentIdentifier)
                default:
                    simpleStack(for: yokai)
                        .accessibilityIdentifier(Self.contentIdentifier)
                }
            }
        }
    }

    /// Accessibility identifier on the cutscene's rendered content stack.
    /// Tests use this to assert which arm of the body rendered (or that
    /// nothing rendered at all) without depending on UIView description
    /// strings, which do not surface SwiftUI text content.
    static let contentIdentifier = "yokai-cutscene-overlay-content"

    @ViewBuilder
    private func fridayClimax(for yokai: YokaiDefinition) -> some View {
        ZStack {
            WashiCardMorph(progress: $washiProgress)
                .frame(width: 280, height: 280)

            VStack(spacing: 24) {
                YokaiPortraitCorner(yokai: yokai)
                    .frame(width: 360, height: 360)
                    .scaleEffect(reduceMotion ? 1.0 : (fridayPhase >= 2 ? 1.25 : 1.0))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: fridayPhase)

                if fridayPhase >= 3 {
                    Text(yokai.voice.clips[.fridayAcknowledge] ?? "")
                        .font(MoraType.bodyReading(size: 32))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .transition(.opacity)
                }

                HeroCTA(title: strings.sessionCloseKeepGoing) {
                    choreographyTask?.cancel()
                    stopAudio()
                    orchestrator.dismissCutscene()
                }
            }
        }
        .onAppear {
            if store == nil { store = try? BundledYokaiStore() }
            fridayPhase = 0
            washiProgress = 0
            if !didHapticFriday {
                didHapticFriday = true
                YokaiHaptics.fridaySuccess()
            }
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
            didHapticFriday = false
            stopAudio()
        }
    }

    @ViewBuilder
    private func simpleStack(for yokai: YokaiDefinition) -> some View {
        VStack(spacing: 24) {
            YokaiPortraitCorner(yokai: yokai)
                .frame(width: 360, height: 360)
            Text(subtitleText(for: orchestrator.activeCutscene, yokai: yokai))
                .font(MoraType.bodyReading(size: 32))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
            HeroCTA(title: strings.sessionCloseKeepGoing) {
                orchestrator.dismissCutscene()
            }
        }
    }

    private func subtitleText(for cutscene: YokaiCutscene?, yokai: YokaiDefinition) -> String {
        switch cutscene {
        case .fridayClimax:
            return yokai.voice.clips[.fridayAcknowledge] ?? ""
        case .srsCameo:
            return yokai.voice.clips[.encourage] ?? ""
        case .mondayIntro, .sessionStart, .none:
            return ""
        }
    }

    private func play(clip: YokaiClipKey, yokai: YokaiDefinition) {
        player?.stop()
        if let store, let url = store.voiceClipURL(for: yokai.id, clip: clip) {
            // Drain any in-flight TTS before starting the bundled clip so the two
            // sources don't briefly overlap on a cold cut from speech to audio file.
            Task { @MainActor in
                await speech?.stop()
                player = try? AVAudioPlayer(contentsOf: url)
                player?.play()
            }
        } else if let text = yokai.voice.clips[clip] {
            player = nil
            speech?.play([.text(text, .normal)])
        }
    }

    private func stopAudio() {
        Task { @MainActor in await speech?.stop() }
        player?.stop()
    }
}
