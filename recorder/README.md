# Mora Fixture Recorder

iPad-only dev tool for capturing fixture audio that `dev-tools/pronunciation-bench/`
and `FeatureBasedEvaluatorFixtureTests` consume. Not shipped; not distributed
via App Store or TestFlight.

Drives the 12 patterns in `FixtureCatalog.v1Patterns` (r/l, v/b, æ/ʌ × 4). The
user picks a pattern, taps Record / Stop / Save, and exports via the iOS Share
Sheet — per take (two files) or per session (zip of all takes under the current
speaker).

## Build

```sh
cd recorder
# Inject team for physical-device signing, generate, revert (per repo convention)
python3 -c "
import re
with open('project.yml') as f: p = f.read()
if 'DEVELOPMENT_TEAM' not in p:
    p2 = re.sub(r'(CODE_SIGN_STYLE: Automatic)', r'\1\n        DEVELOPMENT_TEAM: 7BT28X9TQ9', p, count=1)
    with open('project.yml', 'w') as f: f.write(p2)
"
xcodegen generate
git restore --source=HEAD -- project.yml
open "Mora Fixture Recorder.xcodeproj"
```

Select `MoraFixtureRecorder` scheme, connect an iPad, and build & run.

## Usage

1. Launch the app on the iPad.
2. Pick the speaker toggle at the top of the list (adult / child).
3. Tap a pattern row (e.g. "right — /r/ matched").
4. Tap Record, say the word, tap Stop. The Capture section shows a
   verdict inline (✓ / ✗ / ⚠︎ with the label heard and — if different
   from expected — what it was expected to be). Tap the verdict to
   expand feature values, score, reliability, and coaching key.
5. If the verdict disagrees with the expected label, tap Record again
   to discard and re-take. If the verdict agrees (or you want to save
   anyway), tap Save. The take appears in the takes list with a
   matching badge.
6. To export a single take: tap its share icon → AirDrop → Mac.
7. To export the whole session: back on the list screen, tap the
   toolbar Share button ("Share adult takes (N)"). A zip of
   `<Documents>/<speaker>/` is built on the fly; AirDrop it to your Mac.

Takes recorded in previous sessions also show verdict badges in the
takes list — the recorder lazily evaluates them from disk on first view
and caches the result for the rest of the session.

## How the on-device verdict matches bench

The iPad's verdict is produced by `PronunciationEvaluationRunner` in
`MoraEngines`, which is the same type the Mac CLI
(`dev-tools/pronunciation-bench/`) routes `EngineARunner` through. When
the iPad says `matched` for a take, the bench will say `matched` for
the same take. Use the on-device verdict to decide whether to keep or
re-record before exporting; run bench to produce the CSV report for
committed fixtures.

Verdicts are **not persisted**. Killing and relaunching the recorder
wipes the session cache; re-opening a pattern detail lazily
re-evaluates saved takes the first time each `TakeRow` appears.

## Output layout

```
<Documents>/
├── adult/<pattern outputSubdir>/<pattern filenameStem>-take<N>.wav/.json
└── child/<pattern outputSubdir>/<pattern filenameStem>-take<N>.wav/.json
```

See `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md`.
