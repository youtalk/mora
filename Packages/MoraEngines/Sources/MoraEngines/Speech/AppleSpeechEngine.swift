import AVFoundation
import Foundation
import Speech

public enum AppleSpeechEngineError: Error, Equatable {
    case notSupportedOnDevice
    case audioEngineStartFailed
    case recognizerUnavailable
    case audioSessionConfigurationFailed
    case audioConverterUnavailable
}

public final class AppleSpeechEngine: SpeechEngine, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer
    private let silenceTimeout: TimeInterval
    private let hardTimeout: TimeInterval

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var ringBuffer: PCMRingBuffer?
    private let lock = NSLock()

    public init(
        localeIdentifier: String = "en-US",
        silenceTimeout: TimeInterval = 2.5,
        hardTimeout: TimeInterval = 15.0
    ) throws {
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) else {
            throw AppleSpeechEngineError.recognizerUnavailable
        }
        guard rec.supportsOnDeviceRecognition else {
            throw AppleSpeechEngineError.notSupportedOnDevice
        }
        self.recognizer = rec
        self.silenceTimeout = silenceTimeout
        self.hardTimeout = hardTimeout
    }

    public func listen() -> AsyncThrowingStream<SpeechEvent, Error> {
        AsyncThrowingStream { continuation in
            // If the consumer stops iterating early (view disappears, task
            // cancelled), tear the engine down so the audio tap and
            // recognition task don't keep running until the watchdog fires.
            continuation.onTermination = { [weak self] _ in
                self?.cancel()
            }
            do {
                try self.startSession(continuation: continuation)
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        tearDownLocked()
    }

    private func startSession(
        continuation: AsyncThrowingStream<SpeechEvent, Error>.Continuation
    ) throws {
        #if os(iOS)
        // SFSpeechRecognizer needs an active record audio session; without
        // this, engine.start() either fails or the tap captures nothing.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AppleSpeechEngineError.audioSessionConfigurationFailed
        }
        #endif

        lock.lock()
        tearDownLocked()
        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        self.audioEngine = engine
        self.request = req

        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)

        let ring = PCMRingBuffer(capacitySeconds: 20.0, sampleRate: 16_000)
        self.ringBuffer = ring

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )
        else {
            lock.unlock()
            throw AppleSpeechEngineError.audioConverterUnavailable
        }
        guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
            lock.unlock()
            throw AppleSpeechEngineError.audioConverterUnavailable
        }

        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate
            )
            guard frameCapacity > 0,
                let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: frameCapacity
                )
            else {
                return
            }
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if status == .haveData, error == nil,
                let ch0 = convertedBuffer.floatChannelData?[0]
            {
                let frames = Int(convertedBuffer.frameLength)
                let chunk = Array(UnsafeBufferPointer(start: ch0, count: frames))
                ring.append(chunk)
            }
        }
        engine.prepare()
        lock.unlock()

        do {
            try engine.start()
        } catch {
            self.cancel()
            continuation.finish(throwing: AppleSpeechEngineError.audioEngineStartFailed)
            return
        }

        continuation.yield(.started)

        let timestamps = TimestampBox()
        timestamps.reset()

        self.task = recognizer.recognitionTask(with: req) { [weak self, ringRef = ring] result, err in
            guard let self else { return }
            if let err {
                self.cancel()
                continuation.finish(throwing: err)
                return
            }
            guard let result else { return }
            let transcript = result.bestTranscription.formattedString
            let confidence = Double(result.bestTranscription.segments.last?.confidence ?? 0)
            if !result.isFinal {
                continuation.yield(.partial(transcript))
                timestamps.markPartial()
                return
            }
            guard timestamps.tryMarkFinalized() else { return }
            let clip = ringRef.drain()
            continuation.yield(
                .final(
                    TrialRecording(
                        asr: ASRResult(transcript: transcript, confidence: confidence),
                        audio: clip
                    )))
            continuation.finish()
            self.cancel()
        }

        // Silence + hard-timeout watchdog. Polls twice per second — imprecise
        // but keeps the surface small. A half-second stale read only delays
        // the timeout by one tick.
        Task.detached { [weak self, ringRef = ring] in
            while let self, !timestamps.isFinalized() {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let silence = timestamps.silenceSeconds()
                let total = timestamps.totalSeconds()
                if silence >= self.silenceTimeout || total >= self.hardTimeout {
                    guard timestamps.tryMarkFinalized() else { return }
                    let clip = ringRef.drain()
                    continuation.yield(
                        .final(
                            TrialRecording(
                                asr: ASRResult(transcript: "", confidence: 0),
                                audio: clip
                            )))
                    continuation.finish()
                    self.cancel()
                    return
                }
            }
        }
    }

    /// Must be called with `lock` held.
    private func tearDownLocked() {
        request?.endAudio()
        task?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        request = nil
        task = nil
        audioEngine = nil
        ringBuffer?.reset()
        ringBuffer = nil
    }
}

/// Collects the two timestamps the watchdog and recognition callback share.
/// A dedicated class lets us mark @unchecked Sendable in one place and keeps
/// the locking local.
private final class TimestampBox: @unchecked Sendable {
    private let lock = NSLock()
    private var start = Date()
    private var lastPartial = Date()
    private var finalized = false

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        start = Date()
        lastPartial = Date()
        finalized = false
    }

    func markPartial() {
        lock.lock()
        defer { lock.unlock() }
        lastPartial = Date()
    }

    func markFinalized() {
        lock.lock()
        defer { lock.unlock() }
        finalized = true
    }

    /// Atomically transitions from not-finalized → finalized. Returns `true`
    /// only for the single caller that makes the transition; all subsequent
    /// callers return `false`. Use this instead of `isFinalized()` + `markFinalized()`
    /// at drain sites to eliminate the mark-and-drain race.
    func tryMarkFinalized() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finalized else { return false }
        finalized = true
        return true
    }

    func isFinalized() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return finalized
    }

    func silenceSeconds() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(lastPartial)
    }

    func totalSeconds() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(start)
    }
}

/// Thread-safe fixed-capacity ring buffer for Float32 mono PCM. The audio
/// tap appends live samples; `drain()` returns a copy of the current contents
/// as an `AudioClip`. Oldest samples are dropped when capacity is exceeded.
final class PCMRingBuffer: @unchecked Sendable {
    private let bufferLock = NSLock()
    private var samples: [Float] = []
    private let capacity: Int
    let sampleRate: Double

    init(capacitySeconds: Double, sampleRate: Double) {
        self.capacity = Int(capacitySeconds * sampleRate)
        self.sampleRate = sampleRate
    }

    func append(_ chunk: [Float]) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        samples.append(contentsOf: chunk)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    func drain() -> AudioClip {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        let copy = samples
        samples.removeAll(keepingCapacity: true)
        return AudioClip(samples: copy, sampleRate: sampleRate)
    }

    func reset() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        samples.removeAll(keepingCapacity: true)
    }
}
