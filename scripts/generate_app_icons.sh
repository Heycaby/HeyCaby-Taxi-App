#!/usr/bin/env bash
# Regenerate iOS/Android launcher icons + native splash assets from 1024×1024 masters.
# Usage: ./scripts/generate_app_icons.sh [rider|driver|all]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${TMPDIR:-/tmp}/heycaby-icon-venv"
TARGET="${1:-all}"

RIDER_SRC="$ROOT/apps/rider/assets/branding/heycaby_app_icon_source.png"
DRIVER_SRC="$ROOT/apps/driver/assets/branding/heycaby_app_icon_source.png"

python3 -m venv "$VENV" >/dev/null 2>&1 || true
"$VENV/bin/pip" install -q pillow

generate_for_app() {
  local app_name="$1"
  local app_dir="$2"
  local src="$3"
  local bg_r="$4"
  local bg_g="$5"
  local bg_b="$6"

  if [[ ! -f "$src" ]]; then
    echo "Missing icon source: $src" >&2
    exit 1
  fi

  "$VENV/bin/python3" <<PY
from collections import deque
from pathlib import Path
from PIL import Image

APP_DIR = Path("$app_dir")
SRC = Path("$src")
BG = ($bg_r, $bg_g, $bg_b)
SIZE = 1024

def prepare_square_icon(src: Path) -> Image.Image:
    """Flatten AI squircle previews onto a full square App Store icon."""
    img = Image.open(src).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    px = img.load()
    outer = set()
    q = deque([(0, 0), (0, SIZE - 1), (SIZE - 1, 0), (SIZE - 1, SIZE - 1)])

    def is_corner_artifact(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        if a < 20:
            return True
        if sum(BG) > 600:
            return r < 20 and g < 20 and b < 20
        return r > 235 and g > 235 and b > 235

    while q:
        x, y = q.popleft()
        if (x, y) in outer or not (0 <= x < SIZE and 0 <= y < SIZE):
            continue
        if not is_corner_artifact(x, y):
            continue
        outer.add((x, y))
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    out = Image.new("RGB", (SIZE, SIZE), BG)
    out_px = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if (x, y) in outer:
                out_px[x, y] = BG
                continue
            r, g, b, a = px[x, y]
            if a < 255:
                ar = a / 255.0
                out_px[x, y] = (
                    int(r * ar + BG[0] * (1 - ar)),
                    int(g * ar + BG[1] * (1 - ar)),
                    int(b * ar + BG[2] * (1 - ar)),
                )
            else:
                out_px[x, y] = (r, g, b)
    return out

canvas = prepare_square_icon(SRC)
canvas.save(SRC, "PNG", optimize=True)

ios_dir = APP_DIR / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ios_dir.mkdir(parents=True, exist_ok=True)
for name, px in {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}.items():
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(ios_dir / name, "PNG", optimize=True)

for rel, px in {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}.items():
    out = APP_DIR / "android/app/src/main/res" / rel
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(out, "PNG", optimize=True)

launch = APP_DIR / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
launch.mkdir(parents=True, exist_ok=True)
for name, px in [("LaunchImage.png", 512), ("LaunchImage@2x.png", 1024), ("LaunchImage@3x.png", 1536)]:
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(launch / name, "PNG", optimize=True)

nodpi = APP_DIR / "android/app/src/main/res/drawable-nodpi"
nodpi.mkdir(parents=True, exist_ok=True)
canvas.resize((512, 512), Image.Resampling.LANCZOS).save(nodpi / "splash_logo.png", "PNG", optimize=True)

print(f"{APP_DIR.name} app icons regenerated.")
print(f"App Store icon: {ios_dir / 'Icon-App-1024x1024@1x.png'}")
PY
}

case "$TARGET" in
  rider)
    generate_for_app rider "$ROOT/apps/rider" "$RIDER_SRC" 255 255 255
    ;;
  driver)
    generate_for_app driver "$ROOT/apps/driver" "$DRIVER_SRC" 26 92 69
    ;;
  all)
    generate_for_app rider "$ROOT/apps/rider" "$RIDER_SRC" 255 255 255
    generate_for_app driver "$ROOT/apps/driver" "$DRIVER_SRC" 26 92 69
    ;;
  *)
    echo "Usage: $0 [rider|driver|all]" >&2
    exit 1
    ;;
esac
