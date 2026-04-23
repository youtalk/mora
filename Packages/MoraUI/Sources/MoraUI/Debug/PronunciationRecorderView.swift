#if DEBUG
import MoraCore
import MoraEngines
import SwiftUI

public struct PronunciationRecorderView: View {
    @State private var recorder = FixtureRecorder()
    @State private var isRecording = false
    @State private var capturedSamples: [Float] = []
    @State private var targetPhonemeIPA: String = "ʃ"
    @State private var expectedLabel: ExpectedLabel = .matched
    @State private var substitutePhonemeIPA: String = "s"
    @State private var wordSurface: String = "ship"
    @State private var speakerTag: SpeakerTag = .adult
    @State private var phonemeSequenceRaw: String = ""
    @State private var targetPhonemeIndex: Int = 0
    @State private var lastSaveURL: URL?
    @State private var errorMessage: String?

    public init() {}

    private let supportedTargets: [String] = [
        "ʃ", "r", "l", "f", "h", "v", "b", "θ", "s", "t", "æ", "ʌ",
    ]

    public var body: some View {
        Form {
            Section("Fixture") {
                Picker("Target phoneme", selection: $targetPhonemeIPA) {
                    ForEach(supportedTargets, id: \.self) { Text($0).tag($0) }
                }
                Picker("Expected label", selection: $expectedLabel) {
                    Text("matched").tag(ExpectedLabel.matched)
                    Text("substitutedBy").tag(ExpectedLabel.substitutedBy)
                    Text("driftedWithin").tag(ExpectedLabel.driftedWithin)
                }
                if expectedLabel == .substitutedBy {
                    Picker("Substitute phoneme", selection: $substitutePhonemeIPA) {
                        ForEach(supportedTargets, id: \.self) { Text($0).tag($0) }
                    }
                }
                TextField("Word", text: $wordSurface)
                TextField(
                    "Phoneme sequence (space-separated IPA, optional)",
                    text: $phonemeSequenceRaw
                )
                .onChange(of: phonemeSequenceRaw) { _, _ in
                    // SwiftUI doesn't auto-clamp @State Int values when a
                    // bound range shrinks. Re-clamp explicitly whenever the
                    // user edits the raw sequence so the stored index never
                    // exceeds the live sequence length.
                    let upper = max(0, parsedPhonemeSequence.count - 1)
                    targetPhonemeIndex = min(targetPhonemeIndex, upper)
                }
                if !parsedPhonemeSequence.isEmpty {
                    Stepper(
                        "Target index: \(targetPhonemeIndex)",
                        value: $targetPhonemeIndex,
                        in: 0...max(0, parsedPhonemeSequence.count - 1)
                    )
                }
                Picker("Speaker", selection: $speakerTag) {
                    Text("adult").tag(SpeakerTag.adult)
                    Text("child").tag(SpeakerTag.child)
                }
            }

            Section("Capture") {
                Button(isRecording ? "Stop" : "Record") {
                    if isRecording {
                        recorder.stop()
                        capturedSamples = recorder.drain()
                        isRecording = false
                    } else {
                        do {
                            try recorder.start()
                            isRecording = true
                        } catch {
                            errorMessage = String(describing: error)
                        }
                    }
                }
                Button("Save") { save() }
                    .disabled(capturedSamples.isEmpty)
                if let url = lastSaveURL {
                    Text("Saved: \(url.lastPathComponent)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Fixture Recorder")
    }

    /// Trimmed, whitespace-split phoneme sequence derived from
    /// `phonemeSequenceRaw`. Empty when the user has not typed a sequence
    /// — the Stepper and sidecar fields stay hidden / nil in that case.
    private var parsedPhonemeSequence: [String] {
        phonemeSequenceRaw
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func save() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sub = (expectedLabel == .substitutedBy) ? substitutePhonemeIPA : nil
        let sequence = parsedPhonemeSequence
        let sequenceOrNil: [String]? = sequence.isEmpty ? nil : sequence
        let indexOrNil: Int? = sequenceOrNil == nil ? nil : targetPhonemeIndex
        let meta = FixtureMetadata(
            capturedAt: Date(),
            targetPhonemeIPA: targetPhonemeIPA,
            expectedLabel: expectedLabel,
            substitutePhonemeIPA: sub,
            wordSurface: wordSurface,
            sampleRate: recorder.targetSampleRate,
            durationSeconds: Double(capturedSamples.count) / recorder.targetSampleRate,
            speakerTag: speakerTag,
            phonemeSequenceIPA: sequenceOrNil,
            targetPhonemeIndex: indexOrNil
        )
        do {
            let out = try FixtureWriter.write(
                samples: capturedSamples, metadata: meta, into: documents
            )
            lastSaveURL = out.wav
            capturedSamples.removeAll()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
#endif
