// Packages/MoraEngines/Sources/MoraEngines/Pronunciation/PhonemePosteriorProvider.swift
import Foundation

/// Produces a `PhonemePosterior` for a recorded utterance. Real
/// implementations live in `MoraMLX` and are backed by CoreML; tests use
/// `FakePhonemePosteriorProvider` from `MoraTesting`.
public protocol PhonemePosteriorProvider: Sendable {
    func posterior(for audio: AudioClip) async throws -> PhonemePosterior
}
