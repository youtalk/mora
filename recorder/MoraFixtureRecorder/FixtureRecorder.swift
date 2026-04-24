import AVFoundation
import Foundation

public enum FixtureRecorderError: Error, Sendable {
    case converterInitFailed
    case audioEngineStartFailed(underlying: Error)
    case notRecording
}

/// Captures mono Float32 samples at 16 kHz from the default input device.
/// Not thread-safe — intended to be used from the main actor inside a
/// SwiftUI view.
@MainActor
public final class FixtureRecorder {

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var isRecording = false
    private var sessionGeneration: UInt64 = 0
    public private(set) var buffer: [Float] = []
    public let targetSampleRate: Double = 16_000

    public init() {}

    public var isRunning: Bool { isRecording }

    public func start() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: targetSampleRate,
                channels: 1,
                interleaved: false
            )
        else {
            throw FixtureRecorderError.converterInitFailed
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw FixtureRecorderError.converterInitFailed
        }
        self.converter = converter

        buffer.removeAll(keepingCapacity: true)
        sessionGeneration &+= 1
        let capturedGeneration = sessionGeneration

        inputNode.installTap(
            onBus: 0, bufferSize: 4_096, format: hardwareFormat
        ) { [weak self] inBuffer, _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.sessionGeneration == capturedGeneration else { return }
                self.append(convert: inBuffer, with: converter, to: targetFormat)
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw FixtureRecorderError.audioEngineStartFailed(underlying: error)
        }

        isRecording = true
    }

    public func stop() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        sessionGeneration &+= 1
    }

    public func drain() -> [Float] {
        let out = buffer
        buffer.removeAll(keepingCapacity: false)
        return out
    }

    private func append(
        convert inBuffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to targetFormat: AVAudioFormat
    ) {
        let ratio = targetFormat.sampleRate / inBuffer.format.sampleRate
        let outCapacity = AVAudioFrameCount(Double(inBuffer.frameLength) * ratio) + 16
        guard
            let outBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat, frameCapacity: outCapacity
            )
        else { return }

        var done = false
        let input: AVAudioConverterInputBlock = { _, outStatus in
            if done {
                outStatus.pointee = .noDataNow
                return nil
            }
            done = true
            outStatus.pointee = .haveData
            return inBuffer
        }

        var error: NSError?
        _ = converter.convert(to: outBuffer, error: &error, withInputFrom: input)
        guard error == nil, let channelData = outBuffer.floatChannelData else { return }

        let frameCount = Int(outBuffer.frameLength)
        buffer.append(contentsOf: UnsafeBufferPointer(start: channelData[0], count: frameCount))
    }
}
