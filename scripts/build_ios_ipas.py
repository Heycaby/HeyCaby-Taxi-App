#!/usr/bin/env python3
"""
Build rider + driver iOS IPAs with --dart-define values from merged .env files.

Env merge order per app (later files override earlier):
  1. REPO_ROOT/.env (if present)
  2. apps/<peer>/.env (if present) — the *other* app, so shared Mapbox/Supabase
     keys kept only under apps/rider/.env still apply when building driver IPA
     (and vice versa).
  3. apps/<rider|driver>/.env (if present)
  4. --env-file / $ENV_FILE (if set and present), applied last

Only keys in ALLOW_KEYS are forwarded.

Before each `flutter build ipa`:
  • Writes `ios/Flutter/Secrets.xcconfig` (gitignored) with `MAPBOX_ACCESS_TOKEN` so Xcode
    substitutes `$(MAPBOX_ACCESS_TOKEN)` in Info.plist (`MBXAccessToken`) for the native SDK.
  • Writes `ios/.ipa_dart_defines.json` and passes `--dart-define-from-file=…` so Dart
    `String.fromEnvironment` gets the same values without fragile shell escaping (important
    for Mapbox tokens and URLs with special characters).

Usage:
  ./scripts/build_ios_ipas.sh
  ENV_FILE=~/.heycaby/extra.env ./scripts/build_ios_ipas.py --driver-only

Required after merge: SUPABASE_URL, SUPABASE_ANON_KEY, MAPBOX_ACCESS_TOKEN
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_KEYS = ("SUPABASE_URL", "SUPABASE_ANON_KEY", "MAPBOX_ACCESS_TOKEN")

# Keys that must not be wiped by a later .env file setting an empty value.
# Driver builds merge apps/driver/.env *last*; a stray `MAPBOX_ACCESS_TOKEN=`
# there would override a good token from root or apps/rider/.env and yield a
# black Mapbox map, while rider builds still "win" from apps/rider/.env last.
_EMPTY_OVERRIDE_PROTECTED_KEYS = frozenset(REQUIRED_KEYS)

ALLOW_KEYS = frozenset(
    {
        *REQUIRED_KEYS,
        "API_BASE_URL",
        "APP_PUBLIC_WEB_ORIGIN",
        "RIDER_IOS_APP_STORE_URL",
        "DRIVER_IOS_APP_STORE_URL",
        "APP_QR_MARKETING_URL",
        "MAPBOX_STYLE_DAYLIGHT",
        "MAPBOX_STYLE_FRESH",
        "MAPBOX_STYLE_BLOSSOM",
        "MAPBOX_STYLE_TAXI_SHADE_6",
        "MAPBOX_STYLE_TAXI_SHADE_2",
        "MAPBOX_STYLE_FOREST_DUSK",
        "MAPBOX_STYLE_ROSE_NOIR",
        "MAPBOX_STYLE_ALPINE_CREAM",
        "MAPBOX_STYLE_WARM_GLOSS",
        "MAPBOX_STYLE_FROSTY_BLACK_WHITE",
        "MAPBOX_STYLE_FROSTY_BLACK_YELLOW",
        "MAPBOX_STYLE_MIDNIGHT_CARBON",
        "MAPBOX_STYLE_DEFAULT",
        "MAPBOX_STYLE_NAVIGATION_DAY",
        "DRIVER_VERIFF_HVP_URL",
        "DRIVER_TERMS_URL",
        "DRIVER_TERMS_VERIFF_URL",
    }
)


def parse_env_file(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    text = path.read_text(encoding="utf-8")
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip()
        if not key:
            continue
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "'\"":
            val = val[1:-1]
        data[key] = val
    return data


def _merge_env_into(
    merged: dict[str, str],
    new_entries: dict[str, str],
    source: Path | str,
) -> None:
    for key, val in new_entries.items():
        if (
            key in _EMPTY_OVERRIDE_PROTECTED_KEYS
            and (val or "").strip() == ""
            and (merged.get(key) or "").strip() != ""
        ):
            print(
                f"Note: keeping non-empty {key} from an earlier env file "
                f"(empty value in {source} ignored)",
                file=sys.stderr,
            )
            continue
        merged[key] = val


def merge_env_for_app(app: str, extra: Path | None) -> tuple[dict[str, str], list[Path]]:
    """Merge root .env, peer app .env, apps/<app>/.env, then optional extra file."""
    merged: dict[str, str] = {}
    used: list[Path] = []
    peer = "rider" if app == "driver" else "driver"
    for p in (
        REPO_ROOT / ".env",
        REPO_ROOT / "apps" / peer / ".env",
        REPO_ROOT / "apps" / app / ".env",
    ):
        if p.is_file():
            _merge_env_into(merged, parse_env_file(p), p)
            used.append(p)
    if extra is not None:
        if extra.is_file():
            _merge_env_into(merged, parse_env_file(extra), extra)
            used.append(extra)
        else:
            print(f"Warning: extra env file missing, skipping: {extra}", file=sys.stderr)
    return merged, used


def write_ipa_dart_define_json(app_dir: Path, env: dict[str, str]) -> Path:
    """JSON for `flutter build ipa --dart-define-from-file` (robust escaping)."""
    payload = {
        k: env[k]
        for k in sorted(ALLOW_KEYS)
        if k in env and (env[k] or "").strip() != ""
    }
    out = app_dir / "ios" / ".ipa_dart_defines.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + "\n", encoding="utf-8")
    return out


def _xcconfig_value(val: str) -> str:
    """Return an xcconfig-safe single-line value for plist substitution."""
    return val.replace("\\", "\\\\").replace("\n", "").replace("\r", "")


def write_ios_mapbox_secrets_xcconfig(app_dir: Path, env: dict[str, str]) -> None:
    """So Info.plist $(MAPBOX_ACCESS_TOKEN) resolves during xcodebuild (Mapbox iOS)."""
    token = (env.get("MAPBOX_ACCESS_TOKEN") or "").strip()
    flutter_ios = app_dir / "ios" / "Flutter"
    flutter_ios.mkdir(parents=True, exist_ok=True)
    path = flutter_ios / "Secrets.xcconfig"
    if not token:
        if path.is_file():
            path.unlink()
        return
    body = (
        "// Generated by scripts/build_ios_ipas.py — do not commit (see .gitignore)\n"
        f"MAPBOX_ACCESS_TOKEN={_xcconfig_value(token)}\n"
    )
    path.write_text(body, encoding="utf-8")


def run_flutter_build(
    app_name: str,
    app_dir: Path,
    env_map: dict[str, str],
    skip_pub: bool,
) -> None:
    if not skip_pub:
        subprocess.run(
            ["flutter", "pub", "get"],
            cwd=app_dir,
            check=True,
        )
    define_path = write_ipa_dart_define_json(app_dir, env_map)
    n_defines = sum(
        1 for k in ALLOW_KEYS if (env_map.get(k) or "").strip() != ""
    )
    token_ok = (env_map.get("MAPBOX_ACCESS_TOKEN") or "").strip() != ""
    secrets = app_dir / "ios" / "Flutter" / "Secrets.xcconfig"
    print(
        f"\n=== Building {app_name} ({n_defines} keys in {define_path.name}; "
        f"MBX plist via Secrets.xcconfig: {'yes' if token_ok and secrets.is_file() else 'NO — check token'}) ===\n",
        flush=True,
    )
    cmd = [
        "flutter",
        "build",
        "ipa",
        "--release",
        "--export-options-plist=ios/ExportOptions.plist",
        f"--dart-define-from-file={define_path}",
    ]
    subprocess.run(cmd, cwd=app_dir, check=True)


def main() -> int:
    p = argparse.ArgumentParser(description="Build iOS IPAs with dart-define from .env")
    p.add_argument(
        "--env-file",
        type=Path,
        default=None,
        help="Optional extra .env merged last (default: $ENV_FILE if set)",
    )
    p.add_argument("--rider-only", action="store_true")
    p.add_argument("--driver-only", action="store_true")
    p.add_argument("--skip-pub-get", action="store_true")
    args = p.parse_args()

    extra = args.env_file
    if extra is None and os.environ.get("ENV_FILE"):
        extra = Path(os.environ["ENV_FILE"])

    do_rider = not args.driver_only
    do_driver = not args.rider_only

    try:
        if do_rider:
            env_map, sources = merge_env_for_app("rider", extra)
            if not sources:
                print(
                    "No env files found. Expected at least one of:\n"
                    f"  {REPO_ROOT / '.env'}\n"
                    f"  {REPO_ROOT / 'apps' / 'rider' / '.env'}",
                    file=sys.stderr,
                )
                return 1
            print(f"Rider env from: {', '.join(str(s) for s in sources)}", flush=True)
            missing = [k for k in REQUIRED_KEYS if not env_map.get(k, "").strip()]
            if missing:
                print(
                    f"Missing or empty required keys after merge: {', '.join(missing)}",
                    file=sys.stderr,
                )
                return 1
            unknown = sorted(k for k in env_map if k not in ALLOW_KEYS)
            if unknown:
                print(
                    f"Note: ignoring {len(unknown)} key(s) not used by Flutter: "
                    f"{', '.join(unknown[:12])}"
                    + (" …" if len(unknown) > 12 else ""),
                    flush=True,
                )
            write_ios_mapbox_secrets_xcconfig(REPO_ROOT / "apps" / "rider", env_map)
            run_flutter_build(
                "rider",
                REPO_ROOT / "apps" / "rider",
                env_map,
                args.skip_pub_get,
            )

        if do_driver:
            env_map, sources = merge_env_for_app("driver", extra)
            if not sources:
                print(
                    "No env files found. Expected at least one of:\n"
                    f"  {REPO_ROOT / '.env'}\n"
                    f"  {REPO_ROOT / 'apps' / 'driver' / '.env'}",
                    file=sys.stderr,
                )
                return 1
            print(f"Driver env from: {', '.join(str(s) for s in sources)}", flush=True)
            missing = [k for k in REQUIRED_KEYS if not env_map.get(k, "").strip()]
            if missing:
                print(
                    f"Missing or empty required keys after merge: {', '.join(missing)}",
                    file=sys.stderr,
                )
                return 1
            unknown = sorted(k for k in env_map if k not in ALLOW_KEYS)
            if unknown:
                print(
                    f"Note: ignoring {len(unknown)} key(s) not used by Flutter: "
                    f"{', '.join(unknown[:12])}"
                    + (" …" if len(unknown) > 12 else ""),
                    flush=True,
                )
            write_ios_mapbox_secrets_xcconfig(REPO_ROOT / "apps" / "driver", env_map)
            run_flutter_build(
                "driver",
                REPO_ROOT / "apps" / "driver",
                env_map,
                args.skip_pub_get,
            )
    except subprocess.CalledProcessError:
        return 1

    print("\nDone. IPAs under apps/*/build/ios/ipa/*.ipa\n", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
