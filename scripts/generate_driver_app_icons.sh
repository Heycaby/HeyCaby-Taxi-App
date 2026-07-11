#!/usr/bin/env bash
# Back-compat wrapper — use scripts/generate_app_icons.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/generate_app_icons.sh" driver "$@"
