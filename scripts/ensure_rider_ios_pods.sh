#!/usr/bin/env bash
# Ensure CocoaPods are installed for the rider iOS app (fixes "Module app_links not found").
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RIDER_IOS="$ROOT/apps/rider/ios"
PODS_XCCONFIG="$RIDER_IOS/Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
SYMLINK="$RIDER_IOS/.symlinks/plugins/app_links/ios"

needs_install=0
if [ ! -f "$PODS_XCCONFIG" ]; then
  needs_install=1
elif [ ! -d "$SYMLINK" ]; then
  needs_install=1
fi

if [ "$needs_install" -eq 0 ]; then
  exit 0
fi

echo "== rider iOS: CocoaPods out of date — running flutter pub get + pod install =="
cd "$ROOT/apps/rider"
flutter pub get
cd ios
pod install

echo "== rider iOS pods ready =="
