# tools/yokai-forge/scripts/make_mouth_sketches.py
"""Render per-phoneme mouth-shape line art as Canny condition input for the
FLUX ControlNet-Canny pipeline.

Each sketch is a 1024x1024 white canvas with thin black edges drawn only in
the face-forward mouth region (a ~320x220 box centered around the face
position of a 3/4 body portrait). Everything outside that box stays white so
the ControlNet leaves body / decor / color free while constraining the
mouth shape.

Outputs:
    refs/mouth_canny/<phoneme>.png

Usage:
    python scripts/make_mouth_sketches.py
"""
from __future__ import annotations
import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "refs" / "mouth_canny"

CANVAS = 1024
# Approximate face-forward mouth center for a 3/4 body portrait.
CX, CY = 512, 440
STROKE = 4


def _base() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (CANVAS, CANVAS), "white")
    return img, ImageDraw.Draw(img)


def _ellipse(draw: ImageDraw.ImageDraw, cx: int, cy: int, w: int, h: int, *, fill=None) -> None:
    draw.ellipse(
        (cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2),
        outline="black", width=STROKE, fill=fill,
    )


def sketch_sh() -> Image.Image:
    """/ʃ/ — lips rounded into a tight forward-pushed pucker, small round opening, no teeth or tongue visible."""
    img, d = _base()
    # Outer lip: a small vertical tear-drop / pucker, wider at bottom
    _ellipse(d, CX, CY, 110, 140)
    # Inner opening: small round hole at the center
    _ellipse(d, CX, CY, 36, 40)
    return img


def sketch_th() -> Image.Image:
    """/θ/ — tongue tip pinched between upper and lower front teeth."""
    img, d = _base()
    # Outer mouth oval (wide)
    _ellipse(d, CX, CY, 260, 150)
    # Upper lip inside line
    d.line((CX - 110, CY - 30, CX + 110, CY - 30), fill="black", width=STROKE)
    # Upper teeth row: short vertical tick marks dropping from upper lip line
    for dx in range(-90, 91, 30):
        d.line((CX + dx, CY - 30, CX + dx, CY - 5), fill="black", width=STROKE - 1)
    # Lower teeth row: short vertical tick marks rising from lower lip line
    for dx in range(-90, 91, 30):
        d.line((CX + dx, CY + 5, CX + dx, CY + 30), fill="black", width=STROKE - 1)
    # Lower lip inside line
    d.line((CX - 110, CY + 30, CX + 110, CY + 30), fill="black", width=STROKE)
    # Tongue: flat horizontal oval pinched between the teeth rows, extending slightly past
    _ellipse(d, CX, CY, 180, 14)
    return img


def sketch_f() -> Image.Image:
    """/f/ — upper front teeth biting the middle of the lower lip, mouth mostly closed."""
    img, d = _base()
    # Upper lip curled up (slight M shape — two arcs)
    d.arc((CX - 110, CY - 60, CX - 10, CY + 10), start=180, end=0, fill="black", width=STROKE)
    d.arc((CX + 10, CY - 60, CX + 110, CY + 10), start=180, end=0, fill="black", width=STROKE)
    # Upper teeth row: small rectangles under the upper lip
    for dx in range(-90, 91, 26):
        d.rectangle(
            (CX + dx - 9, CY - 15, CX + dx + 9, CY + 20),
            outline="black", width=STROKE - 1, fill="white",
        )
    # Lower lip: a long horizontal arc being pressed down in the middle (concave top)
    d.arc((CX - 140, CY + 10, CX + 140, CY + 100), start=180, end=360, fill="black", width=STROKE)
    # The bite contact point: a short horizontal line where teeth meet lower lip
    d.line((CX - 60, CY + 22, CX + 60, CY + 22), fill="black", width=STROKE)
    return img


def sketch_r() -> Image.Image:
    """/r/ — mouth open in a tall vertical oval, tongue curled up and back."""
    img, d = _base()
    # Mouth: tall vertical oval
    _ellipse(d, CX, CY, 160, 230)
    # Tongue: curled shape — a wave rising from the bottom and curling back
    # Bottom base
    d.arc((CX - 80, CY + 50, CX + 80, CY + 130), start=0, end=180, fill="black", width=STROKE)
    # Curl stem: vertical line going up
    d.line((CX - 40, CY + 90, CX - 40, CY - 10), fill="black", width=STROKE)
    # Curl top: arc curling back
    d.arc((CX - 60, CY - 40, CX + 20, CY + 20), start=180, end=360, fill="black", width=STROKE)
    # Small fangs at the top corners of the mouth
    d.polygon(
        [(CX - 70, CY - 100), (CX - 55, CY - 60), (CX - 40, CY - 100)],
        outline="black", width=STROKE - 1, fill="white",
    )
    d.polygon(
        [(CX + 70, CY - 100), (CX + 55, CY - 60), (CX + 40, CY - 100)],
        outline="black", width=STROKE - 1, fill="white",
    )
    return img


def sketch_short_a() -> Image.Image:
    """/æ/ — jaw dropped wide, mouth a tall round oval, tongue flat and low."""
    img, d = _base()
    # Big tall oval mouth
    _ellipse(d, CX, CY, 220, 300)
    # Lip thickness — a second oval slightly smaller inside (creates lip edge)
    _ellipse(d, CX, CY, 190, 270)
    # Tongue: flat arc near the bottom of the mouth
    d.arc((CX - 75, CY + 90, CX + 75, CY + 140), start=0, end=180, fill="black", width=STROKE)
    # Back-of-throat hint: small darker arc at the back
    d.arc((CX - 40, CY + 40, CX + 40, CY + 80), start=180, end=360, fill="black", width=STROKE - 1)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for phoneme, fn in [
        ("sh", sketch_sh),
        ("th", sketch_th),
        ("f", sketch_f),
        ("r", sketch_r),
        ("short_a", sketch_short_a),
    ]:
        img = fn()
        path = OUT / f"{phoneme}.png"
        img.save(path)
        print(f"wrote {path}")


if __name__ == "__main__":
    main()
