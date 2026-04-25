import AVFoundation
import MoraCore
import MoraEngines
import SwiftUI

public struct BestiaryDetailView: View {
    let yokai: YokaiDefinition
    let entry: BestiaryEntryEntity
    @State private var player: AVAudioPlayer?
    @State private var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()
    @State private var store: BundledYokaiStore?
    @State private var caption: String = ""
    @Environment(\.moraStrings) private var strings

    public init(yokai: YokaiDefinition, entry: BestiaryEntryEntity) {
        self.yokai = yokai
        self.entry = entry
    }

    public var body: some View {
        VStack(spacing: MoraTheme.Space.lg) {
            YokaiPortraitCorner(yokai: yokai)
                .frame(width: 320, height: 320)
            VStack(spacing: MoraTheme.Space.xs) {
                Text(yokai.grapheme)
                    .font(MoraType.heroWord(96))
                    .foregroundStyle(MoraTheme.Ink.primary)
                Text(yokai.ipa)
                    .font(MoraType.subtitle())
                    .foregroundStyle(MoraTheme.Ink.muted)
            }
            HStack(spacing: MoraTheme.Space.md) {
                ForEach([YokaiClipKey.example1, .example2, .example3], id: \.self) { key in
                    if let word = yokai.voice.clips[key] {
                        Button(action: { play(clip: key) }) {
                            Text(word)
                                .font(MoraType.cta())
                                .foregroundStyle(MoraTheme.Accent.teal)
                                .padding(.vertical, MoraTheme.Space.sm)
                                .padding(.horizontal, MoraTheme.Space.lg)
                                .background(MoraTheme.Background.mint, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button(action: { play(clip: .greet) }) {
                Text(strings.bestiaryPlayGreeting)
                    .font(MoraType.cta())
                    .foregroundStyle(.white)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .padding(.vertical, MoraTheme.Space.md)
                    .frame(minHeight: 72)
                    .background(MoraTheme.Accent.orange, in: .capsule)
            }
            .buttonStyle(.plain)
            if !caption.isEmpty {
                Text(caption)
                    .font(MoraType.bodyReading(size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(MoraTheme.Ink.primary)
                    .padding(.horizontal, MoraTheme.Space.xl)
                    .transition(.opacity)
            }
            Text(strings.bestiaryBefriendedOn(entry.befriendedAt))
                .font(MoraType.label())
                .foregroundStyle(MoraTheme.Ink.muted)
            Spacer()
        }
        .padding(MoraTheme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MoraTheme.Background.page.ignoresSafeArea())
        .onAppear {
            if store == nil { store = try? BundledYokaiStore() }
        }
        .onDisappear {
            synthesizer.stopSpeaking(at: .immediate)
            player?.stop()
        }
    }

    private func play(clip: YokaiClipKey) {
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
        caption = yokai.voice.clips[clip] ?? ""
    }
}
