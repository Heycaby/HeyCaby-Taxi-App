#!/usr/bin/env bash
# Regenerate rider + driver launcher icons from AI/design masters.
# Rider: white background, chunky stacked green Hey / Caby.
# Driver: dark green background, chunky stacked white Hey / Caby.
# Place or update masters at apps/<app>/assets/branding/heycaby_app_icon_source.png
# Usage: ./scripts/generate_app_icons.sh [rider|driver|all]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="${TMPDIR:-/tmp}/heycaby-icon-venv"
TARGET="${1:-all}"

python3 -m venv "$VENV" >/dev/null 2>&1 || true
"$VENV/bin/pip" install -q pillow

case "$TARGET" in
  rider|driver|all) ;;
  *)
    echo "Usage: $0 [rider|driver|all]" >&2
    exit 1
    ;;
esac

"$VENV/bin/python3" "$ROOT/scripts/generate_heycaby_brand_app_icons.py" --target "$TARGET"
