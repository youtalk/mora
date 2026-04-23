# Fixtures

Placeholder directory. The real `short-sh-clip.wav` fixture (small 16 kHz
mono PCM WAV containing a /ʃ/-like burst) is added in Task 26 follow-up
work once the wav2vec2 CoreML model is bundled via Git LFS. Until then,
`CoreMLPhonemePosteriorProviderSmokeTests` calls `XCTSkip` when the
fixture is absent.
