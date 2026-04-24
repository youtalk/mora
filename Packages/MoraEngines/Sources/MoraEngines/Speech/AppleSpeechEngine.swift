import AVFoundation
import Foundation
import OSLog
import Speech

private let asrLog = Logger(subsystem: "tech.reenable.Mora", category: "Speech")

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

        let ring = PCMRingBuffer(capacitySeconds: 5.0, sampleRate: 16_000)
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

        // Pre-allocate a single convert buffer sized for worst-case tap output.
        // Reusing it avoids a per-callback AVAudioPCMBuffer alloc on the RT thread.
        let tapBufferSize: AVAudioFrameCount = 1024
        let convertedBufferCapacity = AVAudioFrameCount(
            ceil(Double(tapBufferSize) * targetFormat.sampleRate / format.sampleRate)
        )
        guard convertedBufferCapacity > 0,
            let reusableConvertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: convertedBufferCapacity
            )
        else {
            lock.unlock()
            throw AppleSpeechEngineError.audioConverterUnavailable
        }

        node.installTap(onBus: 0, bufferSize: tapBufferSize, format: format) { buffer, _ in
            req.append(buffer)
            reusableConvertedBuffer.frameLength = 0
            var error: NSError?
            let status = converter.convert(to: reusableConvertedBuffer, error: &error) {
                _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if status == .haveData, error == nil,
                let ch0 = reusableConvertedBuffer.floatChannelData?[0]
            {
                let frames = Int(reusableConvertedBuffer.frameLength)
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
        #if DEBUG
        asrLog.info("ASR: listening started")
        #endif

        let timestamps = TimestampBox()
        timestamps.reset()

        self.task = recognizer.recognitionTask(with: req) { [weak self, ringRef = ring] result, err in
            guard let self else { return }
            if let err {
                #if DEBUG
                asrLog.error("ASR: error \(String(describing: err), privacy: .public)")
                #endif
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
                #if DEBUG
                asrLog.info("ASR partial: \"\(transcript, privacy: .public)\"")
                #endif
                return
            }
            guard timestamps.tryMarkFinalized() else { return }
            let clip = ringRef.drain()
            #if DEBUG
            asrLog.info(
                """
                ASR final: "\(transcript, privacy: .public)" \
                confidence=\(confidence, privacy: .public) \
                samples=\(clip.samples.count, privacy: .public)
                """
            )
            #endif
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
                    #if DEBUG
                    asrLog.info(
                        """
                        ASR timeout: silence=\(silence, privacy: .public)s \
                        total=\(total, privacy: .public)s \
                        samples=\(clip.samples.count, privacy: .public)
                        """
                    )
                    #endif
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

/// Thread-safe true circular buffer for Float32 mono PCM. The audio tap
/// appends live samples in O(n-chunk) time; `drain()` returns a copy of the
/// current contents as an `AudioClip` with leading silence trimmed. Oldest
/// samples are overwritten when capacity is exceeded — no memmove on the RT
/// thread.
final class PCMRingBuffer: @unchecked Sendable {
    private let bufferLock = NSLock()
    private var samples: [Float]
    private let capacity: Int
    private var head: Int = 0
    private var count: Int = 0
    let sampleRate: Double

    init(capacitySeconds: Double, sampleRate: Double) {
        self.capacity = max(0, Int(capacitySeconds * sampleRate))
        self.samples = Array(repeating: 0, count: self.capacity)
        self.sampleRate = sampleRate
    }

    func append(_ chunk: [Float]) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        guard capacity > 0, !chunk.isEmpty else { return }
        for sample in chunk {
            let writeIndex = (head + count) % capacity
            samples[writeIndex] = sample
            if count == capacity {
                head = (head + 1) % capacity
            } else {
                count += 1
            }
        }
    }

    func drain() -> AudioClip {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        guard count > 0 else {
            return AudioClip(samples: [], sampleRate: sampleRate)
        }
        var copy: [Float] = []
        copy.reserveCapacity(count)
        let firstSegmentCount = min(count, capacity - head)
        copy.append(contentsOf: samples[head..<(head + firstSegmentCount)])
        let remainingCount = count - firstSegmentCount
        if remainingCount > 0 {
            copy.append(contentsOf: samples[0..<remainingCount])
        }
        head = 0
        count = 0
        // Trim leading silence: drop samples before the first one whose
        // absolute value exceeds ~−50 dBFS. Runs off the audio thread so
        // the allocation/scan cost is acceptable.
        let silenceThreshold: Float = 0.003
        let speechStart = copy.firstIndex(where: { abs($0) > silenceThreshold }) ?? 0
        return AudioClip(samples: Array(copy[speechStart...]), sampleRate: sampleRate)
    }

    func reset() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        head = 0
        count = 0
    }
}
