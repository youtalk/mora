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
4. Tap Record, say the word, tap Stop, tap Save. The take appears in the takes
   list with a share icon.
5. To export a single take: tap its share icon → AirDrop → Mac.
6. To export the whole session: back on the list screen, tap the toolbar Share
   button ("Share adult takes (N)"). A zip of `<Documents>/<speaker>/` is built
   on the fly; AirDrop it to your Mac.

## Output layout

```
<Documents>/
├── adult/<pattern outputSubdir>/<pattern filenameStem>-take<N>.wav/.json
└── child/<pattern outputSubdir>/<pattern filenameStem>-take<N>.wav/.json
```

See `docs/superpowers/specs/2026-04-23-fixture-recorder-app-design.md`.
