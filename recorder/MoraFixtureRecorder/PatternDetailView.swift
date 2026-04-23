import MoraFixtures
import SwiftUI

struct PatternDetailView: View {

    @Bindable var store: RecorderStore
    let pattern: FixturePattern

    var body: some View {
        Form {
            Section("Pattern") {
                LabeledContent("Word", value: pattern.wordSurface)
                LabeledContent("Target", value: "/\(pattern.targetPhonemeIPA)/")
                LabeledContent("Expected", value: pattern.expectedLabel.rawValue)
                if let sub = pattern.substitutePhonemeIPA {
                    LabeledContent("Substitute", value: "/\(sub)/")
                }
                LabeledContent(
                    "Sequence",
                    value: pattern.phonemeSequenceIPA.joined(separator: " "))
                LabeledContent(
                    "Target index", value: "\(pattern.targetPhonemeIndex)")
            }

            Section("Capture") {
                Button(store.isRecording ? "Stop" : "Record") {
                    store.toggleRecording()
                }
                Button("Save") {
                    store.save(pattern: pattern)
                }
                .disabled(!store.hasCapturedSamples)
                if case let .captured(_, duration) = store.recordingState {
                    Text(String(format: "Captured: %.2fs", duration))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Takes") {
                ForEach(store.takesOnDisk(for: pattern), id: \.self) { url in
                    TakeRow(wavURL: url, store: store, pattern: pattern)
                }
            }

            if let error = store.errorMessage {
                Section("Error") {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(pattern.filenameStem)
    }
}
