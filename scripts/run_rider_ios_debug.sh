#!/usr/bin/env bash
# Run HeyCaby Rider on a connected iPhone with Supabase/Mapbox dart-defines.
# Full app (no stripped features). For store-parity performance add: --release
# Usage: ./scripts/run_rider_ios_debug.sh [-d DEVICE_ID] [--release] [extra flutter run args]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 <<'PY'
import importlib.util
import os
from pathlib import Path

spec = importlib.util.spec_from_file_location("ipa", Path("scripts/build_ios_ipas.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
extra = Path(os.environ["ENV_FILE"]) if os.environ.get("ENV_FILE") else None
env, sources = m.merge_env_for_app("rider", extra)
if not sources:
    raise SystemExit(
        "No .env files found. Create repo .env and/or apps/rider/.env "
        "(see .env.example), then re-run."
    )
app = Path("apps/rider")
m.write_ipa_dart_define_json(app, env)
m.write_ios_mapbox_secrets_xcconfig(app, env)
print("Merged env from:", ", ".join(str(s) for s in sources), flush=True)
print("Wrote apps/rider/ios/.ipa_dart_defines.json + Flutter/Secrets.xcconfig", flush=True)
PY

cd "$ROOT/apps/rider"

"$ROOT/scripts/ensure_rider_ios_pods.sh"

# Prefer a connected physical iPhone when -d is omitted (full device QA path).
args=("$@")
has_device=0
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    -d|--device-id) has_device=1; break ;;
  esac
done

if [ "$has_device" -eq 0 ]; then
  device_id="$(
    flutter devices --machine 2>/dev/null | python3 - <<'PY'
import json, sys

devices = json.load(sys.stdin)
physical = [
    d for d in devices
    if d.get("targetPlatform") == "ios" and not d.get("emulator", False)
]
physical.sort(key=lambda d: 0 if d.get("ephemeral", True) else 1)
if physical:
    print(physical[0]["id"])
PY
  )" || true
  if [ -n "${device_id:-}" ]; then
    echo "Using physical iPhone: ${device_id}" >&2
    args=(-d "$device_id" "${args[@]}")
  else
    echo "No physical iPhone found. Pass a simulator explicitly, e.g.:" >&2
    echo "  ./scripts/run_rider_ios_debug.sh -d \"iPhone 17 Pro\"" >&2
    exit 1
  fi
fi

echo "Launching with ios/.ipa_dart_defines.json (Supabase + Mapbox secrets)" >&2
exec flutter run --dart-define-from-file=ios/.ipa_dart_defines.json "${args[@]}"
