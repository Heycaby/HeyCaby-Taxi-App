#!/usr/bin/env python3
"""
Generate HeyCaby rider/driver app icons from brand wordmarks.

Apple HIG / App Store:
  • 1024×1024 master, opaque RGB PNG (no alpha on marketing icon)
  • Square artwork — iOS applies the mask; do not bake corner radius
  • Bold, centered mark with safe margins for home-screen clipping
  • All required iPhone icon sizes in AppIcon.appiconset

Rider: white background, HeyCaby green wordmark (#1A5C45)
Driver: dark green background (#1A5C45), white HeyCaby wordmark
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent

# Taxi theme accent from packages/heycaby_ui (matches generate_app_icons.sh driver bg).
HEYCABY_GREEN = (26, 92, 69)  # #1A5C45
WHITE = (255, 255, 255)

WORDMARK = "HeyCaby"

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


def _pick_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for path in candidates:
        p = Path(path)
        if not p.is_file():
            continue
        try:
            return ImageFont.truetype(str(p), size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def render_wordmark_icon(
    *,
    background: tuple[int, int, int],
    foreground: tuple[int, int, int],
    size: int = 1024,
) -> Image.Image:
    """Opaque square icon with centered HeyCaby wordmark."""
    img = Image.new("RGB", (size, size), background)
    draw = ImageDraw.Draw(img)

    # Large centered wordmark stays legible on 60pt home-screen icons.
    font_size = int(size * 0.21)
    font = _pick_font(font_size)

    bbox = draw.textbbox((0, 0), WORDMARK, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    x = (size - text_w) // 2 - bbox[0]
    y = (size - text_h) // 2 - bbox[1]

    draw.text((x, y), WORDMARK, fill=foreground, font=font)
    return img


def write_icon_set(app_dir: Path, canvas: Image.Image, label: str) -> None:
    src = app_dir / "assets" / "branding" / "heycaby_app_icon_source.png"
    src.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(src, "PNG", optimize=True)

    ios_dir = app_dir / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_dir.mkdir(parents=True, exist_ok=True)
    for name, px in IOS_SIZES.items():
        out = canvas.resize((px, px), Image.Resampling.LANCZOS)
        if name == "Icon-App-1024x1024@1x.png":
            # App Store Connect rejects alpha on the marketing icon.
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

    targets: list[tuple[str, Path, tuple[int, int, int], tuple[int, int, int]]] = []
    if args.target in ("rider", "all"):
        targets.append(
            (
                "Rider",
                REPO / "apps" / "rider",
                WHITE,
                HEYCABY_GREEN,
            )
        )
    if args.target in ("driver", "all"):
        targets.append(
            (
                "Driver",
                REPO / "apps" / "driver",
                HEYCABY_GREEN,
                WHITE,
            )
        )

    for label, app_dir, bg, fg in targets:
        canvas = render_wordmark_icon(background=bg, foreground=fg)
        write_icon_set(app_dir, canvas, label)

    print("\nDone. Icons follow Apple square opaque 1024 marketing spec.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
