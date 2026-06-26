#!/usr/bin/env bash
# Regenerate iOS/Android launcher icons + native splash assets from the driver wordmark.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER="$ROOT/apps/driver"
SRC="$DRIVER/assets/branding/heycaby_logo_black_yellow.png"
VENV="${TMPDIR:-/tmp}/heycaby-icon-venv"

if [[ ! -f "$SRC" ]]; then
  echo "Missing logo: $SRC" >&2
  exit 1
fi

python3 -m venv "$VENV"
"$VENV/bin/pip" install -q pillow

"$VENV/bin/python3" <<PY
from PIL import Image
from pathlib import Path

ROOT = Path("$DRIVER")
SRC = Path("$SRC")
OUT_SQUARE = ROOT / 'assets/branding/heycaby_app_icon_source.png'

img = Image.open(SRC).convert('RGBA')
size = 1024
canvas = Image.new('RGBA', (size, size), (0, 0, 0, 255))
max_w = int(size * 0.82)
max_h = int(size * 0.82)
ratio = min(max_w / img.width, max_h / img.height)
logo = img.resize((int(img.width * ratio), int(img.height * ratio)), Image.Resampling.LANCZOS)
x = (size - logo.width) // 2
y = (size - logo.height) // 2
canvas.paste(logo, (x, y), logo)
canvas = canvas.convert('RGB')
canvas.save(OUT_SQUARE, 'PNG', optimize=True)

ios_dir = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for name, px in {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167, 'Icon-App-1024x1024@1x.png': 1024,
}.items():
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(ios_dir / name, 'PNG', optimize=True)

for rel, px in {
    'mipmap-mdpi/ic_launcher.png': 48, 'mipmap-hdpi/ic_launcher.png': 72,
    'mipmap-xhdpi/ic_launcher.png': 96, 'mipmap-xxhdpi/ic_launcher.png': 144,
    'mipmap-xxxhdpi/ic_launcher.png': 192,
}.items():
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(ROOT / 'android/app/src/main/res' / rel, 'PNG', optimize=True)

launch = ROOT / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
for name, px in [('LaunchImage.png', 512), ('LaunchImage@2x.png', 1024), ('LaunchImage@3x.png', 1536)]:
    canvas.resize((px, px), Image.Resampling.LANCZOS).save(launch / name, 'PNG', optimize=True)

nodpi = ROOT / 'android/app/src/main/res/drawable-nodpi'
nodpi.mkdir(parents=True, exist_ok=True)
canvas.resize((512, 512), Image.Resampling.LANCZOS).save(nodpi / 'splash_logo.png', 'PNG', optimize=True)
print('Driver app icons regenerated.')
PY

echo "App Store marketing icon: $DRIVER/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
