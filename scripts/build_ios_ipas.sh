#!/usr/bin/env bash
# Build rider + driver release IPAs with secrets from .env as --dart-define.
# Default env file: repo root `.env`. Override: ENV_FILE=/path/to/file ./scripts/build_ios_ipas.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$ROOT/scripts/build_ios_ipas.py" "$@"
