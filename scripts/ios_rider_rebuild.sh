#!/usr/bin/env bash
# Full clean iOS workspace for rider (Pods + Flutter build). Use after Xcode/Flutter upgrades
# or odd errors (e.g. native_assets / SdkRoot / stale embed).
# Does NOT disable Impeller, strip plugins, or use "minimal" defines.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/apps/rider"

echo "== flutter clean =="
flutter clean

echo "== remove iOS ephemeral pods / lock (will pod install) =="
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter/Flutter.podspec 2>/dev/null || true
rm -rf build build/native_assets .dart_tool/hooks_runner 2>/dev/null || true

echo "== pub get =="
flutter pub get

echo "== pod install =="
cd ios
pod install --repo-update

echo "Done. Run on device (full secrets from .env):"
echo "  cd $ROOT && ./scripts/run_rider_ios_debug.sh -d <DEVICE_ID>"
echo "Store-parity (release/AOT, still full app):"
echo "  ./scripts/run_rider_ios_debug.sh --release -d <DEVICE_ID>"
