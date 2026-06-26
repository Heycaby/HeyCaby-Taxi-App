#!/usr/bin/env bash
# Sync chauffeur terms + support HTML from heycaby-tos into a local HeyCaby web (Next.js) clone.
# Usage:
#   export HEYCABY_WEB_ROOT=../heycaby-web   # or path to your Next.js app repo
#   ./scripts/sync-driver-legal-to-heycaby-web.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${HEYCABY_WEB_ROOT:?Set HEYCABY_WEB_ROOT to your HeyCaby web repo path}"
mkdir -p "$DEST/public/chauffeur/voorwaarden" "$DEST/public/chauffeur/vrijwaring" "$DEST/public/chauffeur/founding-member-contract" "$DEST/public/support"
cp "$ROOT/heycaby-tos/chauffeur/voorwaarden/index.html" "$DEST/public/chauffeur/voorwaarden/index.html"
cp "$ROOT/heycaby-tos/chauffeur/vrijwaring/index.html" "$DEST/public/chauffeur/vrijwaring/index.html"
cp "$ROOT/heycaby-tos/chauffeur/founding-member-contract/index.html" "$DEST/public/chauffeur/founding-member-contract/index.html"
cp "$ROOT/heycaby-tos/support/index.html" "$DEST/public/support/index.html"
echo "OK: synced into $DEST/public — commit and push your HeyCaby web deployment"
