#!/usr/bin/env bash
# Regenerate rider + driver launcher icons from HeyCaby wordmarks.
# Rider: white background, green HeyCaby text.
# Driver: dark green background, white HeyCaby text.
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
