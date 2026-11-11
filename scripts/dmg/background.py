"""Draws scripts/dmg/background.tiff, the window of the disk image: the green of dimmela.app's
hero, an arrow from Dimmela to Applications and a line under the icons with the shortcut as the
site draws its keys. Rendered with Google Chrome at 1× and 2×, joined by tiffutil so Finder picks
the sharp one on Retina screens. The icon positions in make-dmg.sh match ICON_Y, DIMMELA_X and
APPLICATIONS_X. From Takku's.

    python3 scripts/dmg/background.py
"""
import math
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

WIDTH, HEIGHT = 640, 400
ICON_Y, DIMMELA_X, APPLICATIONS_X = 200, 175, 465

# A soft curve over the gap between the icons, its head along the curve's last direction.
start, end = DIMMELA_X + 82, APPLICATIONS_X - 86
mid, top = (start + end) / 2, ICON_Y - 46
angle = math.atan2((ICON_Y - 6) - top, end - mid)
head = [
    (end - 15 * math.cos(angle + side * 0.55), ICON_Y - 6 - 15 * math.sin(angle + side * 0.55)) for side in (-1, 1)
]
arrow = (
    f"M{start} {ICON_Y - 6} Q{mid} {top} {end} {ICON_Y - 6}"
    f"M{head[0][0]:.1f} {head[0][1]:.1f} L{end} {ICON_Y - 6} L{head[1][0]:.1f} {head[1][1]:.1f}"
)

page = f"""<!doctype html>
<html><head><meta charset="utf-8"><style>
  html, body {{ margin: 0; width: {WIDTH}px; height: {HEIGHT}px; overflow: hidden; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
    color: #04220f;
    background:
      radial-gradient(90% 70% at 50% -10%, #8ff5a4 0%, transparent 60%),
      radial-gradient(70% 60% at 100% 100%, #2fbf68 0%, transparent 70%),
      linear-gradient(180deg, #74ee8e 0%, #5ee079 45%, #39c970 100%);
  }}
  svg {{ position: absolute; inset: 0; }}
  h1 {{
    position: absolute; top: 46px; left: 0; right: 0; margin: 0; text-align: center;
    font-size: 26px; font-weight: 700; letter-spacing: -0.5px;
  }}
  .then {{
    position: absolute; top: 322px; left: 0; right: 0; margin: 0; text-align: center;
    font-size: 14px; color: rgba(4, 34, 15, .78);
    display: flex; justify-content: center; align-items: center; gap: 6px;
  }}
  .key {{
    display: inline-flex; align-items: center; justify-content: center; gap: 4px;
    min-width: 22px; height: 24px; padding: 0 9px; border-radius: 6px;
    font-size: 12px; font-weight: 600; color: #3a3a3c;
    background: linear-gradient(#ffffff, #f4f4f6);
    box-shadow: 0 0 0 .5px rgba(0,0,0,.14), 0 1px 0 rgba(0,0,0,.10), 0 3px 6px -2px rgba(0,0,0,.16);
  }}
  .space {{ min-width: 64px; }}
</style></head><body>
<h1>Drag Dimmela into Applications</h1>
<svg viewBox="0 0 {WIDTH} {HEIGHT}" fill="none" stroke-linecap="round" stroke-linejoin="round">
  <path d="{arrow}" stroke="#04220f" stroke-opacity="0.72" stroke-width="3.5"/>
</svg>
<p class="then">Then open it and hold
  <span class="key">fn <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="#3a3a3c" stroke-width="2.2"
    style="position: static"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/></svg></span>
  <span class="key space">space</span> to dictate.</p>
</body></html>"""

with tempfile.TemporaryDirectory() as tmp:
    html = Path(tmp) / "background.html"
    html.write_text(page)
    pngs = []
    for scale in (1, 2):
        png = Path(tmp) / f"background-{scale}x.png"
        subprocess.run(
            [
                CHROME, "--headless", "--disable-gpu", "--hide-scrollbars", f"--force-device-scale-factor={scale}",
                "--virtual-time-budget=2000", f"--window-size={WIDTH},{HEIGHT}", f"--screenshot={png}", html.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        pngs.append(str(png))
    # 72 and 144 dpi, so Finder lays both out at 640 × 400 points.
    subprocess.run(["sips", "-s", "dpiWidth", "144", "-s", "dpiHeight", "144", pngs[1]], check=True, capture_output=True)
    subprocess.run(["tiffutil", "-cathidpicheck", *pngs, "-out", str(HERE / "background.tiff")], check=True, capture_output=True)
print(f"background.tiff: {(HERE / 'background.tiff').stat().st_size // 1024} KB")
