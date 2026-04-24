import MoraEngines
import MoraFixtures

/// Adapter that pulls FixtureMetadata-shaped input out of `LoadedFixture`
/// and hands the primitives to `PronunciationEvaluationRunner`. Exists so
/// `BenchCLI` keeps its current method-on-fixture call shape; new code
/// paths prefer `PronunciationEvaluationRunner` directly.
public struct EngineARunner {
    private let runner: any PronunciationRunning

    public init(runner: any PronunciationRunning = PronunciationEvaluationRunner()) {
        self.runner = runner
    }

    public func evaluate(_ loaded: LoadedFixture) async -> PhonemeTrialAssessment {
        await runner.evaluate(
            samples: loaded.samples,
            sampleRate: loaded.sampleRate,
            wordSurface: loaded.metadata.wordSurface,
            targetPhonemeIPA: loaded.metadata.targetPhonemeIPA,
            phonemeSequenceIPA: loaded.metadata.phonemeSequenceIPA,
            targetPhonemeIndex: loaded.metadata.targetPhonemeIndex
        )
    }
}
