import Combine
import Foundation
import MoraFixtures
import Observation

public enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case captured(samples: [Float], durationSeconds: Double)
    case saving
    case saveFailed(String)

    public static func == (lhs: RecordingState, rhs: RecordingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.saving, .saving): return true
        case let (.captured(a, b), .captured(c, d)): return a == c && b == d
        case let (.saveFailed(a), .saveFailed(b)): return a == b
        default: return false
        }
    }
}

public enum FixtureExportError: Error, Sendable {
    case emptyDirectory
    case coordinatorFailed(String)
}

private let speakerTagUserDefaultsKey = "MoraFixtureRecorder.speakerTag"

@Observable @MainActor
public final class RecorderStore {

    public var speakerTag: SpeakerTag {
        didSet { userDefaults.set(speakerTag.rawValue, forKey: speakerTagUserDefaultsKey) }
    }

    public var recordingState: RecordingState = .idle
    public var errorMessage: String? {
        if case let .saveFailed(message) = recordingState { return message }
        return nil
    }

    public var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }

    public var hasCapturedSamples: Bool {
        if case .captured = recordingState { return true }
        return false
    }

    public var totalTakesInCurrentSpeaker: Int {
        FixtureCatalog.v1Patterns.reduce(0) { $0 + takeCount(for: $1) }
    }

    private let documentsDirectory: URL
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let recorder: FixtureRecorder

    public init(
        documentsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        recorder: FixtureRecorder? = nil
    ) {
        self.documentsDirectory = documentsDirectory ?? RecorderStore.defaultDocumentsDirectory()
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.recorder = recorder ?? FixtureRecorder()
        if let raw = userDefaults.string(forKey: speakerTagUserDefaultsKey),
            let tag = SpeakerTag(rawValue: raw)
        {
            self.speakerTag = tag
        } else {
            self.speakerTag = .adult
        }
    }

    private static func defaultDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    public func speakerDirectory() -> URL {
        documentsDirectory.appendingPathComponent(speakerTag.rawValue)
    }

    public func patternDirectory(for pattern: FixturePattern) -> URL {
        speakerDirectory().appendingPathComponent(pattern.outputSubdirectory)
    }

    public func takesOnDisk(for pattern: FixturePattern) -> [URL] {
        let dir = patternDirectory(for: pattern)
        guard
            let entries = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
            )
        else { return [] }
        let stemPrefix = "\(pattern.filenameStem)-take"
        return
            entries
            .filter { $0.pathExtension == "wav" }
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(stemPrefix) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func takeCount(for pattern: FixturePattern) -> Int {
        takesOnDisk(for: pattern).count
    }

    public func nextTakeNumber(for pattern: FixturePattern) -> Int {
        let stemPrefix = "\(pattern.filenameStem)-take"
        let numbers = takesOnDisk(for: pattern)
            .map { $0.deletingPathExtension().lastPathComponent.dropFirst(stemPrefix.count) }
            .compactMap { Int($0) }
        return (numbers.max() ?? 0) + 1
    }

    public func takeArtifacts(for wavURL: URL) -> [URL] {
        [wavURL, wavURL.deletingPathExtension().appendingPathExtension("json")]
    }

    public func toggleRecording() {
        switch recordingState {
        case .idle, .saveFailed, .captured:
            do {
                try recorder.start()
                recordingState = .recording
            } catch {
                recordingState = .saveFailed(String(describing: error))
            }
        case .recording:
            recorder.stop()
            let samples = recorder.drain()
            let duration = Double(samples.count) / recorder.targetSampleRate
            recordingState = .captured(samples: samples, durationSeconds: duration)
        case .saving:
            break
        }
    }

    public func save(pattern: FixturePattern) {
        guard case let .captured(samples, duration) = recordingState else { return }
        recordingState = .saving
        do {
            let n = nextTakeNumber(for: pattern)
            let dir = patternDirectory(for: pattern)
            let meta = pattern.metadata(
                capturedAt: Date(),
                sampleRate: recorder.targetSampleRate,
                durationSeconds: duration,
                speakerTag: speakerTag
            )
            _ = try FixtureWriter.writeTake(
                samples: samples, metadata: meta,
                pattern: pattern, takeNumber: n, into: dir
            )
            recordingState = .idle
        } catch {
            recordingState = .saveFailed(String(describing: error))
        }
    }

    public func deleteTake(url: URL) {
        try? fileManager.removeItem(at: url)
        let sidecar = url.deletingPathExtension().appendingPathExtension("json")
        try? fileManager.removeItem(at: sidecar)
    }

    public func prepareSpeakerArchive() throws -> URL {
        let dir = speakerDirectory()
        guard fileManager.fileExists(atPath: dir.path),
            let entries = try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil),
            !entries.isEmpty
        else {
            throw FixtureExportError.emptyDirectory
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var resultURL: URL?

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")

        coordinator.coordinate(
            readingItemAt: dir,
            options: .forUploading,
            error: &coordinationError
        ) { tempURL in
            let dest = fileManager.temporaryDirectory
                .appendingPathComponent("\(speakerTag.rawValue)-\(timestamp).zip")
            try? fileManager.removeItem(at: dest)
            try? fileManager.copyItem(at: tempURL, to: dest)
            resultURL = dest
        }

        if let coordinationError {
            throw FixtureExportError.coordinatorFailed(coordinationError.localizedDescription)
        }
        guard let url = resultURL else {
            throw FixtureExportError.coordinatorFailed("coordinator produced no zip")
        }
        return url
    }
}
