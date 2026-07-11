#!/bin/sh
# Flutter native-assets can cache a simulator objective_c.framework and reuse it
# on the next device build (platform 7 vs 2), causing install error 0xe8008014.
# Purging only the .framework can leave NativeAssetsManifest.json pointing at
# objective_c while build/native_assets/ios/ is empty → xcode_backend embed fails.
# See: https://github.com/flutter/flutter/issues/185667
set -eu

if [ -z "${SRCROOT:-}" ]; then
  exit 0
fi

RIDER_ROOT="${SRCROOT}/.."
FRAMEWORK="${RIDER_ROOT}/build/native_assets/ios/objective_c.framework/objective_c"
CACHE_DIR="${RIDER_ROOT}/build/native_assets/ios"
IOS_BUILD_DIR="${RIDER_ROOT}/build/ios"

invalidate_flutter_ios_artifacts() {
  echo "note: Invalidating Flutter iOS build cache so native assets recompile."
  rm -rf "${IOS_BUILD_DIR}" "${RIDER_ROOT}/.dart_tool/hooks_runner"
}

# Manifest still lists objective_c but the framework file is gone → embed step crashes.
if [ ! -f "$FRAMEWORK" ]; then
  if [ -d "${IOS_BUILD_DIR}" ] && find "${IOS_BUILD_DIR}" -path '*/App.framework/flutter_assets/NativeAssetsManifest.json' -print0 2>/dev/null \
    | xargs -0 grep -l 'objective_c' 2>/dev/null | grep -q .; then
    echo "note: Stale NativeAssetsManifest references objective_c but framework is missing."
    invalidate_flutter_ios_artifacts
    rm -rf "${CACHE_DIR}/objective_c.framework"
  fi
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
  invalidate_flutter_ios_artifacts
fi
