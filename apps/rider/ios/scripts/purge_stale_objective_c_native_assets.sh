#!/bin/sh
# Flutter native-assets can cache a simulator objective_c.framework and reuse it
# on the next device build (platform 7 vs 2), causing install error 0xe8008014.
# See: https://github.com/flutter/flutter/issues/185667
set -eu

if [ -z "${SRCROOT:-}" ]; then
  exit 0
fi

FRAMEWORK="${SRCROOT}/../build/native_assets/ios/objective_c.framework/objective_c"
CACHE_DIR="${SRCROOT}/../build/native_assets/ios"

if [ ! -f "$FRAMEWORK" ]; then
  exit 0
fi

PLATFORM="$(otool -l "$FRAMEWORK" 2>/dev/null | awk '/LC_BUILD_VERSION/{getline; getline; if ($1=="platform") {print $2; exit}}')"
if [ -z "$PLATFORM" ]; then
  exit 0
fi

EXPECTED=2
if [ "${PLATFORM_NAME:-iphoneos}" = "iphonesimulator" ]; then
  EXPECTED=7
fi

if [ "$PLATFORM" != "$EXPECTED" ]; then
  echo "note: Purging stale objective_c native asset (platform ${PLATFORM}, expected ${EXPECTED} for ${PLATFORM_NAME})."
  rm -rf "${CACHE_DIR}/objective_c.framework"
fi
