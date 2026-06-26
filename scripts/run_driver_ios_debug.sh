#!/usr/bin/env bash
# Run HeyCaby Driver on a connected iPhone with Supabase/Mapbox dart-defines.
# Full app (no stripped features). For store-parity performance add: --release
# Usage: ./scripts/run_driver_ios_debug.sh [-d DEVICE_ID] [--release] [extra flutter run args]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 <<'PY'
import importlib.util
from pathlib import Path

spec = importlib.util.spec_from_file_location("ipa", Path("scripts/build_ios_ipas.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
env, sources = m.merge_env_for_app("driver", None)
if not sources:
    raise SystemExit(
        "No .env files found. Create repo .env and/or apps/driver/.env "
        "(see .env.example), then re-run."
    )
app = Path("apps/driver")
m.write_ipa_dart_define_json(app, env)
m.write_ios_mapbox_secrets_xcconfig(app, env)
print("Merged env from:", ", ".join(str(s) for s in sources), flush=True)
print("Wrote apps/driver/ios/.ipa_dart_defines.json + Flutter/Secrets.xcconfig", flush=True)
PY

cd "$ROOT/apps/driver"
exec flutter run --dart-define-from-file=ios/.ipa_dart_defines.json "$@"
