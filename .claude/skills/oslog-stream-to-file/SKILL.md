---
name: oslog-stream-to-file
description: Stream an Apple-platform app's OSLog rows into /tmp/<repo>.log so Claude can `Read` live runtime logs directly while the user interacts with the running app. Use this skill whenever the user wants to debug an iOS Simulator / macOS native / Mac Catalyst / Designed-for-iPad app, verify on-device functionality on a Mac, watch live phase or state transitions, correlate user interactions to log timestamps without screenshots, or any variation like "ログをClaudeで読みたい", "Console.app の代わりにファイルに流す", "stream the logs to file", "live debug from the chat", "check what the app is doing right now", "tail os_log output", "verify the timeline as I tap through". The killer move is that the user runs the app and Claude reads the OSLog timeline directly — the debug round-trip drops from "screenshot Console.app and paste" to "press the button, tell me you pressed it, I'll quote the matching rows back". Skip when the target is a real iPhone/iPad attached over USB or Wi-Fi — that flow goes through `xcrun devicectl device console` and the `conduit-run-on-iphone` skill captures it.
---

# Stream OSLog to a file Claude can read

Run an Apple-platform app whose process lives on this Mac (native macOS, Mac Catalyst, Designed-for-iPad, or iOS Simulator), filter its OSLog rows by `subsystem`, and tee them to `/tmp/<repo>.log` in the background. The user drives the app from Xcode / the Dock / Simulator; Claude reads the file as the user reports their interactions. Either side can replay the timeline at any point.

## When this works vs when it doesn't

- ✅ The app's process runs **on this Mac**: macOS native, Mac Catalyst, "My Mac (Designed for iPad)", and iOS Simulator (booted on this Mac) all emit OSLog rows that the host's `log stream` can subscribe to.
- ✅ The app source uses Apple's unified logging (`os.Logger`, `os_log`, `os_signpost`). Plain `print` and bare `NSLog` rarely show up under a `subsystem` filter and won't reach the file.
- ❌ The app runs on a real iPhone / iPad / Apple Watch / Apple TV connected over USB or Wi-Fi. Use `xcrun devicectl device console` against that device's UDID instead — that pattern lives in the `conduit-run-on-iphone` skill.
- ⚠️ Apple's `os_log` redacts string interpolations to `<private>` at runtime unless either (a) the build is DEBUG **and** the source uses `privacy: .public`, or (b) you've installed an Apple sysdiagnose-style logging profile. If the captured file is full of `<private>`, the build is Release or the source is missing `privacy: .public`. Fix that at the source — this skill won't unmask redacted values.

## Discover the inputs first, do not guess

The skill needs two strings to start: the **repo name** (drives the log filename) and the **bundle identifier** (drives the `subsystem` filter). Discover both before opening the stream.

1. **Repo name** — `basename "$(git rev-parse --show-toplevel)"`. The active log file is always `/tmp/<repo>.log`. (User's standing rule: log filename matches repo name so multiple project sessions don't collide.)

2. **Bundle identifier** — search top-down, take the first hit:
   - `grep -E 'PRODUCT_BUNDLE_IDENTIFIER|bundleIdPrefix' project.yml` (XcodeGen-managed projects)
   - `grep PRODUCT_BUNDLE_IDENTIFIER *.xcodeproj/project.pbxproj | head -1`
   - `defaults read $(find . -path "*/Info.plist" -not -path "*/build/*" | head -1) CFBundleIdentifier`

   Multi-target projects (Watch extension, Widget, etc.) emit multiple matches — the main app target is the one this skill cares about. If the matches don't make the choice obvious, ask the user. Don't pick at random.

3. **Confirm the app actually emits OSLog** — `grep -rEn 'Logger\(subsystem:|os_log_create|OSLog\(subsystem:' --include='*.swift' --include='*.m' .` should return at least one site with the bundle ID as the `subsystem`. Zero hits means the app uses `print` / bare `NSLog` and the filtered stream will stay silent — surface that to the user **before** starting the stream so they're not waiting for output that will never come.

## Procedure

Four steps. Steps 2 and 4 must be separate Bash invocations — step 2 runs in the background and never returns on its own; step 4 is the cleanup that ends it.

### Step 1 — rotate the log so the new run's timeline is clean

```bash
REPO=$(basename "$(git rev-parse --show-toplevel)")
LOG=/tmp/$REPO.log
[ -s "$LOG" ] && mv "$LOG" "$LOG.$(date +%Y%m%dT%H%M%S)"
: > "$LOG"
```

Old logs land beside the active one as `/tmp/<repo>.log.<timestamp>` rather than being deleted — the user's next "wait, what did the warmup phase look like in the previous run?" will need them. /tmp is cleaned by macOS over time so this isn't permanent storage; if a session produces a finding worth keeping, copy the archived log somewhere durable.

### Step 2 — start the stream in the background

Run via the Bash tool with `run_in_background: true`, substituting the bundle ID and repo name:

```bash
/usr/bin/log stream \
  --predicate 'subsystem == "<bundle.id>"' \
  --style compact \
  --info --debug \
  >> /tmp/<repo>.log 2>&1
```

Each flag earns its place:

- **`/usr/bin/log` — the absolute path matters.** zsh has a `log` builtin that intercepts the command and chokes on the predicate's quotes (the failure looks like `(eval):log:1: too many arguments`). The Bash tool inherits zsh's environment via the shell snapshot, so the conflict bites here even though the tool is named "Bash". Always type `/usr/bin/log`.
- **`--predicate 'subsystem == "..."'`** scopes the stream to one app. Without it, every OSLog row from every process on the Mac lands in the file and the signal drowns within seconds.
- **`--style compact`** produces one line per row prefixed with `[subsystem:category]`. The default `syslog` style spreads each row over multiple lines and reads poorly through `Read`.
- **`--info --debug`** adds the two lower OSLog levels to the stream. `log stream` defaults to `default` and above, so anything emitted at `.info` / `.debug` (which is most lifecycle and trace logging) silently drops without these flags.

After the background command starts, do a quick sanity Read of the file (one second is enough) — the first line should be `Filtering the log data using "subsystem == \"<bundle.id>\""`. If that line is missing, the stream didn't start; the most likely cause is the zsh-builtin trap (`log` instead of `/usr/bin/log`) or a misquoted predicate.

### Step 3 — user runs the app, Claude reads the file as a conversation

Tell the user how to launch their target environment:

- **Designed for iPad on Mac / Mac Catalyst / native macOS**: Xcode → pick the matching destination → ⌘R. After Xcode has installed it once, subsequent runs without a rebuild can be launched from Launchpad.
- **iOS Simulator**: open Simulator.app (or `xcrun simctl boot <UDID>`), then either ⌘R from Xcode or `xcrun simctl launch booted <bundle.id>`.

Then walk the user through the scenario one beat at a time. Each time they say "I tapped X" / "phase Y reached" / "the alert appeared", `Read /tmp/<repo>.log` and quote the matching rows back with timestamps. The user's words are ground truth ("did this happen?"); the log is evidence ("here's exactly when, to the millisecond, with the surrounding events").

When the file has grown past a few hundred lines, narrow without restarting the stream:

- **Per-category** — rows include `[subsystem:Category]`, so `grep '\[<bundle>:<Category>\]' /tmp/<repo>.log` walks one category top-to-bottom. Useful when the app uses `Logger(subsystem: ..., category: "Speech")` etc.
- **Per-thread** — rows include `[PID:TID]`, so `grep '\[<pid>:<tid>\]'` follows one async chain.
- **Read with offset** — once the user reaches a known signpost, re-`Read` with `offset=` near that line on subsequent checks so the relevant tail keeps fitting in context.

### Step 4 — cleanup when the session ends

```bash
pkill -f "log stream.*<bundle.id>"
```

Match by predicate substring (the bundle ID) rather than by PID — the wrapper that `run_in_background` creates obscures the inner `log` PID, but the spawned `/usr/bin/log` always carries the predicate on its command line.

If the session produced findings worth keeping, archive the active log so the next run's rotation doesn't bury it under a generic timestamp:

```bash
mv /tmp/<repo>.log /tmp/<repo>.log.session-$(date +%Y%m%dT%H%M%S)
```

Skip the archive when nothing was found — keeping `/tmp` tidy is its own small kindness.

## Multiple subsystems in one run

When the project has multiple packages each emitting under their own subsystem (an app target plus framework targets, for example), widen the predicate with `OR`:

```
--predicate 'subsystem == "com.example.App" OR subsystem == "com.example.Pkg"'
```

The compact-style prefix tags each row with its subsystem, so reading stays readable across the merge.

## Worked example (from the mora repo, 2026-04-25)

Bundle `tech.reenable.Mora`, target "My Mac (Designed for iPad)", verifying that a recent PR's lifecycle logs interleave correctly during one A-day session:

```bash
# step 1 — rotate
[ -s /tmp/mora.log ] && mv /tmp/mora.log /tmp/mora.log.$(date +%H%M%S); : > /tmp/mora.log

# step 2 — stream (run_in_background=true)
/usr/bin/log stream --predicate 'subsystem == "tech.reenable.Mora"' --style compact --info --debug >> /tmp/mora.log 2>&1

# step 3 — user does ⌘R in Xcode and runs through one session.
# Claude reads /tmp/mora.log periodically; the captured timeline reads:
#
#   2026-04-25 11:29:42.692  [Session] phase notStarted→warmup
#   2026-04-25 11:29:45.910  [Session] phase warmup→newRule
#   2026-04-25 11:29:45.927  [AudioSession] TTS: /ʃ/                     ← 17 ms after the phase change
#   2026-04-25 11:29:46.178  [AudioSession] TTS: "Two letters, one sound."
#   2026-04-25 11:29:54.910  [Session] phase newRule→decoding
#   2026-04-25 11:29:54.950  [AudioSession] TTS: "cat"                   ← 40 ms after, again
#   2026-04-25 11:29:57.494  [Session] phase decoding→shortSentences
#   2026-04-25 11:29:58.626  [Speech]   mic startListening expected="The ship can hop."
#   2026-04-25 11:30:05.438  [Speech]   ASR timeout: silence=2.7s transcript="This ship can hawk"

# step 4 — cleanup
pkill -f 'log stream.*tech.reenable.Mora'
mv /tmp/mora.log /tmp/mora.log.session-$(date +%H%M%S)  # keep this run's evidence
```

That session uncovered a SwiftUI `.onChange(phase) { Task { await speech.stop() } }` race that was silencing auto-play TTS on every phase transition — invisible from screenshots, immediately obvious from the file: a new view's `speech.play(...)` would land on a row, and the very next row was a stop on the same controller cancelling it. That kind of timing-driven, multi-component bug is exactly what this skill exists to make visible.
