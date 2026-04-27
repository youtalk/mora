#!/usr/bin/env bash
# Render every 1920×1080 board in docs/og.html to a PNG under docs/img/og/.
#
# Each board lives at the URL fragment #native-XX. The gallery page uses
# :has(.thumb:target) to swap into a fullscreen, native-size view of just
# that board, which lets headless Chrome capture a pixel-perfect 1920×1080
# screenshot per pattern.
#
# Usage: tools/og/render-og.sh [pattern_number...]
#   tools/og/render-og.sh                 # render 01..06
#   tools/og/render-og.sh 03 05           # render only those

set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="file://${REPO}/docs/og.html"
OUT="${REPO}/docs/img/og"

if [[ ! -x "$CHROME" ]]; then
  echo "Could not find Chrome at: $CHROME" >&2
  exit 1
fi

mkdir -p "$OUT"

patterns=("$@")
if [[ ${#patterns[@]} -eq 0 ]]; then
  patterns=(01 02 03 04 05 06 01-dyslexic)
fi

# Resolve `01-dyslexic` (and similar aliases) to the gallery anchor that
# actually carries that variant. `01-dyslexic` lives under #native-07 and
# is rendered to docs/img/og/og-01-dyslexic.png.
resolve_anchor() {
  case "$1" in
    01-dyslexic) echo 07 ;;
    *)           echo "$1" ;;
  esac
}

# Headless Chrome reserves ~90px at the bottom of the screenshot for browser
# chrome that isn't actually rendered. Render at 1920×1170 then crop the top
# 1080 to get a clean 1920×1080 image with no body-bg band at the bottom.
WIN_W=1920
WIN_H=1170
CROP_H=1080

pids=()
for p in "${patterns[@]}"; do
  anchor="$(resolve_anchor "$p")"
  out_file="${OUT}/og-${p}.png"
  echo "→ rendering ${SRC}#native-${anchor} to ${out_file}"
  "$CHROME" \
    --headless=new --disable-gpu --no-sandbox \
    --hide-scrollbars \
    --window-size=${WIN_W},${WIN_H} \
    --force-device-scale-factor=1 \
    --virtual-time-budget=4000 \
    --screenshot="$out_file" \
    "${SRC}#native-${anchor}" >/dev/null 2>&1 &
  pids+=($!)
done

for pid in "${pids[@]}"; do
  wait "$pid"
done

# Crop the top 1920×1080 from each rendered PNG via Python.
# Headless Chrome's screenshot includes ~90px of reserved chrome at the bottom
# that isn't actually rendered, so the bottom of the screenshot is body-bg.
# sips --cropToHeightWidth crops from CENTER (not top), so use Python instead.
PY_BIN="${PY_BIN:-/tmp/og-venv/bin/python3}"
if [[ ! -x "$PY_BIN" ]]; then
  PY_BIN="$(command -v python3 || true)"
fi
if [[ -x "$PY_BIN" ]]; then
  "$PY_BIN" - "$CROP_H" "$WIN_W" "${patterns[@]/#/${OUT}/og-}" <<'PY' || true
import sys
try:
    from PIL import Image
except ModuleNotFoundError:
    print("Pillow not available — skipping crop. Install with: /tmp/og-venv/bin/pip install Pillow", file=sys.stderr)
    sys.exit(0)
crop_h = int(sys.argv[1]); crop_w = int(sys.argv[2])
for path in sys.argv[3:]:
    if not path.endswith('.png'):
        path = path + '.png'
    try:
        img = Image.open(path)
    except FileNotFoundError:
        continue
    cropped = img.crop((0, 0, crop_w, crop_h))
    cropped.save(path)
PY
fi

echo
echo "Rendered ${#patterns[@]} pattern(s) to ${OUT}:"
for p in "${patterns[@]}"; do
  ls -lh "${OUT}/og-${p}.png" 2>/dev/null || true
done
