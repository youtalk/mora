# sentence-validator

Standalone Swift CLI that validates the bundled decodable-sentence library
(`Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary/`) against
the rules in
[`docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md`](../../docs/superpowers/specs/2026-04-25-yokai-voice-wiring-and-decodable-sentence-library-design.md)
§ 6.4.

## Usage

```sh
swift run --package-path dev-tools/sentence-validator \
    sentence-validator \
    --bundle Packages/MoraEngines/Sources/MoraEngines/Resources/SentenceLibrary
```

Exits 0 if every cell file validates; non-zero with a per-violation report
otherwise. Wired into CI after the SPM test loop.

## What it checks

For every `{interest}_{ageBand}.json` under each phoneme directory:

- Every sentence's words decompose into graphemes drawn from
  `CurriculumEngine.taughtGraphemes(beforeWeekIndex:) ∪ {target}` plus the
  sight-word whitelist (`the, a, and, is, to, on, at`).
- The target phoneme appears word-initial in ≥3 content words and
  ≥4 times total per sentence.
- Each sentence has ≥1 entry in its `interestWords` list, and every
  `interestWords` entry matches a word in the sentence text.
- Sentence length is 6–10 words.
