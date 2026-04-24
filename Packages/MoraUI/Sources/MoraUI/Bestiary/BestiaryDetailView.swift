import AVFoundation
import MoraCore
import MoraEngines
import SwiftUI

public struct BestiaryDetailView: View {
    let yokai: YokaiDefinition
    let entry: BestiaryEntryEntity
    @State private var player: AVAudioPlayer?
    @State private var synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer()

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
            Button("🔊 Play greeting") { play(clip: .greet) }
                .buttonStyle(.borderedProminent)
            Text(
                "Befriended: \(entry.befriendedAt.formatted(date: .abbreviated, time: .omitted))"
            )
            .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func play(clip: YokaiClipKey) {
        guard let store = try? BundledYokaiStore() else { return }
        if let url = store.voiceClipURL(for: yokai.id, clip: clip) {
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        } else if let text = yokai.voice.clips[clip] {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }
}
