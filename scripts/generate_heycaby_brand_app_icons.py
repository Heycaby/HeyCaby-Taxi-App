#!/usr/bin/env python3
"""
Export HeyCaby rider/driver app icons for iOS + Android.

Default mode reads AI/design masters from:
  apps/<app>/assets/branding/heycaby_app_icon_source.png

Apple HIG / App Store:
  • 1024×1024 marketing icon — opaque RGB (no alpha)
  • Square artwork (iOS applies the mask)
  • All required AppIcon.appiconset sizes

Rider master: white background, green stacked Hey / Caby (#1A5C45)
Driver master: dark green background (#1A5C45), white stacked Hey / Caby
"""
from __future__ import annotations

import argparse
import sys
from collections import deque
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent

HEYCABY_GREEN = (26, 92, 69)  # #1A5C45
WHITE = (255, 255, 255)

IOS_SIZES = {
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
}

ANDROID_SIZES = {
    "mipmap-mdpi/ic_launcher.png": 48,
    "mipmap-hdpi/ic_launcher.png": 72,
    "mipmap-xhdpi/ic_launcher.png": 96,
    "mipmap-xxhdpi/ic_launcher.png": 144,
    "mipmap-xxxhdpi/ic_launcher.png": 192,
}


def prepare_square_icon(src: Path, bg: tuple[int, int, int], size: int = 1024) -> Image.Image:
    """Flatten AI previews onto a full square, opaque App Store icon."""
    img = Image.open(src).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    px = img.load()
    outer = set()
    q = deque([(0, 0), (0, size - 1), (size - 1, 0), (size - 1, size - 1)])

    def is_corner_artifact(x: int, y: int) -> bool:
        r, g, b, a = px[x, y]
        if a < 20:
            return True
        if sum(bg) > 600:
            return r < 20 and g < 20 and b < 20
        return r > 235 and g > 235 and b > 235

    while q:
        x, y = q.popleft()
        if (x, y) in outer or not (0 <= x < size and 0 <= y < size):
            continue
        if not is_corner_artifact(x, y):
            continue
        outer.add((x, y))
        q.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    out = Image.new("RGB", (size, size), bg)
    out_px = out.load()
    for y in range(size):
        for x in range(size):
            if (x, y) in outer:
                out_px[x, y] = bg
                continue
            r, g, b, a = px[x, y]
            if a < 255:
                ar = a / 255.0
                out_px[x, y] = (
                    int(r * ar + bg[0] * (1 - ar)),
                    int(g * ar + bg[1] * (1 - ar)),
                    int(b * ar + bg[2] * (1 - ar)),
                )
            else:
                out_px[x, y] = (r, g, b)
    return out


def write_icon_set(app_dir: Path, canvas: Image.Image, label: str) -> None:
    src = app_dir / "assets" / "branding" / "heycaby_app_icon_source.png"
    src.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(src, "PNG", optimize=True)

    ios_dir = app_dir / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_dir.mkdir(parents=True, exist_ok=True)
    for name, px in IOS_SIZES.items():
        out = canvas.resize((px, px), Image.Resampling.LANCZOS)
        if out.mode != "RGB":
            out = out.convert("RGB")
        out.save(ios_dir / name, "PNG", optimize=True)

    android_res = app_dir / "android" / "app" / "src" / "main" / "res"
    for rel, px in ANDROID_SIZES.items():
        out_path = android_res / rel
        out_path.parent.mkdir(parents=True, exist_ok=True)
        canvas.resize((px, px), Image.Resampling.LANCZOS).save(
            out_path, "PNG", optimize=True
        )

    nodpi = android_res / "drawable-nodpi"
    nodpi.mkdir(parents=True, exist_ok=True)
    canvas.resize((512, 512), Image.Resampling.LANCZOS).save(
        nodpi / "splash_logo.png", "PNG", optimize=True
    )

    launch = app_dir / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    launch.mkdir(parents=True, exist_ok=True)
    for name, px in [
        ("LaunchImage.png", 512),
        ("LaunchImage@2x.png", 1024),
        ("LaunchImage@3x.png", 1536),
    ]:
        canvas.resize((px, px), Image.Resampling.LANCZOS).save(
            launch / name, "PNG", optimize=True
        )

    print(f"{label}: wrote {src}")
    print(f"{label}: App Store icon -> {ios_dir / 'Icon-App-1024x1024@1x.png'}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=("rider", "driver", "all"), default="all")
    args = parser.parse_args()

    targets: list[tuple[str, Path, tuple[int, int, int]]] = []
    if args.target in ("rider", "all"):
        targets.append(("Rider", REPO / "apps" / "rider", WHITE))
    if args.target in ("driver", "all"):
        targets.append(("Driver", REPO / "apps" / "driver", HEYCABY_GREEN))

    for label, app_dir, bg in targets:
        src = app_dir / "assets" / "branding" / "heycaby_app_icon_source.png"
        if not src.is_file():
            print(f"Missing icon master: {src}", file=sys.stderr)
            return 1
        canvas = prepare_square_icon(src, bg)
        write_icon_set(app_dir, canvas, label)

    print("\nDone. Exported stacked Hey/Caby masters to all launcher sizes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
