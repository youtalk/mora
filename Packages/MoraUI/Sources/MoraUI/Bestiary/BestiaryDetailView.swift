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

    public init(yokai: YokaiDefinition, entry: BestiaryEntryEntity) {
        self.yokai = yokai
        self.entry = entry
    }

    public var body: some View {
        VStack(spacing: 24) {
            YokaiPortraitCorner(yokai: yokai).frame(width: 200, height: 200)
            VStack(spacing: 4) {
                Text(yokai.grapheme).font(.largeTitle.weight(.bold))
                Text(yokai.ipa).font(.title3).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                ForEach([YokaiClipKey.example1, .example2, .example3], id: \.self) { key in
                    if let word = yokai.voice.clips[key] {
                        Button(word) { play(clip: key) }
                            .buttonStyle(.bordered)
                    }
                }
            }
            Button(action: { play(clip: .greet) }) {
                Label("Play greeting", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderedProminent)
            if !caption.isEmpty {
                Text(caption)
                    .font(MoraType.bodyReading(size: 32))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            }
            Text(
                "Befriended: \(entry.befriendedAt.formatted(date: .abbreviated, time: .omitted))"
            )
            .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
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
