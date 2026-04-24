import Foundation
import MoraCore
import MoraEngines
import MoraFixtures
import Observation

/// Immutable snapshot of one capture session's audio. Identified by a UUID
/// so `RecordingState.captured` equality is O(1) instead of walking the
/// full `[Float]` sample buffer on every SwiftUI observation cycle.
public struct CaptureSnapshot: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let samples: [Float]
    public let durationSeconds: Double

    public init(samples: [Float], durationSeconds: Double) {
        self.id = UUID()
        self.samples = samples
        self.durationSeconds = durationSeconds
    }

    public static func == (lhs: CaptureSnapshot, rhs: CaptureSnapshot) -> Bool {
        lhs.id == rhs.id
    }
}

public enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case captured(CaptureSnapshot)
    case saving
    case saveFailed(String)
}

public enum PendingVerdict: Sendable, Equatable {
    case idle
    case evaluating
    case ready(PhonemeTrialAssessment)
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

    /// Bumped whenever a take is saved or deleted. SwiftUI views that cache
    /// derived state (e.g. `BulkShareButton`'s zip URL) observe this so they
    /// invalidate when the underlying takes set changes.
    public private(set) var takesRevision: UInt64 = 0

    public var pendingVerdict: PendingVerdict = .idle
    public private(set) var savedVerdicts: [URL: PhonemeTrialAssessment] = [:]

    private var evaluationTask: Task<Void, Never>?
    private let runner: any PronunciationRunning

    private let documentsDirectory: URL
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let recorder: FixtureRecorder

    public init(
        documentsDirectory: URL? = nil,
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        recorder: FixtureRecorder? = nil,
        runner: any PronunciationRunning = PronunciationEvaluationRunner()
    ) {
        self.documentsDirectory = documentsDirectory ?? RecorderStore.defaultDocumentsDirectory()
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.recorder = recorder ?? FixtureRecorder()
        self.runner = runner
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
            .sorted { lhs, rhs in
                let a = Self.takeNumber(from: lhs, stemPrefix: stemPrefix) ?? 0
                let b = Self.takeNumber(from: rhs, stemPrefix: stemPrefix) ?? 0
                return a < b
            }
    }

    public func takeCount(for pattern: FixturePattern) -> Int {
        takesOnDisk(for: pattern).count
    }

    public func nextTakeNumber(for pattern: FixturePattern) -> Int {
        let stemPrefix = "\(pattern.filenameStem)-take"
        let numbers = takesOnDisk(for: pattern)
            .compactMap { Self.takeNumber(from: $0, stemPrefix: stemPrefix) }
        return (numbers.max() ?? 0) + 1
    }

    /// Extracts the numeric take index from a `<stem>-take<N>.wav` URL, or
    /// `nil` if the filename doesn't match. Exposed internally so `TakeRow`
    /// can render the same number the store uses for ordering.
    static func takeNumber(from url: URL, stemPrefix: String) -> Int? {
        let basename = url.deletingPathExtension().lastPathComponent
        guard basename.hasPrefix(stemPrefix) else { return nil }
        return Int(basename.dropFirst(stemPrefix.count))
    }

    public func takeArtifacts(for wavURL: URL) -> [URL] {
        [wavURL, wavURL.deletingPathExtension().appendingPathExtension("json")]
    }

    /// Test helper: spin on MainActor until `pendingVerdict` reaches
    /// `target` or `timeout` seconds elapse. Non-production.
    public func waitForPendingVerdict(
        _ target: PendingVerdict,
        timeout: TimeInterval
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while pendingVerdict != target && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)  // 5 ms
        }
    }

    public func toggleRecording(pattern: FixturePattern) {
        switch recordingState {
        case .idle, .saveFailed, .captured:
            evaluationTask?.cancel()
            pendingVerdict = .idle
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
            recordingState = .captured(
                CaptureSnapshot(samples: samples, durationSeconds: duration))
            evaluateCaptured(pattern: pattern)
        case .saving:
            break
        }
    }

    private func evaluateCaptured(pattern: FixturePattern) {
        guard case let .captured(snapshot) = recordingState else { return }
        pendingVerdict = .evaluating
        let runner = self.runner
        let sampleRate = recorder.targetSampleRate
        evaluationTask = Task.detached { [weak self] in
            let assessment = await runner.evaluate(
                samples: snapshot.samples,
                sampleRate: sampleRate,
                wordSurface: pattern.wordSurface,
                targetPhonemeIPA: pattern.targetPhonemeIPA,
                phonemeSequenceIPA: pattern.phonemeSequenceIPA,
                targetPhonemeIndex: pattern.targetPhonemeIndex
            )
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self else { return }
                if case .evaluating = self.pendingVerdict {
                    self.pendingVerdict = .ready(assessment)
                }
            }
        }
    }

    public func save(pattern: FixturePattern) {
        guard case let .captured(snapshot) = recordingState else { return }
        recordingState = .saving
        do {
            let n = nextTakeNumber(for: pattern)
            let dir = patternDirectory(for: pattern)
            let meta = pattern.metadata(
                capturedAt: Date(),
                sampleRate: recorder.targetSampleRate,
                durationSeconds: snapshot.durationSeconds,
                speakerTag: speakerTag
            )
            let output = try FixtureWriter.writeTake(
                samples: snapshot.samples, metadata: meta,
                pattern: pattern, takeNumber: n, into: dir
            )
            if case let .ready(assessment) = pendingVerdict {
                savedVerdicts[output.wav] = assessment
                pendingVerdict = .idle
            }
            // If pendingVerdict is .evaluating, leave it as-is — the late
            // assessment will land on the still-visible captured snapshot
            // path and a later lazy TakeRow.onAppear will fill savedVerdicts.
            recordingState = .idle
            takesRevision &+= 1
        } catch {
            recordingState = .saveFailed(String(describing: error))
        }
    }

    public func deleteTake(url: URL) {
        try? fileManager.removeItem(at: url)
        let sidecar = url.deletingPathExtension().appendingPathExtension("json")
        try? fileManager.removeItem(at: sidecar)
        savedVerdicts[url] = nil
        takesRevision &+= 1
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
        var copyError: Error?

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
            // Removing a non-existent destination is a benign no-op, so we
            // can swallow it. Copy failures must surface so `ShareLink`
            // never receives a missing file.
            try? fileManager.removeItem(at: dest)
            do {
                try fileManager.copyItem(at: tempURL, to: dest)
                resultURL = dest
            } catch {
                copyError = error
            }
        }

        if let coordinationError {
            throw FixtureExportError.coordinatorFailed(coordinationError.localizedDescription)
        }
        if let copyError {
            throw FixtureExportError.coordinatorFailed(
                "failed to materialize zip: \(copyError.localizedDescription)")
        }
        guard let url = resultURL else {
            throw FixtureExportError.coordinatorFailed("coordinator produced no zip")
        }
        return url
    }
}
