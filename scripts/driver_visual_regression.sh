#!/usr/bin/env bash
# HeyCaby Driver — visual regression (Phase 1.9)
#
# Usage:
#   ./scripts/driver_visual_regression.sh baseline   # freeze / update goldens
#   ./scripts/driver_visual_regression.sh compare    # pixel diff vs baseline (CI)
#   ./scripts/driver_visual_regression.sh gallery      # copy goldens → design-gallery
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIVER="$ROOT/apps/driver"
GOLDENS="$DRIVER/test/visual/goldens"
GALLERY="$ROOT/apps/driver/docs/design-gallery"
PHASE="${PHASE:-phase-1-baseline}"

cmd="${1:-compare}"

cd "$DRIVER"

case "$cmd" in
  baseline|update)
    echo "Updating visual baselines (goldens)…"
    flutter test test/visual/ --update-goldens --no-pub
    echo "Done. Commit test/visual/goldens/*.png"
    ;;
  compare|test)
    echo "Comparing against frozen baselines…"
    flutter test test/visual/ --no-pub
    ;;
  gallery)
    mkdir -p "$GALLERY/$PHASE"
    if [[ ! -d "$GOLDENS" ]]; then
      echo "No goldens at $GOLDENS — run baseline first." >&2
      exit 1
    fi
    cp -f "$GOLDENS"/*.png "$GALLERY/$PHASE/" 2>/dev/null || true
    echo "Copied goldens to $GALLERY/$PHASE/"
    ls -la "$GALLERY/$PHASE/" || true
    ;;
  *)
    echo "Unknown command: $cmd (use baseline|compare|gallery)" >&2
    exit 1
    ;;
esac
